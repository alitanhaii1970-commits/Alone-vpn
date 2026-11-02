import 'dart:convert';

import 'package:alone_vpn/data/vpngate.dart';
import 'package:alone_vpn/services/vpngate_sources.dart';

/// Synthetic test data in the documented VPN Gate CSV layout. Addresses are from the reserved
/// documentation ranges (RFC 5737); nothing here is a real server.
String ovpnFixture({String host = '203.0.113.10', int port = 443, String extra = '', bool ca = true, bool client = true}) => [
      if (client) 'client',
      'dev tun',
      'proto tcp',
      'remote $host $port',
      'cipher AES-128-CBC',
      'auth SHA1',
      'nobind',
      if (extra.isNotEmpty) extra,
      if (ca) '<ca>\n-----BEGIN CERTIFICATE-----\nVEVTVC1GSVhUVVJF\n-----END CERTIFICATE-----\n</ca>',
    ].join('\n');

const String csvHeader =
    '#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,OpenVPN_ConfigData_Base64';

String csvRow({
  String host = 'test-relay',
  String ip = '203.0.113.10',
  int score = 1000,
  int ping = 20,
  int speed = 50000000,
  String country = 'Japan',
  String short = 'JP',
  String log = '2 weeks',
  String? config,
}) =>
    '$host,$ip,$score,$ping,$speed,$country,$short,5,86400000,100,1000000,$log,"Volunteer, test",,${base64.encode(utf8.encode(config ?? ovpnFixture(host: ip)))}';

String csvOf(List<String> rows) => '*vpn_servers\n$csvHeader\n${rows.join('\n')}\n*\n';

/// A list fetcher that "downloads" [csv] (re-read on every call) and parses it with the app's parser.
Future<FetchedList> Function() csvFetcher(String Function() csv, {String source = 'test'}) => () async {
      final p = parseVpnGateCsv(csv());
      return FetchedList(p.servers, source, null, p.rejected);
    };
