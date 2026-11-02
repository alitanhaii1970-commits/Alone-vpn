import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/vpngate.dart';
import 'vpngate_api.dart';

/// Where the relay list can come from. The official API is tried first. Where it is filtered, ALONE's own
/// copy (made every few hours from that same API) is tried on several different hosts at once.
class ListSource {
  const ListSource(this.label, this.url, {this.snapshot = false});
  final String label;
  final String url;
  final bool snapshot;
}

const ListSource kOfficialSource = ListSource('vpngate.net', kVpnGateApi);

const List<ListSource> kMirrorSources = <ListSource>[
  ListSource('raw.githubusercontent.com', 'https://raw.githubusercontent.com/alitanhaii1970-commits/Alone-vpn/vpngate-data/snapshot.json', snapshot: true),
  ListSource('cdn.jsdelivr.net', 'https://cdn.jsdelivr.net/gh/alitanhaii1970-commits/Alone-vpn@vpngate-data/snapshot.json', snapshot: true),
  ListSource('github.com', 'https://github.com/alitanhaii1970-commits/Alone-vpn/raw/vpngate-data/snapshot.json', snapshot: true),
];

class FetchedList {
  const FetchedList(this.servers, this.source, this.generatedAt, this.rejected);
  final List<VpnGateServer> servers;

  /// Host label shown to the user.
  final String source;

  /// When the list was made (mirrors only; null = just fetched from the official API).
  final DateTime? generatedAt;
  final Map<String, int> rejected;
}

Future<FetchedList?> _fetchOne(http.Client c, ListSource s, Duration timeout, List<String> errors) async {
  try {
    final r = await c.get(Uri.parse(s.url), headers: const {'User-Agent': 'ALONE-VPN'}).timeout(timeout);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    if (r.bodyBytes.length > 20 * 1024 * 1024) throw Exception('answer too large');
    final body = utf8.decode(r.bodyBytes, allowMalformed: true);
    if (s.snapshot) {
      final snap = parseSnapshotJson(body);
      if (snap == null || snap.servers.isEmpty) throw Exception('no usable snapshot');
      return FetchedList(snap.servers, s.label, snap.generatedAt, const <String, int>{});
    }
    final p = parseVpnGateCsv(body);
    if (p.servers.isEmpty) throw Exception('no usable server');
    return FetchedList(p.servers, s.label, null, p.rejected);
  } catch (e) {
    errors.add('${s.label}: ${e.toString().split('\n').first}');
    return null;
  }
}

/// Official API first; if it does not answer in time, every mirror at once and the first valid answer wins.
Future<FetchedList> fetchListFromAnySource({
  http.Client? client,
  ListSource official = kOfficialSource,
  List<ListSource> mirrors = kMirrorSources,
  Duration officialTimeout = const Duration(seconds: 8),
  Duration mirrorTimeout = const Duration(seconds: 20),
}) async {
  final c = client ?? http.Client();
  final errors = <String>[];
  try {
    final o = await _fetchOne(c, official, officialTimeout, errors);
    if (o != null) return o;
    if (mirrors.isEmpty) throw StateError('no source answered: ${errors.join('; ')}');
    final done = Completer<FetchedList>();
    var left = mirrors.length;
    for (final m in mirrors) {
      _fetchOne(c, m, mirrorTimeout, errors).then((r) {
        if (r != null && !done.isCompleted) done.complete(r);
        left--;
        if (left == 0 && !done.isCompleted) done.completeError(StateError('no source answered: ${errors.join('; ')}'));
      });
    }
    return await done.future;
  } finally {
    if (client == null) c.close();
  }
}
