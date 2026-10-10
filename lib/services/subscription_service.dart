import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/proxy_config.dart';

/// Fetches a "subscription link" — a URL that returns either:
/// - a base64 blob decoding to one config-link per line, or
/// - plain text with one config-link per line
/// This is the standard format used by V2Ray/Xray/sing-box subscription
/// providers (the same format apps like v2rayNG / Hiddify support).
class SubscriptionService {
  static Future<List<ProxyConfig>> fetch(String url) async {
    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    String body = resp.body.trim();

    // try base64 decode first; if it fails, assume plain text
    String decoded;
    try {
      final compact = body.replaceAll(RegExp(r'\s+'), '');
      final standard = compact.replaceAll('-', '+').replaceAll('_', '/');
      decoded = utf8.decode(base64.decode(_pad(standard)));
    } catch (_) {
      decoded = body;
    }

    final lines = decoded.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty);
    final configs = <ProxyConfig>[];
    for (final line in lines) {
      final cfg = ProxyConfig.parse(line);
      if (cfg != null) configs.add(cfg);
    }
    return configs;
  }

  static String _pad(String b64) {
    final mod = b64.length % 4;
    if (mod == 0) return b64;
    return b64 + '=' * (4 - mod);
  }
}
