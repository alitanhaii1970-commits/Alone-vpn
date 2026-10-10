import 'dart:math' as math;
import 'dart:ui' show Color;

/// A colour in OKLab. The whole palette is derived from these (the design's
/// `oklch()` knobs), so no RGB channel is ever read back from a [Color] —
/// those accessors were renamed across Flutter versions.
class Ok {
  final double l;
  final double a;
  final double b;
  const Ok(this.l, this.a, this.b);

  factory Ok.lch(double l, double c, double hDeg) {
    final h = hDeg * math.pi / 180.0;
    return Ok(l, c * math.cos(h), c * math.sin(h));
  }

  /// color-mix(in oklab, x px%, y) for opaque colours.
  static Ok mix(Ok x, double px, Ok y) =>
      Ok(x.l * px + y.l * (1 - px), x.a * px + y.a * (1 - px), x.b * px + y.b * (1 - px));

  static List<double> _linear(double l, double a, double b) {
    final lp = l + 0.3963377774 * a + 0.2158037573 * b;
    final mp = l - 0.1055613458 * a - 0.0638541728 * b;
    final sp = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = lp * lp * lp;
    final m3 = mp * mp * mp;
    final s3 = sp * sp * sp;
    return [
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    ];
  }

  static double _encode(double v) {
    final x = v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
    if (x <= 0.0031308) return 12.92 * x;
    return 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
  }

  static bool _inGamut(List<double> v) {
    for (final e in v) {
      if (e < -0.0005 || e > 1.0005) return false;
    }
    return true;
  }

  /// OKLab -> sRGB. Out-of-gamut colours are mapped by reducing chroma while
  /// keeping lightness and hue, which is what CSS Color 4 gamut mapping does.
  Color toColor([double alpha = 1.0]) {
    var rgb = _linear(l, a, b);
    if (!_inGamut(rgb)) {
      var lo = 0.0;
      var hi = 1.0;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (_inGamut(_linear(l, a * mid, b * mid))) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      rgb = _linear(l, a * lo, b * lo);
    }
    int ch(double v) => (_encode(v) * 255).round().clamp(0, 255).toInt();
    final al = (alpha * 255).round().clamp(0, 255).toInt();
    return Color.fromARGB(al, ch(rgb[0]), ch(rgb[1]), ch(rgb[2]));
  }
}

/// color-mix(in oklab, c p%, transparent): the same colour at p of its alpha.
Color alpha(Color c, double p) => c.withAlpha((p * 255).round().clamp(0, 255).toInt());
