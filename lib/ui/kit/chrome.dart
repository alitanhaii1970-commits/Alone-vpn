import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import 'base.dart';

// ───────────── ambient background ─────────────
/// Surface colour, two soft top/bottom glows, three slowly drifting colour
/// pools (primary / tertiary / secondary) and a faint specular sheen.
class AmbientBg extends StatefulWidget {
  final Widget child;
  const AmbientBg({super.key, required this.child});
  @override
  State<AmbientBg> createState() => _AmbientBgState();
}

class _AmbientBgState extends State<AmbientBg> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 23));
  late final AnimationController _b = AnimationController(vsync: this, duration: const Duration(seconds: 31));
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 41));
  bool _saver = false;

  void _sync(bool saver) {
    if (saver == _saver && _a.isAnimating == !saver) return;
    _saver = saver;
    if (saver) {
      _a.stop();
      _b.stop();
      _c.stop();
    } else {
      _a.repeat(reverse: true);
      _b.repeat(reverse: true);
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    _sync(context.st.saver);
    final op = p.dark ? .62 : .30;
    Widget pool(AnimationController c, Color col, double size, Alignment at, Offset drift) {
      return Align(
        alignment: at,
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(c.value);
            return Transform.translate(
              offset: Offset(drift.dx * t, drift.dy * t),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [alpha(col, op), alpha(col, 0)], stops: const [0, .7]),
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: p.surface),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.24),
              radius: .9,
              colors: [alpha(p.primary, p.dark ? .22 : .10), alpha(p.primary, 0)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.4, 1.05),
              radius: .8,
              colors: [alpha(p.tertiary, p.dark ? .12 : .06), alpha(p.tertiary, 0)],
            ),
          ),
        ),
        IgnorePointer(child: pool(_a, p.primary, 380, const Alignment(-1.1, -.95), const Offset(60, 90))),
        IgnorePointer(child: pool(_b, p.tertiary, 330, const Alignment(1.15, .15), const Offset(-70, 40))),
        IgnorePointer(child: pool(_c, p.secondary, 300, const Alignment(-.2, 1.15), const Offset(40, -80))),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-.56, -.83),
                end: const Alignment(.56, .83),
                colors: [alpha(const Color(0xFFFFFFFF), .085), const Color(0x00FFFFFF), const Color(0x00FFFFFF), alpha(const Color(0xFFFFFFFF), .03)],
                stops: const [0, .24, .76, 1],
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ───────────── entrance ─────────────
/// `.rise`: fade + lift + settle, staggered 52ms per index.
class Rise extends StatefulWidget {
  final int i;
  final Widget child;
  const Rise({super.key, this.i = 0, required this.child});
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 52 * widget.i), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Tk.snappy.transform(_c.value);
        return Opacity(
          opacity: Curves.easeOut.transform(_c.value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: Transform.scale(scale: .975 + .025 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ───────────── status pill ─────────────
/// The pill under the status bar: spinner + step while connecting, server +
/// timer when connected, alert on failure.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Conn.I,
      builder: (context, _) {
        final c = Conn.I;
        final p = context.pal;
        final open = c.state != CS.off;
        final top = MediaQuery.of(context).padding.top + 8;
        Widget? inner;
        Color border = alpha(p.glassEdge, .62);
        if (open) {
          final srv = c.server;
          switch (c.state) {
            case CS.connecting:
              inner = Row(mainAxisSize: MainAxisSize.min, children: [
                _Spin(color: p.primary),
                const SizedBox(width: 8),
                Text(tr('st_connecting'), style: context.ty(R.labelL, p.onSurface)),
                const SizedBox(width: 8),
                Text(tr(kHsSteps[c.hs.clamp(0, 3).toInt()]), style: context.ty(R.labelL, p.onSurfaceVariant, true)),
              ]);
              break;
            case CS.on:
              inner = Row(mainAxisSize: MainAxisSize.min, children: [
                _Dot(color: p.ok),
                const SizedBox(width: 8),
                Text(srv?.title ?? '', style: context.ty(R.labelL, p.onSurface)),
                const SizedBox(width: 8),
                Text(mmss(c.secs), style: context.ty(R.labelL, p.onSurfaceVariant, true)),
              ]);
              border = alpha(p.ok, .42);
              break;
            case CS.failed:
              inner = Row(mainAxisSize: MainAxisSize.min, children: [
                AppIcon(Ic.alert, size: 15, color: p.error),
                const SizedBox(width: 8),
                Text(tr('st_failed'), style: context.ty(R.labelL, p.onSurface)),
              ]);
              border = alpha(p.error, .5);
              break;
            default:
              inner = Row(mainAxisSize: MainAxisSize.min, children: [
                _Spin(color: p.primary),
                const SizedBox(width: 8),
                Text(tr('st_disconnecting'), style: context.ty(R.labelL, p.onSurface)),
              ]);
          }
        }
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: Tk.spatial,
                switchInCurve: Tk.bouncy,
                switchOutCurve: Tk.accelerate,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween<double>(begin: .72, end: 1).animate(anim), child: child),
                ),
                child: inner == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : Container(
                        key: ValueKey('${c.state}-${c.state == CS.connecting ? c.hs : 0}'),
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Tk.rFull),
                          color: alpha(p.containerHighest, .94),
                          border: Border.all(color: border),
                          boxShadow: elev(p, 3),
                        ),
                        child: Center(child: inner),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Spin extends StatefulWidget {
  final Color color;
  const _Spin({required this.color});
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _c,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: widget.color, backgroundColor: alpha(widget.color, .22)),
        ),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: alpha(color, .8), blurRadius: 8)]),
      );
}

