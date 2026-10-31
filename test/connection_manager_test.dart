import 'dart:async';

import 'package:alone_vpn/core/connection/connection_manager.dart';
import 'package:alone_vpn/core/connection/engines.dart';
import 'package:alone_vpn/core/connection/link_state.dart';
import 'package:alone_vpn/core/connection/vpn_engine.dart';
import 'package:alone_vpn/data/stores.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test double for the manager logic only. It is not part of the app.
class FakeEngine extends ChangeNotifier implements VpnEngine {
  FakeEngine(
    this.kind, {
    this.installed = true,
    this.startTime = Duration.zero,
    this.outcome = LinkState.connected,
    this.stopWorks = true,
    this.log,
  });

  @override
  final EngineKind kind;
  @override
  final bool installed;
  Duration startTime;
  LinkState outcome;
  bool stopWorks;
  final List<String>? log;
  int startCalls = 0;
  int stopCalls = 0;
  EngineStatus _s = EngineStatus.disconnected;
  Completer<void>? _gate;

  @override
  String get label => 'fake-${kind.name}';

  @override
  EngineStatus get status => _s;

  void _set(LinkState s, {String? error}) {
    _s = EngineStatus(s, error: error);
    notifyListeners();
  }

  /// Simulates something outside the manager changing the engine (service killed, etc.).
  void forceState(LinkState s) => _set(s);

  @override
  Future<void> start() async {
    startCalls++;
    log?.add('start:${kind.name}');
    _set(LinkState.connecting);
    final gate = Completer<void>();
    _gate = gate;
    final t = Timer(startTime, () {
      if (!gate.isCompleted) gate.complete();
    });
    await gate.future;
    t.cancel();
    if (_s.state != LinkState.connecting) return;
    _set(outcome, error: outcome == LinkState.error ? 'boom' : null);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    log?.add('stop:${kind.name}');
    if (!stopWorks) return;
    _set(LinkState.disconnected);
    final g = _gate;
    if (g != null && !g.isCompleted) g.complete();
  }

  @override
  void cancel() {
    if (_s.state != LinkState.connecting) return;
    _set(LinkState.disconnected);
    final g = _gate;
    if (g != null && !g.isCompleted) g.complete();
  }
}

const _ms = Duration(milliseconds: 20);

ConnectionManager _manager(
  FakeEngine manual,
  VpnEngine smart, {
  Duration start = const Duration(seconds: 5),
  Duration stop = const Duration(seconds: 5),
}) {
  final m = ConnectionManager(
    engines: {EngineKind.manual: manual, EngineKind.smart: smart},
    startTimeout: start,
    stopTimeout: stop,
  );
  addTearDown(m.dispose);
  return m;
}

