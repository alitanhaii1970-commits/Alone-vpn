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
import 'base.dart';
import 'chrome.dart';

/// Light / dark / system segmented control.
class ModeSeg extends StatelessWidget {
  const ModeSeg({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.st;
    return Segmented(
      items: [Seg('light', tr('mode_light')), Seg('dark', tr('mode_dark')), Seg('system', tr('mode_system'))],
      value: st.mode,
      onChanged: (v) => st.update(() => st.mode = v),
    );
  }
}

/// 3-column theme grid: each cell previews the theme's surface + accent.
class ThemeGrid extends StatelessWidget {
  const ThemeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final dark = st.isDark(MediaQuery.of(context).platformBrightness);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: EdgeInsets.zero, // a GridView adds the status-bar inset as padding otherwise (empty band above it)
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: .86,
      children: [
        for (var i = 0; i < kThemes.length; i++)
          Rise(
            i: i,
            child: _ThemeCell(spec: kThemes[i], dark: dark, on: kThemes[i].id == st.theme, onTap: () => st.update(() => st.theme = kThemes[i].id)),
          ),
      ],
    );
  }
}

class _ThemeCell extends StatelessWidget {
  final ThemeSpec spec;
  final bool dark;
  final bool on;
  final VoidCallback onTap;
  const _ThemeCell({required this.spec, required this.dark, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sl = dark ? spec.darkL : spec.lightL;
    final lift = dark ? 1.0 : -1.0;
    final tint = dark ? .02 : .01;
    final a = Ok.lch(sl, tint, spec.h).toColor();
    final b = Ok.lch(sl + lift * .07, tint * 1.4, spec.h).toColor();
    final accent = Ok.lch(dark ? .805 : .495, spec.c, spec.h).toColor();
    return CardX(
      padding: const EdgeInsets.all(9),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedScale(
              scale: on ? 1.06 : 1,
              duration: const Duration(milliseconds: 460),
              curve: Tk.bouncy,
              child: AnimatedRotation(
                turns: 0,
                duration: const Duration(milliseconds: 460),
                curve: Tk.snappy,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: Tk.fx,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(on ? Tk.rL : Tk.rM),
                      gradient: LinearGradient(begin: const Alignment(-.5, -.87), end: const Alignment(.5, .87), colors: [a, b]),
                      border: Border.all(color: on ? p.primary : p.glassHi, width: on ? 1.8 : 1),
                    ),
                    child: Align(
                      alignment: const Alignment(.64, -.56),
                      child: FractionallySizedBox(
                        widthFactor: .34,
                        heightFactor: .34,
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: accent, boxShadow: [BoxShadow(color: accent, blurRadius: 12, spreadRadius: -1)]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(tr('th_${spec.id}'), style: context.ty(R.labelM, on ? p.primary : p.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Typeface rows, each previewed in its own font.
class FontList extends StatelessWidget {
  const FontList({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final p = context.pal;
    return Column(
      children: [
        for (var i = 0; i < kFonts.length; i++)
          Rise(
            i: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: CardX(
                selected: kFonts[i].id == st.font,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                onTap: () => st.update(() => st.font = kFonts[i].id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(kFonts[i].label, style: TextStyle(fontFamily: 'Geist', fontSize: 11 * st.textScale, color: p.onSurfaceVariant))),
                        if (kFonts[i].id == st.font) AppIcon(Ic.check, size: 15, color: p.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('font_prev'),
                      style: Ty(st.fa, kFonts[i].id, st.textScale)(R.bodyL, p.onSurface).copyWith(height: 1.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
