import 'package:flutter/material.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import 'base.dart';

/// Generic list row (`.row`): icon chip, label + sub, trailing, chevron.
class RowTile extends StatelessWidget {
  final Ic? icon;
  final Tone tone;
  final String label;
  final String? sub;
  final Widget? trail;
  final Widget? leading;
  final bool chev;
  final bool compact;
  final bool selected;
  final bool grouped;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const RowTile({
    super.key,
    this.grouped = false,
    this.icon,
    this.tone = Tone.primary,
    required this.label,
    this.sub,
    this.trail,
    this.leading,
    this.chev = false,
    this.compact = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (grouped) {
      return Press(
        radius: 0,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)] else if (icon != null) ...[ChipIc(icon!, tone: tone, sm: compact), const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: context.ty(R.titleM, p.onSurface)),
                      if (sub != null) Text(sub!, style: context.ty(R.bodyS, p.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trail != null) ...[const SizedBox(width: 8), trail!],
                if (chev) ...[const SizedBox(width: 6), AppIcon(Ic.chev, size: 16, color: p.outline, flip: true)],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 7),
      child: CardX(
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 13, vertical: compact ? 8 : 11),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 28 : 30),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 11)] else if (icon != null) ...[ChipIc(icon!, tone: tone, sm: compact), const SizedBox(width: 11)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: context.ty(R.titleM, p.onSurface)),
                    if (sub != null) Text(sub!, style: context.ty(R.bodyS, p.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trail != null) ...[const SizedBox(width: 6), trail!],
              if (chev) ...[const SizedBox(width: 6), AppIcon(Ic.chev, size: 16, color: p.outline, flip: true)],
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings-style group: rows inside one flat card, separated by hairlines.
class GroupCard extends StatelessWidget {
  final List<Widget> children;
  const GroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: p.container,
        borderRadius: BorderRadius.circular(Tk.rL),
        border: Border.all(color: alpha(p.outlineVariant, .75)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tk.rL - 1),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 62, color: alpha(p.outlineVariant, .55)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder with a breathing pulse and a travelling sheen.
class Skel extends StatefulWidget {
  final double? w;
  final double h;
  final double r;
  const Skel({super.key, this.w, this.h = 14, this.r = 6});
  @override
  State<Skel> createState() => _SkelState();
}

class _SkelState extends State<Skel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: .7 + .3 * (1 - (2 * t - 1).abs()),
          child: Container(
            width: widget.w,
            height: widget.h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: alpha(p.onSurface, .07), borderRadius: BorderRadius.circular(widget.r)),
            child: FractionallySizedBox(
              alignment: Alignment(-1.2 + 2.4 * t, 0),
              widthFactor: .5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0x00000000), alpha(p.onSurface, .14), const Color(0x00000000)]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 4px linear bar (`.bar-track` / `.bar-fill`).
class Bar extends StatelessWidget {
  final double value;
  final Color color;
  final double h;
  const Bar({super.key, required this.value, required this.color, this.h = 4});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: h,
      decoration: BoxDecoration(color: alpha(p.onSurface, .08), borderRadius: BorderRadius.circular(Tk.rFull)),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(seconds: 1),
          curve: Tk.snappy,
          widthFactor: value.clamp(0.0, 1.0),
          child: AnimatedContainer(
            duration: Tk.fx,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Tk.rFull)),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final Ic icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            margin: const EdgeInsets.only(bottom: Tk.sp3),
            decoration: BoxDecoration(color: alpha(p.onSurface, .06), borderRadius: BorderRadius.circular(Tk.rL)),
            child: Center(child: AppIcon(icon, size: 24, color: p.outline)),
          ),
          Text(title, textAlign: TextAlign.center, style: context.ty(R.titleM, p.onSurface)),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(body, textAlign: TextAlign.center, style: context.ty(R.bodyS, p.onSurfaceVariant)),
          ),
          if (action != null) ...[const SizedBox(height: Tk.sp4), action!],
        ],
      ),
    );
  }
}

/// Inline note: tonal card with an icon and short text.
class Notice extends StatelessWidget {
  final Ic icon;
  final String text;
  final Tone tone;
  const Notice(this.text, {super.key, this.icon = Ic.info, this.tone = Tone.primary});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = toneColor(p, tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alpha(c, .10),
        borderRadius: BorderRadius.circular(Tk.rM),
        border: Border.all(color: alpha(c, .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: AppIcon(icon, size: 16, color: c)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.ty(R.bodyS, p.onSurfaceVariant))),
        ],
      ),
    );
  }
}
