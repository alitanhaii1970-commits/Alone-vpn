import 'package:flutter/material.dart';
import '../../core/connection/connection_manager.dart';
import '../../core/connection/link_state.dart';
import '../../core/connection/vpn_engine.dart';
import '../../core/connection/vpngate_engine.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../../data/vpngate.dart';
import '../../services/ovpn.dart';
import '../../services/smart_servers.dart';
import '../kit/base.dart';
import 'home_hero.dart';

/// Two independent engine cards. Smart: VPN Gate public relays through OpenVPN. Manual: the user's
/// own servers (Xray). Every status shown is read from the engine through [ConnectionManager].
class ConnectionCards extends StatefulWidget {
  const ConnectionCards({super.key});

  @override
  State<ConnectionCards> createState() => _ConnectionCardsState();
}

class _ConnectionCardsState extends State<ConnectionCards> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConnectionManager.I.engine(EngineKind.smart).refresh();
    SmartServerManager.I.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // the user may have just installed the OpenVPN app
    if (state == AppLifecycleState.resumed) ConnectionManager.I.engine(EngineKind.smart).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SmartCard(),
        SizedBox(height: 10),
        _ManualCard(),
      ],
    );
  }
}

String _stateLabel(LinkState s) {
  switch (s) {
    case LinkState.disconnected:
      return trOr('cm_s_off', 'قطع', 'Disconnected');
    case LinkState.preparing:
      return trOr('cm_s_prep', 'در حال آماده‌سازی', 'Preparing');
    case LinkState.connecting:
      return trOr('cm_s_conn', 'در حال اتصال', 'Connecting');
    case LinkState.connected:
      return trOr('cm_s_on', 'متصل', 'Connected');
    case LinkState.disconnecting:
      return trOr('cm_s_down', 'در حال قطع', 'Disconnecting');
    case LinkState.error:
      return trOr('cm_s_err', 'خطا', 'Error');
    case LinkState.engineNotInstalled:
      return trOr('cm_s_noeng', 'موتور OpenVPN نصب نیست', 'OpenVPN Engine Not Installed');
  }
}

Color _tone(Pal p, LinkState s) {
  switch (s) {
    case LinkState.connected:
      return p.ok;
    case LinkState.error:
      return p.error;
    case LinkState.preparing:
    case LinkState.connecting:
    case LinkState.disconnecting:
      return p.warn;
    case LinkState.engineNotInstalled:
      return p.outline;
    case LinkState.disconnected:
      return p.onSurfaceVariant;
  }
}

String _dur(DateTime since) {
  final d = DateTime.now().difference(since);
  String two(int n) => n.toString().padLeft(2, '0');
  return loc('${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}');
}

class _Shell extends StatelessWidget {
  const _Shell({required this.tone, required this.child});
  final Color tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Glass(radius: Tk.rL, edge: alpha(tone, .5), padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.icon, required this.title, required this.tagline, required this.engine});
  final Ic icon;
  final String title;
  final String tagline;
  final String engine;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        ChipIc(icon, round: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleM, p.onSurface)),
              Text(tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.ty(R.labelM, p.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(engine, maxLines: 1, style: context.ty(R.labelM, p.outline, true)),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, color))),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v, {this.color});
  final String k;
  final String v;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: context.ty(R.labelM, p.onSurfaceVariant)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v, textAlign: TextAlign.end, style: context.ty(R.labelM, color ?? p.onSurface, true)),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = onTap != null;
    final bg = !enabled ? alpha(p.onSurface, .10) : (danger ? p.error : p.primary);
    final fg = !enabled ? p.onSurfaceVariant : (danger ? const Color(0xFFFFFFFF) : p.onPrimary);
    final box = Container(
      height: 44,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tk.rFull),
        border: enabled ? null : Border.all(color: alpha(p.outline, .4)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, fg)),
    );
    return enabled ? Press(radius: Tk.rFull, onTap: onTap, child: box) : box;
  }
}

String _privacyNote() => trOr(
      'vg_note',
      'این سرورها رو داوطلب‌ها اداره می‌کنن و ربطی به ALONE ندارن. ممکنه ثبت لاگ داشته باشن (سیاست لاگ هر سرور بعد از اتصال نشون داده می‌شه) و ترافیک تو رو ببینن؛ برای کارهای حساس استفاده نکن.',
      'These servers are run by volunteers and are not ALONE servers. They may keep logs (each server\'s log policy is shown once connected) and can see your traffic; do not use them for sensitive work.',
    );

