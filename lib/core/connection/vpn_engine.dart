import 'package:flutter/foundation.dart';
import 'link_state.dart';

enum EngineKind { manual, smart }

/// Thrown by an engine whose binaries are not part of this build.
class EngineNotInstalled implements Exception {
  const EngineNotInstalled(this.engine);
  final String engine;
  @override
  String toString() => 'EngineNotInstalled($engine)';
}

/// A tunnel engine. [status] must always reflect what the engine really reports.
abstract class VpnEngine implements Listenable {
  EngineKind get kind;
  String get label;
  bool get installed;
  EngineStatus get status;

  /// Completes when the attempt has finished (connected, failed or cancelled).
  Future<void> start();

  /// Completes when the engine is down (or the attempt to stop it has ended).
  Future<void> stop();

  /// Aborts an attempt that is still connecting.
  void cancel();
}
