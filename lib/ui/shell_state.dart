import 'package:flutter/foundation.dart';

/// Shared flags the app root needs from the shell.
class ShellState {
  ShellState._();

  /// True while a top-level tab (with the nav bar) is on screen — lifts the snackbar.
  static final ValueNotifier<bool> onTopLevel = ValueNotifier<bool>(false);
}
