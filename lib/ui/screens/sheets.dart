import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/foreign.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/inputs.dart';
import '../kit/feedback.dart';

/// Add-config sheet: paste share links or subscription URLs, validated on submit.
Future<void> showImport(BuildContext context) {
  final ctrl = TextEditingController();
  var busy = false;
  String? err;
  return showSheet<void>(
    context,
    title: tr('import_t'),
    body: tr('import_b'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Future<void> go() async {
          if (ctrl.text.trim().isEmpty || busy) return;
          set(() {
            busy = true;
            err = null;
          });
          final foreign = classifyForeign(ctrl.text);
          if (foreign == ForeignConfig.openvpn) {
            final problem = ServerStore.I.addOvpn(ctrl.text);
            if (problem != null) {
              set(() {
                busy = false;
                err = tr(problem);
              });
              HapticFeedback.heavyImpact();
              return;
            }
            HapticFeedback.lightImpact();
            Navigator.of(ctx).pop();
            snack(tr('ovpn_added'), tone: 'ok');
            return;
          }
          if (foreign != null) {
            set(() {
              busy = false;
              err = tr('foreign_npv');
            });
            HapticFeedback.heavyImpact();
            return;
          }
          final r = await ServerStore.I.addText(expandBase64Links(ctrl.text));
          if (!ctx.mounted) return;
          if (r.added == 0) {
            set(() {
              busy = false;
              err = r.dup > 0 ? tr('dup_only') : tr('bad_link');
            });
            HapticFeedback.heavyImpact();
            return;
          }
          HapticFeedback.lightImpact();
          Navigator.of(ctx).pop();
          snack(tr('imported', {'n': '${r.added}'}), tone: 'ok');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            AlField(controller: ctrl, hint: 'vless:// · vmess:// · https://…', maxLines: 4, onSubmit: (_) => go()),
            if (err != null) ...[const SizedBox(height: 8), Notice(err!, icon: Ic.alert, tone: Tone.bad)],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Btn(tr('paste'), variant: Bv.tonal, wide: true, onTap: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    final txt = d?.text ?? '';
                    if (txt.trim().isEmpty) return;
                    ctrl.text = txt.trim();
                    set(() => err = null);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Btn(busy ? tr('importing') : tr('import_cta'), icon: Ic.plus, wide: true, onTap: go)),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// Confirmation before a destructive action.
Future<bool> confirm(BuildContext context, {required String title, required String body, required String yes}) async {
  final r = await showSheet<bool>(
    context,
    title: title,
    body: body,
    showClose: false,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(child: Btn(tr('cancel'), variant: Bv.tonal, wide: true, onTap: () => Navigator.of(ctx).pop(false))),
          const SizedBox(width: 8),
          Expanded(child: Btn(yes, variant: Bv.danger, wide: true, onTap: () => Navigator.of(ctx).pop(true))),
        ],
      ),
    ),
  );
  return r ?? false;
}
