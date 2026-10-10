import 'package:flutter/widgets.dart';
import 'palette.dart';
import 'settings.dart';
import 'typography.dart';

/// One inherited scope for palette + settings + type. Anything that reads
/// `context.pal` / `context.ty` / `context.st` repaints on theme, mode,
/// language, typeface or size changes.
class AppScope extends InheritedWidget {
  final Pal pal;
  final AppSettings st;
  final Ty ty;
  const AppScope({super.key, required this.pal, required this.st, required this.ty, required super.child});

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => true;
}

extension AppCtx on BuildContext {
  Pal get pal => AppScope.of(this).pal;
  Ty get ty => AppScope.of(this).ty;
  AppSettings get st => AppScope.of(this).st;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
