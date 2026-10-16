import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import '../nav.dart';
import 'latency.dart';
import 'log.dart';
import 'servers.dart';
import 'sheets.dart';

/// The connect dial: track + sweep ring (progress), breathing glow, the orbit
/// and pulses while connected, a wave on success, a shake on failure.
class ConnectDial extends StatefulWidget {
  const ConnectDial({super.key});
  @override
  State<ConnectDial> createState() => _ConnectDialState();
}

class _ConnectDialState extends State<ConnectDial> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))..repeat();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1050));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  CS? _last;

  @override
  void dispose() {
    for (final c in [_bob, _glow, _spin, _pulse, _wave, _shake, _burst]) {
      c.dispose();
    }
    super.dispose();
  }

  void _react(CS s) {
    if (s == _last) return;
    final was = _last;
    _last = s;
    if (s == CS.on) {
      _wave.forward(from: 0);
      _burst.forward(from: 0);
      _pulse.repeat(); // the pulses only run while connected
    } else {
      _pulse.stop();
      if (s == CS.failed && was != null) _shake.forward(from: 0);
    }
  }

  // Performance rule for this widget: everything that moves every frame is a static picture
  // inside its own RepaintBoundary, and only its transform / opacity is animated. The GPU then
  // just re-composites cached layers instead of re-drawing blurred shadows and gradients.
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final c = Conn.I;
        _react(c.state);
        final on = c.state == CS.on;
        final failed = c.state == CS.failed;
        final busy = c.busy;
        final accent = on ? p.ok : (failed ? p.error : p.primary);
        final sweep = c.state == CS.connecting
            ? (c.hs + 1) / 4
            : on
                ? 1.0
                : 0.0;
        return SizedBox(
          height: 212,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // slowly turning dotted halo
              IgnorePointer(
                child: SizedBox(
                  width: 236,
                  height: 236,
                  child: AnimatedBuilder(
                    animation: _spin,
                    child: RepaintBoundary(child: CustomPaint(painter: _DotField(p.primary))),
                    builder: (context, child) => Transform.rotate(angle: _spin.value * 6.2832 / 6, child: child),
                  ),
                ),
              ),
              // soft coloured glow under the button, breathing
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _glow,
                  child: RepaintBoundary(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: accent),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, col, _) => Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [glow(col ?? accent, on ? .42 : .30, blur: 54, spread: -4)]),
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    final g = Curves.easeInOut.transform(_glow.value);
                    return Opacity(opacity: .72 + .28 * g, child: Transform.scale(scale: .96 + .1 * g, child: child));
                  },
                ),
              ),
              // progress ring (handshake steps)
              IgnorePointer(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: sweep),
                    duration: const Duration(milliseconds: 1350),
                    curve: Tk.standard,
                    builder: (context, v, _) => CustomPaint(
                      size: const Size(196, 196),
                      painter: _Ring(v, accent, p.onSurface, on ? 1 : 0),
                    ),
                  ),
                ),
              ),
              // expanding pulses while connected
              if (on)
                for (final off in const [0.0, 1.05, 2.1])
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      child: RepaintBoundary(
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: alpha(p.ok, .46), width: 1)),
                        ),
                      ),
                      builder: (context, child) {
                        final t = ((_pulse.value - off / 3.2) % 1.0 + 1.0) % 1.0;
                        final o = (t < .18 ? t / .18 * .6 : (1 - t) * .6 * (1 - t) / .82).clamp(0.0, 1.0);
                        return Opacity(opacity: o, child: Transform.scale(scale: .97 + .73 * t, child: child));
                      },
                    ),
                  ),
              // orbiting dots while connected
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: const Duration(milliseconds: 380),
                  child: AnimatedBuilder(
                    animation: _spin,
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: 228,
                        height: 228,
                        child: Stack(children: [
                          for (final a in const [0.0, 120.0, 238.0])
                            Align(
                              alignment: Alignment.center,
                              child: Transform.translate(
                                offset: const Offset(0, -114),
                                child: Transform.rotate(
                                  angle: a * 3.1415926 / 180,
                                  child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: p.ok, boxShadow: [BoxShadow(color: p.ok, blurRadius: 9)])),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    builder: (context, child) => Transform.rotate(angle: _spin.value * 6.2832 * 2.4, child: child),
                  ),
                ),
              ),
              // success wave
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _wave,
                  child: RepaintBoundary(
                    child: Container(width: 158, height: 158, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.ok, width: 1.6))),
                  ),
                  builder: (context, child) {
                    final t = _wave.value;
                    if (t == 0 || t >= 1) return const SizedBox.shrink();
                    return Opacity(
                      opacity: (t < .6 ? .9 - .5 * (t / .6) : .3 * (1 - (t - .6) / .4)).clamp(0.0, 1.0),
                      child: Transform.scale(scale: .94 + 1.46 * t, child: child),
                    );
                  },
                ),
              ),
              // the button: floats, shakes on failure, pops on success
              AnimatedBuilder(
                animation: Listenable.merge([_bob, _shake, _burst]),
                child: RepaintBoundary(
                  child: Press(
                    radius: 130,
                    pressScale: .92,
                    haptic: false,
                    onTap: () => Conn.I.toggle(),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: accent),
                      duration: const Duration(milliseconds: 450),
                      builder: (context, col, _) {
                        final cc = col ?? accent;
                        return Container(
                          width: 158,
                          height: 158,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: alpha(cc, .62), width: 1.4),
                            gradient: RadialGradient(
                              center: const Alignment(-.28, -.42),
                              radius: 1.05,
                              colors: [alpha(cc, .78), alpha(cc, .30), alpha(p.surface, .96)],
                              stops: const [0, .55, 1],
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // glassy highlight
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: const Alignment(.15, .15),
                                      colors: [alpha(Colors.white, .30), alpha(Colors.white, 0)],
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 380),
                                switchInCurve: Tk.bouncy,
                                child: busy
                                    ? RepaintBoundary(
                                        key: const ValueKey('busy'),
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onSurface),
                                        ),
                                      )
                                    : AppIcon(on ? Ic.shield : Ic.power, key: ValueKey(on), size: 58, color: p.onSurface),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                builder: (context, child) {
                  final b = Curves.easeInOut.transform(_bob.value);
                  final s = _shake.value;
                  final shakeDx = _shake.isAnimating || s > 0 ? (s < .14 ? -7 * s / .14 : (s < .31 ? 6 * (s - .14) / .17 : -4 * (1 - (s - .31) / .69))) : 0.0;
                  final bu = _burst.value;
                  final bScale = _burst.isAnimating ? (bu < .24 ? .88 + .25 * bu / .24 : 1.13 - .17 * (bu - .24) / .76) : 1.0;
                  return Transform.translate(
                    offset: Offset(shakeDx, -4 * (b < .5 ? b * 2 : (1 - b) * 2)),
                    child: Transform.scale(scale: bScale, child: child),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DotField extends CustomPainter {
  final Color c;
  const _DotField(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = alpha(c, .5);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2;
    for (double y = 0; y <= size.height; y += 16) {
      for (double x = 0; x <= size.width; x += 16) {
        final d = Offset(x - cx, y - cy).distance / maxR;
        if (d < .34 || d > .96) continue;
        final a = d > .74 ? (1 - (d - .74) / .22) : 1.0;
        paint.color = alpha(c, .5 * a * .62);
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotField old) => old.c != c;
}

class _Ring extends CustomPainter {
  final double sweep;
  final Color ring;
  final Color track;
  final double on;
  const _Ring(this.sweep, this.ring, this.track, this.on);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rect = r.deflate(1.6);
    canvas.drawCircle(
        rect.center,
        rect.width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..color = alpha(track, .09));
    if (sweep > 0) {
      canvas.drawArc(
          rect,
          -1.5708,
          6.2832 * sweep.clamp(0.0, 1.0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round
            ..color = ring
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.4 * (.4 + .6 * on)));
      canvas.drawArc(
          rect,
          -1.5708,
          6.2832 * sweep.clamp(0.0, 1.0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round
            ..color = ring);
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.sweep != sweep || old.ring != ring || old.on != on;
}

/// Four handshake segments: resolve → tcp → tls → tunnel.
class Handshake extends StatelessWidget {
  const Handshake({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = Conn.I;
    final show = c.state == CS.connecting || c.state == CS.failed;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 320),
      opacity: show ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: _HsSeg(state: _segState(c, i), color: p.primary, ok: p.ok, err: p.error, base: alpha(p.onSurface, .10))),
            ],
          ],
        ),
      ),
    );
  }

  String _segState(Conn c, int i) {
    if (c.state == CS.failed) {
      if (i < c.failStep) return 'done';
      if (i == c.failStep) return 'failed';
      return 'idle';
    }
    if (i < c.hs) return 'done';
    if (i == c.hs && c.state == CS.connecting) return 'active';
    return 'idle';
  }
}

class _HsSeg extends StatefulWidget {
  final String state;
  final Color color;
  final Color ok;
  final Color err;
  final Color base;
  const _HsSeg({required this.state, required this.color, required this.ok, required this.err, required this.base});
  @override
  State<_HsSeg> createState() => _HsSegState();
}

class _HsSegState extends State<_HsSeg> with SingleTickerProviderStateMixin {
  late final AnimationController _crawl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.state == 'active') _crawl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _HsSeg old) {
    super.didUpdateWidget(old);
    if (widget.state == 'active' && !_crawl.isAnimating) {
      _crawl.repeat(reverse: true);
    } else if (widget.state != 'active' && _crawl.isAnimating) {
      _crawl.stop();
    }
  }

  @override
  void dispose() {
    _crawl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.state == 'failed' ? widget.err : widget.state == 'done' ? widget.ok : widget.color;
    return AnimatedBuilder(
      animation: _crawl,
      builder: (context, _) {
        final f = widget.state == 'idle' ? 0.0 : widget.state == 'active' ? (.55 + (.92 - .55) * _crawl.value) : 1.0;
        return Container(
          height: 3,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: widget.base, borderRadius: BorderRadius.circular(Tk.rFull)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: Tk.spatial,
              curve: Tk.standard,
              widthFactor: f,
              child: DecoratedBox(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(Tk.rFull))),
            ),
          ),
        );
      },
    );
  }
}

