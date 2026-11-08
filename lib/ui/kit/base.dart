import 'package:flutter/material.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';

// ───────────── shape language: one 45° cut, hairline edges ─────────────
/// The app's single shape: a rectangle with its four corners cut at 45°. [cut] is the size of the
/// cut. Anything bigger than the largest token (the old pill, 999) is clamped, so a legacy
/// `radius: Tk.rFull` turns into a chamfered tag instead of a diamond.
ShapeBorder cutShape(double cut, {BorderSide side = BorderSide.none}) =>
    BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(cut > Tk.rXl ? Tk.rXl : cut)), side: side);

/// Clips a child to the cut outline (ripples, the inside of grouped cards).
class CutClip extends StatelessWidget {
  final double cut;
  final Widget child;
  const CutClip({super.key, required this.cut, required this.child});

  @override
  Widget build(BuildContext context) => ClipPath(clipper: ShapeBorderClipper(shape: cutShape(cut)), child: child);
}

/// Elevation. Surfaces are flat and edged by a hairline; only what floats over content (nav bar,
/// sheets, dialogs, toasts) gets one short shadow.
List<BoxShadow> elev(Pal p, int n) {
  if (n <= 2) return const [];
  final blur = n == 3 ? 16.0 : 26.0;
  final dy = n == 3 ? 6.0 : 10.0;
  return [BoxShadow(color: p.shadowKey, offset: Offset(0, dy), blurRadius: blur)];
}

BoxShadow glow(Color c, double pct, {double blur = 40, double spread = -8}) =>
    BoxShadow(color: alpha(c, pct), blurRadius: blur, spreadRadius: spread);

// ───────────── panel ─────────────
/// The design's `.glass`, now a flat cut-corner panel: a lifted, opaque fill and a hairline edge.
/// It keeps its old name so every card, bar, sheet and dialog picks up the new look.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final Color? edge;

  /// Kept for old call sites: the fill is opaque now, so nothing shows through any more.
  final double minFill;
  const Glass({super.key, required this.child, this.radius = Tk.rL, this.padding, this.shadows, this.edge, this.minFill = .74});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // In Flutter a gradient replaces the box colour, so the gradient stops ARE the fill.
    return DecoratedBox(
      decoration: ShapeDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.containerHigh, p.container]),
        shape: cutShape(radius, side: BorderSide(color: edge ?? p.outlineVariant)),
        shadows: shadows ?? elev(p, 1),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

// ───────────── press: spring scale + ripple + haptic ─────────────
/// The design's `.press`: down = scale .945 / 1px drop in 90ms, release =
/// bouncy spring, plus the expanding ripple from the touch point.
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool ripple;
  final bool disabled;
  final double pressScale;
  final bool haptic;
  const Press({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.radius = Tk.rM,
    this.ripple = true,
    this.disabled = false,
    this.pressScale = .945,
    this.haptic = true,
  });

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 0);
  late final AnimationController _r = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Offset _pt = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    _r.dispose();
    super.dispose();
  }

  void _down(TapDownDetails d) {
    _pt = d.localPosition;
    _c.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.linear);
    if (widget.ripple && !context.st.saver) _r.forward(from: 0);
  }

  void _release() {
    _c.animateTo(0, duration: Tk.spatial, curve: Tk.bouncy);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final active = widget.onTap != null || widget.onLongPress != null;
    Widget content = AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        return Transform.translate(
          offset: Offset(0, v),
          child: Transform.scale(scale: 1 - (1 - widget.pressScale) * v, child: child),
        );
      },
      child: widget.ripple
          ? Stack(
              // passthrough: a loose Stack let cards shrink to their content inside Expanded/stretch slots
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: CutClip(
                      cut: widget.radius,
                      child: CustomPaint(painter: _RipplePainter(_r, () => _pt, p.primary)),
                    ),
                  ),
                ),
              ],
            )
          : widget.child,
    );
    if (!active) return content;
    return Opacity(
      opacity: widget.disabled ? .4 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.disabled ? null : _down,
        onTapUp: widget.disabled ? null : (_) => _release(),
        onTapCancel: widget.disabled ? null : _release,
        onTap: widget.disabled
            ? null
            : () {
                if (widget.haptic) Hx.tap();
                widget.onTap?.call();
              },
        onLongPress: widget.disabled ? null : widget.onLongPress,
        child: content,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final AnimationController c;
  final Offset Function() origin;
  final Color color;
  _RipplePainter(this.c, this.origin, this.color) : super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    final t = c.value;
    if (t <= 0 || t >= 1) return;
    double scale;
    double op;
    if (t < .1) {
      scale = 2.2 * (t / .6);
      op = (t / .1) * .5;
    } else if (t < .6) {
      scale = 2.2 * (t / .6);
      op = .5 + (.2 - .5) * ((t - .1) / .5);
    } else {
      scale = 2.2 + 1.2 * ((t - .6) / .4);
      op = .2 * (1 - (t - .6) / .4);
    }
    final r0 = (size.width > size.height ? size.width : size.height) / 2;
    final r = r0 * scale;
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: origin(), radius: r);
    final tint = Color.lerp(const Color(0xFFFFFFFF), color, .6)!;
    final paint = Paint()
      ..shader = RadialGradient(colors: [alpha(tint, op), alpha(tint, 0)], stops: const [0, .68]).createShader(rect);
    canvas.drawCircle(origin(), r, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => true;
}

