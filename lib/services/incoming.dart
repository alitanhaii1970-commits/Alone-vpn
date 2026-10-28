import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/i18n.dart';
import '../data/foreign.dart';
import '../data/stores.dart';

/// Links, shared text and text files that arrive from other apps (Android intents):
/// opening a vless:// / vmess:// / ss:// / trojan:// … link, "Share" → ALONE VPN, "Open with" on a
/// file full of links. The native side (MainActivity, patched in by scripts/patch_incoming_intents.py)
/// forwards them over this channel.
class IncomingService {
  IncomingService._();
  static const MethodChannel _ch = MethodChannel('alone/intent');
  static bool _started = false;

  static void start() {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'incoming' && call.arguments is Map) {
        await handle(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    // the intent that started the app (cold start)
    _ch.invokeMethod<Object?>('initial').then((v) {
      if (v is Map) handle(Map<Object?, Object?>.from(v));
    }).catchError((Object _) {});
  }

  @visibleForTesting
  static Future<void> handle(Map<Object?, Object?> m) async {
    final text = (m['text'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    debugPrint('ALONE_INTENT received name="$name" chars=${text.length}');
    if (text.trim().isEmpty) return;
    final foreign = classifyForeign(text, name: name);
    if (foreign == ForeignConfig.openvpn) {
      // a shared text has no file name: let the profile be named after its server instead
      final label = name == 'shared text' ? '' : name.replaceAll(RegExp(r'\.ovpn$', caseSensitive: false), '');
      final problem = ServerStore.I.addOvpn(text, name: label);
      debugPrint('ALONE_INTENT ovpn=${problem ?? 'added'}');
      snack(problem == null ? tr('ovpn_added') : tr(problem), tone: problem == null ? 'ok' : 'err');
      return;
    }
    if (foreign != null) {
      debugPrint('ALONE_INTENT foreign=${foreign.name}');
      snack(tr('foreign_npv'), tone: 'warn');
      return;
    }
    final r = await ServerStore.I.addText(expandBase64Links(text));
    debugPrint('ALONE_INTENT imported=${r.added} dup=${r.dup} bad=${r.bad}');
    if (r.added > 0) {
      snack(tr('imported', {'n': '${r.added}'}), tone: 'ok');
    } else {
      snack(r.dup > 0 ? tr('dup_only') : tr('bad_link'), tone: 'err');
    }
  }
}
