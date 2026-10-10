import 'package:flutter/animation.dart';

/// Design tokens, 1:1 from the design's :root block.
/// The spring curves are the design's own sampled `linear()` tables, so the
/// motion matches exactly rather than approximately.
class SampledCurve extends Curve {
  final List<double> xs;
  final List<double> ys;
  const SampledCurve(this.xs, this.ys);

  @override
  double transformInternal(double t) {
    int i = 1;
    while (i < xs.length - 1 && xs[i] < t) {
      i++;
    }
    final x0 = xs[i - 1];
    final x1 = xs[i];
    final k = x1 == x0 ? 1.0 : (t - x0) / (x1 - x0);
    return ys[i - 1] + (ys[i] - ys[i - 1]) * k;
  }
}

class Tk {
  Tk._();
  // spacing (8dp grid, 4dp half-step)
  static const double sp1 = 4, sp2 = 8, sp3 = 12, sp4 = 16, sp5 = 20, sp6 = 24, sp7 = 32, sp8 = 40;
  // shape
  static const double rXs = 6, rS = 10, rM = 14, rL = 20, rXl = 28, rFull = 999, rDevice = 42;
  // blur
  static const double blurGlass = 20, blurScrim = 6;
  // durations
  static const Duration spatialFast = Duration(milliseconds: 200);
  static const Duration spatial = Duration(milliseconds: 380);
  static const Duration spatialSlow = Duration(milliseconds: 620);
  static const Duration fxFast = Duration(milliseconds: 130);
  static const Duration fx = Duration(milliseconds: 220);
  static const Duration fxSlow = Duration(milliseconds: 380);
  // easing
  static const Curve standard = Cubic(.2, 0, 0, 1);
  static const Curve decelerate = Cubic(0, 0, 0, 1);
  static const Curve accelerate = Cubic(.3, 0, 1, 1);
  static const Curve emphasized = Cubic(.22, 1, .24, 1);
  static const Curve snappy = SampledCurve(
    [0.0, 0.01, 0.02, 0.04, 0.06, 0.084, 0.11, 0.13699999999999998, 0.166, 0.196, 0.228, 0.262, 0.299, 0.34, 0.386, 0.44, 0.506, 0.59, 0.72, 1.0],
    [0.0, 0.006, 0.026, 0.099, 0.213, 0.355, 0.51, 0.66, 0.79, 0.889, 0.958, 1.001, 1.024, 1.031, 1.026, 1.014, 1.002, 0.996, 0.998, 1.0],
  );
  static const Curve bouncy = SampledCurve(
    [0.0, 0.01, 0.024, 0.05, 0.078, 0.10800000000000001, 0.14, 0.172, 0.204, 0.23800000000000002, 0.27399999999999997, 0.314, 0.358, 0.408, 0.466, 0.536, 0.62, 0.72, 0.84, 1.0],
    [0.0, 0.008, 0.034, 0.128, 0.276, 0.455, 0.636, 0.79, 0.905, 0.98, 1.03, 1.06, 1.068, 1.056, 1.03, 1.001, 0.978, 0.974, 0.99, 1.0],
  );
  static const Curve slow = SampledCurve(
    [0.0, 0.016, 0.036000000000000004, 0.07, 0.106, 0.14400000000000002, 0.184, 0.22399999999999998, 0.264, 0.306, 0.348, 0.392, 0.43799999999999994, 0.488, 0.544, 0.61, 0.7, 1.0],
    [0.0, 0.004, 0.02, 0.076, 0.166, 0.284, 0.418, 0.553, 0.677, 0.783, 0.866, 0.926, 0.966, 0.99, 1.002, 1.006, 1.004, 1.0],
  );
  static const Curve anticipate = SampledCurve(
    [0.0, 0.06, 0.11, 0.15, 0.2, 0.256, 0.316, 0.38, 0.446, 0.51, 0.57, 0.634, 0.7, 0.78, 0.88, 1.0],
    [0.0, -0.018, -0.026, -0.012, 0.04, 0.147, 0.31, 0.51, 0.706, 0.859, 0.955, 1.006, 1.021, 1.014, 1.002, 1.0],
  );
}