Future<void> _connectSmart(BuildContext context) async {
  final sm = SmartServerManager.I;
  await sm.load();
  if (!context.mounted) return;
  if (!sm.consent) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trOr('vg_consent_t', 'قبل از اتصال', 'Before you connect')),
        content: Text(_privacyNote()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(trOr('cm_cancel', 'لغو', 'Cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(trOr('vg_consent_ok', 'متوجهم، ادامه', 'I understand, continue'))),
        ],
      ),
    );
    if (ok != true) return;
    await sm.setConsent();
  }
  await ConnectionManager.I.toggle(EngineKind.smart);
}

class _SmartCard extends StatelessWidget {
  const _SmartCard();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([ConnectionManager.I, SmartServerManager.I]),
      builder: (context, _) {
        final m = ConnectionManager.I;
        final engine = m.engine(EngineKind.smart);
        final eng = engine is VpnGateEngine ? engine : null;
        final status = engine.status;
        final st = status.state;
        final c = _tone(p, st);
        final err = m.errorOf(EngineKind.smart);
        final cur = eng?.current;
        final sm = SmartServerManager.I;
        final blocked = m.busy && m.pending != EngineKind.smart;

        Widget action;
        switch (st) {
          case LinkState.engineNotInstalled:
            action = _Action(label: trOr('vg_install', 'نصب OpenVPN for Android', 'Install OpenVPN for Android'), onTap: () => OvpnEngine.openInstallPage());
            break;
          case LinkState.connected:
            action = _Action(label: trOr('cm_disconnect', 'قطع اتصال', 'Disconnect'), danger: true, onTap: blocked ? null : () => m.toggle(EngineKind.smart));
            break;
          case LinkState.preparing:
          case LinkState.connecting:
            action = _Action(label: trOr('cm_cancel', 'لغو', 'Cancel'), onTap: () => m.toggle(EngineKind.smart));
            break;
          case LinkState.disconnecting:
            action = _Action(label: trOr('cm_disconnecting', 'در حال قطع…', 'Disconnecting…'), onTap: null);
            break;
          case LinkState.disconnected:
          case LinkState.error:
            action = _Action(label: trOr('cm_connect', 'اتصال', 'Connect'), onTap: blocked ? null : () => _connectSmart(context));
            break;
        }

        final details = <Widget>[];
        if (st == LinkState.connected && cur != null) {
          details
            ..add(_Kv(trOr('vg_k_country', 'کشور', 'Country'), '${flagEmoji(cur.countryShort)} ${cur.countryLong}'))
            ..add(_Kv(trOr('vg_k_ping', 'پینگ (اعلام‌شده)', 'Ping (reported)'), cur.pingMs == null ? '—' : '${loc(cur.pingMs!)} ms'))
            ..add(_Kv(trOr('vg_k_speed', 'سرعت (اعلام‌شده)', 'Speed (reported)'), '${loc(cur.speedMbps.toStringAsFixed(1))} Mbps'));
          if (status.since != null) details.add(_Kv(trOr('vg_k_time', 'زمان اتصال', 'Connected for'), _dur(status.since!)));
          if (eng?.exitIp != null) {
            details.add(_Kv(trOr('vg_k_ip', 'آی‌پی عمومی', 'Public IP'), '${eng?.ipBefore ?? '?'} → ${eng!.exitIp}'));
          }
          final v6 = eng?.ipv6Exposed;
          details.add(_Kv(
            'IPv6',
            v6 == null
                ? trOr('vg_v6_unk', 'نامشخص', 'unknown')
                : v6
                    ? trOr('vg_v6_leak', 'بیرون تونل دیده شد (نشت)', 'seen outside the tunnel (leak)')
                    : trOr('vg_v6_ok', 'نشتی دیده نشد', 'no leak seen'),
            color: v6 == true ? p.warn : null,
          ));
          details.add(_Kv(trOr('vg_k_log', 'سیاست لاگ سرور', 'Server log policy'), cur.logType.isEmpty ? '—' : cur.logType));
        } else if ((st == LinkState.connecting || st == LinkState.preparing) && cur != null) {
          details.add(_Kv(trOr('vg_k_trying', 'در حال امتحان', 'Trying'), '${flagEmoji(cur.countryShort)} ${cur.countryLong} · ${loc(eng!.attempt)}'));
        }

        final countries = sm.countries();
        final picked = sm.country;
        String pickedName = trOr('vg_auto', 'خودکار', 'Auto');
        for (final x in countries) {
          if (x.$1 == picked) pickedName = '${flagEmoji(x.$1)} ${x.$2}';
        }

        return _Shell(
          tone: c,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Head(
                icon: Ic.globe,
                title: 'VPN Gate Global Network',
                tagline: trOr('vg_sub', 'سرورهای عمومی رایگان داوطلب‌ها (نه سرور ALONE)', 'Free public relays run by volunteers (not ALONE servers)'),
                engine: engine.label,
              ),
              const SizedBox(height: 12),
              _StatusRow(_stateLabel(st), c),
              if (err != null) ...[
                const SizedBox(height: 4),
                Text(err, style: context.ty(R.labelM, p.error)),
              ],
              ...details,
              const SizedBox(height: 8),
              PopupMenuButton<String>(
                enabled: !st.occupiesTunnel && countries.isNotEmpty,
                onSelected: (v) => sm.setCountry(v.isEmpty ? null : v),
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: '', child: Text(trOr('vg_auto', 'خودکار', 'Auto'))),
                  for (final x in countries) PopupMenuItem<String>(value: x.$1, child: Text('${flagEmoji(x.$1)} ${x.$2} (${loc(x.$3)})')),
                ],
                child: Row(
                  children: [
                    Text(trOr('vg_k_pick', 'کشور سرور', 'Server country'), style: context.ty(R.labelM, p.onSurfaceVariant)),
                    const Spacer(),
                    Text(pickedName, style: context.ty(R.labelM, p.primary)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: p.primary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(_privacyNote(), style: context.ty(R.labelM, p.onSurfaceVariant)),
              const SizedBox(height: 12),
              action,
            ],
          ),
        );
      },
    );
  }
}

