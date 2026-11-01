// Runs only when VPNGATE_LIVE=1 (a CI lab). It talks to the real VPN Gate API and a public
// IP-echo service. It never prints server addresses or profile contents.
import 'dart:io';

import 'package:alone_vpn/data/vpngate.dart';
import 'package:alone_vpn/services/vpngate_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = Platform.environment['VPNGATE_LIVE'] == '1';
  final skip = live ? false : 'set VPNGATE_LIVE=1 to run against the real service';

  test('the real VPN Gate API answers and its profiles parse', () async {
    final body = await fetchVpnGateCsv();
    final r = parseVpnGateCsv(body);
    // ignore: avoid_print
    print('LIVE: bytes=${body.length} rows=${r.rows} valid=${r.servers.length} rejected=${r.rejected}');
    final byCountry = <String, int>{};
    final proto = <String, int>{};
    final ciphers = <String, int>{};
    for (final s in r.servers) {
      byCountry[s.countryShort] = (byCountry[s.countryShort] ?? 0) + 1;
      final p = RegExp(r'^proto\s+(\S+)', multiLine: true).firstMatch(s.config)?.group(1) ?? '?';
      proto[p] = (proto[p] ?? 0) + 1;
      final c = RegExp(r'^(?:cipher|data-ciphers)\s+(\S+)', multiLine: true).firstMatch(s.config)?.group(1) ?? '-';
      ciphers[c] = (ciphers[c] ?? 0) + 1;
    }
    final top = byCountry.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('LIVE: countries=${byCountry.length} top=${top.take(6).map((e) => '${e.key}:${e.value}').join(',')} proto=$proto cipher=$ciphers');
    final best = List<VpnGateServer>.of(r.servers)..sort((a, b) => b.score.compareTo(a.score));
    for (final s in best.take(3)) {
      // ignore: avoid_print
      print('LIVE: sample ${s.countryShort} score=${s.score} ping=${s.pingMs} speed=${s.speedMbps.toStringAsFixed(1)}Mbps log="${s.logType}"');
    }
    expect(r.servers, isNotEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('the public IP probes answer', () async {
    final ip = await fetchPublicIp();
    final v6 = await fetchIpv6Probe();
    // ignore: avoid_print
    print('LIVE: ip probe ok=${ip != null} dual-stack probe ok=${v6 != null} sees_ipv6=${v6?.contains(':')}');
    expect(ip, isNotNull);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 1)));
}
