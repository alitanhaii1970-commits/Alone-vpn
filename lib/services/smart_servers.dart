import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/vpngate.dart';
import 'vpngate_api.dart';

/// Where the cached relay list (and the Smart settings) live.
abstract class SmartCacheStorage {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> data);
}

class MemorySmartCache implements SmartCacheStorage {
  MemorySmartCache([this.data]);
  Map<String, Object?>? data;
  @override
  Future<Map<String, Object?>?> read() async => data == null ? null : Map<String, Object?>.of(data!);
  @override
  Future<void> write(Map<String, Object?> d) async => data = Map<String, Object?>.of(d);
}

/// A JSON file in the app's private folder (same strategy as the settings file).
class FileSmartCache implements SmartCacheStorage {
  File? _file;
  bool _resolved = false;

  File? _resolve() {
    if (_resolved) return _file;
    _resolved = true;
    try {
      final tmp = Directory.systemTemp;
      for (final d in <Directory>[Directory('${tmp.parent.path}/files'), Directory('${tmp.parent.path}/app_flutter'), Directory('${tmp.path}/alone')]) {
        try {
          if (!d.existsSync()) d.createSync(recursive: true);
          _file = File('${d.path}/alone_vpngate_cache.json');
          return _file;
        } catch (_) {}
      }
    } catch (_) {}
    return _file;
  }

  @override
  Future<Map<String, Object?>?> read() async {
    try {
      final f = _resolve();
      if (f == null || !f.existsSync()) return null;
      final j = jsonDecode(await f.readAsString());
      return j is Map ? Map<String, Object?>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, Object?> data) async {
    try {
      final f = _resolve();
      if (f == null) return;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }
}

/// Owns the list of VPN Gate relays: fetch, validate, cache, rank, and hand out candidates.
/// The relays are volunteer-run public infrastructure, never ALONE servers.
class SmartServerManager extends ChangeNotifier {
  SmartServerManager({
    SmartCacheStorage? storage,
    Future<String> Function()? fetcher,
    DateTime Function()? now,
    this.maxAge = const Duration(minutes: 30),
    this.keep = 60,
  })  : _storage = storage ?? MemorySmartCache(),
        _fetcher = fetcher ?? fetchVpnGateCsv,
        _now = now ?? DateTime.now;

  static final SmartServerManager I = SmartServerManager(storage: FileSmartCache());

  final SmartCacheStorage _storage;
  final Future<String> Function() _fetcher;
  final DateTime Function() _now;
  final Duration maxAge;
  final int keep;

  List<VpnGateServer> servers = const <VpnGateServer>[];
  DateTime? fetchedAt;
  bool fromCache = false;
  bool loading = false;
  String? lastError;
  Map<String, int> lastRejected = const <String, int>{};

  /// Two-letter country code, or null for "Auto".
  String? country;
  bool consent = false;

  final Set<String> _failed = <String>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final m = await _storage.read();
    if (m == null) return;
    country = m['country'] is String ? m['country'] as String : null;
    consent = m['consent'] == true;
    final at = m['fetchedAt'];
    if (at is String) fetchedAt = DateTime.tryParse(at);
    final list = m['servers'];
    if (list is List) {
      final parsed = <VpnGateServer>[];
      for (final o in list) {
        final s = VpnGateServer.fromJson(o);
        if (s != null) parsed.add(s);
      }
      servers = parsed;
      fromCache = servers.isNotEmpty;
    }
    notifyListeners();
  }

  Future<void> _save() => _storage.write(<String, Object?>{
        'v': 1,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'country': country,
        'consent': consent,
        'servers': <Object?>[for (final s in servers) s.toJson()],
      });

  /// Gets a fresh list when the cached one is old. Falls back to the cache when the API is down.
  /// True when there is a usable list afterwards.
  Future<bool> refresh({bool force = false}) async {
    await load();
    final t = _now();
    if (!force && servers.isNotEmpty && !fromCache && fetchedAt != null && t.difference(fetchedAt!) < maxAge) return true;
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final parsed = parseVpnGateCsv(await _fetcher());
      lastRejected = parsed.rejected;
      if (parsed.servers.isEmpty) throw const FormatException('no usable server in the VPN Gate answer');
      final all = List<VpnGateServer>.of(parsed.servers)..sort(_byQuality);
      servers = all.take(keep).toList();
      fetchedAt = t;
      fromCache = false;
      _failed.clear();
      await _save();
      return true;
    } catch (e) {
      lastError = '$e';
      fromCache = servers.isNotEmpty;
      return servers.isNotEmpty;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static int _byQuality(VpnGateServer a, VpnGateServer b) {
    var d = b.score.compareTo(a.score);
    if (d != 0) return d;
    d = (a.pingMs ?? 1 << 30).compareTo(b.pingMs ?? 1 << 30);
    if (d != 0) return d;
    return b.speedBps.compareTo(a.speedBps);
  }

  /// Usable relays in the order they should be tried: quality score, then ping, then speed.
  List<VpnGateServer> candidates() {
    final c = country;
    final l = servers.where((s) => !_failed.contains(s.ip) && (c == null || s.countryShort == c)).toList();
    l.sort(_byQuality);
    return l;
  }

  /// (code, name, count) for every country in the list, most relays first.
  List<(String, String, int)> countries() {
    final m = <String, (String, int)>{};
    for (final s in servers) {
      final cur = m[s.countryShort];
      m[s.countryShort] = (s.countryLong, (cur?.$2 ?? 0) + 1);
    }
    final out = <(String, String, int)>[for (final e in m.entries) (e.key, e.value.$1, e.value.$2)];
    out.sort((a, b) => b.$3.compareTo(a.$3));
    return out;
  }

  void markFailed(String ip) => _failed.add(ip);
  void clearFailed() => _failed.clear();

  Future<void> setCountry(String? code) async {
    country = code;
    notifyListeners();
    await _save();
  }

  Future<void> setConsent() async {
    consent = true;
    notifyListeners();
    await _save();
  }
}
