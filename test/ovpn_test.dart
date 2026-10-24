import 'package:flutter_test/flutter_test.dart';
import 'package:alone_vpn/core/settings.dart';
import 'package:alone_vpn/core/storage.dart';
import 'package:alone_vpn/data/ovpn.dart';
import 'package:alone_vpn/data/stores.dart';

const _good = '''client
dev tun
proto udp
remote vpn.example.org 1194
<ca>
-----BEGIN CERTIFICATE-----
MIIB
-----END CERTIFICATE-----
</ca>
''';

void main() {
  test('an .ovpn text survives the ovpn:// link round trip', () {
    final link = ovpnLink(_good, name: 'Work VPN');
    expect(isOvpnLink(link), isTrue);
    expect(ovpnConfigOf(link), _good);
    expect(ovpnNameOf(link), 'Work VPN');
    expect(hostPortOf(_good), ('vpn.example.org', 1194));
  });

  test('profiles that point to external files are detected, inline ones are not', () {
    expect(externalFilesIn(_good), isEmpty);
    expect(externalFilesIn('client\nremote a.b 443\nca ca.crt\ncert client.crt\nkey client.key\n'), ['ca.crt', 'client.crt', 'client.key']);
    expect(externalFilesIn('remote a.b 443\n# ca old.crt\n'), isEmpty);
  });

  test('credentials are noticed unless embedded', () {
    expect(needsCredentials('client\nauth-user-pass\nremote a.b 1\n'), isTrue);
    expect(needsCredentials('client\nremote a.b 1\n'), isFalse);
    expect(needsCredentials('client\nremote a.b 1\n<auth-user-pass>\nu\np\n</auth-user-pass>\n'), isFalse);
  });

  test('ServerStore imports an OpenVPN profile as a server and rejects bad ones', () async {
    AppSettings.storage = MemoryStorage({'al.onboarded': true});
    AppSettings.I.onboarded = false;
    await AppSettings.I.load();
    ServerStore.I.load();
    expect(ServerStore.I.addOvpn(_good, name: 'Work'), isNull);
    final s = ServerStore.I.items.firstWhere((e) => e.isOvpn);
    expect(s.title, 'Work');
    expect(s.host, 'vpn.example.org');
    expect(ServerStore.I.addOvpn(_good, name: 'Work'), 'ovpn_dup');
    expect(ServerStore.I.addOvpn('client\ndev tun\n'), 'ovpn_invalid');
    expect(ServerStore.I.addOvpn('client\nremote a.b 1\nca ca.crt\n'), 'ovpn_external');
    // OpenVPN profiles are never called "dead" by a TCP test
    expect(ServerStore.I.testable.any((e) => e.isOvpn), isFalse);
  });
}
