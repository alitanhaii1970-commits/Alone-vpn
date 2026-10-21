import 'package:flutter/material.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';

// ───────────── elevation (the design's --elev-1..5 and glows) ─────────────
List<BoxShadow> elev(Pal p, int n) {
  BoxShadow s(double dy, double blur, double spread, Color c) =>
      BoxShadow(color: c, offset: Offset(0, dy), blurRadius: blur, spreadRadius: spread);
  switch (n) {
    case 1:
      return [s(1, 2, 0, p.shadowAmb), s(1, 3, 1, p.shadowAmb)];
    case 2:
      return [s(1, 2, 0, p.shadowAmb), s(2, 6, 2, p.shadowAmb)];
    case 3:
      return [s(4, 8, 3, p.shadowAmb), s(1, 3, 0, p.shadowKey)];
    case 4:
      return [s(6, 10, 4, p.shadowAmb), s(2, 3, 0, p.shadowKey)];
    default:
      return [s(8, 14, 6, p.shadowAmb), s(4, 5, 0, p.shadowKey)];
  }
}

BoxShadow glow(Color c, double pct, {double blur = 40, double spread = -8}) =>
    BoxShadow(color: alpha(c, pct), blurRadius: blur, spreadRadius: spread);

/// Paints box shadows only *outside* the shape, like CSS box-shadow (Flutter's
/// own would show through translucent glass).
class _OuterShadow extends CustomPainter {
  final double radius;
  final List<BoxShadow> shadows;
  const _OuterShadow(this.radius, this.shadows);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    final outer = Path()..addRect(Rect.fromLTWH(-200, -200, size.width + 400, size.height + 400));
    final hole = Path()..addRRect(rr);
    canvas.clipPath(Path.combine(PathOperation.difference, outer, hole));
    for (final sh in shadows) {
      canvas.drawRRect(rr.shift(sh.offset).inflate(sh.spreadRadius), sh.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) => old.radius != radius || old.shadows != shadows;
}

/// `inset 0 1px 0 hi, inset 0 -1px 0 shade`: a 1px lit top edge and shaded bottom edge.
class _InsetEdges extends CustomPainter {
  final double radius;
  final Color top;
  final Color? bottom;
  const _InsetEdges(this.radius, this.top, this.bottom);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final base = Path()..addRRect(rr);
    canvas.drawPath(
        Path.combine(PathOperation.difference, base, Path()..addRRect(rr.shift(const Offset(0, 1)))), Paint()..color = top);
    if (bottom != null) {
      canvas.drawPath(Path.combine(PathOperation.difference, base, Path()..addRRect(rr.shift(const Offset(0, -1)))),
          Paint()..color = bottom!);
    }
  }

  @override
  bool shouldRepaint(_InsetEdges old) => old.top != top || old.bottom != bottom || old.radius != radius;
}

