import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../services/engine.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/pickers.dart';
import '../nav.dart';
import 'shell.dart';

/// Glass call-to-action button used on the full-bleed screens.
class GlassBtn extends StatelessWidget {
  final String label;
  final Ic? icon;
  final VoidCallback onTap;
  const GlassBtn(this.label, {super.key, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Press(
      radius: Tk.rFull,
      onTap: onTap,
      child: Glass(
        radius: Tk.rFull,
        shadows: elev(p, 2),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[AppIcon(icon!, size: 18, color: p.onSurface), const SizedBox(width: 8)],
              Text(label, style: context.ty(R.titleM, p.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── splash ─────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _mark = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  late final AnimationController _load = AnimationController(vsync: this, duration: const Duration(milliseconds: 1750))..repeat();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1700), _next);
  }

  void _next() {
    if (!mounted) return;
    final st = AppSettings.I;
    if (st.onboarded) {
      replaceAll(context, const AppShell());
    } else {
      replaceAll(context, const LanguageScreen());
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _mark.dispose();
    _sweep.dispose();
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AmbientBg(
      child: ScreenFrame(
        scroll: false,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _mark,
                    builder: (context, child) {
                      final t = Tk.bouncy.transform(_mark.value);
                      return Opacity(
                        opacity: Curves.easeOut.transform(_mark.value).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - t)),
                          child: Transform.rotate(angle: -.19 * (1 - t), child: Transform.scale(scale: .55 + .45 * t, child: child)),
                        ),
                      );
                    },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tk.rXl),
                        gradient: LinearGradient(
                          begin: const Alignment(-.5, -.87),
                          end: const Alignment(.5, .87),
                          colors: [alpha(p.primary, .62), alpha(p.tertiary, .24)],
                        ),
                        boxShadow: [BoxShadow(color: alpha(p.primary, .72), blurRadius: 44, offset: const Offset(0, 20), spreadRadius: -18)],
                      ),
                      child: Center(child: AppIcon(Ic.fingerprint, size: 42, color: p.onSurface)),
                    ),
                  ),
                  const SizedBox(height: Tk.sp3),
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) => ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => LinearGradient(
                        begin: Alignment(-1 + 4 * _sweep.value, 0),
                        end: Alignment(1 + 4 * _sweep.value, 0),
                        tileMode: TileMode.mirror,
                        colors: [p.onSurface, p.primary, p.onSurface],
                        stops: const [0, .42, .74],
                      ).createShader(r),
                      child: Text('ALONE VPN', style: context.ty(R.displayM, p.onSurface).copyWith(letterSpacing: -.96, height: 1)),
                    ),
                  ),
                  const SizedBox(height: Tk.sp3),
                  Text('v1.2.0 · beta', style: context.ty(R.labelL, p.onSurfaceVariant, true)),
                  const SizedBox(height: 22),
                  Container(
                    width: 112,
                    height: 3,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: alpha(p.onSurface, .10), borderRadius: BorderRadius.circular(Tk.rFull)),
                    child: AnimatedBuilder(
                      animation: _load,
                      builder: (context, _) {
                        final t = Tk.standard.transform(_load.value);
                        return Align(
                          alignment: Alignment(-1.6 + 3.2 * t, 0),
                          child: FractionallySizedBox(
                            widthFactor: .36,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: p.primary,
                                borderRadius: BorderRadius.circular(Tk.rFull),
                                boxShadow: [BoxShadow(color: alpha(p.primary, .8), blurRadius: 10, spreadRadius: -1)],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Text(tr('splash_note'), textAlign: TextAlign.center, style: context.ty(R.labelM, p.outline)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── language ─────────────────────────
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  void _pick(BuildContext context, String lang) {
    final st = AppSettings.I;
    // First run is done the moment a language is picked. The rest of onboarding is optional
    // (permissions are asked again when needed), so quitting half-way must never bring the
    // language screen back on the next launch.
    st.update(() {
      st.lang = lang;
      st.onboarded = true;
    });
    if (Platform.isAndroid) {
      pushScreen<void>(context, const OnbNotif());
    } else {
      // notification + VpnService consent are Android concepts: nothing to ask on desktop
      pushScreen<void>(context, const OnbLook());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget lang(int i, String name, String code, String id) => Rise(
          i: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Tk.sp2),
            child: Press(
              radius: Tk.rFull,
              onTap: () => _pick(context, id),
              child: Glass(
                radius: Tk.rFull,
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const ChipIc(Ic.lang, tone: Tone.plain, round: true),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name, style: context.ty(R.titleL, p.onSurface))),
                        Text(code, style: context.ty(R.labelM, p.outline, true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return AmbientBg(
      child: ScreenFrame(
        scroll: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Choose your language', textAlign: TextAlign.center, style: context.ty(R.headlineM, p.onSurface)),
            const SizedBox(height: Tk.sp2),
            Padding(
              padding: const EdgeInsets.only(bottom: Tk.sp5),
              child: Text('زبان خود را انتخاب کنید', textAlign: TextAlign.center, style: context.ty(R.bodyL, p.onSurfaceVariant)),
            ),
            lang(0, 'فارسی', 'FA', 'fa'),
            lang(1, 'English', 'EN', 'en'),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── onboarding ─────────────────────────
class _Dots extends StatelessWidget {
  final int on;
  const _Dots(this.on);
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 460),
              curve: Tk.bouncy,
              width: i == on ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == on ? p.primary : p.outlineVariant,
                borderRadius: BorderRadius.circular(Tk.rFull),
                boxShadow: i == on ? [BoxShadow(color: alpha(p.primary, .76), blurRadius: 10, spreadRadius: -1)] : const [],
              ),
            ),
          ),
      ],
    );
  }
}

class _Hero extends StatefulWidget {
  final Ic icon;
  final Tone tone;
  const _Hero(this.icon, this.tone);
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !AppSettings.I.saver) _float.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = toneColor(p, widget.tone);
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _float]),
        builder: (context, child) {
          final t = Tk.bouncy.transform(_in.value);
          final f = Curves.easeInOut.transform(_float.value);
          return Opacity(
            opacity: Curves.easeOut.transform(_in.value).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - t) - 6 * f),
              child: Transform.rotate(angle: -.19 * (1 - t) + .035 * (f - .5), child: Transform.scale(scale: .55 + .45 * t, child: child)),
            ),
          );
        },
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: alpha(c, .15),
            borderRadius: BorderRadius.circular(Tk.rXl),
            border: Border.all(color: alpha(c, .22)),
          ),
          child: Center(child: AppIcon(widget.icon, size: 38, color: c)),
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  final int step;
  final Ic icon;
  final Tone tone;
  final String title;
  final String body;
  final String note;
  final String? result;
  final String cta;
  final Ic ctaIcon;
  final VoidCallback onAct;
  final VoidCallback onSkip;
  const _OnbPage({
    required this.step,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.note,
    required this.result,
    required this.cta,
    required this.ctaIcon,
    required this.onAct,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AmbientBg(
      child: ScreenFrame(
        scroll: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Btn(tr('skip_step'), variant: Bv.text, onTap: onSkip),
                _Dots(step),
              ],
            ),
            const SizedBox(height: Tk.sp5),
            _Hero(icon, tone),
            const SizedBox(height: Tk.sp4),
            Text(title, textAlign: TextAlign.center, style: context.ty(R.headlineM, p.onSurface)),
            const SizedBox(height: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(body, textAlign: TextAlign.center, style: context.ty(R.bodyL, p.onSurfaceVariant)),
            ),
            AnimatedSwitcher(
              duration: Tk.spatial,
              switchInCurve: Tk.bouncy,
              child: result == null
                  ? const SizedBox(key: ValueKey('r0'), height: 12)
                  : Padding(
                      key: const ValueKey('r1'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [AppIcon(Ic.check, size: 18, color: p.ok), const SizedBox(width: 7), Text(result!, style: context.ty(R.bodyM, p.ok))],
                      ),
                    ),
            ),
            const SizedBox(height: 11),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Text(note, textAlign: TextAlign.center, style: context.ty(R.labelM, p.outline)),
            ),
            const Spacer(),
            GlassBtn(cta, icon: ctaIcon, onTap: onAct),
          ],
        ),
      ),
    );
  }
}

