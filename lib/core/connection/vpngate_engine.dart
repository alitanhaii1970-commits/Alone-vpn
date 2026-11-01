import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/ovpn.dart';
import '../../data/stores.dart';
import '../../data/vpngate.dart';
import '../../services/smart_servers.dart';
import '../i18n.dart';
import 'engines.dart';
import 'link_state.dart';
import 'vpn_engine.dart';

/// The tunnel the Smart engine drives. The real one is [ConnSmartTunnel] (the app's existing
/// OpenVPN path); tests give it a stand-in so the selection/verification logic can be exercised.
abstract class SmartTunnel implements Listenable {
  LinkState get state;
  DateTime? get since;
  Future<void> connect(VpnGateServer server);
  Future<void> disconnect();
  void cancel();
}

/// Starts a public-relay profile through [Conn] (OpenVPN for Android's remote API). The profile is
/// transient: it is never added to the user's server list.
class ConnSmartTunnel extends ChangeNotifier implements SmartTunnel {
  ConnSmartTunnel(this._c) {
    _c.addListener(notifyListeners);
  }
  final Conn _c;

  bool get _mine => _c.origin == SessionOrigin.smart;

  @override
  LinkState get state => _mine ? linkStateOfConn(_c.state, _c.hs) : LinkState.disconnected;

  @override
  DateTime? get since => _mine && _c.state == CS.on ? _c.since : null;

  @override
  Future<void> connect(VpnGateServer s) async {
    final link = ovpnLink(s.config, name: '${s.countryLong} · ${s.hostName}');
    final srv = ServerStore.I.transient(link);
    if (srv == null) throw StateError('profile could not be read');
    if (_c.state == CS.failed) _c.dismissFailure();
    await _c.connect(smart: srv);
  }

  @override
  Future<void> disconnect() async {
    if (!_mine) return;
    switch (_c.state) {
      case CS.on:
        await _c.disconnect();
        break;
      case CS.connecting:
        _c.cancel();
        break;
      case CS.failed:
        _c.dismissFailure();
        break;
      case CS.off:
      case CS.disconnecting:
        break;
    }
  }

  @override
  void cancel() {
    if (_mine) _c.cancel();
  }

  @override
  void dispose() {
    _c.removeListener(notifyListeners);
    super.dispose();
  }
}

enum _Phase { idle, fetching, trying, up, failed }

/// Smart mode: VPN Gate public relays through OpenVPN.
///
/// It picks relays by quality, tries them one after another, and reports "connected" only after
/// the tunnel is up AND the public IP seen from outside has really changed.
class VpnGateEngine extends ChangeNotifier implements VpnEngine {
  VpnGateEngine({
    required this.tunnel,
    required this.servers,
    required this.openVpnInstalled,
    required this.publicIp,
    required this.ipv6Probe,
    this.maxAttempts = 6,
    this.settle = const Duration(milliseconds: 1500),
  }) {
    tunnel.addListener(_relay);
  }

  final SmartTunnel tunnel;
  final SmartServerManager servers;
  final Future<bool> Function() openVpnInstalled;
  final Future<String?> Function() publicIp;
  final Future<String?> Function() ipv6Probe;
  final int maxAttempts;
  final Duration settle;

  bool? _installed;
  _Phase _phase = _Phase.idle;
  bool _cancelled = false;
  bool _busy = false;
  String? _error;
  VpnGateServer? _current;
  String? _exitIp;
  String? _ipBefore;
  bool? _ipv6Exposed;
  int _attempt = 0;

  /// The relay being tried, or the one in use.
  VpnGateServer? get current => _current;
  String? get exitIp => _exitIp;
  String? get ipBefore => _ipBefore;

  /// True when IPv6 traffic is seen leaving outside the tunnel; null when the probe could not tell.
  bool? get ipv6Exposed => _ipv6Exposed;
  int get attempt => _attempt;

  @override
  EngineKind get kind => EngineKind.smart;

  @override
  String get label => 'OpenVPN';

  @override
  bool get installed => _installed ?? true;

  @override
  Future<void> refresh() async {
    final v = await openVpnInstalled();
    if (v != _installed) {
      _installed = v;
      notifyListeners();
    }
  }

  void _relay() {
    if (_phase == _Phase.up && tunnel.state != LinkState.connected) {
      _phase = _Phase.idle; // the tunnel went away underneath us
    }
    notifyListeners();
  }

