import 'dart:async';

import 'package:alone_vpn/core/connection/link_state.dart';
import 'package:alone_vpn/core/connection/vpn_engine.dart';
import 'package:alone_vpn/core/connection/vpngate_engine.dart';
import 'package:alone_vpn/data/vpngate.dart';
import 'package:alone_vpn/services/smart_servers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vpngate_fixture.dart';

/// Stand-in for the tunnel so the selection / verification logic can be tested without a device.
class FakeTunnel extends ChangeNotifier implements SmartTunnel {
  FakeTunnel({this.works = const {}, this.leaks = const {}, this.hold = false});
  final Set<String> works; // relays whose tunnel comes up
  final Set<String> leaks; // relays that come up but do not change the public IP
  bool hold; // keep connect() pending until cancel()
  LinkState _s = LinkState.disconnected;
  VpnGateServer? last;
  final List<String> tried = <String>[];
  int disconnects = 0;
  Completer<void>? _gate;

  bool get ipChanged => _s == LinkState.connected && !leaks.contains(last?.ip);

  @override
  LinkState get state => _s;
  @override
  DateTime? get since => _s == LinkState.connected ? DateTime(2026) : null;

  @override
  Future<void> connect(VpnGateServer s) async {
    last = s;
    tried.add(s.ip);
    _s = LinkState.connecting;
    notifyListeners();
    if (hold) {
      final g = _gate = Completer<void>();
      await g.future;
      return;
    }
    await Future<void>.delayed(Duration.zero);
    _s = works.contains(s.ip) ? LinkState.connected : LinkState.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    _s = LinkState.disconnected;
    notifyListeners();
  }

  @override
  void cancel() {
    _s = LinkState.disconnected;
    notifyListeners();
    final g = _gate;
    if (g != null && !g.isCompleted) g.complete();
  }
}

const String _before = '198.51.100.1';
const String _after = '198.51.100.77';

String _list() => csvOf([
      csvRow(ip: '203.0.113.41', score: 900, ping: 10, short: 'JP', country: 'Japan'),
      csvRow(ip: '203.0.113.42', score: 800, ping: 10, short: 'KR', country: 'South Korea'),
      csvRow(ip: '203.0.113.43', score: 700, ping: 10, short: 'US', country: 'United States'),
    ]);

VpnGateEngine _engine(
  FakeTunnel t, {
  SmartServerManager? servers,
  bool installed = true,
  Future<String?> Function()? ip,
  int maxAttempts = 6,
  Future<String?> Function()? v6,
}) {
  final e = VpnGateEngine(
    tunnel: t,
    servers: servers ?? SmartServerManager(storage: MemorySmartCache(), fetcher: csvFetcher(_list)),
    openVpnInstalled: () async => installed,
    publicIp: ip ?? () async => t.ipChanged ? _after : _before,
    ipv6Probe: v6 ?? () async => _before,
    maxAttempts: maxAttempts,
    settle: Duration.zero,
  );
  addTearDown(e.dispose);
  return e;
}

