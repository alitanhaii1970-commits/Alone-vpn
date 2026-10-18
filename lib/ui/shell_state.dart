import 'package:flutter/foundation.dart';

/// Shared flags the app root needs from the shell.
class ShellState {
  ShellState._();

  /// True while a top-level tab (with the nav bar) is on screen — lifts the snackbar.
  static final ValueNotifier<bool> onTopLevel = ValueNotifier<bool>(false);

  /// True while the Home tab is the visible screen (no pushed screen on top). The Home dial already
  /// shows the connection state, so the floating status pill is hidden there.
  static final ValueNotifier<bool> homeVisible = ValueNotifier<bool>(false);
}
