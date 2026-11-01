import 'dart:async';
import 'package:flutter/foundation.dart';
import 'core/connection/connection_manager.dart';
import 'core/connection/vpn_engine.dart';
import 'core/connection/vpngate_engine.dart';
import 'core/settings.dart';
import 'data/stores.dart';
import 'services/ovpn.dart';
import 'services/smart_servers.dart';

/// CI-only end-to-end self test. It is compiled in only when the build passes
/// `--dart-define=ALONE_SELFTEST_LINK=<share link>`; normal builds contain none of it.
const String _link = String.fromEnvironment('ALONE_SELFTEST_LINK');
bool get selfTestEnabled => _link.isNotEmpty;

/// Skip onboarding so the test lands directly on the real home screen.
void prepareSelfTest() {
  if (!selfTestEnabled && !smartSelfTestEnabled) return;
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

/// CI-only end-to-end test of Smart mode against the REAL VPN Gate network. It exists only in builds
/// made with `--dart-define=ALONE_SELFTEST_SMART=1`. It prints `SELFTEST_SMART: ...` lines (never an
/// IP address) that scripts/vpngate_e2e.sh reads from logcat.
const String _smart = String.fromEnvironment('ALONE_SELFTEST_SMART');
bool get smartSelfTestEnabled => _smart.isNotEmpty;

Future<void> runSmartSelfTest() async {
  if (!smartSelfTestEnabled) return;
  void say(String m) => debugPrint('SELFTEST_SMART: $m');
  try {
    await Future<void>.delayed(const Duration(seconds: 8));
    final m = ConnectionManager.I;
    final engine = m.engine(EngineKind.smart);
    if (engine is! VpnGateEngine) {
      say('FAILED the smart engine is not the VPN Gate engine');
      return;
    }
    final sm = SmartServerManager.I;
    await sm.load();
    await sm.setConsent(); // there is nobody to tick the privacy dialog in CI
    await sm.setCountry(null);
    say('OPENVPN_APP installed=${await OvpnEngine.installed()}');

    String describe(String tag, ConnectResult r) {
      final s = engine.current;
      final changed = engine.exitIp != null && engine.exitIp != engine.ipBefore;
      return '$tag result=${r.name} state=${m.statusOf(EngineKind.smart).state.name} attempts=${engine.attempt} '
          'country=${s?.countryShort} reportedPing=${s?.pingMs} reportedMbps=${s?.speedMbps.toStringAsFixed(1)} '
          'log=${s?.logType} ipChanged=$changed ipv6Exposed=${engine.ipv6Exposed} err=${m.errorOf(EngineKind.smart)}';
    }

    // 1. real list, real profile, real tunnel, public IP compared
    say('CONNECTING');
    final r1 = await m.connect(EngineKind.smart);
    say(describe('CONNECT', r1));
    if (r1 != ConnectResult.success) {
      say('DONE ok=false');
      return;
    }
    final exit1 = engine.exitIp;
    final country1 = engine.current?.countryShort;
    say('HOLD'); // the host script inspects the tunnel during this time
    await Future<void>.delayed(const Duration(seconds: 45));

    // 2. mutual exclusion: starting the manual engine must tear the Smart tunnel down first
    final rx = await m.connect(EngineKind.manual);
    say('EXCLUSION manualResult=${rx.name} smart=${m.statusOf(EngineKind.smart).state.name} '
        'manual=${m.statusOf(EngineKind.manual).state.name} occupying=${m.occupying.map((e) => e.name).toList()}');

    // 3. disconnect, then connect again
    await m.disconnect(EngineKind.smart);
    say('DISCONNECT state=${m.statusOf(EngineKind.smart).state.name}');
    final r2 = await m.connect(EngineKind.smart);
    say(describe('RECONNECT', r2));
    if (r2 != ConnectResult.success) {
      say('DONE ok=false');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 15));

    // 4. switch server: another country, and a different public IP
    final exit2 = engine.exitIp;
    final country2 = engine.current?.countryShort;
    String? other;
    for (final c in sm.countries()) {
      if (c.$1 != country2) {
        other = c.$1;
        break;
      }
    }
    await m.disconnect(EngineKind.smart);
    if (other == null) {
      say('SWITCH skipped (the list has only one country)');
    } else {
      await sm.setCountry(other);
      final r3 = await m.connect(EngineKind.smart);
      say(describe('SWITCH', r3));
      say('SWITCH countryChanged=${engine.current?.countryShort != country2} exitChanged=${engine.exitIp != exit2} '
          'firstExitDiffers=${engine.exitIp != exit1} firstCountry=$country1');
      await Future<void>.delayed(const Duration(seconds: 10));
      await m.disconnect(EngineKind.smart);
    }
    say('FINAL smart=${m.statusOf(EngineKind.smart).state.name} occupying=${m.occupying.map((e) => e.name).toList()}');
    say('DONE ok=true');
  } catch (e) {
    say('EXCEPTION $e');
    say('DONE ok=false');
  }
}
