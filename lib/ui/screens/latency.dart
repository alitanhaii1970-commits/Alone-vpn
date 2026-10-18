import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import '../kit/inputs.dart';
import '../nav.dart';

/// Latency: TCP vs URL probe mode, test-all, per-server bars.
class LatencyScreen extends StatelessWidget {
  const LatencyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = context.st;
    return ListenableBuilder(
      listenable: ServerStore.I,
      builder: (context, _) {
        final items = ServerStore.I.items;
        return ScreenFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBarRow(title: tr('t_latency'), sub: tr('lat_sub'), onBack: () => Navigator.of(context).maybePop(), actions: [
                IconBtn(Ic.refresh, glass: true, label: tr('test_all'), onTap: () => ServerStore.I.probeAll()),
              ]),
              SectionLabel(tr('probe_mode')),
              Segmented(
                items: [Seg('tcp', 'TCP'), Seg('url', 'URL')],
                value: st.probe,
                onChanged: (v) => st.update(() => st.probe = v),
              ),
              const SizedBox(height: 6),
              Text(st.probe == 'url' ? tr('probe_url_d') : tr('probe_tcp_d'), style: context.ty(R.labelM, p.outline)),
              SectionLabel(tr('results')),
              if (items.isEmpty)
                EmptyState(icon: Ic.pulse, title: tr('empty_t'), body: tr('empty_b'))
              else
                for (var i = 0; i < items.length; i++)
                  Rise(
                    i: i,
                    child: CardX(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      onTap: () => ServerStore.I.probeOne(items[i]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty(R.titleS, p.onSurface))),
                            Text(ServerStore.I.probing.contains(items[i].id) ? '…' : latText(ServerStore.I.lat[items[i].id]),
                                style: context.ty(R.labelM, latTone(p, ServerStore.I.lat[items[i].id]), true)),
                          ]),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (var b = 0; b < 4; b++) ...[
                                if (b > 0) const SizedBox(width: 4),
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: b < latBars(ServerStore.I.lat[items[i].id]) ? latTone(p, ServerStore.I.lat[items[i].id]) : alpha(p.onSurface, .08),
                                      borderRadius: BorderRadius.circular(Tk.rFull),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
}

/// DNS for gaming: toggle, preset list, custom resolver.
class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});
  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  final TextEditingController _c = TextEditingController();
  String? _err;

  bool _valid(String s) {
    final ip = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ip.hasMatch(s)) return false;
    return s.split('.').every((x) => int.parse(x) <= 255);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = context.st;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('t_dns'), onBack: () => Navigator.of(context).maybePop()),
          CardX(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('dns_on'), style: context.ty(R.titleM, p.onSurface)),
                      const SizedBox(height: 3),
                      Text(tr('dns_d'), style: context.ty(R.bodyS, p.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AlSwitch(on: st.dnsOn, onChanged: (v) => st.update(() => st.dnsOn = v)),
              ],
            ),
          ),
          SectionLabel(tr('dns_presets')),
          for (var i = 0; i < kDns.length; i++)
            Rise(
              i: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: CardX(
                selected: st.dnsSel == kDns[i].id,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                onTap: () => st.update(() => st.dnsSel = kDns[i].id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kDns[i].name, style: context.ty(R.titleM, p.onSurface)),
                          Text('${kDns[i].ip} · ${tr(kDns[i].noteKey)}', style: context.ty(R.labelS, p.onSurfaceVariant, true)),
                        ],
                      ),
                    ),
                    AlRadio(on: st.dnsSel == kDns[i].id, onTap: () => st.update(() => st.dnsSel = kDns[i].id)),
                  ],
                ),
              ),
              ),
            ),
          SectionLabel(tr('dns_custom')),
          AlField(controller: _c, hint: '1.1.1.1', keyboard: TextInputType.number, invalid: _err != null, onSubmit: (_) => _add()),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(_err!, style: context.ty(R.labelM, p.error))),
          const SizedBox(height: 8),
          Btn(tr('add'), variant: Bv.tonal, wide: true, icon: Ic.plus, onTap: _add),
          for (final cd in st.customDns)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: CardX(
                selected: st.dnsSel == cd.id,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                onTap: () => st.update(() => st.dnsSel = cd.id),
                child: Row(children: [
                  Expanded(child: Text(cd.ip, style: context.ty(R.titleS, p.onSurface, true))),
                  Press(
                    radius: Tk.rFull,
                    onTap: () => st.update(() {
                      st.customDns.removeWhere((x) => x.id == cd.id);
                      if (st.dnsSel == cd.id) st.dnsSel = 'cf';
                    }),
                    child: Padding(padding: const EdgeInsets.all(6), child: AppIcon(Ic.x, size: 14, color: p.outline)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _add() {
    final v = _c.text.trim();
    final st = AppSettings.I;
    if (!_valid(v)) {
      setState(() => _err = trOr('dns_bad', 'آی‌پی معتبر نیست', 'Not a valid IP address'));
      Hx.fail();
      return;
    }
    st.update(() {
      final id = 'c${v.hashCode.toUnsigned(20)}';
      if (!st.customDns.any((x) => x.ip == v)) st.customDns.add(CustomDns(id, v));
      st.dnsSel = st.customDns.firstWhere((x) => x.ip == v).id;
    });
    _c.clear();
    setState(() => _err = null);
    Hx.ok();
  }
}
