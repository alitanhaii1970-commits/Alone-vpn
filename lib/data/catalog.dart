import '../core/icons.dart';

/// Static catalogues taken from the design (DNS presets, routing rules, help
/// topics, diagnostics, handshake steps, typefaces).
class DnsDef {
  final String id;
  final String name;
  final String ip;
  final String noteKey;
  const DnsDef(this.id, this.name, this.ip, this.noteKey);

  /// What the engine is given as the remote resolver.
  String get engineAddress => id == 'el' ? ip : 'https://$ip/dns-query';
}

const List<DnsDef> kDns = [
  DnsDef('cf', 'Cloudflare', '1.1.1.1', 'dns_fastest'),
  DnsDef('gg', 'Google', '8.8.8.8', 'dns_stable'),
  DnsDef('q9', 'Quad9', '9.9.9.9', 'dns_private'),
  DnsDef('el', 'Electro', '78.157.42.100', 'dns_gaming'),
];

class RuleDef {
  final String id;
  final String key;
  final String act; // direct | block | proxy
  final bool on;
  const RuleDef(this.id, this.key, this.act, this.on);
}

const List<RuleDef> kRules = [
  RuleDef('ir', 'r_ir', 'direct', true),
  RuleDef('lan', 'r_lan', 'direct', true),
  RuleDef('ads', 'r_ads', 'block', true),
  RuleDef('apps', 'r_apps', 'proxy', true),
  RuleDef('udp', 'r_udp', 'proxy', false),
  RuleDef('quic', 'r_quic', 'block', false),
];

class HelpDef {
  final Ic icon;
  final String tone; // '' | ok | warn | plain
  final String k;
  const HelpDef(this.icon, this.tone, this.k);
}

const List<HelpDef> kHelp = [
  HelpDef(Ic.power, '', 'h_dial'),
  HelpDef(Ic.globe, '', 'h_server'),
  HelpDef(Ic.pulse, 'ok', 'h_latency'),
  HelpDef(Ic.pad, 'warn', 'h_dns'),
  HelpDef(Ic.apps, '', 'h_split'),
  HelpDef(Ic.layers, 'plain', 'h_routing'),
  HelpDef(Ic.terminal, 'plain', 'h_log'),
  HelpDef(Ic.batt, 'plain', 'h_saver'),
];

const List<String> kDiagIds = ['notif', 'vpn', 'core', 'tun', 'dns', 'clock', 'batt'];
const List<String> kHsSteps = ['hs_resolve', 'hs_tcp', 'hs_tls', 'hs_tunnel'];

class FontDef {
  final String id;
  final String label;
  const FontDef(this.id, this.label);
}

const List<FontDef> kFonts = [
  FontDef('vazir', 'Vazirmatn'),
  FontDef('naskh', 'Noto Naskh Arabic'),
  FontDef('geist', 'Geist'),
  FontDef('system', 'System UI'),
];

class CustomDns {
  final String id;
  final String ip;
  const CustomDns(this.id, this.ip);
}
