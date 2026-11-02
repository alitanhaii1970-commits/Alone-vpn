import 'dart:async';
import 'dart:convert';

import 'package:alone_vpn/data/vpngate.dart';
import 'package:alone_vpn/services/vpngate_api.dart';
import 'package:alone_vpn/services/vpngate_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/vpngate_fixture.dart';

String _csv() => csvOf([
      csvRow(ip: '203.0.113.51', score: 900, short: 'JP', country: 'Japan'),
      csvRow(ip: '203.0.113.52', score: 800, short: 'KR', country: 'South Korea'),
    ]);

String _snap() => snapshotToJson(parseVpnGateCsv(_csv()).servers, DateTime.utc(2026, 11, 1, 12));

void main() {
  group('list sources', () {
    test('the official API is used when it answers', () async {
      final c = MockClient((r) async => r.url.toString() == kVpnGateApi ? http.Response(_csv(), 200) : http.Response('no', 500));
      final r = await fetchListFromAnySource(client: c);
      expect(r.source, 'vpngate.net');
      expect(r.generatedAt, isNull);
      expect(r.servers, hasLength(2));
    });

    test('when the official API is blocked, ALONE\'s copy is used', () async {
      final c = MockClient((r) async {
        if (r.url.toString() == kVpnGateApi) throw const FormatException('connection reset');
        return http.Response(_snap(), 200);
      });
      final r = await fetchListFromAnySource(client: c);
      expect(kMirrorSources.map((m) => m.label), contains(r.source));
      expect(r.generatedAt, DateTime.utc(2026, 11, 1, 12));
      expect(r.servers, hasLength(2));
    });

    test('an official API that never answers does not block the mirrors', () async {
      final hang = Completer<http.Response>();
      final c = MockClient((r) => r.url.toString() == kVpnGateApi ? hang.future : Future.value(http.Response(_snap(), 200)));
      final r = await fetchListFromAnySource(client: c, officialTimeout: const Duration(milliseconds: 80));
      expect(r.generatedAt, isNotNull);
    });

    test('a mirror that answers garbage is skipped', () async {
      final bad = kMirrorSources.first.url;
      final c = MockClient((r) async {
        final u = r.url.toString();
        if (u == kVpnGateApi) return http.Response('x', 503);
        if (u == bad) return http.Response('<html>not json</html>', 200);
        return http.Response(_snap(), 200);
      });
      final r = await fetchListFromAnySource(client: c);
      expect(r.source, isNot(kMirrorSources.first.label));
      expect(r.servers, hasLength(2));
    });

    test('when nothing answers it says so', () async {
      final c = MockClient((r) async => http.Response('down', 503));
      await expectLater(
        fetchListFromAnySource(client: c, officialTimeout: const Duration(seconds: 1)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('vpngate.net'))),
      );
    });
  });

  group('snapshot', () {
    test('round trip keeps the relays', () {
      final snap = parseSnapshotJson(_snap())!;
      expect(snap.generatedAt, DateTime.utc(2026, 11, 1, 12));
      expect(snap.servers.map((s) => s.ip), ['203.0.113.51', '203.0.113.52']);
    });

    test('a profile that fails validation is dropped when the snapshot is read', () {
      final good = parseVpnGateCsv(_csv()).servers.first.toJson();
      final bad = <String, Object?>{...good, 'ip': '203.0.113.99', 'cfg': ovpnFixture(extra: 'up /bin/sh')};
      final body = '{"v":1,"generatedAt":"2026-11-01T00:00:00Z","servers":[${_j(good)},${_j(bad)}]}';
      expect(parseSnapshotJson(body)!.servers.map((s) => s.ip), ['203.0.113.51']);
    });

    test('things that are not snapshots are refused', () {
      expect(parseSnapshotJson('nope'), isNull);
      expect(parseSnapshotJson('{"v":2,"servers":[]}'), isNull);
      expect(parseSnapshotJson('{"v":1,"generatedAt":"x","servers":[]}'), isNull);
    });

    test('selection keeps the best overall and the best few of every country', () {
      final rows = <String>[
        for (var i = 0; i < 30; i++) csvRow(ip: '203.0.113.${100 + i}', score: 1000 - i, short: 'JP', country: 'Japan'),
        for (var i = 0; i < 9; i++) csvRow(ip: '203.0.113.${150 + i}', score: 100 - i, short: 'TH', country: 'Thailand'),
      ];
      final all = parseVpnGateCsv(csvOf(rows)).servers;
      final picked = selectForSnapshot(all, top: 10, perCountry: 3);
      expect(picked.where((s) => s.countryShort == 'TH'), hasLength(3));
      expect(picked.where((s) => s.countryShort == 'JP'), hasLength(10));
      expect(picked.first.score, 1000);
    });
  });

  group('public IP probes', () {
    test('plain and Cloudflare-style answers are read, garbage is not', () {
      expect(parseIpResponse('198.51.100.5\n'), '198.51.100.5');
      expect(parseIpResponse('fl=1\nip=198.51.100.6\nts=1\n'), '198.51.100.6');
      expect(parseIpResponse('2001:db8::1'), '2001:db8::1');
      expect(parseIpResponse('<html>blocked</html>'), isNull);
    });

    test('one working probe is enough, even when the others are blocked', () async {
      final c = MockClient((r) async {
        if (r.url.host == 'icanhazip.com') return http.Response('198.51.100.7\n', 200);
        throw const FormatException('blocked');
      });
      expect(await fetchPublicIp(client: c), '198.51.100.7');
    });

    test('no working probe gives null', () async {
      final c = MockClient((r) async => http.Response('nope', 500));
      expect(await fetchPublicIp(client: c), isNull);
    });
  });
}

String _j(Map<String, Object?> m) => jsonEncode(m);