// ───────────── glass ─────────────
/// The design's `.glass`: translucent gradient fill, blurred backdrop, lit edge.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final Color? edge;

  /// Minimum opacity of the fill. Surfaces that sit over other content (bottom bar, sheets,
  /// dialogs) use a nearly solid fill so what is behind them does not show through.
  final double minFill;
  const Glass({super.key, required this.child, this.radius = Tk.rL, this.padding, this.shadows, this.edge, this.minFill = .74});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final saver = context.st.saver;
    final br = BorderRadius.circular(radius);
    // No BackdropFilter: a live blur over the animated ambient background re-renders every
    // frame and is what made the UI janky. A denser translucent fill gives the same glass look.
    final fillA = saver ? .94 : (p.glassA < minFill ? minFill : p.glassA);
    final c1 = Color.lerp(p.glassHi, alpha(p.containerHigh, fillA), .78)!;
    final c2 = alpha(p.containerHigh, fillA);
    final c3 = alpha(p.containerHigh, minFill >= .9 ? fillA : fillA * .84);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(color: alpha(edge ?? p.glassEdge, .62), width: 1),
        gradient: LinearGradient(
          begin: const Alignment(-.47, -.88),
          end: const Alignment(.47, .88),
          colors: [c1, c2, c3],
          stops: const [0, .58, 1],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _InsetEdges(radius, alpha(p.glassHi, .55), const Color(0x1F000000)),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    return CustomPaint(
      painter: _OuterShadow(radius, shadows ?? elev(p, 2)),
      child: ClipRRect(borderRadius: br, child: body),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
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

/// `.card` / `.tonal` / `.filled` / `.outlined`, with the selected rail.
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
    final br = BorderRadius.circular(radius);
    Color bg;
    List<BoxShadow> sh = const [];
    Border? border;
    switch (surf) {
      case Surf.card:
        bg = selected ? alpha(p.primary, .14) : alpha(p.container, .88);
        break;
      case Surf.tonal:
        bg = alpha(p.primaryContainer, .92);
        sh = elev(p, 1);
        break;
      case Surf.filled:
        bg = p.primary;
        sh = [...elev(p, 2), glow(p.primary, .58)];
        break;
      case Surf.outlined:
        bg = const Color(0x00000000);
        border = Border.all(color: p.outlineVariant);
        break;
    }
    if (selected) {
      sh = [BoxShadow(color: alpha(p.primary, .42), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -10)];
    }
    // passthrough: when the parent gives the card a tight size (Expanded / stretch), the background
    // must fill it; with the default loose fit it shrank to its content and looked misaligned.
    Widget body = Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: bg, borderRadius: br, border: border),
          child: CustomPaint(
            foregroundPainter: selected
                ? _RingPainter(radius, alpha(p.primary, .46))
                : _InsetEdges(radius, alpha(p.glassHi, .45), null),
            child: Padding(padding: padding, child: child),
          ),
        ),
        if (selected)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                heightFactor: .52,
                child: _Rail(color: p.primary),
              ),
            ),
          ),
      ],
    );
    body = CustomPaint(painter: _OuterShadow(radius, sh), child: body);
    if (onTap == null && onLongPress == null) return body;
    return Press(radius: radius, onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

class _Rail extends StatelessWidget {
  final Color color;
  const _Rail({required this.color});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Tk.bouncy,
      builder: (context, v, _) => Transform.scale(
        scaleY: v,
        child: Container(
          width: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Tk.rFull),
            boxShadow: [BoxShadow(color: alpha(color, .72), blurRadius: 9)],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double radius;
  final Color color;
  const _RingPainter(this.radius, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius((Offset.zero & size).deflate(.6), Radius.circular(radius));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.radius != radius;
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
    final rad = round ? Tk.rFull : (sm ? Tk.rS : Tk.rM);
    final plain = tone == Tone.plain;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: plain ? alpha(p.onSurface, .08) : alpha(c, .15),
        borderRadius: BorderRadius.circular(rad),
        border: Border.all(color: plain ? p.outlineVariant : alpha(c, tone == Tone.primary ? .18 : .22)),
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
    if (glass) inner = Glass(radius: Tk.rM, shadows: elev(p, 1), child: inner);
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
        child: Transform.scale(scale: .5 + .5 * v, child: Transform.rotate(angle: -.14 * (1 - v), child: child)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: alpha(c, .18), borderRadius: BorderRadius.circular(Tk.rXs)),
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
    Border? border;
    List<BoxShadow> sh = const [];
    switch (variant) {
      case Bv.filled:
        bg = p.primary;
        fg = p.onPrimary;
        sh = [...elev(p, 1), glow(p.primary, .58)];
        break;
      case Bv.tonal:
        bg = alpha(p.primary, p.dark ? .14 : .12);
        fg = p.primary;
        border = Border.all(color: alpha(p.primary, .28));
        break;
      case Bv.outlined:
        bg = const Color(0x00000000);
        fg = p.onSurface;
        border = Border.all(color: p.outline);
        break;
      case Bv.text:
        bg = const Color(0x00000000);
        fg = p.primary;
        break;
      case Bv.danger:
        bg = alpha(p.error, p.dark ? .14 : .10);
        fg = p.error;
        border = Border.all(color: alpha(p.error, .30));
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
    final body = CustomPaint(
      painter: _OuterShadow(Tk.rFull, sh),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: variant == Bv.text ? 12 : 20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tk.rFull), border: border),
        child: Center(widthFactor: wide ? null : 1, child: row),
      ),
    );
    return Press(radius: Tk.rFull, onTap: onTap, child: body);
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
          decoration: BoxDecoration(
            color: alpha(p.containerLowest, .8),
            borderRadius: BorderRadius.circular(Tk.rFull),
            border: Border.all(color: p.outlineVariant),
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
      radius: Tk.rFull,
      pressScale: .94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tk.fx,
        curve: Tk.standard,
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on ? p.primary : const Color(0x00000000),
          borderRadius: BorderRadius.circular(Tk.rFull),
          boxShadow: on ? elev(p, 1) : const [],
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
      radius: Tk.rFull,
      pressScale: .93,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tk.fx,
        curve: Tk.standard,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? p.secondaryContainer : const Color(0x00000000),
          borderRadius: BorderRadius.circular(Tk.rFull),
          border: Border.all(color: on ? const Color(0x00000000) : p.outlineVariant),
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

/// The micro-caps section label (`.t-micro`, upper-cased in English).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fa = context.st.fa;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 14, bottom: 8),
      child: Text(fa ? text : text.toUpperCase(), style: context.ty(R.micro, p.onSurfaceVariant)),
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
