/// One typed connection state shared by every engine (Xray today, a smart engine later).
enum LinkState { disconnected, preparing, connecting, connected, disconnecting, error, engineNotInstalled }

extension LinkStateX on LinkState {
  /// True while the engine owns the VPN tunnel: coming up, up, or going down.
  bool get occupiesTunnel =>
      this == LinkState.preparing ||
      this == LinkState.connecting ||
      this == LinkState.connected ||
      this == LinkState.disconnecting;

  bool get isTransitional =>
      this == LinkState.preparing || this == LinkState.connecting || this == LinkState.disconnecting;
}

/// What an engine reports about itself. [error] is only set in [LinkState.error].
class EngineStatus {
  const EngineStatus(this.state, {this.error, this.since});
  final LinkState state;
  final String? error;
  final DateTime? since;

  static const EngineStatus disconnected = EngineStatus(LinkState.disconnected);
  static const EngineStatus notInstalled = EngineStatus(LinkState.engineNotInstalled);

  @override
  bool operator ==(Object other) =>
      other is EngineStatus && other.state == state && other.error == error && other.since == since;

  @override
  int get hashCode => Object.hash(state, error, since);
}
