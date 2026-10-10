import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';

/// Connection log: tagged lines (INF / OK / WRN / ERR), clear, newest first.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: LogStore.I,
      builder: (context, _) {
        final lines = LogStore.I.lines.reversed.toList();
        return ScreenFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBarRow(title: tr('al_log'), onBack: () => Navigator.of(context).maybePop(), actions: [
                IconBtn(Ic.trash, glass: true, label: tr('clear'), onTap: () => LogStore.I.clear()),
              ]),
              if (lines.isEmpty)
                EmptyState(icon: Ic.terminal, title: tr('log_empty'), body: tr('log_empty_b'))
              else
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: CardX(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(_tag(l.lvl), style: context.ty(R.labelS, _tone(p, l.lvl), true)),
                          ),
                          Expanded(child: Text(l.msg, style: context.ty(R.bodyS, p.onSurface))),
                          Text('${l.t.hour.toString().padLeft(2, '0')}:${l.t.minute.toString().padLeft(2, '0')}:${l.t.second.toString().padLeft(2, '0')}', style: context.ty(R.micro, p.outline, true)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _tag(String l) => l == 'err' ? 'ERR' : l == 'warn' ? 'WRN' : l == 'ok' ? ' OK' : 'INF';
  Color _tone(Pal p, String l) => l == 'err' ? p.error : l == 'warn' ? p.warn : l == 'ok' ? p.ok : p.onSurfaceVariant;
}

/// Help: one card per topic.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('al_help'), onBack: () => Navigator.of(context).maybePop()),
          for (var i = 0; i < kHelp.length; i++)
            Rise(
              i: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: CardX(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChipIc(kHelp[i].icon, tone: toneOf(kHelp[i].tone), sm: true),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('${kHelp[i].k}_t'), style: context.ty(R.titleS, context.pal.onSurface)),
                            const SizedBox(height: 3),
                            Text(tr('${kHelp[i].k}_b'), style: context.ty(R.bodyS, context.pal.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
