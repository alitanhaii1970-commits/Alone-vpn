import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/core/storage.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/main.dart';

/// Boots the real app and walks splash -> first screen, failing on any build/layout exception.
void main() {
  testWidgets('fresh install reaches the language screen without exceptions', (tester) async {
    AppSettings.storage = MemoryStorage({});
    await AppSettings.I.load();
    await tester.pumpWidget(const AloneVpnApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Choose your language'), findsOneWidget);
  });
}