// ───────────── cards ─────────────
enum Surf { card, tonal, filled, outlined }

/// `.card` / `.tonal` / `.filled` / `.outlined` as flat cut-corner panels. A selected card takes a
/// full accent edge and a faint accent wash instead of the old side rail.
class CardX extends StatelessWidget {
  final Widget child;
  final Surf surf;
  final bool selected;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const CardX({
    super.key,
    required this.child,
    this.surf = Surf.card,
    this.selected = false,
    this.radius = Tk.rM,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color? fill;
    Gradient? grad;
    var side = BorderSide.none;
    switch (surf) {
      case Surf.card:
        grad = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selected
              ? [Color.alphaBlend(alpha(p.primary, .07), p.containerHigh), Color.alphaBlend(alpha(p.primary, .03), p.container)]
              : [p.containerHigh, p.container],
        );
        side = BorderSide(color: selected ? p.primary : p.outlineVariant, width: selected ? 1.5 : 1);
        break;
      case Surf.tonal:
        fill = Color.alphaBlend(alpha(p.primary, .08), p.containerHigh);
        side = BorderSide(color: alpha(p.primary, .4));
        break;
      case Surf.filled:
        fill = p.primary;
        break;
      case Surf.outlined:
        side = BorderSide(color: p.outline);
        break;
    }
    // In Flutter a gradient replaces the colour, so only one of the two is ever set.
    final body = DecoratedBox(
      decoration: ShapeDecoration(color: fill, gradient: grad, shape: cutShape(radius, side: side)),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null && onLongPress == null) return body;
    return Press(radius: radius, onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

// ───────────── icon chip, icon button, badge ─────────────
enum Tone { primary, ok, warn, bad, plain }

Color toneColor(Pal p, Tone t) {
  switch (t) {
    case Tone.ok:
      return p.ok;
    case Tone.warn:
      return p.warn;
    case Tone.bad:
      return p.error;
    case Tone.plain:
      return p.onSurfaceVariant;
    case Tone.primary:
      return p.primary;
  }
}

Tone toneOf(String s) {
  switch (s) {
    case 'ok':
      return Tone.ok;
    case 'warn':
      return Tone.warn;
    case 'bad':
    case 'err':
      return Tone.bad;
    case 'plain':
      return Tone.plain;
    default:
      return Tone.primary;
  }
}

class ChipIc extends StatelessWidget {
  final Ic icon;
  final Tone tone;
  final bool round;
  final bool sm;
  final Widget? custom;
  const ChipIc(this.icon, {super.key, this.tone = Tone.primary, this.round = false, this.sm = false, this.custom});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = toneColor(p, tone);
    final size = sm ? 30.0 : 38.0;
    final plain = tone == Tone.plain;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: plain ? alpha(p.onSurface, .08) : alpha(c, .10),
        shape: cutShape(sm ? Tk.rXs : Tk.rS, side: BorderSide(color: plain ? p.outlineVariant : alpha(c, .45))),
      ),
      child: custom ?? AppIcon(icon, size: sm ? 15 : 18, color: c),
    );
  }
}

