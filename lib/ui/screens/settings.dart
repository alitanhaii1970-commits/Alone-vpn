import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart' as vb;
import '../../core/i18n.dart';
import '../../core/version.dart';
import '../../core/icons.dart';
import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../data/catalog.dart';
import '../../data/stores.dart';
import '../../services/engine.dart';
import '../kit/base.dart';
import '../kit/chrome.dart';
import '../kit/feedback.dart';
import '../kit/inputs.dart';
import '../kit/pickers.dart';
import '../nav.dart';
import 'subscriptions.dart';
import 'latency.dart';
import 'log.dart';
import 'sheets.dart';

/// Settings tab: appearance, language, display, VPN behaviour, data.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) => const _SettingsBody(top: true);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _SettingsBody(top: false);
}

class _SettingsBody extends StatelessWidget {
  final bool top;
  const _SettingsBody({required this.top});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = context.st;
    return ScreenFrame(
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('settings'), onBack: top ? null : () => Navigator.of(context).maybePop()),
          SectionLabel(tr('al_appearance')),
          CardX(padding: const EdgeInsets.all(12), child: Column(children: [
            const ModeSeg(),
            const SizedBox(height: 12),
            const ThemeGrid(),
          ])),
          const SizedBox(height: 10),
          GroupCard(children: [
          RowTile(grouped: true, 
            icon: Ic.type,
            label: tr('font'),
            sub: kFonts.firstWhere((f) => f.id == st.font, orElse: () => kFonts.first).label,
            chev: true,
            onTap: () => showSheet<void>(context, title: tr('font'), builder: (_) => const FontList()),
          ),
          RowTile(grouped: true, 
            icon: Ic.lang,
            tone: Tone.plain,
            label: tr('al_lang'),
            sub: st.fa ? 'فارسی' : 'English',
            trail: Segmented(
              items: [Seg('fa', 'FA'), Seg('en', 'EN')],
              value: st.lang,
              onChanged: (v) => st.update(() => st.lang = v),
            ),
          ),
          ]),
          SectionLabel(tr('al_display')),
          GroupCard(children: [
          RowTile(grouped: true, 
            icon: Ic.textsize,
            label: tr('al_size'),
            sub: '${loc(st.size)}%',
            trail: SizedBox(width: 150, child: AlSlider(
              value: st.size.toDouble(),
              min: 90,
              max: 125,
              onChanged: (v) => st.update(() => st.size = v.round()),
              onEnd: (_) {},
            )),
          ),
          RowTile(grouped: true, 
            icon: Ic.textsize,
            tone: Tone.plain,
            label: tr('al_digits'),
            sub: st.digits == 'fa' ? '۱۲۳' : '123',
            trail: Segmented(
              items: [Seg('latin', '123'), Seg('fa', '۱۲۳')],
              value: st.digits,
              onChanged: (v) => st.update(() => st.digits = v),
            ),
          ),
          RowTile(grouped: true, 
            icon: Ic.batt,
            tone: Tone.ok,
            label: tr('al_saver'),
            sub: tr('al_saver_d'),
            trail: AlSwitch(on: st.saver, onChanged: (v) => st.update(() => st.saver = v)),
          ),
          RowTile(grouped: true, 
            icon: Ic.vibrate,
            tone: Tone.plain,
            label: tr('al_haptics'),
            trail: AlSwitch(on: st.haptics, onChanged: (v) => st.update(() => st.haptics = v)),
          ),
          ]),
          SectionLabel(tr('al_vpn')),
          GroupCard(children: [
          RowTile(grouped: true, 
            icon: Ic.shieldOff,
            tone: Tone.warn,
            label: tr('al_kill'),
            sub: tr('al_kill_d'),
            trail: AlSwitch(on: st.killswitch, onChanged: (v) => st.update(() => st.killswitch = v)),
          ),
          RowTile(grouped: true, 
            icon: Ic.apps,
            label: tr('al_split'),
            sub: st.splitMode == 'off' ? tr('off') : '${st.splitMode} · ${loc(st.splitApps.length)}',
            chev: true,
            onTap: () => pushScreen<void>(context, const SplitScreen()),
          ),
          RowTile(grouped: true, 
            icon: Ic.layers,
            label: tr('al_routing'),
            chev: true,
            onTap: () => pushScreen<void>(context, const RoutingScreen()),
          ),
          RowTile(grouped: true, 
            icon: Ic.pulse,
            label: tr('al_probe'),
            sub: st.probe == 'url' ? 'URL' : 'TCP',
            chev: true,
            onTap: () => pushScreen<void>(context, const LatencyScreen()),
          ),
          ]),
          SectionLabel(tr('al_data')),
          GroupCard(children: [
          RowTile(grouped: true, icon: Ic.refresh, tone: Tone.primary, label: tr('subs'), sub: tr('subs_sub'), chev: true, onTap: () => pushScreen<void>(context, const SubscriptionsScreen())),
          RowTile(grouped: true, icon: Ic.terminal, tone: Tone.plain, label: tr('al_log'), chev: true, onTap: () => pushScreen<void>(context, const LogScreen())),
          RowTile(grouped: true, icon: Ic.trash, tone: Tone.bad, label: tr('al_clear_servers'), onTap: () async {
            final ok = await confirm(context, title: tr('al_clear_servers'), body: tr('al_clear_servers_b'), yes: tr('al_clear_servers'));
            if (!ok) return;
            for (final s in [...ServerStore.I.items]) {
              ServerStore.I.remove(s.id);
            }
            Hx.ok();
          }),
          RowTile(grouped: true, 
            icon: Ic.info,
            tone: Tone.primary,
            label: tr('about'),
            sub: 'ALONE VPN · v$kAppVersion beta',
            chev: true,
            onTap: () => showSheet<void>(context, title: 'ALONE VPN', body: tr('about_b'), builder: (_) => const SizedBox.shrink()),
          ),
          ]),
        ],
      ),
    );
  }
}

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final TextEditingController _search = TextEditingController();
  late Future<List<vb.AppInfo>> _appsFuture;
  bool _showSystemApps = false;

  @override
  void initState() {
    super.initState();
    _appsFuture = _loadApps();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<vb.AppInfo>> _loadApps() async {
    final apps = await Engine.I.installedApps();
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  void _reloadApps() {
    setState(() => _appsFuture = _loadApps());
  }

  void _selectApp(vb.AppInfo app, bool selected) {
    final st = AppSettings.I;
    st.update(() {
      if (selected) {
        st.splitApps.add(app.packageName);
      } else {
        st.splitApps.remove(app.packageName);
      }
    });
    Hx.tap();
  }

  void _clearSelection() {
    AppSettings.I.update(() => AppSettings.I.splitApps.clear());
    Hx.tap();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final p = context.pal;
    final query = _search.text.trim().toLowerCase();
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('al_split'), onBack: () => Navigator.of(context).maybePop()),
          Segmented(
            items: [Seg('off', tr('off')), Seg('include', tr('split_inc')), Seg('exclude', tr('split_exc'))],
            value: st.splitMode,
            onChanged: (v) => st.update(() => st.splitMode = v),
          ),
          const SizedBox(height: 8),
          Notice(tr('split_note'), icon: Ic.info),
          const SizedBox(height: 8),
          Notice(tr('split_apply_next'), icon: Ic.info, tone: Tone.plain),
          if (st.splitMode == 'include' && st.splitApps.isEmpty) ...[
            const SizedBox(height: 8),
            Notice(tr('split_empty_include'), icon: Ic.alert, tone: Tone.warn),
          ],
          const SizedBox(height: 8),
          SectionLabel(tr('apps')),
          if (!Engine.real)
            Notice(tr('split_android_only'), icon: Ic.apps, tone: Tone.warn)
          else ...[
            AlField(
              controller: _search,
              hint: tr('split_search'),
              prefix: AppIcon(Ic.search, size: 18, color: p.onSurfaceVariant),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('split_selected_count', {'selected': loc(st.splitApps.length)}),
                    style: context.ty(R.bodyS, p.onSurfaceVariant),
                  ),
                ),
                FChip(
                  tr('show_system_apps'),
                  icon: Ic.layers,
                  on: _showSystemApps,
                  onTap: () => setState(() => _showSystemApps = !_showSystemApps),
                ),
                if (st.splitApps.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  IconBtn(Ic.trash, glass: true, label: tr('clear_selection'), onTap: _clearSelection),
                ],
              ],
            ),
            FutureBuilder<List<vb.AppInfo>>(
              future: _appsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator(color: p.primary)),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Notice(tr('load_apps_error'), icon: Ic.alert, tone: Tone.bad),
                      const SizedBox(height: 8),
                      Btn(tr('retry'), icon: Ic.refresh, variant: Bv.tonal, onTap: _reloadApps),
                    ],
                  );
                }
                final allApps = snapshot.data ?? const <vb.AppInfo>[];
                if (allApps.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Notice(tr('load_apps_empty'), icon: Ic.apps, tone: Tone.warn),
                      const SizedBox(height: 8),
                      Btn(tr('retry'), icon: Ic.refresh, variant: Bv.tonal, onTap: _reloadApps),
                    ],
                  );
                }
                final visible = allApps.where((app) {
                  if (!_showSystemApps && app.isSystemApp) return false;
                  if (query.isEmpty) return true;
                  return app.name.toLowerCase().contains(query) || app.packageName.toLowerCase().contains(query);
                }).toList(growable: false);
                if (visible.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: EmptyState(
                      icon: Ic.search,
                      title: tr('split_no_match'),
                      body: tr('split_no_match_b'),
                      action: Btn(tr('clear'), variant: Bv.tonal, onTap: () {
                        _search.clear();
                        setState(() {});
                      }),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      RowTile(
                        key: ValueKey(visible[i].packageName),
                        icon: visible[i].isSystemApp ? Ic.layers : Ic.apps,
                        tone: visible[i].isSystemApp ? Tone.plain : Tone.primary,
                        label: visible[i].name,
                        sub: visible[i].packageName,
                        compact: true,
                        trail: AlCheck(
                          on: st.splitApps.contains(visible[i].packageName),
                          onChanged: (value) => _selectApp(visible[i], value),
                        ),
                        onTap: () => _selectApp(visible[i], !st.splitApps.contains(visible[i].packageName)),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class RoutingScreen extends StatelessWidget {
  const RoutingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.st;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBarRow(title: tr('al_routing'), onBack: () => Navigator.of(context).maybePop()),
          for (var i = 0; i < kRules.length; i++)
            Rise(
              i: i,
              child: RowTile(
                icon: Ic.layers,
                label: tr(kRules[i].key),
                sub: tr('act_${kRules[i].act}'),
                trail: AlCheck(
                  on: st.rules[kRules[i].id] ?? kRules[i].on,
                  onChanged: (v) => st.update(() => st.rules[kRules[i].id] = v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