void main() {
  test('connects to the best relay and reports the verified public IP', () async {
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42'});
    final e = _engine(t);
    await e.start();
    expect(e.status.state, LinkState.connected);
    expect(t.tried, ['203.0.113.41']);
    expect(e.current?.countryShort, 'JP');
    expect(e.ipBefore, _before);
    expect(e.exitIp, _after);
    expect(e.ipv6Exposed, isFalse);
  });

  test('an IPv6 address seen from outside is reported as a leak', () async {
    final t = FakeTunnel(works: {'203.0.113.41'});
    final e = _engine(t, v6: () async => '2001:db8::1');
    await e.start();
    expect(e.status.state, LinkState.connected);
    expect(e.ipv6Exposed, isTrue);
  });

  test('moves on to the next relay when the first one fails', () async {
    final t = FakeTunnel(works: {'203.0.113.42'});
    final e = _engine(t);
    await e.start();
    expect(t.tried, ['203.0.113.41', '203.0.113.42']);
    expect(e.status.state, LinkState.connected);
    expect(e.current?.ip, '203.0.113.42');
  });

  test('a tunnel that is up but does not change the public IP is not a success', () async {
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42'}, leaks: {'203.0.113.41'});
    final e = _engine(t);
    await e.start();
    expect(t.tried, ['203.0.113.41', '203.0.113.42']);
    expect(t.disconnects, greaterThanOrEqualTo(1));
    expect(e.current?.ip, '203.0.113.42');
    expect(e.status.state, LinkState.connected);
  });

  test('it is not "connected" while the public IP is still being verified', () async {
    final gate = Completer<String?>();
    final t = FakeTunnel(works: {'203.0.113.41'});
    var calls = 0;
    final e = _engine(t, ip: () {
      calls++;
      return calls == 1 ? Future<String?>.value(_before) : gate.future;
    });
    final run = e.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(t.state, LinkState.connected);
    expect(e.status.state, LinkState.connecting);
    gate.complete(_after);
    await run;
    expect(e.status.state, LinkState.connected);
  });

  test('when every relay fails it ends in an error and leaves no tunnel', () async {
    final t = FakeTunnel();
    final e = _engine(t);
    await e.start();
    expect(e.status.state, LinkState.error);
    expect(e.status.error, isNotNull);
    expect(t.tried, hasLength(3));
    expect(t.state, LinkState.disconnected);
  });

  test('every relay that only "connects" without changing the IP also ends in an error', () async {
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42', '203.0.113.43'}, leaks: {'203.0.113.41', '203.0.113.42', '203.0.113.43'});
    final e = _engine(t);
    await e.start();
    expect(e.status.state, LinkState.error);
    expect(t.state, LinkState.disconnected);
  });

  test('stops after the attempt limit', () async {
    final t = FakeTunnel();
    final e = _engine(t, maxAttempts: 2);
    await e.start();
    expect(t.tried, hasLength(2));
    expect(e.status.state, LinkState.error);
  });

  test('a missing OpenVPN engine is reported, never faked', () async {
    final t = FakeTunnel(works: {'203.0.113.41'});
    final e = _engine(t, installed: false);
    await expectLater(e.start(), throwsA(isA<EngineNotInstalled>()));
    expect(e.installed, isFalse);
    expect(e.status.state, LinkState.engineNotInstalled);
    expect(t.tried, isEmpty);
  });

  test('when the public IP cannot be read beforehand, an exit equal to the relay address still proves the tunnel', () async {
    final t = FakeTunnel(works: {'203.0.113.41'});
    final e = _engine(t, ip: () async => t.state == LinkState.connected ? t.last?.ip : null);
    await e.start();
    expect(e.status.state, LinkState.connected);
    expect(e.ipBefore, isNull);
    expect(e.exitIp, '203.0.113.41');
  });

  test('when the public IP cannot be read beforehand, any other exit address is not proof', () async {
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42', '203.0.113.43'});
    final e = _engine(t, ip: () async => t.state == LinkState.connected ? '198.51.100.99' : null);
    await e.start();
    expect(e.status.state, LinkState.error);
    expect(t.state, LinkState.disconnected);
  });

  test('when the public IP cannot be read at all, nothing is claimed', () async {
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42', '203.0.113.43'});
    final e = _engine(t, ip: () async => null);
    await e.start();
    expect(e.status.state, LinkState.error);
    expect(t.state, LinkState.disconnected);
  });

  test('without any list (API down, no cache) it ends in an error', () async {
    final t = FakeTunnel(works: {'203.0.113.41'});
    final servers = SmartServerManager(storage: MemorySmartCache(), fetcher: () async => throw Exception('down'));
    final e = _engine(t, servers: servers);
    await e.start();
    expect(e.status.state, LinkState.error);
    expect(t.tried, isEmpty);
  });

  test('the cached list is used when the API is down', () async {
    final storage = MemorySmartCache();
    await SmartServerManager(storage: storage, fetcher: csvFetcher(_list)).refresh();
    final t = FakeTunnel(works: {'203.0.113.41'});
    final e = _engine(t, servers: SmartServerManager(storage: storage, fetcher: () async => throw Exception('down')));
    await e.start();
    expect(e.status.state, LinkState.connected);
  });

  test('the chosen country limits which relays are tried', () async {
    final servers = SmartServerManager(storage: MemorySmartCache(), fetcher: csvFetcher(_list));
    await servers.refresh();
    await servers.setCountry('US');
    final t = FakeTunnel(works: {'203.0.113.41', '203.0.113.42', '203.0.113.43'});
    final e = _engine(t, servers: servers);
    await e.start();
    expect(t.tried, ['203.0.113.43']);
    expect(e.current?.countryShort, 'US');
  });

  test('cancelling while a relay is being tried ends cleanly', () async {
    final t = FakeTunnel(hold: true);
    final e = _engine(t);
    final run = e.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(e.status.state, LinkState.connecting);
    e.cancel();
    await run;
    expect(e.status.state, LinkState.disconnected);
    expect(t.state, LinkState.disconnected);
  });

  test('stop disconnects, and losing the tunnel from outside is reflected', () async {
    final t = FakeTunnel(works: {'203.0.113.41'});
    final e = _engine(t);
    await e.start();
    expect(e.status.state, LinkState.connected);
    await t.disconnect(); // the service is killed from outside
    expect(e.status.state, LinkState.disconnected);
    await e.start();
    expect(e.status.state, LinkState.connected);
    await e.stop();
    expect(e.status.state, LinkState.disconnected);
  });
}