/// Status line: headline (on/off/…) and support line (server · step).
class DialLabel extends StatelessWidget {
  const DialLabel({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final c = Conn.I;
        final headline = switch (c.state) {
          CS.on => tr('st_on'),
          CS.connecting => tr('st_connecting'),
          CS.disconnecting => tr('st_disconnecting'),
          CS.failed => tr('st_failed'),
          CS.off => tr('st_off'),
        };
        final support = switch (c.state) {
          CS.on => c.server?.title ?? '',
          CS.connecting => tr(kHsSteps[c.hs.clamp(0, 3).toInt()]),
          CS.failed => tr('sn_fail', {'s': c.server?.title ?? '', 'd': tr(kHsSteps[c.failStep.clamp(0, 3).toInt()])}),
          _ => '',
        };
        final color = c.state == CS.on ? p.ok : c.state == CS.failed ? p.error : p.onSurface;
        return Column(
          children: [
            Text(headline, style: context.ty(R.titleL, color)),
            const SizedBox(height: 2),
            SizedBox(
              height: 19,
              child: Text(support, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.labelL, p.onSurfaceVariant)),
            ),
          ],
        );
      },
    );
  }
}

/// The three-cell telemetry strip: status · latency · exit IP.
class Telemetry extends StatelessWidget {
  const Telemetry({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final c = Conn.I;
        final srv = c.server;
        final lat = srv == null ? null : ServerStore.I.lat[srv.id];
        final tone = c.state == CS.on ? 'ok' : c.state == CS.failed ? 'bad' : c.busy ? 'warn' : '';
        return CardX(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _Cell(k: tr('k_status'), v: tr(c.state == CS.on ? 'v_on' : c.busy ? 'v_busy' : c.state == CS.failed ? 'v_fail' : 'v_off'), tone: tone, title: true),
                Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: p.outlineVariant),
                _Cell(k: tr('k_latency'), v: c.state == CS.on && lat != null ? '${loc(lat)} ms' : '—', num: true, title: true),
                Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: p.outlineVariant),
                _Cell(k: tr('k_exit'), v: c.state == CS.on && srv != null ? srv.host : '—', num: true, small: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final String k;
  final String v;
  final String tone;
  final bool num;
  final bool title;
  final bool small;
  const _Cell({required this.k, required this.v, this.tone = '', this.num = false, this.title = false, this.small = false});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vc = tone == 'ok' ? p.ok : tone == 'bad' ? p.error : tone == 'warn' ? p.warn : p.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Text(k, style: context.ty(R.micro, p.onSurfaceVariant)),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: Tk.fx,
              style: context.ty(small ? R.titleS : R.titleM, vc, num),
              child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

/// Active server card: globe chip, title/subtitle, protocol, chevron.
class ActiveServerCard extends StatelessWidget {
  const ActiveServerCard({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([ServerStore.I, Conn.I]),
      builder: (context, _) {
        final s = ServerStore.I.active;
        return CardX(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => pushScreen<void>(context, const ServersScreen()),
          child: Row(
            children: [
              const ChipIc(Ic.globe, round: false, sm: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('active_server'), style: context.ty(R.labelM, p.onSurfaceVariant)),
                    Text(s?.title ?? tr('no_server'), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleM, p.onSurface)),
                  ],
                ),
              ),
              if (s != null) Text(s.proto, style: context.ty(R.labelM, p.outline, true)),
              const SizedBox(width: 6),
              AppIcon(Ic.chev, size: 16, color: p.outline, flip: true),
            ],
          ),
        );
      },
    );
  }
}

