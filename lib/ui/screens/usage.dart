import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../../services/engine.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import '../nav.dart';
import 'sheets.dart';

/// Usage tab: live rates + sparklines from the engine, session totals, history.
class UsageTab extends StatelessWidget {
  const UsageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final c = Conn.I;
        final on = c.state == CS.on;
        final hist = AppSettings.I.history;
        return ScreenFrame(
          top: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBarRow(title: tr('m_usage'), sub: on ? (c.server?.title ?? '') : tr('usage_off')),
              Rise(
                i: 0,
                child: CardX(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _Rate(label: '↓', value: on ? fmtBytes(c.rateDown) : '—', sub: '/s', color: p.primary, spark: c.sparkDown),
                      const SizedBox(height: 12),
                      _Rate(label: '↑', value: on ? fmtBytes(c.rateUp) : '—', sub: '/s', color: p.tertiary, spark: c.sparkUp),
                    ],
                  ),
                ),
              ),
              SectionLabel(tr('session')),
              Rise(
                i: 1,
                child: CardX(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    _Kv(tr('k_down'), on ? fmtBytes(c.sessDown) : '—'),
                    const SizedBox(height: 8),
                    _Kv(tr('k_up'), on ? fmtBytes(c.sessUp) : '—'),
                    const SizedBox(height: 8),
                    _Kv(tr('k_peak'), on ? '${fmtBytes(c.peakDown)}/s' : '—'),
                    const SizedBox(height: 8),
                    _Kv(tr('k_time'), on ? mmss(c.secs) : '—', num: true),
                  ]),
                ),
              ),
              SectionLabel(tr('history')),
              if (hist.isEmpty)
                EmptyState(icon: Ic.chart, title: tr('hist_empty_t'), body: tr('hist_empty_b'))
              else
                for (var i = 0; i < hist.length; i++)
                  Rise(
                    i: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: CardX(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${hist[i]['srv']}', style: context.ty(R.titleS, p.onSurface)),
                                Text(
                                  '${mmss(hist[i]['secs'] as int)} · ↓ ${fmtBytes(hist[i]['down'] as int)} · ↑ ${fmtBytes(hist[i]['up'] as int)}',
                                  style: context.ty(R.labelS, p.onSurfaceVariant, true),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
              const SizedBox(height: Tk.sp3),
              Btn(tr('reset_totals'), variant: Bv.danger, wide: true, icon: Ic.refresh, onTap: () async {
                final ok = await confirm(context, title: tr('reset_totals'), body: tr('reset_totals_b'), yes: tr('reset_totals'));
                if (!ok) return;
                await Engine.I.resetTotals();
                AppSettings.I.update(() => AppSettings.I.history.clear());
                Hx.ok();
                snack(tr('done'), tone: 'ok');
              }),
            ],
          ),
        );
      },
    );
  }
}

class _Rate extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final List<double> spark;
  const _Rate({required this.label, required this.value, required this.sub, required this.color, required this.spark});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: context.ty(R.titleM, color)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: context.ty(R.headlineS, p.onSurface, true))),
          Text(sub, style: context.ty(R.labelM, p.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 34, width: double.infinity, child: CustomPaint(painter: _Line(spark, color))),
      ],
    );
  }
}

class _Line extends CustomPainter {
  final List<double> v;
  final Color c;
  _Line(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final mx = v.reduce((a, b) => a > b ? a : b);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1);
      final y = size.height - size.height * (mx == 0 ? 0 : v[i] / mx);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [alpha(c, .28), alpha(c, 0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round..color = c);
  }

  @override
  bool shouldRepaint(_Line old) => old.v != v || old.c != c;
}

class _Kv extends StatelessWidget {
  final String k;
  final String v;
  final bool num;
  const _Kv(this.k, this.v, {this.num = false});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(children: [
      Expanded(child: Text(k, style: context.ty(R.bodyM, p.onSurfaceVariant))),
      Text(v, style: context.ty(R.titleS, p.onSurface, num)),
    ]);
  }
}
