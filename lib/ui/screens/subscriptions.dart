import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/typography.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import 'sheets.dart';

/// Subscriptions: every subscription URL the servers were imported from, with one-tap update.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final Set<String> _busy = <String>{};
  bool _all = false;

  String _ago(int ms) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return tr('ago_now');
    if (d.inHours < 1) return tr('ago_m', {'n': loc(d.inMinutes)});
    if (d.inDays < 1) return tr('ago_h', {'n': loc(d.inHours)});
    return tr('ago_d', {'n': loc(d.inDays)});
  }

  Future<void> _update(String url) async {
    if (_busy.contains(url)) return;
    setState(() => _busy.add(url));
    final r = await ServerStore.I.updateSub(url);
    if (!mounted) return;
    setState(() => _busy.remove(url));
    if (r.ok) {
      Hx.ok();
      snack(tr('sub_done', {'a': loc(r.added), 'r': loc(r.removed)}), tone: 'ok');
    } else {
      Hx.fail();
      snack(tr('sub_failed'), tone: 'err');
    }
  }

  Future<void> _updateAll() async {
    if (_all) return;
    setState(() => _all = true);
    snack(tr('sub_updating'), tone: 'info');
    final r = await ServerStore.I.updateAllSubs();
    if (!mounted) return;
    setState(() => _all = false);
    if (r.ok) {
      Hx.ok();
      snack(tr('sub_done', {'a': loc(r.added), 'r': loc(r.removed)}), tone: 'ok');
    } else {
      Hx.fail();
      snack(tr('sub_failed'), tone: 'err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettings.I, ServerStore.I]),
      builder: (context, _) {
        final subs = AppSettings.I.subs;
        return ScreenFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBarRow(
                title: tr('subs'),
                sub: tr('subs_sub'),
                onBack: () => Navigator.of(context).maybePop(),
                actions: [IconBtn(Ic.plus, glass: true, label: tr('add'), onTap: () => showImport(context))],
              ),
              if (subs.isEmpty)
                CardX(child: EmptyState(icon: Ic.refresh, title: tr('sub_empty_t'), body: tr('sub_empty_b'), action: Btn(tr('import_cta'), variant: Bv.tonal, icon: Ic.plus, onTap: () => showImport(context))))
              else ...[
                for (var i = 0; i < subs.length; i++)
                  Rise(
                    i: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CardX(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          children: [
                            ChipIc(Ic.refresh, tone: Tone.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${subs[i]['name'] ?? subs[i]['url']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleM, p.onSurface)),
                                  Text(
                                    '${tr('sub_servers', {'n': loc(((subs[i]['links'] as List?) ?? const []).length)})} · ${_ago((subs[i]['at'] as num?)?.toInt() ?? 0)}',
                                    style: context.ty(R.bodyS, p.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (_busy.contains(subs[i]['url']) || _all)
                              const SizedBox(width: 40, height: 40, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                            else
                              IconBtn(Ic.refresh, label: tr('sub_update'), onTap: () => _update('${subs[i]['url']}')),
                            IconBtn(Ic.trash, label: tr('sub_delete'), onTap: () async {
                              final ok = await confirm(context, title: tr('sub_delete'), body: tr('sub_delete_b'), yes: tr('sub_delete'));
                              if (ok) ServerStore.I.removeSub('${subs[i]['url']}');
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Btn(tr('sub_update_all'), icon: Ic.refresh, wide: true, busy: _all, onTap: _updateAll),
              ],
            ],
          ),
        );
      },
    );
  }
}
