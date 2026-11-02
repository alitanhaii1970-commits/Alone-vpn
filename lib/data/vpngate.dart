import 'dart:convert';
import 'dart:io';
import 'ovpn.dart';

/// One public relay from the VPN Gate API (https://www.vpngate.net/api/iphone/).
/// VPN Gate is an academic project (University of Tsukuba); the relays are run by volunteers.
class VpnGateServer {
  const VpnGateServer({
    required this.hostName,
    required this.ip,
    required this.score,
    required this.pingMs,
    required this.speedBps,
    required this.countryLong,
    required this.countryShort,
    required this.sessions,
    required this.uptimeMs,
    required this.logType,
    required this.config,
  });

  final String hostName;
  final String ip;
  final int score;
  final int? pingMs; // as reported by VPN Gate, not measured by this app
  final int speedBps; // as reported by VPN Gate, not measured by this app
  final String countryLong;
  final String countryShort;
  final int sessions;
  final int uptimeMs;
  final String logType; // the operator's own log policy, e.g. "2 weeks"
  final String config; // the .ovpn text, validated

  double get speedMbps => speedBps / 1000000;

  Map<String, Object?> toJson() => <String, Object?>{
        'h': hostName,
        'ip': ip,
        's': score,
        'p': pingMs,
        'sp': speedBps,
        'cl': countryLong,
        'cs': countryShort,
        'n': sessions,
        'u': uptimeMs,
        'lt': logType,
        'cfg': config,
      };

  static VpnGateServer? fromJson(Object? o) {
    if (o is! Map) return null;
    final cfg = o['cfg'];
    final ip = o['ip'];
    if (cfg is! String || ip is! String || ovpnProblem(cfg) != null) return null;
    return VpnGateServer(
      hostName: '${o['h'] ?? ''}',
      ip: ip,
      score: (o['s'] as num?)?.toInt() ?? 0,
      pingMs: (o['p'] as num?)?.toInt(),
      speedBps: (o['sp'] as num?)?.toInt() ?? 0,
      countryLong: '${o['cl'] ?? ''}',
      countryShort: '${o['cs'] ?? ''}',
      sessions: (o['n'] as num?)?.toInt() ?? 0,
      uptimeMs: (o['u'] as num?)?.toInt() ?? 0,
      logType: '${o['lt'] ?? ''}',
      config: cfg,
    );
  }
}

class VpnGateParse {
  const VpnGateParse(this.servers, this.rows, this.rejected);
  final List<VpnGateServer> servers;
  final int rows;

  /// Why rows were dropped (reason -> count). Nothing is guessed or repaired.
  final Map<String, int> rejected;
}

/// Splits one CSV line, honouring double quotes.
List<String> splitCsvLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

/// Directives that run programs or open management channels. Public, volunteer-supplied profiles
/// must never carry them, so such a profile is rejected outright.
const Set<String> _forbidden = <String>{
  'up', 'down', 'route-up', 'route-pre-down', 'ipchange', 'learn-address', 'tls-verify',
  'auth-user-pass-verify', 'client-connect', 'client-disconnect', 'plugin', 'script-security',
  'management', 'up-restart', 'down-pre', 'config',
};

/// Null when [cfg] is a profile the app can start as is; otherwise a short reason code.
String? ovpnProblem(String cfg) {
  if (cfg.length > 65536) return 'size';
  var client = false;
  var tun = false;
  String? host;
  int? port;
  var inBlock = false;
  for (final raw in cfg.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (l.isEmpty || l.startsWith('#') || l.startsWith(';')) continue;
    if (l.startsWith('</')) {
      inBlock = false;
      continue;
    }
    if (l.startsWith('<')) {
      inBlock = true;
      continue;
    }
    if (inBlock) continue;
    final parts = l.split(RegExp(r'\s+'));
    final d = parts.first.toLowerCase();
    if (_forbidden.contains(d)) return 'script:$d';
    if (d == 'auth-user-pass') return 'auth_user_pass';
    if (d == 'client' || d == 'pull') client = true;
    if (d == 'dev' && parts.length > 1 && parts[1].toLowerCase().startsWith('tun')) tun = true;
    if (d == 'remote' && host == null && parts.length > 1) {
      host = parts[1];
      port = parts.length > 2 ? int.tryParse(parts[2]) : 1194;
    }
  }
  if (host == null) return 'no_remote';
  if (!RegExp(r'^[A-Za-z0-9.\-:]+$').hasMatch(host)) return 'bad_host';
  if (port == null || port < 1 || port > 65535) return 'bad_port';
  if (!client) return 'no_client';
  if (!tun) return 'no_tun';
  if (!RegExp(r'<ca>[\s\S]*BEGIN CERTIFICATE[\s\S]*</ca>').hasMatch(cfg)) return 'no_ca';
  if (externalFilesIn(cfg).isNotEmpty) return 'external_file';
  return null;
}

