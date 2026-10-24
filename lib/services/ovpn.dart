import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OpenVPN through the separately installed "OpenVPN for Android" app (package de.blinkt.openvpn),
/// using its official remote API. ALONE VPN carries no OpenVPN engine of its own: Xray and sing-box
/// do not speak OpenVPN, so this is a hand-off the user sees as one tap on "Connect".
class OvpnEngine {
  OvpnEngine._();
  static const MethodChannel _ch = MethodChannel('alone/ovpn');
  static void Function(String state, String message)? _onStatus;

  static bool get supported => Platform.isAndroid;

  static void listen(void Function(String state, String message) onStatus) {
    _onStatus = onStatus;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'status' && call.arguments is Map) {
        final m = Map<Object?, Object?>.from(call.arguments as Map);
        final s = (m['state'] ?? '').toString();
        final msg = (m['message'] ?? '').toString();
        debugPrint('ALONE_OVPN status=$s message=$msg');
        _onStatus?.call(s, msg);
      }
      return null;
    });
  }

  static Future<bool> installed() async {
    if (!supported) return false;
    try {
      return (await _ch.invokeMethod<bool>('installed')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openInstallPage() async {
    try {
      await _ch.invokeMethod<void>('install');
    } catch (_) {}
  }

  /// Asks OpenVPN for Android to start [config] (all certificates inline). Permission dialogs
  /// (API access, VPN consent) are shown by Android / OpenVPN for Android as needed.
  static Future<void> start(String config) async {
    debugPrint('ALONE_OVPN start requested (${config.length} chars)');
    await _ch.invokeMethod<void>('start', {'config': config});
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