/// Quick tiles: latency (with sparkline), DNS, add config. Uneven widths on purpose.
class QuickTiles extends StatelessWidget {
  const QuickTiles({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = context.st;
    return ListenableBuilder(
      listenable: Listenable.merge([Conn.I, ServerStore.I]),
      builder: (context, _) {
        Widget tile(Ic icon, String label, Widget extra, VoidCallback onTap, {int flex = 1}) => Expanded(
              flex: flex,
              child: CardX(
                padding: const EdgeInsets.fromLTRB(7, 10, 7, 9),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 78),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(icon, size: 22, color: p.primary),
                      const SizedBox(height: 4),
                      Text(label, textAlign: TextAlign.center, style: context.ty(R.labelM, p.onSurfaceVariant)),
                      extra,
                    ],
                  ),
                ),
              ),
            );
        final dnsLabel = !st.dnsOn ? 'off' : (st.activeDns?.name ?? 'custom');
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(
              Ic.pulse,
              tr('t_latency'),
              SizedBox(height: 16, width: double.infinity, child: _Spark(ServerStore.I.lat.values.whereType<int>().toList(), p.primary)),
              () => pushScreen<void>(context, const LatencyScreen()),
              flex: 145,
            ),
            const SizedBox(width: 8),
            tile(Ic.pad, tr('t_dns'), Text(dnsLabel, style: context.ty(R.labelS, p.outline, true)), () => pushScreen<void>(context, const DnsScreen())),
            const SizedBox(width: 8),
            tile(
              Ic.cast,
              tr('t_import'),
              Text('${loc(ServerStore.I.items.length)}', style: context.ty(R.labelS, p.outline, true)),
              () => showImport(context),
            ),
          ],
        );
      },
    );
  }
}

