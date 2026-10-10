import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Brightness;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/catalog.dart';

/// Everything the Settings / Appearance / Split / Routing screens edit.
/// Persisted in SharedPreferences; any change notifies the whole UI.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings I = AppSettings._();
  SharedPreferences? _p;

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

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    lang = p.getString('al.lang') ?? lang;
    theme = p.getString('al.theme') ?? theme;
    mode = p.getString('al.mode') ?? mode;
    font = p.getString('al.font') ?? font;
    digits = p.getString('al.digits') ?? digits;
    size = p.getInt('al.size') ?? size;
    saver = p.getBool('al.saver') ?? saver;
    haptics = p.getBool('al.haptics') ?? haptics;
    onboarded = p.getBool('al.onboarded') ?? onboarded;
    killswitch = p.getBool('al.kill') ?? killswitch;
    splitMode = p.getString('al.splitMode') ?? splitMode;
    splitApps = (p.getStringList('al.splitApps') ?? <String>[]).toSet();
    dnsOn = p.getBool('al.dnsOn') ?? dnsOn;
    dnsSel = p.getString('al.dnsSel') ?? dnsSel;
    favs = (p.getStringList('al.favs') ?? <String>[]).toSet();
    activeServer = p.getString('al.active') ?? activeServer;
    probe = p.getString('al.probe') ?? probe;
    serverLinks = p.getStringList('al.links') ?? <String>[];
    try {
      final cd = p.getString('al.customDns');
      if (cd != null) {
        customDns = [for (final m in (jsonDecode(cd) as List)) CustomDns(m['id'] as String, m['ip'] as String)];
      }
      final rs = p.getString('al.rules');
      if (rs != null) {
        final m = jsonDecode(rs) as Map<String, dynamic>;
        for (final k in m.keys) {
          rules[k] = m[k] == true;
        }
      }
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

  void _persist() {
    final p = _p;
    if (p == null) return;
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
