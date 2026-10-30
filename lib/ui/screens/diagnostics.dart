import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../../services/engine.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';

enum _Res { wait, busy, ok, bad, na }

class _Check {
  final String id;
  final String key;
  // true = ok, false = problem, null = cannot be judged right now
  final Future<bool?> Function() run;
  const _Check(this.id, this.key, this.run);
}

Future<bool?> _notif() async {
  try {
    return (await Permission.notification.status).isGranted;
  } catch (_) {
    return null;
  }
}

Future<bool?> _vpn() async => Engine.real ? await Engine.I.hasPermission() : null;

Future<bool?> _core() async {
  if (!Engine.real) return null;
  try {
    await Engine.I.ensure().timeout(const Duration(seconds: 8));
    return true;
  } catch (_) {
    return false;
  }
}

// Only meaningful while connected; otherwise there is nothing real to measure.
Future<bool?> _tun() async => Conn.I.state == CS.on ? true : null;

Future<bool?> _dns() async {
  try {
    final r = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 5));
    return r.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool?> _batt() async {
  if (!Platform.isAndroid) return null;
  try {
    return (await Permission.ignoreBatteryOptimizations.status).isGranted;
  } catch (_) {
    return null;
  }
}

final List<_Check> _checks = [
  _Check('notif', 'd_notif', _notif),
  _Check('vpn', 'd_vpn', _vpn),
  _Check('core', 'd_core', _core),
  _Check('tun', 'd_tun', _tun),
  _Check('dns', 'd_dns', _dns),
  _Check('batt', 'd_batt', _batt),
];

/// Diagnostics: every line is a real probe (permissions, engine, resolver,
/// battery policy). A check that cannot be judged says so instead of guessing.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final Map<String, _Res> _res = {};
  bool _running = false;

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      for (final c in _checks) {
        _res[c.id] = _Res.busy;
      }
    });
    var bad = 0;
    for (final c in _checks) {
      bool? ok;
      try {
        ok = await c.run();
      } catch (_) {
        ok = false;
      }
      if (!mounted) return;
      if (ok == false) bad++;
      setState(() => _res[c.id] = ok == null ? _Res.na : (ok ? _Res.ok : _Res.bad));
    }
    if (!mounted) return;
    setState(() => _running = false);
    snack(bad > 0 ? tr('diag_d') : trOr('diag_all_ok', 'همه‌ی بررسی‌ها سالمه', 'All checks passed'), tone: bad > 0 ? 'err' : 'ok');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('s_diag'), onBack: () => Navigator.of(context).maybePop()),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(tr('diag_d'), style: context.ty(R.bodyM, p.onSurfaceVariant)),
          ),
          Btn(_running ? tr('diag_busy') : tr('diag_run'), icon: Ic.refresh, variant: Bv.tonal, wide: true, onTap: _running ? null : _runAll),
          const SizedBox(height: 12),
          for (var i = 0; i < _checks.length; i++) _row(context, i, _checks[i]),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, _Check c) {
    final p = context.pal;
    final r = _res[c.id] ?? _Res.wait;
    final Ic icon = r == _Res.ok ? Ic.check : r == _Res.bad ? Ic.alert : r == _Res.busy ? Ic.refresh : Ic.info;
    final Tone tone = r == _Res.ok ? Tone.ok : r == _Res.bad ? Tone.bad : Tone.plain;
    String sub;
    switch (r) {
      case _Res.bad:
        sub = tr('${c.key}_bad');
        break;
      case _Res.busy:
        sub = tr('diag_busy');
        break;
      case _Res.ok:
        sub = trOr('diag_ok', 'سالمه', 'OK');
        break;
      case _Res.na:
        sub = c.id == 'tun'
            ? trOr('d_tun_idle', 'اتصال برقرار نیست؛ بعد از وصل شدن دوباره بررسی کن', 'Not connected; run again once connected')
            : trOr('diag_na', 'روی این دستگاه قابل بررسی نیست', 'Cannot be checked on this device');
        break;
      case _Res.wait:
        sub = tr('diag_wait');
        break;
    }
    return Rise(
      i: i,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: CardX(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ChipIc(icon, tone: tone, sm: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(c.key), style: context.ty(R.titleS, p.onSurface)),
                    const SizedBox(height: 2),
                    Text(sub, style: context.ty(R.labelM, r == _Res.bad ? p.error : p.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
