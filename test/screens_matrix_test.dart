import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alone_vpn/core/i18n.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/main.dart';
import 'package:alone_vpn/ui/kit/chrome.dart';
import 'package:alone_vpn/ui/nav.dart';
import 'package:alone_vpn/ui/screens/latency.dart';
import 'package:alone_vpn/ui/screens/log.dart';
import 'package:alone_vpn/ui/screens/servers.dart';
import 'package:alone_vpn/ui/screens/settings.dart';
import 'package:alone_vpn/ui/screens/shell.dart';
import 'package:alone_vpn/ui/screens/splash.dart';

/// Opens every tab and every pushed screen on small / normal / large phones, with normal and
/// enlarged text, in English and Persian, and reports every layout exception (overflow, unbounded
/// constraints, ...). The test font (Ahem) is about twice as wide as the real fonts, so the text
/// scale is halved: 0.5 here is "100 %" on a device and 0.65 is "130 %".
void main() {
  const sizes = {'small 360x640': Size(360, 640), 'normal 411x891': Size(411, 891), 'large 600x960': Size(600, 960)};
  const scales = {'text 100%': .5, 'text 130%': .65};

  for (final lang in ['en', 'fa']) {
    for (final se in sizes.entries) {
      for (final sc in scales.entries) {
        final combo = '$lang | ${se.key} | ${sc.key}';
        testWidgets(combo, (tester) async {
          const dpr = 2.75;
          tester.view.physicalSize = Size(se.value.width * dpr, se.value.height * dpr);
          tester.view.devicePixelRatio = dpr;
          tester.platformDispatcher.textScaleFactorTestValue = sc.value;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({
            'al.onboarded': true,
            'al.lang': lang,
            'al.links': ['ss://YWVzLTI1Ni1nY206cGFzcw==@10.0.2.2:8388#CI-Test', 'vless://123e4567-e89b-12d3-a456-426614174000@example.com:443?security=tls#Second'],
          });
          AppSettings.I.onboarded = true;
          await AppSettings.I.load();

          final problems = <String>[];
          Future<void> look(String what) async {
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            var ex = tester.takeException();
            while (ex != null) {
              final full = ex is FlutterError ? ex.toStringDeep() : ex.toString();
              final msg = full.split('\n').firstWhere((l) => l.contains('overflowed') || l.contains('constraints') || l.contains('Failed'), orElse: () => full.split('\n').first);
              final where = RegExp(r'creator: [^\n]{0,230}').firstMatch(full)?.group(0) ?? '';
              problems.add('$what -> ${msg.length > 120 ? msg.substring(0, 120) : msg} @ $where');
              ex = tester.takeException();
            }
          }

          await tester.pumpWidget(const AloneVpnApp());
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await look('home');

          Finder nav(String key) => find.descendant(of: find.byType(NavBar), matching: find.text(tr(key)));
          for (final k in ['servers', 'm_usage', 'settings', 'm_home']) {
            await tester.tap(nav(k));
            await look('tab $k');
          }

          final screens = <String, Widget>{
            'ServersScreen': const ServersScreen(),
            'LatencyScreen': const LatencyScreen(),
            'DnsScreen': const DnsScreen(),
            'LogScreen': const LogScreen(),
            'HelpScreen': const HelpScreen(),
            'SettingsScreen': const SettingsScreen(),
            'SplitScreen': const SplitScreen(),
            'RoutingScreen': const RoutingScreen(),
            'LanguageScreen': const LanguageScreen(),
            'OnbNotif': const OnbNotif(),
            'OnbVpn': const OnbVpn(),
            'OnbLook': const OnbLook(),
          };
          for (final e in screens.entries) {
            final ctx = tester.element(find.byType(AppShell));
            pushScreen<void>(ctx, e.value);
            await look(e.key);
            Navigator.of(ctx).pop();
            await look('${e.key} (closing)');
          }

          final unique = problems.toSet().toList();
          // ignore: avoid_print
          for (final p in unique) print('SIZEPROBLEM [$combo] $p');
          expect(unique, isEmpty, reason: '${unique.length} layout problem(s) at $combo');
        });
      }
    }
  }
}
