import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../nav.dart';
import 'log.dart';

/// Two-letter country code to a flag emoji ("" when the code is not two letters).
String flagEmoji(String cc) =>
    cc.length == 2 ? String.fromCharCodes(cc.toUpperCase().codeUnits.map((u) => 0x1F1E6 + u - 65)) : '';

/// Header: shield logo, two-tone wordmark and tagline.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final big = context.ty(R.headlineS, p.onSurface);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/brand/logo.svg', width: 38, height: 42),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'ALONE ', style: big),
              TextSpan(text: 'VPN', style: big.copyWith(color: p.primary)),
            ])),
            Text(tr('tagline'), style: context.ty(R.labelM, p.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

/// Capsule under the header. It only says "secure and stable" while the tunnel is really up.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final s = Conn.I.state;
        final on = s == CS.on;
        final bad = s == CS.failed;
        final busy = Conn.I.busy;
        final text = on
            ? trOr('banner_on', 'اتصال ایمن و پایدار', 'Secure and stable connection')
            : bad
                ? trOr('banner_bad', 'اتصال برقرار نشد', 'Connection failed')
                : busy
                    ? trOr('banner_busy', 'در حال اتصال…', 'Connecting…')
                    : trOr('banner_off', 'آماده برای اتصال', 'Ready to connect');
        final c = on ? p.ok : bad ? p.error : busy ? p.warn : p.primary;
        return Glass(
          radius: Tk.rFull,
          edge: alpha(c, .6),
          child: Press(
            radius: Tk.rFull,
            onTap: () => pushScreen<void>(context, const LogScreen()),
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    AppIcon(Ic.shield, size: 22, color: c),
                    Expanded(
                      child: Text(text, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, p.onSurface)),
                    ),
                    AppIcon(Ic.chev, size: 16, color: p.outline, flip: true),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Download / upload / ping tiles. Real numbers from the engine while connected, "--" otherwise.
class SpeedTiles extends StatelessWidget {
  const SpeedTiles({super.key});

  String _mbps(int bytesPerSec) {
    final v = bytesPerSec * 8 / 1000000;
    return loc(v >= 100 ? v.round() : v.toStringAsFixed(1));
  }

  Widget _tile(BuildContext context, {required Widget lead, required String label, required String value, required String unit, required Color c}) {
    final p = context.pal;
    return Expanded(
      child: Glass(
        radius: Tk.rL,
        edge: alpha(c, .55),
        padding: const EdgeInsets.fromLTRB(8, 11, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                lead,
                const SizedBox(width: 5),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.labelM, p.onSurfaceVariant))),
              ],
            ),
            const SizedBox(height: 7),
            Text(value, maxLines: 1, style: context.ty(R.titleM, p.onSurface, true)),
            Text(unit, style: context.ty(R.labelM, c)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([Conn.I, ServerStore.I]),
      builder: (context, _) {
        final c = Conn.I;
        final on = c.state == CS.on;
        final srv = c.server;
        final lat = srv == null ? null : ServerStore.I.lat[srv.id];
        Widget arrow(String a, Color col) => Text(a, style: TextStyle(fontSize: 18, height: 1, fontWeight: FontWeight.w700, color: col));
        return Row(
          children: [
            _tile(context, lead: arrow('↓', p.primary), label: trOr('sp_down', 'سرعت دانلود', 'Download'), value: on ? _mbps(c.rateDown) : '--', unit: 'Mbps', c: p.primary),
            const SizedBox(width: 8),
            _tile(context, lead: arrow('↑', p.tertiary), label: trOr('sp_up', 'سرعت آپلود', 'Upload'), value: on ? _mbps(c.rateUp) : '--', unit: 'Mbps', c: p.tertiary),
            const SizedBox(width: 8),
            _tile(context, lead: AppIcon(Ic.pulse, size: 16, color: p.ok), label: trOr('sp_ping', 'تأخیر (Ping)', 'Ping'), value: on && lat != null ? loc(lat) : '--', unit: 'ms', c: p.ok),
          ],
        );
      },
    );
  }
}
