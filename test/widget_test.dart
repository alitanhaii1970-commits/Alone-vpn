import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/models/proxy_config.dart';

void main() {
  group('ProxyConfig.parse', () {
    test('parses a VLESS link and decodes the profile name', () {
      final config = ProxyConfig.parse(
        'vless://123e4567-e89b-12d3-a456-426614174000@example.com:443'
        '?encryption=none&security=tls#Test%20Server',
      );

      expect(config, isNotNull);
      expect(config!.protocol, ProxyProtocol.vless);
      expect(config.address, 'example.com');
      expect(config.port, 443);
      expect(config.name, 'Test Server');
    });

    test('parses VMess URL-safe base64 without padding', () {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'add': 'edge.example', 'port': '8443', 'ps': 'Test VMess'})))
          .replaceAll('=', '');
      final config = ProxyConfig.parse('vmess://$payload');

      expect(config, isNotNull);
      expect(config!.protocol, ProxyProtocol.vmess);
      expect(config.address, 'edge.example');
      expect(config.port, 8443);
      expect(config.name, 'Test VMess');
    });

    test('parses a Shadowsocks link with encoded method/password', () {
      final config = ProxyConfig.parse(
        'ss://YWVzLTI1Ni1nY206cGFzcw==@example.com:8388#Test%20SS',
      );

      expect(config, isNotNull);
      expect(config!.protocol, ProxyProtocol.shadowsocks);
      expect(config.address, 'example.com');
      expect(config.port, 8388);
      expect(config.name, 'Test SS');
      expect(config.raw['method'], 'aes-256-gcm');
      expect(config.raw['password'], 'pass');
    });

    test('returns null for malformed or unsupported links', () {
      expect(ProxyConfig.parse('not-a-proxy-link'), isNull);
      expect(ProxyConfig.parse('vless://missing-host-and-port'), isNull);
    });
  });
}
