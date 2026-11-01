import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// The official VPN Gate API for apps (CSV of public relays, each with an inline OpenVPN profile).
const String kVpnGateApi = 'https://www.vpngate.net/api/iphone/';

Future<String> fetchVpnGateCsv({http.Client? client, Duration timeout = const Duration(seconds: 30)}) async {
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse(kVpnGateApi), headers: const {'User-Agent': 'ALONE-VPN'}).timeout(timeout);
    if (r.statusCode != 200) throw HttpException('VPN Gate API answered HTTP ${r.statusCode}');
    if (r.bodyBytes.length > 20 * 1024 * 1024) throw const HttpException('VPN Gate API answer is too large');
    return utf8.decode(r.bodyBytes, allowMalformed: true);
  } finally {
    if (client == null) c.close();
  }
}

/// Services that only echo the caller's public IP. Used to prove that the tunnel really changed it.
const List<String> kIpProbes = <String>['https://api.ipify.org', 'https://icanhazip.com'];

Future<String?> fetchPublicIp({http.Client? client, List<String> urls = kIpProbes, Duration timeout = const Duration(seconds: 8)}) async {
  final c = client ?? http.Client();
  try {
    for (final u in urls) {
      try {
        final r = await c.get(Uri.parse(u)).timeout(timeout);
        final t = r.body.trim();
        if (r.statusCode == 200 && InternetAddress.tryParse(t) != null) return t;
      } catch (_) {
        // try the next probe
      }
    }
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Asks a dual-stack echo service for the address it sees. An IPv6 answer while connected means
/// IPv6 traffic is leaving outside the tunnel. Null = could not tell.
Future<String?> fetchIpv6Probe({http.Client? client, Duration timeout = const Duration(seconds: 8)}) =>
    fetchPublicIp(client: client, urls: const <String>['https://api64.ipify.org'], timeout: timeout);
