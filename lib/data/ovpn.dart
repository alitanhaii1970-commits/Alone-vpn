import 'dart:convert';

/// OpenVPN profiles are stored like every other server: as one string. The whole .ovpn text is
/// base64url-encoded into an `ovpn://` link so it fits the existing list / persistence / UI.
const String kOvpnScheme = 'ovpn://';

String ovpnLink(String config, {String name = ''}) {
  final b = base64Url.encode(utf8.encode(config)).replaceAll('=', '');
  final n = name.trim().isEmpty ? hostPortOf(config).$1 : name.trim();
  return '$kOvpnScheme$b#${Uri.encodeComponent(n)}';
}

bool isOvpnLink(String link) => link.trimLeft().toLowerCase().startsWith(kOvpnScheme);

String ovpnConfigOf(String link) {
  final body = link.trim().substring(kOvpnScheme.length);
  final hash = body.indexOf('#');
  var b = hash >= 0 ? body.substring(0, hash) : body;
  while (b.length % 4 != 0) {
    b += '=';
  }
  return utf8.decode(base64Url.decode(b));
}

String ovpnNameOf(String link) {
  final i = link.indexOf('#');
  if (i < 0) return '';
  try {
    return Uri.decodeComponent(link.substring(i + 1));
  } catch (_) {
    return link.substring(i + 1);
  }
}

/// First `remote host [port]` line (what the profile connects to).
(String, int) hostPortOf(String config) {
  for (final raw in config.split(RegExp(r'\r?\n'))) {
    final m = RegExp(r'^\s*remote\s+(\S+)(?:\s+(\d+))?').firstMatch(raw);
    if (m != null) return (m.group(1)!, int.tryParse(m.group(2) ?? '') ?? 1194);
  }
  return ('openvpn', 1194);
}

/// Files the profile points to instead of embedding. OpenVPN for Android's API can only start a
/// profile that carries everything inline (<ca>, <cert>, <key> …).
List<String> externalFilesIn(String config) {
  final out = <String>[];
  var inBlock = false;
  for (final raw in config.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (l.startsWith('<') && !l.startsWith('</')) {
      inBlock = true;
      continue;
    }
    if (l.startsWith('</')) {
      inBlock = false;
      continue;
    }
    if (inBlock || l.startsWith('#') || l.startsWith(';')) continue;
    final m = RegExp(r'^(ca|cert|key|tls-auth|tls-crypt|tls-crypt-v2|pkcs12|dh|crl-verify|extra-certs)\s+(\S+)').firstMatch(l);
    if (m != null && m.group(2) != 'inline') out.add(m.group(2)!);
  }
  return out;
}

/// Does the profile ask for a username / password the user has not embedded?
bool needsCredentials(String config) {
  var asks = false;
  var inline = false;
  var inBlock = false;
  for (final raw in config.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (l.startsWith('<auth-user-pass>')) inline = true;
    if (l.startsWith('<') && !l.startsWith('</')) inBlock = true;
    if (l.startsWith('</')) inBlock = false;
    if (!inBlock && RegExp(r'^auth-user-pass(\s+\S+)?$').hasMatch(l)) asks = true;
  }
  return asks && !inline;
}