class _Spark extends StatelessWidget {
  final List<int> values;
  final Color color;
  const _Spark(this.values, this.color);
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SparkPainter(values, color));
}

class _SparkPainter extends CustomPainter {
  final List<int> v;
  final Color c;
  _SparkPainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), Paint()..color = alpha(c, .25)..strokeWidth = 1);
      return;
    }
    final mx = v.reduce((a, b) => a > b ? a : b).toDouble();
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1);
      final y = size.height - size.height * (v[i] / (mx == 0 ? 1 : mx));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..color = c);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.c != c;
}

/// Recent servers panel (up to 4): pick, see latency, delete with the ✕.
class RecentsPanel extends StatelessWidget {
  const RecentsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: ServerStore.I,
      builder: (context, _) {
        final items = ServerStore.I.items.take(4).toList();
        return CardX(
          padding: const EdgeInsets.fromLTRB(11, 12, 11, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('recents'), style: context.ty(R.micro, p.onSurfaceVariant)),
                    Press(
                      radius: Tk.rS,
                      onTap: () => pushScreen<void>(context, const ServersScreen()),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(tr('see_all'), style: context.ty(R.labelM, p.primary))),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                EmptyState(icon: Ic.server, title: tr('empty_t'), body: tr('empty_b'), action: Btn(tr('import_cta'), variant: Bv.tonal, icon: Ic.plus, onTap: () => showImport(context)))
              else
                for (var i = 0; i < items.length; i++)
                  Rise(
                    i: i,
                    child: ServerRow(server: items[i], compact: true),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// One server row: title, host/protocol, latency pill, selection rail, ✕.
class ServerRow extends StatelessWidget {
  final Server server;
  final bool compact;
  const ServerRow({super.key, required this.server, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = AppSettings.I;
    final sel = st.activeServer == server.id;
    final ms = ServerStore.I.lat[server.id];
    final probing = ServerStore.I.probing.contains(server.id);
    final tone = latTone(p, ms);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardX(
        selected: sel,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
        onTap: () {
          ServerStore.I.setActive(server.id);
          snack(tr('toast_server', {'s': server.title}), tone: 'ok');
        },
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? p.primary : p.outline, boxShadow: sel ? [BoxShadow(color: p.primary, blurRadius: 8)] : const []),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(server.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, p.onSurface))),
                    if (ServerStore.I.fastest()?.id == server.id && ms != null) ...[const SizedBox(width: 6), const BadgeX('FAST', tone: Tone.ok)],
                  ]),
                  Text('${server.cc.isEmpty ? '' : '${server.cc} · '}${server.proto} · ${server.host}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.labelS, p.onSurfaceVariant, true)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (probing)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
            else
              Text(latText(ms), style: context.ty(R.labelM, ms == null ? p.outline : tone, true)),
            const SizedBox(width: 6),
            Press(
              radius: Tk.rFull,
              onTap: () {
                ServerStore.I.remove(server.id);
                snack(tr('deleted'), tone: 'info');
              },
              child: Padding(padding: const EdgeInsets.all(6), child: AppIcon(Ic.x, size: 14, color: p.outline)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      top: true,
      child: Column(
        children: [
          Rise(
            i: 0,
            child: Row(
              children: [
                IconBtn(Ic.terminal, glass: true, onTap: () => pushScreen<void>(context, const LogScreen())),
                Expanded(
                  child: Column(
                    children: [
                      Text('ALONE VPN', style: context.ty(R.headlineS, context.pal.onSurface)),
                      Text(tr('tagline'), style: context.ty(R.labelM, context.pal.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconBtn(Ic.help, glass: true, onTap: () => pushScreen<void>(context, const HelpScreen())),
              ],
            ),
          ),
          const SizedBox(height: Tk.sp3),
          Rise(i: 1, child: const ConnectDial()),
          Rise(i: 2, child: const DialLabel()),
          const Handshake(),
          const SizedBox(height: Tk.sp4),
          Rise(i: 3, child: const Telemetry()),
          Rise(i: 4, child: const ActiveServerCard()),
          const SizedBox(height: Tk.sp3),
          Rise(i: 5, child: const QuickTiles()),
          const SizedBox(height: Tk.sp2),
          Rise(i: 6, child: const RecentsPanel()),
        ],
      ),
    );
  }
}
