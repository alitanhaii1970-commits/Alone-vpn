import 'package:flutter/material.dart';
import '../../core/connection/connection_manager.dart';
import '../../core/connection/link_state.dart';
import '../../core/connection/vpn_engine.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../kit/base.dart';

/// Two independent engine cards: Smart Connection (not installed in this build) and Manual
/// Connection (Xray). Every status shown is read from the engine through [ConnectionManager].
class ConnectionCards extends StatelessWidget {
  const ConnectionCards({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _EngineCard(EngineKind.smart),
        SizedBox(height: 10),
        _EngineCard(EngineKind.manual),
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
      return trOr('cm_s_noeng', 'موتور هوشمند نصب نیست', 'Smart Engine Not Installed');
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

class _EngineCard extends StatelessWidget {
  const _EngineCard(this.kind);
  final EngineKind kind;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([ConnectionManager.I, ServerStore.I]),
      builder: (context, _) {
        final m = ConnectionManager.I;
        final engine = m.engine(kind);
        final st = engine.status.state;
        final smart = kind == EngineKind.smart;
        final c = _tone(p, st);
        final err = m.errorOf(kind);
        final title = smart
            ? trOr('cm_smart', 'اتصال هوشمند', 'Smart Connection')
            : trOr('cm_manual', 'اتصال دستی', 'Manual Connection');
        final tagline = smart
            ? trOr('cm_smart_sub', 'اتصال هوشمند جهانی با Lantern', 'Global smart connection with Lantern')
            : trOr('cm_manual_sub', 'اتصال با سرورهای شخصی', 'Connect with your own servers');
        String note;
        if (smart) {
          note = trOr(
            'cm_smart_note',
            'مجوزها و تأیید یکپارچه‌سازی هنوز در انتظار است. این موتور در این نسخه نصب نیست و هیچ اتصالی ساخته نمی‌شود.',
            'Licensing and integration approval are still pending. This engine is not installed in this build, so no connection can be made.',
          );
        } else {
          note = ServerStore.I.active?.title ?? trOr('cm_no_server', 'هنوز سروری انتخاب نشده', 'No server selected');
          if (err != null) note = '$note\n${trOr('cm_failed_at', 'ناموفق در مرحله', 'Failed at')}: $err';
        }

        Widget action;
        if (smart) {
          action = _Action(label: trOr('cm_unavailable', 'اتصال در دسترس نیست', 'Connection unavailable'), onTap: null);
        } else {
          final blocked = m.busy && m.pending != kind;
          switch (st) {
            case LinkState.connected:
              action = _Action(
                label: trOr('cm_disconnect', 'قطع اتصال', 'Disconnect'),
                danger: true,
                onTap: blocked ? null : () => m.toggle(kind),
              );
              break;
            case LinkState.preparing:
            case LinkState.connecting:
              action = _Action(label: trOr('cm_cancel', 'لغو', 'Cancel'), onTap: () => m.toggle(kind));
              break;
            case LinkState.disconnecting:
              action = _Action(label: trOr('cm_disconnecting', 'در حال قطع…', 'Disconnecting…'), onTap: null);
              break;
            case LinkState.disconnected:
            case LinkState.error:
            case LinkState.engineNotInstalled:
              action = _Action(
                label: trOr('cm_connect', 'اتصال', 'Connect'),
                onTap: blocked ? null : () => m.toggle(kind),
              );
              break;
          }
        }

        return SizedBox(
          width: double.infinity,
          child: Glass(
            radius: Tk.rL,
            edge: alpha(c, .5),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ChipIc(smart ? Ic.globe : Ic.server, round: true),
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
                    Text(engine.label, maxLines: 1, style: context.ty(R.labelM, p.outline, true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_stateLabel(st), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, c)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(note, style: context.ty(R.labelM, p.onSurfaceVariant)),
                const SizedBox(height: 12),
                action,
              ],
            ),
          ),
        );
      },
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
