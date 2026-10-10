import 'package:flutter/material.dart';
import '../core/scope.dart';
import '../core/tokens.dart';
import 'kit/chrome.dart';

/// Push a screen with the design's spring transition: slides/scales/fades in
/// from the reading-end edge; the screen below recedes slightly.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(_SpringRoute<T>(screen));
}

class _SpringRoute<T> extends PageRouteBuilder<T> {
  _SpringRoute(Widget screen)
      : super(
          opaque: false,
          transitionDuration: Tk.spatialSlow,
          reverseTransitionDuration: Tk.spatial,
          pageBuilder: (context, a, b) => _Pushed(child: screen),
          transitionsBuilder: (context, anim, sec, child) {
            final t = Tk.snappy.transform(anim.value);
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final dx = (rtl ? -1 : 1) * 26 * (1 - t);
            return Opacity(
              opacity: Curves.easeOut.transform(anim.value).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(dx, 0), child: Transform.scale(scale: .955 + .045 * t, child: child)),
            );
          },
        );
}

/// Every pushed screen gets its own ambient background (the shell's one is
/// underneath but this keeps the pushed page opaque).
class _Pushed extends StatelessWidget {
  final Widget child;
  const _Pushed({required this.child});
  @override
  Widget build(BuildContext context) => AmbientBg(child: child);
}

/// Replace the whole stack (onboarding → shell).
void replaceAll(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: Tk.spatialSlow,
      pageBuilder: (c, a, b) => AmbientBg(child: screen),
      transitionsBuilder: (c, anim, s, child) {
        final t = Tk.snappy.transform(anim.value);
        return Opacity(opacity: anim.value.clamp(0.0, 1.0), child: Transform.scale(scale: .975 + .025 * t, child: child));
      },
    ),
    (r) => false,
  );
}
