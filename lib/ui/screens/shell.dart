import '../../core/i18n.dart';
import 'package:flutter/material.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../data/stores.dart';
import '../../services/incoming.dart';
import 'sheets.dart';
import '../kit/chrome.dart';
import '../shell_state.dart';
import 'home.dart';
import 'settings.dart';
import 'usage.dart';
import 'servers.dart';

/// Top-level frame: four tabs (home / servers / usage / settings) under a
/// floating glass nav bar. Tabs are kept alive; switching only fades/scales.
const bool _kTabFade = false;

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _i = 0;
  // short fade + rise whenever the tab changes (the IndexedStack itself switches instantly)
  late final AnimationController _swap = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  void _select(int i) {
    if (i == _i) return;
    setState(() => _i = i);
    _swap.forward(from: 0);
  }
  static const List<Widget> _tabs = [HomeTab(), ServersTab(), UsageTab(), SettingsTab()];

  @override
  void initState() {
    super.initState();
    // Never notify listeners while the tree is being built: the snack host in main.dart listens to
    // this notifier and is a sibling of the Navigator, so changing it synchronously here is a
    // "setState() called during build" error (it left parts of the Home screen half laid out).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShellState.onTopLevel.value = true;
      ServerStore.I.load();
      IncomingService.start();
      Conn.I.askInstallOvpn = () {
        if (!mounted) return Future<bool>.value(false);
        return confirm(context, title: tr('ovpn_missing_t'), body: tr('ovpn_missing_b'), yes: tr('ovpn_install'));
      };
    });
  }

  @override
  void dispose() {
    _swap.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShellState.onTopLevel.value = false;
      ShellState.homeVisible.value = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final onHome = _i == 0 && (ModalRoute.of(context)?.isCurrent ?? true);
    if (ShellState.homeVisible.value != onHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ShellState.homeVisible.value = onHome);
    }
    return AmbientBg(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _swap,
              child: IndexedStack(
                index: _i,
                children: [
                  for (var k = 0; k < _tabs.length; k++) TickerMode(enabled: _i == k, child: _tabs[k]),
                ],
              ),
              builder: (context, child) {
                // Off: the whole-screen Opacity layer coincided with the emulator's GPU/adb hang after every
                // tab switch (screenshots failed from the first tab change on). Re-enable only when proven safe.
                if (!_kTabFade) return child!;
                final v = Curves.easeOutCubic.transform(_swap.value);
                return Opacity(opacity: .25 + .75 * v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child));
              },
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: NavBar(index: _i, onSelect: _select),
          ),
        ],
      ),
    );
  }
}
