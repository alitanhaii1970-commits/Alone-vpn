import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/stores.dart';
import 'engines.dart';
import 'link_state.dart';
import 'vpn_engine.dart';

enum ConnectResult { success, failed, cancelled, timeout, duplicate, alreadyActive, engineNotInstalled, stopFailed }

/// The single place that starts and stops tunnel engines.
///
/// - One request at a time: a second request while one is in flight returns [ConnectResult.duplicate].
/// - Mutual exclusion: another engine that holds the tunnel is stopped (and confirmed down) before
///   the requested one starts; if it cannot be stopped the new engine is NOT started.
/// - An engine that is not installed is refused before anything else is touched.
/// - State is never cached here: every status comes from the engines, so service termination or a
///   change made elsewhere shows up immediately.
class ConnectionManager extends ChangeNotifier {
  ConnectionManager({
    required Map<EngineKind, VpnEngine> engines,
    this.startTimeout = const Duration(seconds: 90),
    this.stopTimeout = const Duration(seconds: 25),
  }) : _engines = Map<EngineKind, VpnEngine>.unmodifiable(engines) {
    for (final e in _engines.values) {
      e.addListener(notifyListeners);
    }
  }

  static final ConnectionManager I = ConnectionManager(
    engines: <EngineKind, VpnEngine>{
      EngineKind.manual: XrayEngine(Conn.I),
      EngineKind.smart: SmartEngine(),
    },
  );

  final Map<EngineKind, VpnEngine> _engines;
  final Duration startTimeout;
  final Duration stopTimeout;
  final Map<EngineKind, String> _errors = <EngineKind, String>{};
  EngineKind? _pending;
  bool _cancelRequested = false;

  VpnEngine engine(EngineKind k) => _engines[k]!;
  EngineStatus statusOf(EngineKind k) => engine(k).status;

  /// The engine a request is currently being processed for, if any.
  EngineKind? get pending => _pending;
  bool get busy => _pending != null;

  /// Every engine that currently holds the tunnel. Must never have more than one entry.
  List<EngineKind> get occupying => <EngineKind>[
        for (final e in _engines.entries)
          if (e.value.status.state.occupiesTunnel) e.key,
      ];

  EngineKind? get activeEngine {
    final o = occupying;
    return o.isEmpty ? null : o.first;
  }

  String? errorOf(EngineKind k) {
    final s = statusOf(k);
    if (s.state == LinkState.error) return s.error ?? _errors[k];
    return _errors[k];
  }

  Future<ConnectResult> connect(EngineKind kind) async {
    if (_pending != null) return ConnectResult.duplicate;
    final target = engine(kind);
    if (!target.installed) return ConnectResult.engineNotInstalled;
    final before = target.status.state;
    if (before == LinkState.connected || before == LinkState.preparing || before == LinkState.connecting) {
      return ConnectResult.alreadyActive;
    }
    _pending = kind;
    _cancelRequested = false;
    _errors.remove(kind);
    notifyListeners();
    try {
      for (final entry in _engines.entries) {
        if (entry.key == kind || !entry.value.status.state.occupiesTunnel) continue;
        if (!await _stopEngine(entry.value)) return ConnectResult.stopFailed;
        if (_cancelRequested) return ConnectResult.cancelled;
      }
      if (before == LinkState.disconnecting && !await _stopEngine(target)) return ConnectResult.stopFailed;
      if (_cancelRequested) return ConnectResult.cancelled;
      try {
        await target.start().timeout(startTimeout);
      } on TimeoutException {
        target.cancel();
        await _stopEngine(target);
        return ConnectResult.timeout;
      } catch (e) {
        _errors[kind] = '$e';
        await _stopEngine(target);
        return ConnectResult.failed;
      }
      switch (target.status.state) {
        case LinkState.connected:
          return ConnectResult.success;
        case LinkState.error:
          return ConnectResult.failed;
        default:
          return _cancelRequested ? ConnectResult.cancelled : ConnectResult.failed;
      }
    } finally {
      _pending = null;
      notifyListeners();
    }
  }

  Future<void> disconnect(EngineKind kind) async {
    if (_pending == kind) {
      cancel();
      return;
    }
    await _stopEngine(engine(kind));
    notifyListeners();
  }

  /// Aborts the attempt in flight (or a connecting engine that was started elsewhere).
  void cancel() {
    final k = _pending;
    if (k != null) {
      _cancelRequested = true;
      engine(k).cancel();
      return;
    }
    final a = activeEngine;
    if (a != null && statusOf(a).state.isTransitional) engine(a).cancel();
  }

  /// Connect when idle, cancel while connecting, disconnect while connected.
  Future<ConnectResult?> toggle(EngineKind kind) async {
    switch (statusOf(kind).state) {
      case LinkState.connected:
        await disconnect(kind);
        return null;
      case LinkState.preparing:
      case LinkState.connecting:
        if (_pending == kind) {
          cancel();
        } else {
          engine(kind).cancel();
        }
        return null;
      case LinkState.disconnecting:
        return null;
      case LinkState.disconnected:
      case LinkState.error:
      case LinkState.engineNotInstalled:
        return connect(kind);
    }
  }

  /// Stops [e] and waits until it reports that it is down. False when it is still up after [stopTimeout].
  Future<bool> _stopEngine(VpnEngine e) async {
    try {
      await e.stop().timeout(stopTimeout);
    } catch (_) {
      // fall through: what matters is the state the engine reports afterwards
    }
    if (!e.status.state.occupiesTunnel) return true;
    final done = Completer<void>();
    void check() {
      if (!e.status.state.occupiesTunnel && !done.isCompleted) done.complete();
    }

    e.addListener(check);
    try {
      await done.future.timeout(stopTimeout);
    } catch (_) {
      // timed out
    } finally {
      e.removeListener(check);
    }
    return !e.status.state.occupiesTunnel;
  }

  @override
  void dispose() {
    for (final e in _engines.values) {
      e.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
