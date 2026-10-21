import 'dart:convert';

/// Config formats of other VPN apps that this app's engines (Xray / sing-box) cannot run.
enum ForeignConfig { openvpn, npv }

/// Recognises an OpenVPN profile or an NPV Tunnel file, by file name or by content.
ForeignConfig? classifyForeign(String text, {String name = ''}) {
  final n = name.toLowerCase();
  if (n.endsWith('.ovpn')) return ForeignConfig.openvpn;
  if (RegExp(r'\.npv[a-z0-9]*$').hasMatch(n)) return ForeignConfig.npv;
  final head = text.length > 6000 ? text.substring(0, 6000) : text;
  var remote = false, client = false, block = false;
  for (final raw in head.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (RegExp(r'^remote\s+\S+').hasMatch(l)) remote = true;
    if (l == 'client' || l.startsWith('dev tun') || l.startsWith('proto udp') || l.startsWith('proto tcp')) client = true;
    if (l.startsWith('<ca>') || l.startsWith('<cert>') || l.startsWith('<key>') || l.startsWith('<tls-auth>') || l.startsWith('<tls-crypt>')) block = true;
  }
  if (remote && (client || block)) return ForeignConfig.openvpn;
  return null;
}

/// Many subscription files are one base64 blob that decodes to a list of share links.
/// Returns the decoded text when [text] is such a blob, otherwise [text] unchanged.
String expandBase64Links(String text) {
  final t = text.trim();
  if (t.length < 16 || RegExp(r'\s').hasMatch(t) || t.contains('://')) return text;
  try {
    var s = t.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    final decoded = utf8.decode(base64.decode(s));
    return decoded.contains('://') ? decoded : text;
  } catch (_) {
    return text;
  }
}
