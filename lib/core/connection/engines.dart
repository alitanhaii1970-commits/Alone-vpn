import 'package:flutter/foundation.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import '../i18n.dart';
import 'link_state.dart';
import 'vpn_engine.dart';

/// Resolve + TCP probe (hs 0..1) count as preparing; TLS + tunnel (hs 2..3) as connecting.
LinkState linkStateOfConn(CS s, int hs) {
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

/// Localised name of the step the last attempt failed at.
String connFailText(Conn c) {
  final i = c.failStep;
  if (i < 0) return trOr('cm_err_generic', 'خطا', 'Error');
  return tr(kHsSteps[i.clamp(0, kHsSteps.length - 1).toInt()]);
}

/// The manual engine: a thin adapter over the existing [Conn] state machine (Xray, and OpenVPN
/// for .ovpn profiles the user added). It adds no behaviour of its own; [Conn] stays the source of
/// truth. It reports activity only for sessions the user started themselves, never for Smart ones.
class XrayEngine extends ChangeNotifier implements VpnEngine {
  XrayEngine(this._conn) {
    _last = status;
    _conn.addListener(_changed);
  }

  final Conn _conn;
  late EngineStatus _last;

  bool get _mine => _conn.origin == SessionOrigin.manual;

  void _changed() {
    final next = status;
    if (next == _last) return;
    _last = next;
    notifyListeners();
  }

  @override
  EngineKind get kind => EngineKind.manual;

  @override
  String get label => (ServerStore.I.active?.isOvpn ?? false) ? 'OpenVPN' : 'Xray';

  @override
  bool get installed => true;

  @override
  EngineStatus get status {
    if (!_mine) return EngineStatus.disconnected;
    final s = _conn.state;
    return EngineStatus(
      linkStateOfConn(s, _conn.hs),
      error: s == CS.failed ? connFailText(_conn) : null,
      since: s == CS.on ? _conn.since : null,
    );
  }

  @visibleForTesting
  static LinkState mapConnState(CS s, int hs) => linkStateOfConn(s, hs);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> start() => _conn.connect();

  @override
  Future<void> stop() async {
    if (!_mine) return;
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
  void cancel() {
    if (_mine) _conn.cancel();
  }

  @override
  void dispose() {
    _conn.removeListener(_changed);
    super.dispose();
  }
}
