import 'package:alone_vpn/core/i18n.dart';
import 'package:alone_vpn/main.dart' as app;
import 'package:alone_vpn/ui/kit/chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Real-app walkthrough on an Android emulator: onboarding -> every tab -> import a config.
/// Each step records problems and takes a screenshot, so one failure does not hide the rest.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ALONE VPN walkthrough', (tester) async {
    final problems = <String>[];
    final timings = <String>[];
    var n = 0;

    Future<void> wait(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> snap(String name) async {
      await wait(300);
      await binding.takeScreenshot('${(++n).toString().padLeft(2, '0')}_$name');
    }

    Future<void> step(String name, Future<void> Function() body) async {
      final sw = Stopwatch()..start();
      try {
        await body();
      } catch (e) {
        problems.add('[$name] $e');
      }
      final ex = tester.takeException();
      if (ex != null) problems.add('[$name] UI exception: $ex');
      timings.add('$name: ${sw.elapsedMilliseconds} ms');
      await snap(name);
    }

    Finder nav(String key) => find.descendant(of: find.byType(NavBar), matching: find.text(tr(key)));

    // ---- launch (real main(), real plugins)
    final launch = Stopwatch()..start();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await wait(3200); // splash is ~2.1 s
    timings.add('launch -> first screen: ${launch.elapsedMilliseconds} ms');
    await snap('language_screen');

    await step('pick_english', () async {
      await tester.tap(find.text('English'));
      await wait(1200);
    });
    await step('onboarding_notifications_skip', () async {
      await tester.tap(find.text(tr('skip_step')));
      await wait(1200);
    });
    await step('onboarding_vpn_skip', () async {
      await tester.tap(find.text(tr('skip_step')));
      await wait(1200);
    });
    await step('onboarding_look_start', () async {
      await tester.tap(find.text(tr('look_cta')));
      await wait(2200);
    });
    await step('home', () async {
      expect(find.byType(NavBar), findsOneWidget);
    });
    await step('tab_servers', () async {
      await tester.tap(nav('servers'));
      await wait(900);
    });

    await step('import_sheet_open', () async {
      await tester.tap(find.text(tr('import_cta')).first);
      await wait(1000);
    });
    await step('import_sheet_filled', () async {
      await tester.enterText(
        find.byType(EditableText).last,
        'vless://123e4567-e89b-12d3-a456-426614174000@example.com:443?encryption=none&security=tls#E2E%20Test',
      );
      await wait(500);
    });
    await step('import_sheet_submit', () async {
      await tester.tap(find.text(tr('import_cta')).last);
      await wait(2500);
    });
    await step('servers_after_import', () async {
      expect(find.textContaining('E2E Test'), findsWidgets);
    });
    await step('tab_usage', () async {
      await tester.tap(nav('m_usage'));
      await wait(900);
    });
    await step('tab_settings', () async {
      await tester.tap(nav('settings'));
      await wait(900);
    });
    await step('settings_scrolled', () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await wait(900);
    });
    await step('tab_home_again', () async {
      await tester.tap(nav('m_home'));
      await wait(1200);
    });

    final report = StringBuffer()
      ..writeln('TIMINGS')
      ..writeln(timings.join('\n'))
      ..writeln()
      ..writeln(problems.isEmpty ? 'NO PROBLEMS' : 'PROBLEMS (${problems.length})')
      ..writeln(problems.join('\n'));
    // ignore: avoid_print
    print('E2E_REPORT_BEGIN\n$report\nE2E_REPORT_END');
    expect(problems, isEmpty, reason: report.toString());
  });
}
