import 'package:flutter/material.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import 'base.dart';

/// Material 3 switch with the design's spring knob (stretches while pressed,
/// grows when on, lands with a bounce).
class AlSwitch extends StatefulWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const AlSwitch({super.key, required this.on, required this.onChanged});
  @override
  State<AlSwitch> createState() => _AlSwitchState();
}

class _AlSwitchState extends State<AlSwitch> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final on = widget.on;
    final knob = on ? 22.0 : 18.0;
    return Semantics(
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          Hx.tap();
          widget.onChanged(!on);
        },
        child: AnimatedScale(
          scale: _down ? .94 : 1,
          duration: Tk.spatialFast,
          curve: Tk.bouncy,
          child: AnimatedContainer(
            duration: Tk.fx,
            curve: Tk.standard,
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              color: on ? p.primary : alpha(p.onSurface, .12),
              borderRadius: BorderRadius.circular(Tk.rFull),
              border: Border.all(color: on ? const Color(0x00000000) : p.outline, width: 1.5),
              boxShadow: on ? [glow(p.primary, .62, blur: 16, spread: -3)] : const [],
            ),
            child: Stack(
              children: [
                AnimatedPositionedDirectional(
                  duration: const Duration(milliseconds: 460),
                  curve: Tk.bouncy,
                  start: on ? 23 : 5 - 1.5,
                  top: on ? 3 - 1.5 : 5 - 1.5,
                  width: knob,
                  height: knob,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: _down ? 1 : 0),
                    duration: Tk.spatialFast,
                    curve: Tk.standard,
                    builder: (context, t, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1 + .18 * t, 1 - .14 * t, 1),
                      child: child,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? p.onPrimary : p.outline,
                        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlCheck extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const AlCheck({super.key, required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      checked: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Hx.tap();
          onChanged(!on);
        },
        child: AnimatedContainer(
          duration: Tk.fxFast,
          curve: Tk.standard,
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: on ? p.primary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: on ? p.primary : p.outline, width: 2),
          ),
          child: AnimatedScale(
            scale: on ? 1 : .4,
            duration: const Duration(milliseconds: 380),
            curve: Tk.bouncy,
            child: AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: Tk.fxFast,
              child: Center(child: AppIcon(Ic.check, size: 14, color: p.onPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}

class AlRadio extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const AlRadio({super.key, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      checked: on,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Hx.tap();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Tk.bouncy,
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: on ? p.primary : p.outline, width: on ? 6 : 2),
            boxShadow: on ? [BoxShadow(color: alpha(p.primary, .62), blurRadius: 12, spreadRadius: -2)] : const [],
          ),
        ),
      ),
    );
  }
}

/// Slider: 6px track, 16px thumb with an 8px halo. Fills from the start edge,
/// so it mirrors in RTL like the design.
class AlSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onEnd;
  const AlSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.onEnd});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rtl = context.isRtl;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double toVal(double dx) {
        var f = (dx / w).clamp(0.0, 1.0);
        if (rtl) f = 1 - f;
        return min + f * (max - min);
      }

      final f = ((value - min) / (max - min)).clamp(0.0, 1.0);
      final x = (rtl ? 1 - f : f) * w;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onChanged(toVal(d.localPosition.dx)),
        onHorizontalDragUpdate: (d) => onChanged(toVal(d.localPosition.dx)),
        onHorizontalDragEnd: (_) => onEnd?.call(value),
        onTapUp: (_) => onEnd?.call(value),
        child: SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(height: 6, decoration: BoxDecoration(color: alpha(p.onSurface, .12), borderRadius: BorderRadius.circular(Tk.rFull))),
              Positioned(
                left: rtl ? x : 0,
                right: rtl ? 0 : w - x,
                child: Container(height: 6, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(Tk.rFull))),
              ),
              Positioned(
                left: x - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.primary,
                    boxShadow: [BoxShadow(color: alpha(p.primary, .14), spreadRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Text field: 46px, medium radius, primary focus ring.
class AlField extends StatefulWidget {
  final TextEditingController controller;
  final String? hint;
  final bool invalid;
  final TextInputType? keyboard;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final int maxLines;
  const AlField({
    super.key,
    required this.controller,
    this.hint,
    this.invalid = false,
    this.keyboard,
    this.onSubmit,
    this.onChanged,
    this.prefix,
    this.maxLines = 1,
  });
  @override
  State<AlField> createState() => _AlFieldState();
}

class _AlFieldState extends State<AlField> {
  final FocusNode _f = FocusNode();

  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final focus = _f.hasFocus;
    final border = widget.invalid ? p.error : (focus ? p.primary : p.outlineVariant);
    return AnimatedContainer(
      duration: Tk.fxFast,
      curve: Tk.standard,
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: alpha(p.containerHighest, .7),
        borderRadius: BorderRadius.circular(Tk.rM),
        border: Border.all(color: border),
        boxShadow: focus && !widget.invalid ? [BoxShadow(color: alpha(p.primary, .22), spreadRadius: 3)] : const [],
      ),
      child: Row(
        children: [
          if (widget.prefix != null) ...[widget.prefix!, const SizedBox(width: 8)],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _f,
              keyboardType: widget.keyboard,
              maxLines: widget.maxLines,
              minLines: 1,
              onSubmitted: widget.onSubmit,
              onChanged: widget.onChanged,
              cursorColor: p.primary,
              style: context.ty(R.bodyL, p.onSurface, true),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: widget.hint,
                hintStyle: context.ty(R.bodyL, p.outline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
