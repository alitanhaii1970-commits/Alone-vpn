import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Brightness;
import '../data/catalog.dart';
import 'storage.dart';

/// Everything the Settings / Appearance / Split / Routing screens edit.
/// Persisted in a JSON file (see storage.dart); any change notifies the whole UI.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings I = AppSettings._();
  /// Tests replace this with a MemoryStorage before calling load().
  static SettingsStorage storage = FileSettingsStorage();
  Prefs? _p;

  String lang = 'fa';
  String theme = 'obsidian';
  String mode = 'dark'; // dark | light | system
  String font = 'vazir';
  String digits = 'latin'; // latin | fa
  int size = 100; // text size in percent: 90 / 100 / 112 / 125
  bool saver = false;
  bool haptics = true;
  bool onboarded = false;
  bool killswitch = false;
  String splitMode = 'off'; // off | include | exclude
  Set<String> splitApps = <String>{};
  bool dnsOn = false;
  String dnsSel = 'cf';
  List<CustomDns> customDns = <CustomDns>[];
  Set<String> favs = <String>{};
  String activeServer = '';
  String probe = 'tcp'; // tcp | url
  Map<String, bool> rules = {for (final r in kRules) r.id: r.on};
  List<String> serverLinks = <String>[];
  /// Subscription URLs the servers came from: {url, name, at (ms), links}. Lets one button refresh them.
  List<Map<String, dynamic>> subs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> history = <Map<String, dynamic>>[];

  bool get fa => lang == 'fa';
  double get textScale => size / 100.0;

  bool isDark(Brightness platform) {
    if (mode == 'light') return false;
    if (mode == 'dark') return true;
    return platform == Brightness.dark;
  }

  DnsDef? get activeDns {
    for (final d in kDns) {
      if (d.id == dnsSel) return d;
    }
    return null;
  }

  /// The resolver address the engine should use (null = engine default).
  String? get dnsEngineAddress {
    if (!dnsOn) return null;
    final d = activeDns;
    if (d != null) return d.engineAddress;
    for (final c in customDns) {
      if (c.id == dnsSel) return c.ip;
    }
    return null;
  }

  Future<void>? _loading;

  /// Completes when the stored settings have been read (or immediately if load() was never called).
  Future<void> get ready => _loading ?? Future<void>.value();

  Future<void> load() => _loading = _load();

  Future<void> _load() async {
    final p = _p = await Prefs.open(storage);
    // Every key is read on its own: one value of an unexpected type used to abort the whole load,
    // which left the defaults in place (language screen on every launch) and then overwrote the
    // good stored values with those defaults.
    T pick<T>(String key, T fallback) {
      try {
        final v = p.get(key);
        return v is T ? v : fallback;
      } catch (_) {
        return fallback;
      }
    }

    List<String> list(String key) {
      try {
        return p.getStringList(key) ?? <String>[];
      } catch (_) {
        return <String>[];
      }
    }

    lang = pick('al.lang', lang);
    theme = pick('al.theme', theme);
    mode = pick('al.mode', mode);
    font = pick('al.font', font);
    digits = pick('al.digits', digits);
    size = pick('al.size', size);
    saver = pick('al.saver', saver);
    haptics = pick('al.haptics', haptics);
    onboarded = pick('al.onboarded', onboarded);
    killswitch = pick('al.kill', killswitch);
    splitMode = pick('al.splitMode', splitMode);
    splitApps = list('al.splitApps').toSet();
    dnsOn = pick('al.dnsOn', dnsOn);
    dnsSel = pick('al.dnsSel', dnsSel);
    favs = list('al.favs').toSet();
    activeServer = pick('al.active', activeServer);
    probe = pick('al.probe', probe);
    serverLinks = list('al.links');
    try {
      final cd = p.getString('al.customDns');
      if (cd != null) {
        customDns = [for (final m in (jsonDecode(cd) as List)) CustomDns(m['id'] as String, m['ip'] as String)];
      }
    } catch (_) {}
    try {
      final rs = p.getString('al.rules');
      if (rs != null) {
        final m = jsonDecode(rs) as Map<String, dynamic>;
        for (final k in m.keys) {
          rules[k] = m[k] == true;
        }
      }
    } catch (_) {}
    try {
      final ss = p.getString('al.subs');
      if (ss != null) {
        subs = [for (final m in (jsonDecode(ss) as List)) Map<String, dynamic>.from(m as Map)];
      }
    } catch (_) {}
    try {
      final hs = p.getString('al.history');
      if (hs != null) {
        history = [for (final m in (jsonDecode(hs) as List)) Map<String, dynamic>.from(m as Map)];
      }
    } catch (_) {}
  }

  /// Mutate settings, persist, and repaint everything that depends on them.
  void update(VoidCallback change) {
    change();
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    // never write the in-memory defaults over stored values: wait until they have been read
    await _loading;
    final p = _p ??= await Prefs.open(storage);
    p.setString('al.lang', lang);
    p.setString('al.theme', theme);
    p.setString('al.mode', mode);
    p.setString('al.font', font);
    p.setString('al.digits', digits);
    p.setInt('al.size', size);
    p.setBool('al.saver', saver);
    p.setBool('al.haptics', haptics);
    p.setBool('al.onboarded', onboarded);
    p.setBool('al.kill', killswitch);
    p.setString('al.splitMode', splitMode);
    p.setStringList('al.splitApps', splitApps.toList());
    p.setBool('al.dnsOn', dnsOn);
    p.setString('al.dnsSel', dnsSel);
    p.setStringList('al.favs', favs.toList());
    p.setString('al.active', activeServer);
    p.setString('al.probe', probe);
    p.setStringList('al.links', serverLinks);
    p.setString('al.customDns', jsonEncode([for (final c in customDns) {'id': c.id, 'ip': c.ip}]));
    p.setString('al.rules', jsonEncode(rules));
    p.setString('al.history', jsonEncode(history));
    p.setString('al.subs', jsonEncode(subs));
  }
}

/// Haptics, gated by the user's setting (spec: tap 10ms, success double, fail long).
class Hx {
  Hx._();
  static void tap() {
    if (AppSettings.I.haptics) HapticFeedback.selectionClick();
  }

  static void ok() {
    if (!AppSettings.I.haptics) return;
    HapticFeedback.lightImpact();
    Future<void>.delayed(const Duration(milliseconds: 90), HapticFeedback.lightImpact);
  }

  static void fail() {
    if (AppSettings.I.haptics) HapticFeedback.heavyImpact();
  }
}
