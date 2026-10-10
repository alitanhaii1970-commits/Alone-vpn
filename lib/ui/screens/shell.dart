import 'package:flutter/material.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../data/stores.dart';
import '../kit/chrome.dart';
import '../shell_state.dart';
import 'home.dart';
import 'settings.dart';
import 'usage.dart';
import 'servers.dart';

/// Top-level frame: four tabs (home / servers / usage / settings) under a
/// floating glass nav bar. Tabs are kept alive; switching only fades/scales.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    ShellState.onTopLevel.value = true;
    ServerStore.I.load();
  }

  @override
  void dispose() {
    ShellState.onTopLevel.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AmbientBg(
      child: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _i,
              children: const [HomeTab(), ServersTab(), UsageTab(), SettingsTab()],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: NavBar(index: _i, onSelect: (i) => setState(() => _i = i)),
          ),
        ],
      ),
    );
  }
}