class OnbNotif extends StatefulWidget {
  const OnbNotif({super.key});
  @override
  State<OnbNotif> createState() => _OnbNotifState();
}

class _OnbNotifState extends State<OnbNotif> {
  String? _result;

  Future<void> _ask() async {
    var ok = true;
    try {
      final s = await Permission.notification.request().timeout(const Duration(seconds: 40));
      ok = s.isGranted || s.isLimited || s.isProvisional;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _result = ok ? tr('notif_ok') : trOr('notif_no', 'می‌تونی بعداً از تنظیمات گوشی روشنش کنی', 'You can turn it on later in system settings'));
    Hx.ok();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) pushScreen<void>(context, const OnbVpn());
  }

  @override
  Widget build(BuildContext context) => _OnbPage(
        step: 0,
        icon: Ic.bell,
        tone: Tone.warn,
        title: tr('notif_t'),
        body: tr('notif_b'),
        note: tr('notif_n'),
        result: _result,
        cta: tr('notif_cta'),
        ctaIcon: Ic.bell,
        onAct: _ask,
        onSkip: () => pushScreen<void>(context, const OnbVpn()),
      );
}

class OnbVpn extends StatefulWidget {
  const OnbVpn({super.key});
  @override
  State<OnbVpn> createState() => _OnbVpnState();
}