  @override
  EngineStatus get status {
    if (!installed) return EngineStatus.notInstalled;
    switch (_phase) {
      case _Phase.fetching:
        return const EngineStatus(LinkState.preparing);
      case _Phase.failed:
        return EngineStatus(LinkState.error, error: _error);
      case _Phase.trying:
        final t = tunnel.state;
        if (t == LinkState.connected || t == LinkState.error || t == LinkState.disconnected) {
          return const EngineStatus(LinkState.connecting); // verifying, or moving to the next relay
        }
        return EngineStatus(t);
      case _Phase.up:
        return EngineStatus(LinkState.connected, since: tunnel.since);
      case _Phase.idle:
        return tunnel.state == LinkState.disconnecting
            ? const EngineStatus(LinkState.disconnecting)
            : EngineStatus.disconnected;
    }
  }

  void _fail(String message) {
    _phase = _Phase.failed;
    _error = message;
    notifyListeners();
  }

  @override
  Future<void> start() async {
    await refresh();
    if (!installed) throw const EngineNotInstalled('OpenVPN for Android');
    _cancelled = false;
    _busy = true;
    _error = null;
    _current = null;
    _exitIp = null;
    _ipBefore = null;
    _ipv6Exposed = null;
    _attempt = 0;
    _phase = _Phase.fetching;
    servers.clearFailed();
    notifyListeners();
    try {
      final ok = await servers.refresh();
      if (_cancelled) return;
      if (!ok) {
        _fail(trOr('vg_err_list', 'فهرست سرورهای VPN Gate در دسترس نیست', 'The VPN Gate server list is unavailable'));
        return;
      }
      final before = await publicIp();
      if (_cancelled) return;
      if (before == null) {
        _fail(trOr('vg_err_ip', 'آی‌پی عمومی فعلی خونده نشد؛ اینترنت رو چک کن', 'Could not read the current public IP; check your internet'));
        return;
      }
      _ipBefore = before;
      final list = servers.candidates();
      if (list.isEmpty) {
        _fail(trOr('vg_err_none', 'برای این انتخاب سرور سالمی نیست', 'No usable server for this choice'));
        return;
      }
      _phase = _Phase.trying;
      for (final s in list) {
        if (_cancelled || _attempt >= maxAttempts) break;
        _attempt++;
        _current = s;
        notifyListeners();
        try {
          await tunnel.connect(s);
        } catch (_) {
          servers.markFailed(s.ip);
          continue;
        }
        if (_cancelled) {
          await tunnel.disconnect();
          return;
        }
        if (tunnel.state != LinkState.connected) {
          servers.markFailed(s.ip);
          continue;
        }
        // The tunnel says it is up. Only a changed public IP proves traffic really goes through it.
        String? after;
        for (var i = 0; i < 3 && after == null && !_cancelled; i++) {
          if (i > 0) await Future<void>.delayed(settle);
          after = await publicIp();
        }
        if (_cancelled) {
          await tunnel.disconnect();
          return;
        }
        if (after != null && after != before) {
          _exitIp = after;
          final v6 = await ipv6Probe();
          _ipv6Exposed = v6 == null ? null : v6.contains(':');
          _phase = _Phase.up;
          notifyListeners();
          return;
        }
        servers.markFailed(s.ip);
        await tunnel.disconnect();
      }
      if (!_cancelled) {
        _fail('${trOr('vg_err_all', 'هیچ‌کدوم از سرورهای امتحان‌شده کار نکرد', 'None of the servers tried worked')} ($_attempt)');
        await tunnel.disconnect();
      }
    } finally {
      _busy = false;
      if (_cancelled && _phase != _Phase.up) _phase = _Phase.idle;
      notifyListeners();
    }
  }

  @override
  Future<void> stop() async {
    _cancelled = true;
    _phase = _Phase.idle;
    notifyListeners();
    await tunnel.disconnect();
  }

  @override
  void cancel() {
    _cancelled = true;
    tunnel.cancel();
    if (_phase == _Phase.fetching || _phase == _Phase.trying) _phase = _Phase.idle;
    notifyListeners();
  }

  /// True while a start() is running.
  bool get busy => _busy;

  @override
  void dispose() {
    tunnel.removeListener(_relay);
    super.dispose();
  }
}
