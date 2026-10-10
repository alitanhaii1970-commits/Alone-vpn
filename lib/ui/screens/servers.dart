import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import '../nav.dart';
import 'home.dart';
import 'sheets.dart';

/// Servers tab (top-level): list with the active rail, latency per row, test-all, pull-to-refresh.
class ServersTab extends StatelessWidget {
  const ServersTab({super.key});
  @override
  Widget build(BuildContext context) => const _ServerList(top: true);
}

/// Servers as a pushed screen (from the active-server card or "see all").
class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});
  @override
  Widget build(BuildContext context) => const _ServerList(top: false);
}

class _ServerList extends StatelessWidget {
  final bool top;
  const _ServerList({required this.top});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: ServerStore.I,
      builder: (context, _) {
        final items = ServerStore.I.items;
        final fast = ServerStore.I.fastest();
        return ScreenFrame(
          top: top,
          onRefresh: () => ServerStore.I.probeAll(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBarRow(
                title: tr('servers'),
                sub: items.isEmpty ? null : '${loc(items.length)} · ${tr('fastest')}: ${fast?.title ?? '—'}',
                onBack: top ? null : () => Navigator.of(context).maybePop(),
                actions: [
                  IconBtn(Ic.refresh, glass: true, label: tr('test_all'), onTap: () => ServerStore.I.probeAll()),
                  const SizedBox(width: 6),
                  IconBtn(Ic.plus, glass: true, label: tr('add'), onTap: () => showImport(context)),
                ],
              ),
              if (items.isEmpty)
                Rise(
                  i: 0,
                  child: CardX(child: EmptyState(icon: Ic.server, title: tr('empty_t'), body: tr('empty_b'), action: Btn(tr('import_cta'), variant: Bv.tonal, icon: Ic.plus, onTap: () => showImport(context)))),
                )
              else
                for (var i = 0; i < items.length; i++)
                  Rise(i: i, child: ServerRow(server: items[i])),
              if (ServerStore.I.sweeping)
                Padding(padding: const EdgeInsets.only(top: 8), child: Bar(value: _progress(), color: p.primary)),
            ],
          ),
        );
      },
    );
  }

  double _progress() {
    final n = ServerStore.I.items.length;
    if (n == 0) return 0;
    final done = ServerStore.I.items.where((s) => ServerStore.I.lat.containsKey(s.id)).length;
    return done / n;
  }
}
