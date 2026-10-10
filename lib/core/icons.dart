import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The icon set, extracted 1:1 from the design's SVG sprite (one 1.7px stroke,
/// round caps/joins). Each value maps to assets/icons/<file>.svg.
enum Ic {
  power('power'),
  shield('shield'),
  shieldOff('shield-off'),
  globe('globe'),
  pulse('pulse'),
  pad('pad'),
  cast('cast'),
  server('server'),
  house('house'),
  chart('chart'),
  sliders('sliders'),
  layers('layers'),
  apps('apps'),
  terminal('terminal'),
  wrench('wrench'),
  history('history'),
  clock('clock'),
  bell('bell'),
  lock('lock'),
  key('key'),
  alert('alert'),
  info('info'),
  help('help'),
  check('check'),
  x('x'),
  plus('plus'),
  minus('minus'),
  chev('chev'),
  back('back'),
  search('search'),
  refresh('refresh'),
  trash('trash'),
  star('star'),
  sort('sort'),
  filter('filter'),
  copy('copy'),
  qr('qr'),
  edit('edit'),
  externalIc('external'),
  down('down'),
  up('up'),
  bolt('bolt'),
  signal('signal'),
  wifi('wifi'),
  batt('batt'),
  lang('lang'),
  palette('palette'),
  type('type'),
  textsize('textsize'),
  sun('sun'),
  moon('moon'),
  monitor('monitor'),
  vibrate('vibrate'),
  headset('headset'),
  plane('plane'),
  update('update'),
  fingerprint('fingerprint'),
  pin('pin'),
  dots('dots');

  final String file;
  const Ic(this.file);
}

/// `AppIcon(Ic.shield, size: 20, color: ...)`. [flip] mirrors direction-bearing
/// icons (back arrow, chevron) so they follow the reading direction: the set
/// is drawn for RTL, so LTR layouts must mirror them.
class AppIcon extends StatelessWidget {
  final Ic icon;
  final double size;
  final Color? color;
  final bool flip;
  const AppIcon(this.icon, {super.key, this.size = 20, this.color, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    Widget w = SvgPicture.asset(
      'assets/icons/${icon.file}.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
    if (flip && Directionality.of(context) == TextDirection.ltr) {
      w = Transform.flip(flipX: true, child: w);
    }
    return w;
  }
}