class IconBtn extends StatelessWidget {
  final Ic icon;
  final VoidCallback? onTap;
  final bool glass;
  final bool flip;
  final Color? color;
  final String? label;
  const IconBtn(this.icon, {super.key, this.onTap, this.glass = false, this.flip = false, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget inner = SizedBox(
      width: 40,
      height: 40,
      child: Center(child: AppIcon(icon, size: 19, color: color ?? p.onSurface, flip: flip)),
    );
    if (glass) inner = Glass(radius: Tk.rM, child: inner);
    return Semantics(label: label, button: true, child: Press(radius: Tk.rM, onTap: onTap, child: inner));
  }
}

class BadgeX extends StatelessWidget {
  final String text;
  final Tone tone;
  const BadgeX(this.text, {super.key, this.tone = Tone.ok});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = tone == Tone.primary ? p.primary : toneColor(p, tone);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Tk.bouncy,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: .85 + .15 * v, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: ShapeDecoration(color: alpha(c, .12), shape: cutShape(Tk.rXs, side: BorderSide(color: alpha(c, .45)))),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Geist',
            fontFamilyFallback: const ['Vazirmatn'],
            fontSize: 9 * context.st.textScale,
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation('wght', 650)],
            letterSpacing: context.st.fa ? 0 : .27,
            color: c,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ───────────── buttons ─────────────
enum Bv { filled, tonal, outlined, text, danger }

class Btn extends StatelessWidget {
  final String label;
  final Bv variant;
  final Ic? icon;
  final VoidCallback? onTap;
  final bool wide;
  final bool tall;
  const Btn(this.label, {super.key, this.variant = Bv.filled, this.icon, this.onTap, this.wide = false, this.tall = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color bg;
    Color fg;
    var border = BorderSide.none;
    switch (variant) {
      case Bv.filled:
        bg = p.primary;
        fg = p.onPrimary;
        break;
      case Bv.tonal:
        bg = Color.alphaBlend(alpha(p.primary, .08), p.containerHigh);
        fg = p.primary;
        border = BorderSide(color: alpha(p.primary, .55));
        break;
      case Bv.outlined:
        bg = const Color(0x00000000);
        fg = p.onSurface;
        border = BorderSide(color: p.outline);
        break;
      case Bv.text:
        bg = const Color(0x00000000);
        fg = p.primary;
        break;
      case Bv.danger:
        bg = Color.alphaBlend(alpha(p.error, .08), p.containerHigh);
        fg = p.error;
        border = BorderSide(color: alpha(p.error, .55));
        break;
    }
    final h = variant == Bv.text ? 40.0 : (tall ? 52.0 : 46.0);
    final row = Row(
      mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[AppIcon(icon!, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, fg))),
      ],
    );
    final body = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: variant == Bv.text ? 12 : 20),
      decoration: ShapeDecoration(color: bg, shape: cutShape(Tk.rM, side: border)),
      child: Center(widthFactor: wide ? null : 1, child: row),
    );
    return Press(radius: Tk.rM, onTap: onTap, child: body);
  }
}

// ───────────── segmented buttons and filter chips ─────────────
class Seg {
  final String id;
  final String label;
  const Seg(this.id, this.label);
}

class Segmented extends StatelessWidget {
  final List<Seg> items;
  final String value;
  final ValueChanged<String> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // Used both full-width and as a Row's trailing control (unbounded width): Expanded children
    // are only legal when the width is bounded, otherwise the control was never laid out.
    return LayoutBuilder(
      builder: (context, c) {
        final bounded = c.maxWidth.isFinite;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            color: p.containerLowest,
            shape: cutShape(Tk.rS, side: BorderSide(color: p.outlineVariant)),
          ),
          child: Row(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                if (bounded)
                  Expanded(child: _SegBtn(item: items[i], on: items[i].id == value, onTap: () => onChanged(items[i].id)))
                else
                  _SegBtn(item: items[i], on: items[i].id == value, onTap: () => onChanged(items[i].id)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SegBtn extends StatelessWidget {
  final Seg item;
  final bool on;
  final VoidCallback onTap;
  const _SegBtn({required this.item, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Press(
      radius: Tk.rXs + 1,
      pressScale: .94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tk.fx,
        curve: Tk.standard,
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: ShapeDecoration(
          color: on ? p.primary : const Color(0x00000000),
          shape: cutShape(Tk.rXs + 1),
        ),
        child: AnimatedDefaultTextStyle(
          duration: Tk.fx,
          curve: Tk.standard,
          style: context.ty(R.titleS, on ? p.onPrimary : p.onSurfaceVariant),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class FChip extends StatelessWidget {
  final String label;
  final bool on;
  final Ic? icon;
  final VoidCallback onTap;
  const FChip(this.label, {super.key, required this.on, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = on ? p.onSecondaryContainer : p.onSurfaceVariant;
    return Press(
      radius: Tk.rS,
      pressScale: .93,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tk.fx,
        curve: Tk.standard,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: ShapeDecoration(
          color: on ? p.secondaryContainer : const Color(0x00000000),
          shape: cutShape(Tk.rS, side: BorderSide(color: on ? p.primary : p.outlineVariant)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[AppIcon(icon!, size: 14, color: fg), const SizedBox(width: 5)],
            Text(label, style: context.ty(R.labelL, fg)),
          ],
        ),
      ),
    );
  }
}

// ───────────── small helpers ─────────────
class Hair extends StatelessWidget {
  const Hair({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, margin: const EdgeInsets.symmetric(vertical: Tk.sp2), color: context.pal.outlineVariant);
}

/// Section label: a short accent bar and the text. No capitals and no tracking (Persian letters join).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, top: 16, bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: p.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: context.ty(R.labelL, p.onSurfaceVariant))),
        ],
      ),
    );
  }
}

/// Top app bar: back button, title (+ optional subtitle), trailing actions.
class AppBarRow extends StatelessWidget {
  final String title;
  final String? sub;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const AppBarRow({super.key, required this.title, this.sub, this.onBack, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tk.sp3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            if (onBack != null) ...[IconBtn(Ic.back, flip: true, glass: true, onTap: onBack), const SizedBox(width: 6)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.ty(R.headlineS, p.onSurface)),
                  if (sub != null) Text(sub!, style: context.ty(R.labelM, p.onSurfaceVariant)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
