import 'package:flutter/foundation.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import '../i18n.dart';
import 'link_state.dart';
import 'vpn_engine.dart';

/// The manual engine: a thin adapter over the existing [Conn] state machine (Xray, and OpenVPN
/// for .ovpn profiles). It adds no behaviour of its own; [Conn] stays the source of truth.
class XrayEngine extends ChangeNotifier implements VpnEngine {
  XrayEngine(this._conn) {
    _last = status;
    _conn.addListener(_changed);
  }

  final Conn _conn;
  late EngineStatus _last;

  void _changed() {
    final next = status;
    if (next == _last) return;
    _last = next;
    notifyListeners();
  }

  @override
  EngineKind get kind => EngineKind.manual;

  @override
  String get label => (_conn.server?.isOvpn ?? false) ? 'OpenVPN' : 'Xray';

  @override
  bool get installed => true;

  @override
  EngineStatus get status {
    final s = _conn.state;
    return EngineStatus(
      mapConnState(s, _conn.hs),
      error: s == CS.failed ? _failText() : null,
      since: s == CS.on ? _conn.since : null,
    );
  }

  String _failText() {
    final i = _conn.failStep;
    if (i < 0) return trOr('cm_err_generic', 'خطا', 'Error');
    return tr(kHsSteps[i.clamp(0, kHsSteps.length - 1).toInt()]);
  }

  /// Resolve + TCP probe (hs 0..1) count as preparing; TLS + tunnel (hs 2..3) as connecting.
  @visibleForTesting
  static LinkState mapConnState(CS s, int hs) {
    switch (s) {
      case CS.off:
        return LinkState.disconnected;
      case CS.connecting:
        return hs < 2 ? LinkState.preparing : LinkState.connecting;
      case CS.on:
        return LinkState.connected;
      case CS.failed:
        return LinkState.error;
      case CS.disconnecting:
        return LinkState.disconnecting;
    }
  }

  @override
  Future<void> start() => _conn.connect();

  @override
  Future<void> stop() async {
    switch (_conn.state) {
      case CS.on:
        await _conn.disconnect();
        break;
      case CS.connecting:
        _conn.cancel();
        break;
      case CS.failed:
        _conn.dismissFailure();
        break;
      case CS.off:
      case CS.disconnecting:
        break;
    }
  }

  @override
  void cancel() => _conn.cancel();

  @override
  void dispose() {
    _conn.removeListener(_changed);
    super.dispose();
  }
}

/// Placeholder for the smart engine (Lantern / Radiance). No binaries are bundled in this
/// build, so it never connects and never reports any activity.
class SmartEngine extends ChangeNotifier implements VpnEngine {
  @override
  EngineKind get kind => EngineKind.smart;

  @override
  String get label => 'Lantern / Radiance';

  @override
  bool get installed => false;

  @override
  EngineStatus get status => EngineStatus.notInstalled;

  @override
  Future<void> start() async => throw const EngineNotInstalled('Lantern / Radiance');

  @override
  Future<void> stop() async {}

  @override
  void cancel() {}
}
