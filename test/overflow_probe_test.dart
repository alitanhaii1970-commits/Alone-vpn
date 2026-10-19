import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/core/storage.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/main.dart';

/// Finds WHICH widget overflows on a small English phone: records the full diagnostics of the
/// first layout error (the creator chain names the widget) and then restores the normal handler.
void main() {
  testWidgets('probe: Home overflow on 360x640 (en)', (tester) async {
    const dpr = 2.75;
    tester.view.physicalSize = const Size(360 * dpr, 640 * dpr);
    tester.view.devicePixelRatio = dpr;
    tester.platformDispatcher.textScaleFactorTestValue = .5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    AppSettings.storage = MemoryStorage({
      'al.onboarded': true,
      'al.lang': 'en',
      'al.links': ['ss://YWVzLTI1Ni1nY206cGFzcw==@10.0.2.2:8388#CI-Test', 'vless://123e4567-e89b-12d3-a456-426614174000@example.com:443?security=tls#Second'],
    });
    AppSettings.I.onboarded = true;
    await AppSettings.I.load();

    final old = FlutterError.onError;
    var captured = '';
    FlutterError.onError = (FlutterErrorDetails d) {
      if (captured.isEmpty) captured = d.toString();
      FlutterError.onError = old; // only the first error is interesting
    };
    await tester.pumpWidget(const AloneVpnApp());
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    FlutterError.onError = old;
    tester.takeException();
    final lines = captured.split('\n');
    // ignore: avoid_print
    print('PROBE_BEGIN');
    // ignore: avoid_print
    for (final l in lines.take(70)) print('PROBE ${l.length > 230 ? l.substring(0, 230) : l}');
    // ignore: avoid_print
    print('PROBE_END');
  });
}
