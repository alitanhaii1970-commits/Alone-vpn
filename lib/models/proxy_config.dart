import 'dart:convert';

enum ProxyProtocol { vmess, vless, shadowsocks, trojan, unknown }

/// A single parsed proxy server configuration.
/// This is the shared model the whole app (UI, ping test, sing-box bridge) uses.
class ProxyConfig {
  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String address;
  final int port;
  final Map<String, dynamic> raw; // full decoded fields for the sing-box outbound builder
  final String originalLink; // the exact share-link string (vless://... etc)
                              // this is what the real VPN engine needs — it
                              // parses its own config from the link itself,
                              // it doesn't take our already-decoded `raw` map

  ProxyConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    required this.raw,
    required this.originalLink,
  });

  /// Parses any of the common share-link formats:
  /// vmess://<base64 json>
  /// vless://uuid@host:port?params#name
  /// ss://base64(method:password)@host:port#name  (or base64 of the whole thing)
  /// trojan://password@host:port?params#name
  static ProxyConfig? parse(String link) {
    link = link.trim();
    try {
      if (link.startsWith('vmess://')) {
        final b64 = link.substring('vmess://'.length);
        final jsonStr = utf8.decode(_decodeBase64(b64));
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final address = (data['add'] ?? '').toString().trim();
        final port = int.tryParse((data['port'] ?? '').toString());
        if (!_validEndpoint(address, port)) return null;
        return ProxyConfig(
          id: _genId(),
          name: (data['ps'] ?? 'VMess Server').toString(),
          protocol: ProxyProtocol.vmess,
          address: address,
          port: port!,
          raw: data,
          originalLink: link,
        );
      }

      if (link.startsWith('vless://')) {
        final uri = Uri.parse(link);
        if (!_validEndpoint(uri.host, uri.hasPort ? uri.port : null) || uri.userInfo.isEmpty) {
          return null;
        }
        return ProxyConfig(
          id: _genId(),
          name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'VLESS Server',
          protocol: ProxyProtocol.vless,
          address: uri.host,
          port: uri.port,
          raw: {'uuid': uri.userInfo, 'params': uri.queryParameters},
          originalLink: link,
        );
      }

      if (link.startsWith('trojan://')) {
        final uri = Uri.parse(link);
        if (!_validEndpoint(uri.host, uri.hasPort ? uri.port : null) || uri.userInfo.isEmpty) {
          return null;
        }
        return ProxyConfig(
          id: _genId(),
          name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'Trojan Server',
          protocol: ProxyProtocol.trojan,
          address: uri.host,
          port: uri.port,
          raw: {'password': uri.userInfo, 'params': uri.queryParameters},
          originalLink: link,
        );
      }

      if (link.startsWith('ss://')) {
        var body = link.substring('ss://'.length);
        var name = 'Shadowsocks Server';
        final fragmentIndex = body.indexOf('#');
        if (fragmentIndex >= 0) {
          name = Uri.decodeComponent(body.substring(fragmentIndex + 1));
          body = body.substring(0, fragmentIndex);
        }

        late final String userInfo;
        late final String hostPort;
        final atIdx = body.indexOf('@');
        if (atIdx >= 0) {
          userInfo = utf8.decode(_decodeBase64(body.substring(0, atIdx)));
          hostPort = body.substring(atIdx + 1);
        } else {
          // Legacy SIP002 links may encode the entire method:password@host:port.
          final decoded = utf8.decode(_decodeBase64(body));
          final decodedAt = decoded.lastIndexOf('@');
          if (decodedAt <= 0 || decodedAt == decoded.length - 1) return null;
          userInfo = decoded.substring(0, decodedAt);
          hostPort = decoded.substring(decodedAt + 1);
        }

        final methodSeparator = userInfo.indexOf(':');
        if (methodSeparator <= 0 || methodSeparator == userInfo.length - 1) return null;
        final method = userInfo.substring(0, methodSeparator);
        final password = userInfo.substring(methodSeparator + 1);
        final serverUri = Uri.parse('ss://$hostPort');
        if (!_validEndpoint(serverUri.host, serverUri.hasPort ? serverUri.port : null)) return null;
        return ProxyConfig(
          id: _genId(),
          name: name,
          protocol: ProxyProtocol.shadowsocks,
          address: serverUri.host,
          port: serverUri.port,
          raw: {'method': method, 'password': password},
          originalLink: link,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static bool _validEndpoint(String host, int? port) =>
      host.trim().isNotEmpty && port != null && port >= 1 && port <= 65535;

  static List<int> _decodeBase64(String value) {
    // Subscription providers commonly emit URL-safe base64 without padding.
    // Normalize both alphabets before decoding so vmess:// and ss:// links
    // copied from mobile apps are accepted consistently.
    final compact = value.trim().replaceAll(RegExp(r'\s+'), '');
    final standard = compact.replaceAll('-', '+').replaceAll('_', '/');
    final mod = standard.length % 4;
    final padded = mod == 0 ? standard : '$standard${'=' * (4 - mod)}';
    return base64.decode(padded);
  }

  static String _genId() => DateTime.now().microsecondsSinceEpoch.toString();
}
