import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/main.dart';
import 'package:alone_vpn/ui/kit/chrome.dart';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var e = Duration.zero; e < d; e += const Duration(milliseconds: 100)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Phone-sized window (392 x 873 dp), like a real device.
void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

void main() {
  for (final lang in ['en', 'fa']) {
    testWidgets('[$lang] splash -> home, then all four tabs render without exceptions', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({'al.onboarded': true, 'al.lang': lang});
      await AppSettings.I.load();
      await tester.pumpWidget(const AloneVpnApp());
      await _pumpFor(tester, const Duration(milliseconds: 3500));
      expect(tester.takeException(), isNull, reason: 'while opening the home screen');
      expect(find.byType(NavBar), findsOneWidget);

      final r = tester.getRect(find.byType(NavBar));
      for (var i = 0; i < 4; i++) {
        await tester.tapAt(Offset(r.left + r.width * (i + .5) / 4, r.center.dy));
        await _pumpFor(tester, const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull, reason: 'tab $i ($lang)');
      }
    });
  }

  testWidgets('fresh install: language screen -> pick English -> next onboarding page', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    await AppSettings.I.load();
    await tester.pumpWidget(const AloneVpnApp());
    await _pumpFor(tester, const Duration(milliseconds: 3000));
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await _pumpFor(tester, const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    expect(find.text('Choose your language'), findsNothing);
  });
}
