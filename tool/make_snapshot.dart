// Builds the relay snapshot that ALONE VPN publishes for people who cannot reach vpngate.net.
// Runs in CI (GitHub Actions), never in the app:  dart run tool/make_snapshot.dart out.json
// It fetches the official API, keeps only profiles that pass the same validation the app uses, and writes
// the best relays overall plus the best few of every country.
import 'dart:convert';
import 'dart:io';

import '../lib/data/vpngate.dart';

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : 'snapshot.json';
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final req = await client.getUrl(Uri.parse('https://www.vpngate.net/api/iphone/'));
    req.headers.set('User-Agent', 'ALONE-VPN-snapshot');
    final res = await req.close().timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      stderr.writeln('VPN Gate API answered HTTP ${res.statusCode}');
      exit(2);
    }
    final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    final parsed = parseVpnGateCsv(utf8.decode(bytes, allowMalformed: true));
    stdout.writeln('rows=${parsed.rows} valid=${parsed.servers.length} rejected=${parsed.rejected}');
    if (parsed.servers.length < 5) {
      stderr.writeln('too few usable servers; not writing a snapshot');
      exit(3);
    }
    final picked = selectForSnapshot(parsed.servers);
    await File(out).writeAsString(snapshotToJson(picked, DateTime.now()));
    final countries = <String>{for (final s in picked) s.countryShort};
    stdout.writeln('snapshot: ${picked.length} relays, ${countries.length} countries');
  } finally {
    client.close(force: true);
  }
}
