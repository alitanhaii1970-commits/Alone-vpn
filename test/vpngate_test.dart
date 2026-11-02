import 'dart:convert';

import 'package:alone_vpn/data/vpngate.dart';
import 'package:alone_vpn/services/smart_servers.dart';
import 'package:alone_vpn/services/vpngate_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/vpngate_fixture.dart';

void main() {
  group('VPN Gate CSV parser', () {
    test('reads the documented layout and keeps every field', () {
      final r = parseVpnGateCsv(csvOf([csvRow(host: 'a', ip: '203.0.113.1', score: 900, ping: 30, speed: 12000000, country: 'South Korea', short: 'kr', log: '7 days')]));
      expect(r.rows, 1);
      expect(r.servers, hasLength(1));
      final s = r.servers.single;
      expect(s.hostName, 'a');
      expect(s.ip, '203.0.113.1');
      expect(s.score, 900);
      expect(s.pingMs, 30);
      expect(s.speedBps, 12000000);
      expect(s.speedMbps, 12);
      expect(s.countryLong, 'South Korea');
      expect(s.countryShort, 'KR');
      expect(s.logType, '7 days');
      expect(s.config, contains('remote 203.0.113.1 443'));
    });

    test('a quoted field with a comma does not shift the columns', () {
      final r = parseVpnGateCsv(csvOf([csvRow(ip: '203.0.113.2')]));
      expect(r.servers.single.ip, '203.0.113.2');
      expect(splitCsvLine('a,"b,c",d'), ['a', 'b,c', 'd']);
    });

    test('rows without a valid profile are dropped with a reason, nothing is repaired', () {
      final rows = [
        csvRow(ip: '203.0.113.3'),
        csvRow(ip: 'not-an-ip'),
        csvRow(ip: '203.0.113.4', config: ovpnFixture(extra: 'up /bin/sh')),
        csvRow(ip: '203.0.113.5', config: ovpnFixture(extra: 'auth-user-pass')),
        csvRow(ip: '203.0.113.6', config: ovpnFixture(extra: 'ca ca.crt', ca: false)),
        csvRow(ip: '203.0.113.7', config: ovpnFixture(ca: false)),
        csvRow(ip: '203.0.113.8', config: ovpnFixture(client: false)),
        csvRow(ip: '203.0.113.9', score: 0),
        '203.0.113.10,short,row',
        'h,203.0.113.11,5,5,5,X,XX,1,1,1,1,l,o,,###not-base64###',
      ];
      final r = parseVpnGateCsv(csvOf(rows));
      expect(r.servers.map((s) => s.ip), ['203.0.113.3']);
      expect(r.rejected['bad_ip'], 1);
      expect(r.rejected['script'], 1);
      expect(r.rejected['auth_user_pass'], 1);
      expect(r.rejected['external_file'] ?? r.rejected['no_ca'], isNotNull);
      expect(r.rejected['no_ca'], isNotNull);
      expect(r.rejected['no_client'], 1);
      expect(r.rejected['no_score'], 1);
      expect(r.rejected['short_row'], 1);
      expect(r.rejected['bad_base64'], 1);
    });

    test('profile validation names the problem', () {
      expect(ovpnProblem(ovpnFixture()), isNull);
      expect(ovpnProblem(ovpnFixture(extra: 'script-security 2')), 'script:script-security');
      expect(ovpnProblem(ovpnFixture(extra: 'management 127.0.0.1 7505')), 'script:management');
      expect(ovpnProblem(ovpnFixture(port: 70000)), 'bad_port');
      expect(ovpnProblem(ovpnFixture(host: 'bad host!')), isNotNull);
      expect(ovpnProblem('x' * 70000), 'size');
    });

    test('an empty or broken answer gives no servers', () {
      expect(parseVpnGateCsv('').servers, isEmpty);
      expect(parseVpnGateCsv('<html>down for maintenance</html>').servers, isEmpty);
    });
  });

  group('SmartServerManager', () {
    String body() => csvOf([
          csvRow(ip: '203.0.113.21', score: 500, ping: 10, speed: 90000000, short: 'JP', country: 'Japan'),
          csvRow(ip: '203.0.113.22', score: 900, ping: 80, speed: 10000000, short: 'KR', country: 'South Korea'),
          csvRow(ip: '203.0.113.23', score: 900, ping: 20, speed: 10000000, short: 'KR', country: 'South Korea'),
          csvRow(ip: '203.0.113.24', score: 900, ping: 20, speed: 30000000, short: 'US', country: 'United States'),
        ]);

    test('ranks by score, then ping, then speed', () async {
      final m = SmartServerManager(storage: MemorySmartCache(), fetcher: csvFetcher(body));
      expect(await m.refresh(), isTrue);
      expect(m.candidates().map((s) => s.ip), ['203.0.113.24', '203.0.113.23', '203.0.113.22', '203.0.113.21']);
    });

    test('country choice filters; failed relays are skipped', () async {
      final m = SmartServerManager(storage: MemorySmartCache(), fetcher: csvFetcher(body));
      await m.refresh();
      await m.setCountry('KR');
      expect(m.candidates().map((s) => s.ip), ['203.0.113.23', '203.0.113.22']);
      m.markFailed('203.0.113.23');
      expect(m.candidates().map((s) => s.ip), ['203.0.113.22']);
      m.clearFailed();
      expect(m.candidates(), hasLength(2));
      expect(m.countries().map((c) => c.$1).toSet(), {'JP', 'KR', 'US'});
      expect(m.countries().first.$1, 'KR'); // most relays first
    });

    test('a fresh list is not fetched again; a stale one is', () async {
      var calls = 0;
      var now = DateTime(2026, 1, 1, 12);
      final m = SmartServerManager(storage: MemorySmartCache(), fetcher: () { calls++; return csvFetcher(body)(); }, now: () => now);
      await m.refresh();
      await m.refresh();
      expect(calls, 1);
      now = now.add(const Duration(minutes: 31));
      await m.refresh();
      expect(calls, 2);
    });

    test('when the API is down the cached list is used', () async {
      final storage = MemorySmartCache();
      final a = SmartServerManager(storage: storage, fetcher: csvFetcher(body));
      await a.refresh();
      await a.setCountry('JP');
      await a.setConsent();

      final b = SmartServerManager(storage: storage, fetcher: () async => throw Exception('API down'));
      expect(await b.refresh(), isTrue);
      expect(b.fromCache, isTrue);
      expect(b.lastError, contains('API down'));
      expect(b.servers, hasLength(4));
      expect(b.country, 'JP');
      expect(b.consent, isTrue);
    });

    test('no cache and no API means no list, honestly', () async {
      final m = SmartServerManager(storage: MemorySmartCache(), fetcher: () async => throw Exception('API down'));
      expect(await m.refresh(), isFalse);
      expect(m.servers, isEmpty);
    });

    test('an answer with no usable server does not replace a good cache', () async {
      final storage = MemorySmartCache();
      final a = SmartServerManager(storage: storage, fetcher: csvFetcher(body));
      await a.refresh();
      final b = SmartServerManager(storage: storage, fetcher: csvFetcher(() => '<html>oops</html>'));
      expect(await b.refresh(force: true), isTrue);
      expect(b.servers, hasLength(4));
      expect(b.lastError, isNotNull);
    });

    test('with no network and no saved list, the snapshot bundled in the app is used', () async {
      final servers = parseVpnGateCsv(body()).servers;
      final m = SmartServerManager(
        storage: MemorySmartCache(),
        fetcher: () async => throw Exception('filtered'),
        bundled: () async => snapshotToJson(servers, DateTime.utc(2026, 11, 1)),
      );
      expect(await m.refresh(), isTrue);
      expect(m.servers, hasLength(4));
      expect(m.source, 'bundled');
      expect(m.fromCache, isTrue);
      expect(m.listTime, DateTime.utc(2026, 11, 1));
    });

    test('a bundled snapshot older than the saved list does not replace it; a newer one does', () async {
      final storage = MemorySmartCache();
      final first = SmartServerManager(storage: storage, fetcher: csvFetcher(body), now: () => DateTime.utc(2026, 11, 10), bundled: () async => null);
      await first.refresh();
      final servers = parseVpnGateCsv(body()).servers.take(2).toList();

      final older = SmartServerManager(storage: storage, fetcher: () async => throw Exception('x'), bundled: () async => snapshotToJson(servers, DateTime.utc(2026, 11, 1)));
      await older.load();
      expect(older.servers, hasLength(4));
      expect(older.source, 'saved');

      final newer = SmartServerManager(storage: storage, fetcher: () async => throw Exception('x'), bundled: () async => snapshotToJson(servers, DateTime.utc(2026, 11, 20)));
      await newer.load();
      expect(newer.servers, hasLength(2));
      expect(newer.source, 'bundled');
    });

    test('a bundled placeholder with no relays is ignored', () async {
      final m = SmartServerManager(storage: MemorySmartCache(), fetcher: () async => throw Exception('x'), bundled: () async => '{"v":1,"generatedAt":"2000-01-01T00:00:00Z","servers":[]}');
      expect(await m.refresh(), isFalse);
      expect(m.servers, isEmpty);
    });

    test('the source and its time are remembered', () async {
      final storage = MemorySmartCache();
      final a = SmartServerManager(storage: storage, fetcher: csvFetcher(body, source: 'vpngate.net'), now: () => DateTime.utc(2026, 11, 2), bundled: () async => null);
      await a.refresh();
      expect(a.source, 'vpngate.net');
      expect(a.listTime, DateTime.utc(2026, 11, 2));
      final b = SmartServerManager(storage: storage, fetcher: () async => throw Exception('x'), bundled: () async => null);
      await b.load();
      expect(b.source, 'saved');
      expect(b.listTime, DateTime.utc(2026, 11, 2));
    });

    test('the cache keeps only profiles that still validate', () async {
      final storage = MemorySmartCache({
        'v': 1,
        'servers': [
          VpnGateServer.fromJson({'ip': '203.0.113.30', 'cfg': ovpnFixture()})?.toJson(),
          {'ip': '203.0.113.31', 'cfg': ovpnFixture(extra: 'up /bin/sh')},
        ],
      });
      final m = SmartServerManager(storage: storage, fetcher: () async => throw Exception('x'));
      await m.load();
      expect(m.servers.map((s) => s.ip), ['203.0.113.30']);
      expect(jsonEncode(m.servers.single.toJson()), isNotEmpty);
    });
  });
}
