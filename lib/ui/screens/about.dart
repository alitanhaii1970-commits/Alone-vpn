import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/palette.dart';
import '../../core/scope.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/version.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';

/// About: wordmark, version, what the app is, support handle, libraries.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('about'), onBack: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 4),
          Center(child: ChipIc(Ic.fingerprint, tone: Tone.primary)),
          const SizedBox(height: 12),
          Center(child: Text('ALONE VPN', style: context.ty(R.headlineS, p.onSurface))),
          Center(child: Text('v$kAppVersion beta', style: context.ty(R.labelL, p.outline, true))),
          const SizedBox(height: 16),
          CardX(
            padding: const EdgeInsets.all(14),
            child: Text(tr('about_b'), style: context.ty(R.bodyM, p.onSurfaceVariant)),
          ),
          const SizedBox(height: 9),
          CardX(
            padding: const EdgeInsets.all(12),
            child: Press(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: '@Alones222'));
                snack(trOr('tg_copied', '@Alones222 کپی شد', '@Alones222 copied'), tone: 'ok');
              },
              child: Row(children: [
                const ChipIc(Ic.plane),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('@Alones222', style: context.ty(R.titleS, p.onSurface, true)),
                    Text(tr('tg_sub'), style: context.ty(R.labelM, p.onSurfaceVariant)),
                  ]),
                ),
                AppIcon(Ic.copy, size: 18, color: p.outline),
              ]),
            ),
          ),
          const SizedBox(height: 9),
          CardX(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const ChipIc(Ic.key, tone: Tone.plain),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('about_oss'), style: context.ty(R.titleS, p.onSurface)),
                  Text('Xray-core · sing-box · v2ray_box · Vazirmatn · Geist', style: context.ty(R.labelM, p.onSurfaceVariant, true)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Center(child: Text(tr('made_by'), style: context.ty(R.labelM, p.outline))),
        ],
      ),
    );
  }
}
