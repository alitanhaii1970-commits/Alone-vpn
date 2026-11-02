/// Services that only echo the caller's public IP. Several, tried at the same time, because some of them
/// are blocked in some countries.
const List<String> kIpProbes = <String>[
  'https://api.ipify.org',
  'https://icanhazip.com',
  'https://checkip.amazonaws.com',
  'https://www.cloudflare.com/cdn-cgi/trace',
  'https://ifconfig.me/ip',
];

/// A bare address, or a Cloudflare-style `ip=...` line. Null when [body] holds neither.
String? parseIpResponse(String body) {
  final t = body.trim();
  if (InternetAddress.tryParse(t) != null) return t;
  for (final line in const LineSplitter().convert(body)) {
    if (line.startsWith('ip=')) {
      final v = line.substring(3).trim();
      if (InternetAddress.tryParse(v) != null) return v;
    }
  }
  return null;
}

/// The first valid answer of any probe, or null when none answered.
Future<String?> fetchPublicIp({http.Client? client, List<String> urls = kIpProbes, Duration timeout = const Duration(seconds: 6)}) async {
  final c = client ?? http.Client();
  try {
    final done = Completer<String?>();
    var left = urls.length;
    for (final u in urls) {
      () async {
        String? ip;
        try {
          final r = await c.get(Uri.parse(u)).timeout(timeout);
          if (r.statusCode == 200) ip = parseIpResponse(r.body);
        } catch (_) {}
        if (ip != null && !done.isCompleted) done.complete(ip);
        left--;
        if (left == 0 && !done.isCompleted) done.complete(null);
      }();
    }
    if (urls.isEmpty) return null;
    return await done.future;
  } finally {
    if (client == null) c.close();
  }
}

/// Asks a dual-stack echo service for the address it sees. An IPv6 answer while connected means
/// IPv6 traffic is leaving outside the tunnel. Null = could not tell.
Future<String?> fetchIpv6Probe({http.Client? client, Duration timeout = const Duration(seconds: 8)}) =>
    fetchPublicIp(client: client, urls: const <String>['https://api64.ipify.org'], timeout: timeout);
