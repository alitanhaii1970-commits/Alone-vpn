import 'dart:async';
import 'dart:io';
import 'package:v2ray_box/v2ray_box.dart' as vb;

/// The one place that talks to the real VPN engine (the `v2ray_box` plugin:
/// Android VpnService + Xray/sing-box cores). On any other platform every call is a
/// harmless no-op, so the UI can still be run and looked at there.
class Engine {
  Engine._();
  static final Engine I = Engine._();
  static bool get real => Platform.isAndroid;

  final vb.V2rayBox _core = vb.V2rayBox();
  Future<void>? _init;

  Future<void> ensure() {
    if (!real) return Future<void>.value();
    return _init ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _core.initialize(notificationStopButtonText: 'Disconnect');
    } catch (_) {
      // Do not permanently cache a failed initialization; a later retry can
      // recover from a transient method-channel or native-engine error.
      _init = null;
      rethrow;
    }
  }

  Stream<vb.VpnStatus> status() => real ? _core.watchStatus() : Stream<vb.VpnStatus>.empty();
  Stream<vb.VpnStats> stats() => real ? _core.watchStats() : Stream<vb.VpnStats>.empty();
  Stream<Map<String, dynamic>> alerts() => real ? _core.watchAlerts() : Stream<Map<String, dynamic>>.empty();

  Future<bool> hasPermission() async {
    if (!real) return false;
    try {
      await ensure();
      return await _core.checkVpnPermission();
    } catch (_) {
      return false;
    }
  }

  Future<bool> start(String link, String name) async {
    await ensure();
    return _core.connect(link, name: name);
  }

  Future<void> stop() async {
    if (!real) return;
    try {
      await _core.disconnect();
    } catch (_) {}
  }

  /// Push the user's DNS / routing / split-tunnel choices into the engine.
  Future<void> configure({
    required String? dns,
    required bool blockAds,
    required bool bypassLan,
    required bool strict,
    required String splitMode,
    required Set<String> apps,
  }) async {
    if (!real) return;
    await ensure();
    await _core.setConfigOptions(vb.ConfigOptions(
      remoteDnsAddress: dns ?? 'https://8.8.8.8/dns-query',
      blockAds: blockAds,
      bypassLan: bypassLan,
      strictRoute: strict,
    ));
    final mode = splitMode == 'include'
        ? vb.PerAppProxyMode.include
        : (splitMode == 'exclude' ? vb.PerAppProxyMode.exclude : vb.PerAppProxyMode.off);
    // Always write the list as well as the mode. Otherwise a previous list
    // can remain stored when split tunnelling is turned off and surprise the
    // user when it is enabled again later.
    await _core.setPerAppProxyList(apps.toList(), mode);
    await _core.setPerAppProxyMode(mode);
  }

  Future<List<vb.AppInfo>> installedApps() async {
    if (!real) return <vb.AppInfo>[];
    await ensure();
    return _core.getInstalledApps();
  }

  /// Real delay through the proxy core (null = no answer).
  Future<int?> coreDelay(String link) async {
    if (!real) return null;
    try {
      await ensure();
      final ms = await _core.ping(link, timeout: 7000);
      return ms > 0 ? ms : null;
    } catch (_) {
      return null;
    }
  }

  Future<vb.TotalTraffic?> totals() async {
    if (!real) return null;
    try {
      await ensure();
      return await _core.getTotalTraffic();
    } catch (_) {
      return null;
    }
  }

  Future<void> resetTotals() async {
    if (!real) return;
    try {
      await _core.resetTotalTraffic();
    } catch (_) {}
  }

  /// Real TCP-connect latency to host:port (null = unreachable / timeout).
  static Future<int?> tcpPing(String host, int port, {int timeoutMs = 3000}) async {
    final sw = Stopwatch()..start();
    try {
      final sock = await Socket.connect(host, port, timeout: Duration(milliseconds: timeoutMs));
      sw.stop();
      sock.destroy();
      return sw.elapsedMilliseconds < 1 ? 1 : sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
