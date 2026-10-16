import 'dart:async';
import 'package:flutter/foundation.dart';
import 'core/settings.dart';
import 'data/stores.dart';

/// CI-only end-to-end self test. It is compiled in only when the build passes
/// `--dart-define=ALONE_SELFTEST_LINK=<share link>`; normal builds contain none of it.
const String _link = String.fromEnvironment('ALONE_SELFTEST_LINK');
bool get selfTestEnabled => _link.isNotEmpty;

/// Skip onboarding so the test lands directly on the real home screen.
void prepareSelfTest() {
  if (!selfTestEnabled) return;
  AppSettings.I.onboarded = true;
  AppSettings.I.lang = 'en';
}

/// Add the test server, connect through the real engine, hold, then disconnect.
/// Progress is printed as `SELFTEST: ...` lines that the emulator script reads from logcat.
Future<void> runSelfTest() async {
  if (!selfTestEnabled) return;
  void say(String m) => debugPrint('SELFTEST: $m');
  try {
    await Future<void>.delayed(const Duration(seconds: 7));
    await ServerStore.I.addText(_link);
    if (ServerStore.I.items.isEmpty) {
      say('FAILED no server was added');
      return;
    }
    ServerStore.I.setActive(ServerStore.I.items.first.id);
    say('CONNECTING');
    await Conn.I.connect();
    if (Conn.I.state != CS.on) {
      say('FAILED state=${Conn.I.state} step=${Conn.I.failStep}');
      return;
    }
    say('CONNECTED');
    await Future<void>.delayed(const Duration(seconds: 70)); // the host script measures the tunnel meanwhile
    await Conn.I.disconnect();
    say('DISCONNECTED state=${Conn.I.state}');
  } catch (e) {
    say('EXCEPTION $e');
  }
}
