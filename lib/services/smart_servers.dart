import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../data/vpngate.dart';
import 'vpngate_sources.dart';

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

/// The relay snapshot that was current when this APK was built (empty placeholder in dev builds).
Future<String?> _bundledSnapshot() async {
  try {
    return await rootBundle.loadString('assets/smart/snapshot.json');
  } catch (_) {
    return null;
  }
}

/// Owns the list of VPN Gate relays: fetch, validate, cache, rank, and hand out candidates.
/// The relays are volunteer-run public infrastructure, never ALONE servers.
///
/// Where the list comes from, in order: the official API, ALONE's own copy of it on several hosts, the
/// last list saved on this device, and the snapshot bundled in the app. [source] and [listTime] say
/// which one is in use so the user can see how old it is.
class SmartServerManager extends ChangeNotifier {
  SmartServerManager({
    SmartCacheStorage? storage,
    Future<FetchedList> Function()? fetcher,
    Future<String?> Function()? bundled,
    DateTime Function()? now,
    this.maxAge = const Duration(minutes: 30),
    this.keep = 120,
  })  : _storage = storage ?? MemorySmartCache(),
        _fetcher = fetcher ?? fetchListFromAnySource,
        _bundled = bundled ?? _bundledSnapshot,
        _now = now ?? DateTime.now;

  static final SmartServerManager I = SmartServerManager(storage: FileSmartCache());

  final SmartCacheStorage _storage;
  final Future<FetchedList> Function() _fetcher;
  final Future<String?> Function() _bundled;
  final DateTime Function() _now;
  final Duration maxAge;
  final int keep;

  List<VpnGateServer> servers = const <VpnGateServer>[];
  DateTime? fetchedAt;

  /// Host label of the list in use ("vpngate.net", "raw.githubusercontent.com", "saved on this device",
  /// "bundled with the app").
  String? source;

  /// When the list in use was made. For the official API this is the time it was fetched.
  DateTime? listTime;
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
    if (m != null) {
      country = m['country'] is String ? m['country'] as String : null;
      consent = m['consent'] == true;
      final at = m['fetchedAt'];
      if (at is String) fetchedAt = DateTime.tryParse(at);
      final lt = m['listTime'];
      listTime = lt is String ? DateTime.tryParse(lt) : fetchedAt;
      final list = m['servers'];
      if (list is List) {
        final parsed = <VpnGateServer>[];
        for (final o in list) {
          final s = VpnGateServer.fromJson(o);
          if (s != null) parsed.add(s);
        }
        servers = parsed;
        fromCache = parsed.isNotEmpty;
        if (parsed.isNotEmpty) source = 'saved';
      }
    }
    await _considerBundled();
    notifyListeners();
  }

  /// The snapshot inside the APK wins over an older saved list (or fills in when there is none).
  Future<void> _considerBundled() async {
    final body = await _bundled();
    final snap = body == null ? null : parseSnapshotJson(body);
    if (snap == null || snap.servers.isEmpty) return;
    final saved = listTime ?? fetchedAt;
    if (servers.isEmpty || saved == null || snap.generatedAt.isAfter(saved)) {
      servers = snap.servers;
      listTime = snap.generatedAt;
      fetchedAt = snap.generatedAt;
      fromCache = true;
      source = 'bundled';
    }
  }

  Future<void> _save() => _storage.write(<String, Object?>{
        'v': 2,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'listTime': listTime?.toIso8601String(),
        'country': country,
        'consent': consent,
        'servers': <Object?>[for (final s in servers) s.toJson()],
      });

  /// Gets a fresh list when the one in use is old. Falls back to what is saved or bundled when no source
  /// answers. True when there is a usable list afterwards.
  Future<bool> refresh({bool force = false}) async {
    await load();
    final t = _now();
    if (!force && servers.isNotEmpty && !fromCache && fetchedAt != null && t.difference(fetchedAt!) < maxAge) return true;
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final got = await _fetcher();
      lastRejected = got.rejected;
      if (got.servers.isEmpty) throw const FormatException('no usable server in the answer');
      final all = List<VpnGateServer>.of(got.servers)..sort(compareVpnGateQuality);
      servers = all.take(keep).toList();
      fetchedAt = t;
      listTime = got.generatedAt ?? t;
      source = got.source;
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

  /// Usable relays in the order they should be tried: quality score, then ping, then speed.
  List<VpnGateServer> candidates() {
    final c = country;
    final l = servers.where((s) => !_failed.contains(s.ip) && (c == null || s.countryShort == c)).toList();
    l.sort(compareVpnGateQuality);
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
