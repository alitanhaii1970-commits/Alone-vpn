import 'package:flutter/painting.dart';
import 'oklch.dart';

/// The six themes: each is just a hue, a chroma and a surface depth per mode —
/// the design derives every Material 3 role from those (see Pal.build).
class ThemeSpec {
  final String id;
  final double h;
  final double c;
  final double darkL;
  final double darkTint;
  final double lightL;
  final double lightTint;
  /// Hue of surfaces, outlines and text when it differs from the accent hue (-1 = same as [h]).
  final double sh;
  /// Hue of the "ok / secure" colour.
  final double okH;
  const ThemeSpec(this.id, this.h, this.c, this.darkL, this.darkTint, this.lightL, this.lightTint, [this.sh = -1, this.okH = 155]);
}

const List<ThemeSpec> kThemes = [
  // saffron accent on lapis night, turquoise for "secure"
  ThemeSpec('obsidian', 76, .16, .14, .045, .977, .008, 268, 178),
  ThemeSpec('aqua', 205, .125, .205, .026, .980, .012),
  ThemeSpec('neon', 322, .185, .125, .028, .984, .014),
  ThemeSpec('midnight', 250, .048, .135, .005, .975, .004),
  ThemeSpec('ember', 48, .145, .162, .028, .982, .014),
  ThemeSpec('matcha', 152, .118, .168, .022, .979, .011),
];

ThemeSpec themeById(String id) => kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

/// Every colour role the design uses, derived from the eight knobs. Do not
/// hand-pick greys here — keep the derivation, exactly as the design says.
class Pal {
  final List<Color> _c;
  final bool dark;
  final double hue;
  const Pal._(this._c, this.dark, this.hue);

  Color get surfaceDim => _c[0];
  Color get surface => _c[1];
  Color get surfaceBright => _c[2];
  Color get containerLowest => _c[3];
  Color get containerLow => _c[4];
  Color get container => _c[5];
  Color get containerHigh => _c[6];
  Color get containerHighest => _c[7];
  Color get onSurface => _c[8];
  Color get onSurfaceVariant => _c[9];
  Color get outline => _c[10];
  Color get outlineVariant => _c[11];
  Color get primary => _c[12];
  Color get onPrimary => _c[13];
  Color get primaryContainer => _c[14];
  Color get onPrimaryContainer => _c[15];
  Color get secondary => _c[16];
  Color get secondaryContainer => _c[17];
  Color get onSecondaryContainer => _c[18];
  Color get tertiary => _c[19];
  Color get tertiaryContainer => _c[20];
  Color get onTertiaryContainer => _c[21];
  Color get ok => _c[22];
  Color get okContainer => _c[23];
  Color get onOkContainer => _c[24];
  Color get warn => _c[25];
  Color get warnContainer => _c[26];
  Color get onWarnContainer => _c[27];
  Color get error => _c[28];
  Color get errorContainer => _c[29];
  Color get onErrorContainer => _c[30];
  Color get inverseSurface => _c[31];
  Color get inverseOnSurface => _c[32];
  Color get scrim => _c[33];
  Color get glassFill => _c[34];
  Color get glassEdge => _c[35];
  Color get glassHi => _c[36];
  Color get shadowKey => _c[37];
  Color get shadowAmb => _c[38];

  /// Glass fill opacity (the design's --glass-a).
  double get glassA => dark ? .92 : .9;

  static Pal lerp(Pal a, Pal b, double t) {
    return Pal._([for (var i = 0; i < a._c.length; i++) Color.lerp(a._c[i], b._c[i], t)!],
        t < .5 ? a.dark : b.dark, a.hue + (b.hue - a.hue) * t);
  }