class _OnbVpnState extends State<OnbVpn> {
  String? _result;

  Future<void> _ask() async {
    // Do not request VpnService permission during onboarding. The native
    // plugin starts the VPN service as part of that request, so requesting it
    // before a server config exists can launch an empty service. The first
    // actual connection will show Android's official consent dialog safely.
    final ok = await Engine.I.hasPermission();
    if (!mounted) return;
    setState(() => _result = ok ? tr('perm_ok') : tr('perm_deferred'));
    if (ok) Hx.ok();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) pushScreen<void>(context, const OnbLook());
  }

  @override
  Widget build(BuildContext context) => _OnbPage(
        step: 1,
        icon: Ic.shield,
        tone: Tone.ok,
        title: tr('perm_t'),
        body: tr('perm_b'),
        note: tr('perm_n'),
        result: _result,
        cta: tr('perm_cta'),
        ctaIcon: Ic.lock,
        onAct: _ask,
        onSkip: () => pushScreen<void>(context, const OnbLook()),
      );
}

class OnbLook extends StatelessWidget {
  const OnbLook({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AmbientBg(
      child: ScreenFrame(
        scroll: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBtn(Ic.back, flip: true, onTap: () => Navigator.of(context).maybePop()),
                if (Platform.isAndroid) const _Dots(2),
              ],
            ),
            const SizedBox(height: Tk.sp4),
            Text(tr('look_t'), style: context.ty(R.headlineM, p.onSurface)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: Tk.sp4),
              child: Text(tr('look_b'), style: context.ty(R.bodyM, p.onSurfaceVariant)),
            ),
            const Padding(padding: EdgeInsets.only(bottom: Tk.sp4), child: ModeSeg()),
            const ThemeGrid(),
            const SizedBox(height: Tk.sp4),
            GlassBtn(tr('look_cta'), icon: Ic.check, onTap: () {
              final st = AppSettings.I;
              st.update(() => st.onboarded = true);
              replaceAll(context, const AppShell());
            }),
          ],
        ),
      ),
    );
  }
}
