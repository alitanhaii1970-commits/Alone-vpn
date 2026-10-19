import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/core/storage.dart';

/// The first-run language screen returned on every launch because nothing was ever persisted on
/// Android. These tests pin the persistence behaviour itself (the emulator test checks it for real).
void main() {
  test('FileSettingsStorage: values survive a "restart" (new instance reads the file)', () async {
    final a = await Prefs.open(FileSettingsStorage());
    a.setBool('al.onboarded', true);
    a.setString('al.lang', 'en');
    a.setInt('al.size', 112);
    a.setStringList('al.links', ['ss://x#one', 'vless://y#two']);
    await a.flush();
    final b = await Prefs.open(FileSettingsStorage());
    expect(b.getBool('al.onboarded'), isTrue);
    expect(b.getString('al.lang'), 'en');
    expect(b.getInt('al.size'), 112);
    expect(b.getStringList('al.links'), ['ss://x#one', 'vless://y#two']);
    // leave a clean slate for other runs
    final c = await Prefs.open(FileSettingsStorage());
    c.setBool('al.onboarded', false);
    await c.flush();
  });

  test('AppSettings: onboarded and language persist across a reload', () async {
    final store = MemoryStorage({});
    AppSettings.storage = store;
    AppSettings.I.onboarded = false;
    await AppSettings.I.load();
    AppSettings.I.update(() {
      AppSettings.I.lang = 'en';
      AppSettings.I.onboarded = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // "restart": defaults in memory, same storage
    AppSettings.I.onboarded = false;
    AppSettings.I.lang = 'fa';
    await AppSettings.I.load();
    expect(AppSettings.I.onboarded, isTrue);
    expect(AppSettings.I.lang, 'en');
  });

  test('a wrongly typed stored value does not stop the other settings from loading', () async {
    AppSettings.storage = MemoryStorage({'al.size': 'oops', 'al.onboarded': true, 'al.lang': 'en'});
    AppSettings.I.onboarded = false;
    await AppSettings.I.load();
    expect(AppSettings.I.onboarded, isTrue);
    expect(AppSettings.I.lang, 'en');
  });
}
