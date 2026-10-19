import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Where the settings JSON lives. The app used `shared_preferences`, but its Android side crashed
/// at runtime in release builds (NoSuchMethodError in the JNI bindings), so nothing was ever
/// stored and the first-run language screen came back on every launch. A plain JSON file in the
/// app's private folder has no native part that can break.
abstract class SettingsStorage {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> data);
}

/// Keeps everything in memory (tests).
class MemoryStorage implements SettingsStorage {
  MemoryStorage([Map<String, Object?>? initial]) : data = Map<String, Object?>.of(initial ?? {});
  Map<String, Object?> data;
  @override
  Future<Map<String, Object?>> read() async => Map<String, Object?>.of(data);
  @override
  Future<void> write(Map<String, Object?> d) async => data = Map<String, Object?>.of(d);
}

class FileSettingsStorage implements SettingsStorage {
  File? _main;
  bool _resolved = false;

  File? _resolve() {
    if (_resolved) return _main;
    _resolved = true;
    final candidates = <Directory>[];
    try {
      final tmp = Directory.systemTemp; // Android: <app data>/cache
      candidates.add(Directory('${tmp.parent.path}/files'));
      candidates.add(Directory('${tmp.parent.path}/app_flutter'));
      candidates.add(Directory('${tmp.path}/alone')); // last resort: the OS may purge cache
    } catch (_) {}
    for (final d in candidates) {
      try {
        if (!d.existsSync()) d.createSync(recursive: true);
        final probe = File('${d.path}/.write_test');
        probe.writeAsStringSync('1', flush: true);
        probe.deleteSync();
        _main = File('${d.path}/alone_settings.json');
        debugPrint('ALONE_STORE path=${_main!.path}');
        return _main;
      } catch (_) {}
    }
    debugPrint('ALONE_STORE no writable folder: settings stay in memory only');
    return null;
  }

  @override
  Future<Map<String, Object?>> read() async {
    final f = _resolve();
    if (f == null) return {};
    for (final candidate in [f, File('${f.path}.bak')]) {
      try {
        if (!candidate.existsSync()) continue;
        final v = jsonDecode(await candidate.readAsString());
        if (v is Map) return Map<String, Object?>.from(v);
      } catch (e) {
        debugPrint('ALONE_STORE could not read ${candidate.path}: $e');
      }
    }
    return {};
  }

  @override
  Future<void> write(Map<String, Object?> data) async {
    final f = _resolve();
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      if (f.existsSync()) {
        try {
          f.copySync('${f.path}.bak');
        } catch (_) {}
      }
      await tmp.rename(f.path); // atomic replace on the same filesystem
    } catch (e) {
      debugPrint('ALONE_STORE write failed: $e');
    }
  }
}

/// Small key/value view over [SettingsStorage] with the same getters the code used before.
/// Writes are batched (one file write shortly after the last change).
class Prefs {
  Prefs._(this._storage, this._m);
  final SettingsStorage _storage;
  final Map<String, Object?> _m;
  Timer? _timer;

  static Future<Prefs> open(SettingsStorage storage) async => Prefs._(storage, await storage.read());

  Object? get(String k) => _m[k];
  String? getString(String k) => _m[k] is String ? _m[k] as String : null;
  int? getInt(String k) => _m[k] is int ? _m[k] as int : null;
  bool? getBool(String k) => _m[k] is bool ? _m[k] as bool : null;
  List<String>? getStringList(String k) {
    final v = _m[k];
    return v is List ? [for (final e in v) e.toString()] : null;
  }

  void setString(String k, String v) => _set(k, v);
  void setInt(String k, int v) => _set(k, v);
  void setBool(String k, bool v) => _set(k, v);
  void setStringList(String k, List<String> v) => _set(k, List<String>.of(v));

  void _set(String k, Object v) {
    _m[k] = v;
    _timer ??= Timer(const Duration(milliseconds: 40), flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await _storage.write(Map<String, Object?>.of(_m));
  }
}