/// Parses the VPN Gate CSV: `*vpn_servers`, a `#HostName,IP,...` header, one row per relay, `*`.
VpnGateParse parseVpnGateCsv(String body) {
  var header = <String>[];
  final out = <VpnGateServer>[];
  final rejected = <String, int>{};
  var rows = 0;
  void reject(String why) => rejected[why] = (rejected[why] ?? 0) + 1;

  for (final raw in const LineSplitter().convert(body)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('*')) continue;
    if (line.startsWith('#')) {
      header = splitCsvLine(line.substring(1)).map((e) => e.trim()).toList();
      continue;
    }
    if (header.isEmpty) continue;
    rows++;
    final f = splitCsvLine(line);
    if (f.length < header.length) {
      reject('short_row');
      continue;
    }
    String col(String name) {
      final i = header.indexOf(name);
      return i < 0 || i >= f.length ? '' : f[i].trim();
    }

    final ip = col('IP');
    if (InternetAddress.tryParse(ip) == null) {
      reject('bad_ip');
      continue;
    }
    final b64 = col('OpenVPN_ConfigData_Base64');
    if (b64.isEmpty) {
      reject('no_config');
      continue;
    }
    String cfg;
    try {
      cfg = utf8.decode(base64.decode(base64.normalize(b64)));
    } catch (_) {
      reject('bad_base64');
      continue;
    }
    final problem = ovpnProblem(cfg);
    if (problem != null) {
      reject(problem.split(':').first);
      continue;
    }
    final short = col('CountryShort');
    if (short.length != 2) {
      reject('bad_country');
      continue;
    }
    final score = int.tryParse(col('Score')) ?? 0;
    if (score <= 0) {
      reject('no_score');
      continue;
    }
    out.add(VpnGateServer(
      hostName: col('HostName'),
      ip: ip,
      score: score,
      pingMs: int.tryParse(col('Ping')),
      speedBps: int.tryParse(col('Speed')) ?? 0,
      countryLong: col('CountryLong'),
      countryShort: short.toUpperCase(),
      sessions: int.tryParse(col('NumVpnSessions')) ?? 0,
      uptimeMs: int.tryParse(col('Uptime')) ?? 0,
      logType: col('LogType'),
      config: cfg,
    ));
  }
  return VpnGateParse(out, rows, rejected);
}

/// Quality order used everywhere: VPN Gate's own score, then ping, then speed.
int compareVpnGateQuality(VpnGateServer a, VpnGateServer b) {
  var d = b.score.compareTo(a.score);
  if (d != 0) return d;
  d = (a.pingMs ?? 1 << 30).compareTo(b.pingMs ?? 1 << 30);
  if (d != 0) return d;
  return b.speedBps.compareTo(a.speedBps);
}

/// A copy of the official list made by ALONE's own scheduled job (GitHub Actions), so people who cannot
/// reach vpngate.net (it is filtered in some countries) can still get it. It contains only profiles that
/// passed [ovpnProblem]; the app validates them again when it reads them.
class VpnGateSnapshot {
  const VpnGateSnapshot(this.generatedAt, this.servers);
  final DateTime generatedAt;
  final List<VpnGateServer> servers;
}

/// Best relays overall plus the best few of every country, so a country choice still works.
List<VpnGateServer> selectForSnapshot(List<VpnGateServer> all, {int top = 60, int perCountry = 5}) {
  final sorted = List<VpnGateServer>.of(all)..sort(compareVpnGateQuality);
  final picked = <String, VpnGateServer>{};
  for (final s in sorted.take(top)) {
    picked[s.ip] = s;
  }
  final seen = <String, int>{};
  for (final s in sorted) {
    final n = seen[s.countryShort] ?? 0;
    if (n < perCountry) picked[s.ip] = s;
    seen[s.countryShort] = n + 1;
  }
  return picked.values.toList()..sort(compareVpnGateQuality);
}

String snapshotToJson(List<VpnGateServer> servers, DateTime generatedAt) => jsonEncode(<String, Object?>{
      'v': 1,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'source': 'https://www.vpngate.net/api/iphone/',
      'servers': <Object?>[for (final s in servers) s.toJson()],
    });

/// Null when [body] is not a snapshot; profiles that fail validation are dropped.
VpnGateSnapshot? parseSnapshotJson(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map || j['v'] != 1) return null;
    final at = DateTime.tryParse('${j['generatedAt']}');
    final list = j['servers'];
    if (at == null || list is! List) return null;
    final out = <VpnGateServer>[];
    for (final o in list) {
      final s = VpnGateServer.fromJson(o);
      if (s != null) out.add(s);
    }
    return VpnGateSnapshot(at, out);
  } catch (_) {
    return null;
  }
}