  static Pal build(ThemeSpec s, bool dark) {
    final lift = dark ? 1.0 : -1.0;
    final sl = dark ? s.darkL : s.lightL;
    final tint = dark ? s.darkTint : s.lightTint;
    final h = s.h;
    final sh = s.sh < 0 ? s.h : s.sh; // surface hue
    final h2 = s.sh < 0 ? s.h + 26 : s.sh; // secondary container hue
    final h3 = s.sh < 0 ? s.h + 64 : s.sh; // tertiary container hue
    final c = s.c;
    final onL = dark ? .965 : .205;
    final onvL = dark ? .80 : .445;
    final olL = dark ? .64 : .575;
    final olvL = dark ? .41 : .845;
    final accL = dark ? .805 : .495;
    final onaccL = dark ? .215 : .995;
    final acccL = dark ? .365 : .905;
    final onacccL = dark ? .925 : .245;
    final stL = dark ? .79 : .505;
    final stcL = dark ? .325 : .915;
    final onstcL = dark ? .94 : .235;
    final glassA = dark ? .92 : .9;
    final hiA = dark ? .14 : .88;

    Ok lch(double l, double ch, double hh) => Ok.lch(l, ch, hh);
    final containerHigh = lch(sl + lift * .058, tint, sh);
    final primary = lch(accL, c, h);
    final outlineVariant = lch(olvL, tint * 1.3, sh);

    final shadowKey = dark
        ? const Color.fromARGB(148, 0, 0, 0)
        : lch(.28, .03, sh).toColor(.18);
    final shadowAmb = dark
        ? const Color.fromARGB(87, 0, 0, 0)
        : lch(.28, .03, sh).toColor(.10);

    final list = <Color>[
      lch(sl - lift * .030, tint, sh).toColor(), // surfaceDim
      lch(sl, tint, sh).toColor(), // surface
      lch(sl + lift * .130, tint, sh).toColor(), // surfaceBright
      lch(sl - lift * .045, tint, sh).toColor(), // containerLowest
      lch(sl + lift * .020, tint, sh).toColor(), // containerLow
      lch(sl + lift * .036, tint, sh).toColor(), // container
      containerHigh.toColor(), // containerHigh
      lch(sl + lift * .085, tint, sh).toColor(), // containerHighest
      lch(onL, tint * .8, sh).toColor(), // onSurface
      lch(onvL, tint * 1.7, sh).toColor(), // onSurfaceVariant
      lch(olL, tint * 1.5, sh).toColor(), // outline
      outlineVariant.toColor(), // outlineVariant
      primary.toColor(), // primary
      lch(onaccL, c * .30, h).toColor(), // onPrimary
      lch(acccL, c * .88, h).toColor(), // primaryContainer
      lch(onacccL, c * .42, h).toColor(), // onPrimaryContainer
      lch(accL - lift * .055, c * .42, h + 26).toColor(), // secondary
      lch(sl + lift * .115, c * .30, h2).toColor(), // secondaryContainer
      lch(onacccL, c * .28, h2).toColor(), // onSecondaryContainer
      lch(accL, c * .82, h + 64).toColor(), // tertiary
      lch(sl + lift * .135, c * .44, h3).toColor(), // tertiaryContainer
      lch(onacccL, c * .34, h3).toColor(), // onTertiaryContainer
      lch(stL, .155, s.okH).toColor(), // ok
      lch(stcL, .085, s.okH).toColor(), // okContainer
      lch(onstcL, .055, s.okH).toColor(), // onOkContainer
      lch(stL, .150, 78).toColor(), // warn
      lch(stcL, .085, 78).toColor(), // warnContainer
      lch(onstcL, .050, 78).toColor(), // onWarnContainer
      lch(stL, .165, 26).toColor(), // error
      lch(stcL, .095, 26).toColor(), // errorContainer
      lch(onstcL, .055, 26).toColor(), // onErrorContainer
      lch(onL, tint * .8, sh).toColor(), // inverseSurface
      lch(sl, tint, sh).toColor(), // inverseOnSurface
      lch(sl * .34, tint, sh).toColor(.62), // scrim
      containerHigh.toColor(glassA), // glassFill
      Ok.mix(primary, .26, outlineVariant).toColor(), // glassEdge
      const Color(0xFFFFFFFF).withAlpha((hiA * 255).round()), // glassHi
      shadowKey,
      shadowAmb,
    ];
    return Pal._(list, dark, h);
  }
}