// ───────────── navigation bar ─────────────
class NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const NavBar({super.key, required this.index, required this.onSelect});

  static const List<(Ic, String)> _items = [
    (Ic.house, 'm_home'),
    (Ic.server, 'servers'),
    (Ic.chart, 'm_usage'),
    (Ic.sliders, 'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Glass(
      radius: Tk.rXl,
      shadows: elev(p, 3),
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _NavItem(icon: _items[i].$1, label: tr(_items[i].$2), on: i == index, onTap: () => onSelect(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Ic icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = on ? p.onSecondaryContainer : p.onSurfaceVariant;
    return Press(
      radius: Tk.rL,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 5,
              child: AnimatedScale(
                scale: on ? 1 : .55,
                duration: const Duration(milliseconds: 440),
                curve: Tk.bouncy,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: Tk.fx,
                  child: Container(
                    width: 54,
                    height: 30,
                    decoration: BoxDecoration(color: p.secondaryContainer, borderRadius: BorderRadius.circular(Tk.rFull)),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 30,
                  child: Center(
                    child: AnimatedScale(
                      scale: on ? 1.04 : 1,
                      duration: const Duration(milliseconds: 400),
                      curve: Tk.bouncy,
                      child: AppIcon(icon, size: 18, color: fg),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: context.ty(R.labelS, fg)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────── snackbar host ─────────────
class SnackHost extends StatelessWidget {
  final bool lifted;
  const SnackHost({super.key, required this.lifted});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Toasts.I,
      builder: (context, _) {
        final s = Toasts.I.cur;
        final p = context.pal;
        final bottom = MediaQuery.of(context).padding.bottom + (lifted ? 86 : 14);
        return AnimatedPositionedDirectional(
          duration: Tk.spatialFast,
          curve: Tk.standard,
          start: 14,
          end: 14,
          bottom: bottom,
          child: IgnorePointer(
            ignoring: s == null,
            child: AnimatedSwitcher(
              duration: Tk.spatialSlow,
              reverseDuration: Tk.fx,
              switchInCurve: Tk.bouncy,
              switchOutCurve: Tk.accelerate,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - anim.value)),
                  child: Transform.scale(scale: .92 + .08 * anim.value, child: child),
                ),
              ),
              child: s == null ? const SizedBox.shrink(key: ValueKey('none')) : _SnackCard(key: ValueKey(s.id), s: s, p: p),
            ),
          ),
        );
      },
    );
  }
}

class _SnackCard extends StatelessWidget {
  final Snack s;
  final Pal p;
  const _SnackCard({super.key, required this.s, required this.p});

  @override
  Widget build(BuildContext context) {
    final ic = s.tone == 'ok' ? Ic.check : (s.tone == 'err' || s.tone == 'bad') ? Ic.alert : s.tone == 'warn' ? Ic.alert : Ic.info;
    final col = s.tone == 'ok' ? p.ok : (s.tone == 'err' || s.tone == 'bad') ? p.error : s.tone == 'warn' ? p.warn : p.inverseOnSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: p.inverseSurface, borderRadius: BorderRadius.circular(Tk.rM), boxShadow: elev(p, 4)),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Tk.bouncy,
            builder: (context, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.rotate(angle: -.52 * (1 - v), child: Transform.scale(scale: .3 + .7 * v, child: child)),
            ),
            child: AppIcon(ic, size: 17, color: col),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s.msg, style: context.ty(R.bodyM, p.inverseOnSurface))),
          if (s.actLabel != null)
            Press(
              radius: Tk.rS,
              onTap: () {
                Toasts.I.hide();
                s.act?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Text(s.actLabel!, style: context.ty(R.labelL, p.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────── bottom sheet & dialog ─────────────
/// Modal bottom sheet: scrim blur, glass panel that springs up, grip, close.
Future<T?> showSheet<T>(BuildContext context, {required String title, String? body, required Widget Function(BuildContext) builder, bool showClose = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: const Color(0x00000000),
    transitionDuration: Tk.spatialSlow,
    pageBuilder: (ctx, a, b) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, sec, _) {
      final p = ctx.pal;
      final t = Tk.snappy.transform(anim.value);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: Tk.blurScrim * anim.value, sigmaY: Tk.blurScrim * anim.value),
                child: ColoredBox(color: alpha(p.scrim, anim.value)),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10 + MediaQuery.of(ctx).padding.bottom,
            child: Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 118 * (1 - t) * 3),
                child: Transform.scale(
                  scale: .97 + .03 * t,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .78),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Glass(
                        radius: Tk.rXl,
                        shadows: elev(p, 5),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 34,
                                height: 4,
                                margin: const EdgeInsets.only(top: 4, bottom: 12),
                                decoration: BoxDecoration(color: p.outlineVariant, borderRadius: BorderRadius.circular(Tk.rFull)),
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(title, style: ctx.ty(R.titleL, p.onSurface)),
                                    if (body != null) ...[
                                      const SizedBox(height: 7),
                                      Text(body, style: ctx.ty(R.bodyM, p.onSurfaceVariant)),
                                    ],
                                    builder(ctx),
                                  ],
                                ),
                              ),
                            ),
                            if (showClose) ...[
                              const SizedBox(height: 14),
                              Btn(tr('close'), variant: Bv.tonal, wide: true, onTap: () => Navigator.of(ctx).pop()),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Centered glass dialog that pops in with a slight tilt (the update dialog).
Future<T?> showGlassDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = false}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: const Color(0x00000000),
    transitionDuration: Tk.spatialSlow,
    pageBuilder: (ctx, a, b) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, sec, _) {
      final p = ctx.pal;
      final t = Tk.bouncy.transform(anim.value);
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: Tk.blurScrim * anim.value, sigmaY: Tk.blurScrim * anim.value),
              child: ColoredBox(color: alpha(p.scrim, anim.value)),
            ),
          ),
          Center(
            child: Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - t)),
                child: Transform.rotate(
                  angle: -.021 * (1 - t),
                  child: Transform.scale(
                    scale: .84 + .16 * t,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 270),
                        child: Glass(
                          radius: Tk.rXl,
                          shadows: elev(p, 5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: builder(ctx),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ───────────── screen frame ─────────────
/// Padding + scrolling + material root shared by every screen.
class ScreenFrame extends StatelessWidget {
  final Widget child;
  final bool top; // top-level (leaves room for the nav bar)
  final bool scroll;
  final Future<void> Function()? onRefresh;
  const ScreenFrame({super.key, required this.child, this.top = false, this.scroll = true, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = EdgeInsets.fromLTRB(16, mq.padding.top + 44, 16, (top ? 98 : 20) + mq.padding.bottom);
    Widget body = scroll
        ? SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: pad, child: child)
        : Padding(padding: pad, child: child);
    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: context.pal.primary,
        backgroundColor: context.pal.containerHighest,
        edgeOffset: mq.padding.top + 40,
        child: body,
      );
    }
    return Material(type: MaterialType.transparency, child: body);
  }
}

double clampd(double v, double a, double b) => math.max(a, math.min(b, v));