void main() {
  group('Conn state mapping', () {
    test('every Conn state maps to a typed link state', () {
      expect(XrayEngine.mapConnState(CS.off, -1), LinkState.disconnected);
      expect(XrayEngine.mapConnState(CS.connecting, 0), LinkState.preparing);
      expect(XrayEngine.mapConnState(CS.connecting, 1), LinkState.preparing);
      expect(XrayEngine.mapConnState(CS.connecting, 2), LinkState.connecting);
      expect(XrayEngine.mapConnState(CS.connecting, 3), LinkState.connecting);
      expect(XrayEngine.mapConnState(CS.on, 4), LinkState.connected);
      expect(XrayEngine.mapConnState(CS.failed, 2), LinkState.error);
      expect(XrayEngine.mapConnState(CS.disconnecting, 4), LinkState.disconnecting);
    });

    test('only the states that hold the tunnel occupy it', () {
      expect(LinkState.disconnected.occupiesTunnel, isFalse);
      expect(LinkState.error.occupiesTunnel, isFalse);
      expect(LinkState.engineNotInstalled.occupiesTunnel, isFalse);
      expect(LinkState.preparing.occupiesTunnel, isTrue);
      expect(LinkState.connecting.occupiesTunnel, isTrue);
      expect(LinkState.connected.occupiesTunnel, isTrue);
      expect(LinkState.disconnecting.occupiesTunnel, isTrue);
    });
  });

  group('state transitions', () {
    test('connect then disconnect walks connecting -> connected -> disconnected', () async {
      final manual = FakeEngine(EngineKind.manual);
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      final seen = <LinkState>[];
      m.addListener(() {
        final s = m.statusOf(EngineKind.manual).state;
        if (seen.isEmpty || seen.last != s) seen.add(s);
      });
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      await m.disconnect(EngineKind.manual);
      expect(seen, [LinkState.connecting, LinkState.connected, LinkState.disconnected]);
    });

    test('an engine failure is reported with its message', () async {
      final manual = FakeEngine(EngineKind.manual, outcome: LinkState.error);
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      expect(await m.connect(EngineKind.manual), ConnectResult.failed);
      expect(m.statusOf(EngineKind.manual).state, LinkState.error);
      expect(m.errorOf(EngineKind.manual), 'boom');
      expect(m.busy, isFalse);
    });

    test('toggle connects, then disconnects, then can reconnect', () async {
      final manual = FakeEngine(EngineKind.manual);
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      await m.toggle(EngineKind.manual);
      expect(m.statusOf(EngineKind.manual).state, LinkState.connected);
      await m.toggle(EngineKind.manual);
      expect(m.statusOf(EngineKind.manual).state, LinkState.disconnected);
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      expect(manual.startCalls, 2);
    });
  });

  group('mutual exclusion', () {
    test('the running engine is stopped before the other one starts, never both up', () async {
      final log = <String>[];
      final manual = FakeEngine(EngineKind.manual, log: log);
      final smart = FakeEngine(EngineKind.smart, log: log);
      final m = _manager(manual, smart);
      var maxOccupying = 0;
      m.addListener(() => maxOccupying = maxOccupying < m.occupying.length ? m.occupying.length : maxOccupying);

      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      expect(await m.connect(EngineKind.smart), ConnectResult.success);

      expect(log, ['start:manual', 'stop:manual', 'start:smart']);
      expect(maxOccupying, 1);
      expect(m.activeEngine, EngineKind.smart);
      expect(m.statusOf(EngineKind.manual).state, LinkState.disconnected);
    });

    test('a failed stop blocks the new engine from starting', () async {
      final manual = FakeEngine(EngineKind.manual, stopWorks: false);
      final smart = FakeEngine(EngineKind.smart);
      final m = _manager(manual, smart, stop: const Duration(milliseconds: 100));
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      expect(await m.connect(EngineKind.smart), ConnectResult.stopFailed);
      expect(smart.startCalls, 0);
      expect(m.occupying, [EngineKind.manual]);
    });

    test('an engine that is not installed is refused without touching the running one', () async {
      final manual = FakeEngine(EngineKind.manual);
      final smart = SmartEngine();
      final m = _manager(manual, smart);
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      expect(await m.connect(EngineKind.smart), ConnectResult.engineNotInstalled);
      expect(manual.stopCalls, 0);
      expect(m.statusOf(EngineKind.manual).state, LinkState.connected);
      expect(m.statusOf(EngineKind.smart).state, LinkState.engineNotInstalled);
    });

    test('the smart placeholder never reports activity and refuses to start', () async {
      final smart = SmartEngine();
      expect(smart.installed, isFalse);
      expect(smart.status.state, LinkState.engineNotInstalled);
      await expectLater(smart.start(), throwsA(isA<EngineNotInstalled>()));
      await smart.stop();
      expect(smart.status.state, LinkState.engineNotInstalled);
    });
  });

  group('duplicate, cancel, timeout, termination', () {
    test('a second request while one is in flight is ignored', () async {
      final manual = FakeEngine(EngineKind.manual, startTime: const Duration(milliseconds: 150));
      final smart = FakeEngine(EngineKind.smart);
      final m = _manager(manual, smart);
      final a = m.connect(EngineKind.manual);
      final b = m.connect(EngineKind.manual);
      final c = m.connect(EngineKind.smart);
      expect(await b, ConnectResult.duplicate);
      expect(await c, ConnectResult.duplicate);
      expect(await a, ConnectResult.success);
      expect(manual.startCalls, 1);
      expect(smart.startCalls, 0);
    });

    test('connecting an engine that is already connected does nothing', () async {
      final manual = FakeEngine(EngineKind.manual);
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      expect(await m.connect(EngineKind.manual), ConnectResult.alreadyActive);
      expect(manual.startCalls, 1);
    });

    test('cancelling while connecting ends cleanly in disconnected', () async {
      final manual = FakeEngine(EngineKind.manual, startTime: const Duration(seconds: 5));
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      final f = m.connect(EngineKind.manual);
      await Future<void>.delayed(_ms);
      expect(m.statusOf(EngineKind.manual).state, LinkState.connecting);
      m.cancel();
      expect(await f, ConnectResult.cancelled);
      expect(m.statusOf(EngineKind.manual).state, LinkState.disconnected);
      expect(m.busy, isFalse);
      expect(m.occupying, isEmpty);
    });

    test('a start that never finishes times out and leaves nothing running', () async {
      final manual = FakeEngine(EngineKind.manual, startTime: const Duration(seconds: 5));
      final m = _manager(manual, FakeEngine(EngineKind.smart), start: const Duration(milliseconds: 100));
      expect(await m.connect(EngineKind.manual), ConnectResult.timeout);
      expect(m.statusOf(EngineKind.manual).state, LinkState.disconnected);
      expect(m.busy, isFalse);
    });

    test('the service being terminated from outside shows up immediately', () async {
      final manual = FakeEngine(EngineKind.manual);
      final m = _manager(manual, FakeEngine(EngineKind.smart));
      var notified = 0;
      m.addListener(() => notified++);
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
      final before = notified;
      manual.forceState(LinkState.disconnected);
      expect(notified, greaterThan(before));
      expect(m.activeEngine, isNull);
      expect(m.statusOf(EngineKind.manual).state, LinkState.disconnected);
      expect(await m.connect(EngineKind.manual), ConnectResult.success);
    });
  });
}
