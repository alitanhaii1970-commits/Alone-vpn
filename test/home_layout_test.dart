import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/main.dart';
import 'package:alone_vpn/ui/screens/home.dart';

/// Emulator screenshots showed the "Recent servers" card painted at the very top of the Home
/// screen. This checks that, at the LAYOUT level, every Home section sits below the previous one.
void main() {
  testWidgets('Home sections are laid out top-to-bottom (server present)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'al.onboarded': true,
      'al.lang': 'en',
      'al.links': ['ss://YWVzLTI1Ni1nY206cGFzcw==@10.0.2.2:8388#CI-Test'],
    });
    await AppSettings.I.load();
    await tester.pumpWidget(const AloneVpnApp());
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    Rect r(Type t) => tester.getRect(find.byType(t));
    final order = <String, Rect>{
      'ConnectDial': r(ConnectDial),
      'Telemetry': r(Telemetry),
      'ActiveServerCard': r(ActiveServerCard),
      'QuickTiles': r(QuickTiles),
      'RecentsPanel': r(RecentsPanel),
    };
    // ignore: avoid_print
    print('LAYOUT ${order.map((k, v) => MapEntry(k, '${v.top.round()}..${v.bottom.round()} x ${v.left.round()}..${v.right.round()}'))}');
    expect(order['QuickTiles']!.height, lessThan(140), reason: 'quick tiles must be one compact row (a bad flex ratio made them 200+ dp tall)');
    final keys = order.keys.toList();
    for (var i = 1; i < keys.length; i++) {
      expect(order[keys[i]]!.top, greaterThanOrEqualTo(order[keys[i - 1]]!.bottom - 1), reason: '${keys[i]} must be below ${keys[i - 1]}');
    }
  });
}
