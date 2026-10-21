import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/data/foreign.dart';

void main() {
  test('OpenVPN profiles are recognised by name and by content', () {
    expect(classifyForeign('x', name: 'work.ovpn'), ForeignConfig.openvpn);
    expect(classifyForeign('client\ndev tun\nproto udp\nremote 1.2.3.4 1194\n<ca>\n-----BEGIN-----\n'), ForeignConfig.openvpn);
  });
  test('NPV Tunnel files are recognised by extension', () {
    expect(classifyForeign('???', name: 'config.npv4'), ForeignConfig.npv);
    expect(classifyForeign('???', name: 'CONFIG.NPVT'), ForeignConfig.npv);
  });
  test('ordinary share links are not foreign', () {
    expect(classifyForeign('vless://123e4567-e89b-12d3-a456-426614174000@example.com:443?security=tls#A'), isNull);
    expect(classifyForeign('Check this:\nss://YWVzLTI1Ni1nY206cGFzcw==@1.2.3.4:8388#X'), isNull);
  });
  test('a base64 subscription blob expands to its links, other text is left alone', () {
    const links = 'ss://YWVzLTI1Ni1nY206cGFzcw==@1.2.3.4:8388#One\nvless://123e4567-e89b-12d3-a456-426614174000@example.com:443#Two';
    final blob = base64.encode(utf8.encode(links));
    expect(expandBase64Links(blob), links);
    expect(expandBase64Links('vless://abc@x:1#T'), 'vless://abc@x:1#T');
    expect(expandBase64Links('hello world'), 'hello world');
    expect(expandBase64Links('notbase64!!!notbase64!!!'), 'notbase64!!!notbase64!!!');
  });
}
