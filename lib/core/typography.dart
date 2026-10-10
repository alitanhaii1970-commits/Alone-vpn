import 'package:flutter/painting.dart';
import 'settings.dart';

/// Material 3 type roles (size, weight, line-height, tracking) from the design.
enum R {
  displayL(40, 700, 1.14, -.015, true),
  displayM(32, 700, 1.17, -.012, true),
  displayS(26, 700, 1.21, -.008, true),
  headlineL(23, 650, 1.26, -.005),
  headlineM(20, 650, 1.29, -.003),
  headlineS(18, 600, 1.33, -.002),
  titleL(16, 600, 1.40, 0),
  titleM(14, 600, 1.43, .004),
  titleS(13, 600, 1.46, .005),
  bodyL(14, 400, 1.62, 0),
  bodyM(13, 400, 1.68, 0),
  bodyS(12, 400, 1.70, 0),
  labelL(12, 550, 1.36, .01),
  labelM(11, 550, 1.36, .02),
  labelS(10, 600, 1.34, .045),
  micro(9.5, 600, 1.3, .09);

  final double size;
  final double weight;
  final double lh;
  final double track;
  final bool display;
  const R(this.size, this.weight, this.lh, this.track, [this.display = false]);
}

/// Builds TextStyles for the current language / typeface / size / digits.
/// Persian: line-height x1.11, no tracking, +0.5px (the design's --fa-bump).
class Ty {
  final bool fa;
  final String font;
  final double scale;
  const Ty(this.fa, this.font, this.scale);

  factory Ty.of(AppSettings s) => Ty(s.fa, s.font, s.textScale);

  List<String> get _uiFallback {
    switch (font) {
      case 'geist':
        return const ['Vazirmatn'];
      case 'system':
        return const ['Vazirmatn', 'Geist'];
      default:
        return const ['Geist', 'Vazirmatn'];
    }
  }

  String? get _uiFamily {
    switch (font) {
      case 'naskh':
        return 'NotoNaskhArabic';
      case 'geist':
        return 'Geist';
      case 'system':
        return null;
      default:
        return 'Vazirmatn';
    }
  }

  TextStyle call(R r, [Color? color, bool num = false]) {
    double size = r.size;
    if (r == R.micro) {
      size = fa ? 10 : 9.5;
    } else if (!r.display && fa) {
      size += .5;
    }
    size *= scale;
    final lh = r == R.micro ? r.lh : r.lh * (fa ? 1.11 : 1.0);
    final spacing = fa ? 0.0 : r.track * size;
    final String? family = num ? 'GeistMono' : (r.display ? 'Geist' : _uiFamily);
    final fallback = num ? const ['Vazirmatn'] : (r.display ? const ['Vazirmatn'] : _uiFallback);
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: _nearest(r.weight),
      fontVariations: [FontVariation('wght', r.weight)],
      height: lh,
      letterSpacing: spacing,
      color: color,
      fontFeatures: num ? const [FontFeature.tabularFigures(), FontFeature.slashedZero()] : null,
    );
  }

  static FontWeight _nearest(double w) {
    if (w >= 700) return FontWeight.w700;
    if (w >= 600) return FontWeight.w600;
    if (w >= 500) return FontWeight.w500;
    return FontWeight.w400;
  }
}