class _ManualCard extends StatelessWidget {
  const _ManualCard();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([ConnectionManager.I, ServerStore.I]),
      builder: (context, _) {
        final m = ConnectionManager.I;
        final engine = m.engine(EngineKind.manual);
        final st = engine.status.state;
        final c = _tone(p, st);
        final err = m.errorOf(EngineKind.manual);
        var note = ServerStore.I.active?.title ?? trOr('cm_no_server', 'هنوز سروری انتخاب نشده', 'No server selected');
        if (err != null) note = '$note\n${trOr('cm_failed_at', 'ناموفق در مرحله', 'Failed at')}: $err';
        final blocked = m.busy && m.pending != EngineKind.manual;

        Widget action;
        switch (st) {
          case LinkState.connected:
            action = _Action(label: trOr('cm_disconnect', 'قطع اتصال', 'Disconnect'), danger: true, onTap: blocked ? null : () => m.toggle(EngineKind.manual));
            break;
          case LinkState.preparing:
          case LinkState.connecting:
            action = _Action(label: trOr('cm_cancel', 'لغو', 'Cancel'), onTap: () => m.toggle(EngineKind.manual));
            break;
          case LinkState.disconnecting:
            action = _Action(label: trOr('cm_disconnecting', 'در حال قطع…', 'Disconnecting…'), onTap: null);
            break;
          case LinkState.disconnected:
          case LinkState.error:
          case LinkState.engineNotInstalled:
            action = _Action(label: trOr('cm_connect', 'اتصال', 'Connect'), onTap: blocked ? null : () => m.toggle(EngineKind.manual));
            break;
        }

        return _Shell(
          tone: c,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Head(
                icon: Ic.server,
                title: trOr('cm_manual', 'اتصال دستی', 'Manual Connection'),
                tagline: trOr('cm_manual_sub', 'اتصال با سرورهای شخصی', 'Connect with your own servers'),
                engine: engine.label,
              ),
              const SizedBox(height: 12),
              _StatusRow(_stateLabel(st), c),
              const SizedBox(height: 6),
              Text(note, style: context.ty(R.labelM, p.onSurfaceVariant)),
              const SizedBox(height: 12),
              action,
            ],
          ),
        );
      },
    );
  }
}
