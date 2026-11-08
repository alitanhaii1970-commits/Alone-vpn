// world_map.dart
//
// The app's background: a dot-matrix world map with relay hubs and the routes between them.
// It is drawn once (the RepaintBoundary caches it) and only re-tinted when the connection state
// changes: neutral while idle, saffron while connecting, turquoise when secure, plus a route from
// the connect dial to the hub nearest the server's country.
//
// Land is Natural Earth 110m (public domain) reduced to 3-degree cells.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/oklch.dart';
import '../../core/scope.dart';
import '../../data/stores.dart';

/// Where the connect dial really is on screen (global coordinates). The dial publishes it and the
/// backdrop reads it, so the map always sits behind the dial whatever the phone or the text size.
class DialAnchor {
  DialAnchor._();
  static final ValueNotifier<Offset?> center = ValueNotifier<Offset?>(null);
}

const double _sp = 4.4; // dp between two dots
const int _cols = 120;
const int _rows = 46;
const double _mapW = _cols * _sp;
const double _mapH = _rows * _sp;
const double _lon0 = 22; // the longitude that sits under the dial
const double _dialAt = .80; // how far down the map the dial sits

/// Land mask: 120 columns (longitude -180..180) by 46 rows (latitude 80..-58), 3 degrees per cell.
const List<String> _land = [
  '............................#######.##################..........####........................#.#.........................',
  '.....................###..#.#####.......#############..........................#.........#########........#.............',
  '..................#######.###.#####......############........................##....#..#################...####..........',
  '.....#################################...########################..###...#.##.#...###############################.......',
  '..###############################################################.......###.............................................',
  '.....#########################.##...##.....###.......#........##########################################################',
  '.....########################.....###.......##................####.#############################################.####...',
  '.......##......###############....#####...................#....###.########################################.....##......',
  '................#################.#######................###...###########################################......##......',
  '.................########################.................##################################################............',
  '..................####################..##.................#################################################............',
  '...................####################....................###########.#####.#############################..............',
  '..................###################....................####..##.####...###.###########################...#............',
  '...................################......................###.....#.#.########.######################.##...#.............',
  '...................################.......................######.....###############################..#..##.............',
  '....................##############.......................#######........############################...##...............',
  '.....................############........................############################################...................',
  '......................######....#.......................############################################....................',
  '........................####...........................########################...##################....................',
  '.........................###..#...#...................##################.#######...###############......................',
  '.........................######.....#.................###################.#####.....####...#####........................',
  '.............................###......................###################.###........##.....####....#...................',
  '...............................#......................#####################..........##......####.......................',
  '................................#.######...............######################........##........#.....#..................',
  '..................................#######...............#####################................#.......#..................',
  '..................................#########....................#############................###...#.....................',
  '.................................###########...................############..................##.###.....................',
  '.................................#############.................###########....................#..##.#...###.............',
  '.................................###############................#########......................#..........###...........',
  '..................................##############................#########........................#........####..........',
  '..................................##############................##########..............................#...............',
  '...................................############.................##########..#.........................###..#............',
  '....................................###########.................#########.###.......................#########...........',
  '....................................###########.................########...#.......................###########..........',
  '....................................#########....................#######..##......................#############.........',
  '....................................########.....................######...........................#############.........',
  '....................................########.....................######...........................#############.........',
  '....................................#######.......................####............................####..#######.........',
  '....................................#####.................................................................####..........',
  '...................................######..................................................................##.........#.',
  '...................................####.....................................................................#........#..',
  '...................................###..............................................................................#...',
  '...................................###..................................................................................',
  '...................................##...................................................................................',
  '...................................###..................................................................................',
  '........................................................................................................................',
];

class _Hub {
  final String id;
  final double lat;
  final double lon;
  const _Hub(this.id, this.lat, this.lon);
}

const List<_Hub> _hubs = [
  _Hub('london', 51.5, -0.1),
  _Hub('paris', 48.9, 2.35),
  _Hub('amsterdam', 52.4, 4.9),
  _Hub('frankfurt', 50.1, 8.7),
  _Hub('madrid', 40.4, -3.7),
  _Hub('rome', 41.9, 12.5),
  _Hub('warsaw', 52.2, 21.0),
  _Hub('istanbul', 41.0, 29.0),
  _Hub('moscow', 55.8, 37.6),
  _Hub('cairo', 30.0, 31.2),
  _Hub('dubai', 25.2, 55.3),
  _Hub('mumbai', 19.1, 72.9),
  _Hub('singapore', 1.35, 103.8),
  _Hub('jakarta', -6.2, 106.8),
  _Hub('bangkok', 13.75, 100.5),
  _Hub('saigon', 10.8, 106.7),
  _Hub('hongkong', 22.3, 114.2),
  _Hub('taipei', 25.0, 121.5),
  _Hub('seoul', 37.6, 127.0),
  _Hub('tokyo', 35.7, 139.7),
  _Hub('sydney', -33.9, 151.2),
  _Hub('joburg', -26.2, 28.0),
  _Hub('lagos', 6.5, 3.4),
  _Hub('saopaulo', -23.5, -46.6),
  _Hub('newyork', 40.7, -74.0),
  _Hub('toronto', 43.7, -79.4),
  _Hub('miami', 25.8, -80.2),
  _Hub('mexico', 19.4, -99.1),
  _Hub('la', 34.0, -118.2),
];

/// Routes drawn between hubs (a hub is a city, not a country: these are the "network").
const List<List<String>> _arcs = [
  ['newyork', 'london'],
  ['frankfurt', 'dubai'],
  ['dubai', 'singapore'],
  ['singapore', 'tokyo'],
  ['singapore', 'sydney'],
  ['london', 'joburg'],
  ['saopaulo', 'newyork'],
  ['istanbul', 'moscow'],
  ['dubai', 'mumbai'],
  ['la', 'newyork'],
  ['hongkong', 'tokyo'],
  ['lagos', 'frankfurt'],
  ['istanbul', 'dubai'],
  ['moscow', 'seoul'],
  ['mumbai', 'singapore'],
  ['miami', 'saopaulo'],
];

/// Country code -> the hub that is in that country (only exact matches, so the lit node is honest).
const Map<String, String> _hubOf = {
  'GB': 'london',
  'FR': 'paris',
  'NL': 'amsterdam',
  'DE': 'frankfurt',
  'ES': 'madrid',
  'IT': 'rome',
  'PL': 'warsaw',
  'TR': 'istanbul',
  'RU': 'moscow',
  'EG': 'cairo',
  'AE': 'dubai',
  'IN': 'mumbai',
  'SG': 'singapore',
  'ID': 'jakarta',
  'TH': 'bangkok',
  'VN': 'saigon',
  'HK': 'hongkong',
  'TW': 'taipei',
  'KR': 'seoul',
  'JP': 'tokyo',
  'AU': 'sydney',
  'ZA': 'joburg',
  'NG': 'lagos',
  'BR': 'saopaulo',
  'US': 'newyork',
  'CA': 'toronto',
  'MX': 'mexico',
};

final Map<String, _Hub> _hubById = {for (final h in _hubs) h.id: h};

/// Centres of the land cells, in cell units.
final List<Offset> _cells = _buildCells();

List<Offset> _buildCells() {
  final out = <Offset>[];
  for (var j = 0; j < _land.length; j++) {
    final row = _land[j];
    for (var i = 0; i < row.length; i++) {
      if (row.codeUnitAt(i) == 35) out.add(Offset(i + .5, j + .5)); // '#'
    }
  }
  return out;
}

class WorldBackdrop extends StatelessWidget {
  const WorldBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final top = MediaQuery.of(context).padding.top;
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, box) => ValueListenableBuilder<Offset?>(
            valueListenable: DialAnchor.center,
            builder: (context, measured, _) => ListenableBuilder(
              listenable: Conn.I,
              builder: (context, _) {
                final s = Conn.I.state;
                final on = s == CS.on;
                final busy = s == CS.connecting;
                final hub = on ? _hubOf[Conn.I.server?.cc ?? ''] : null;
                return CustomPaint(
                  size: box.biggest,
                  painter: _WorldPainter(
                    // before the dial has reported its position: where the home layout puts it
                    dial: measured ?? Offset(box.maxWidth / 2, top + 306),
                    dots: p.onSurfaceVariant,
                    dotAlpha: p.dark ? .34 : .24,
                    net: on ? p.ok : (busy ? p.primary : p.onSurfaceVariant),
                    netAlpha: on ? .62 : .46,
                    core: p.onSurface,
                    wash: on ? p.ok : p.primary,
                    washAlpha: p.dark ? .07 : .05,
                    route: hub == null ? null : p.ok,
                    exitHub: hub,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  final Offset dial;
  final Color dots;
  final double dotAlpha;
  final Color net;
  final double netAlpha;
  final Color core;
  final Color wash;
  final double washAlpha;
  final Color? route;
  final String? exitHub;
  const _WorldPainter({
    required this.dial,
    required this.dots,
    required this.dotAlpha,
    required this.net,
    required this.netAlpha,
    required this.core,
    required this.wash,
    required this.washAlpha,
    required this.route,
    required this.exitHub,
  });

  Offset get _origin => Offset(dial.dx - (_lon0 + 180) / 360 * _mapW, dial.dy - _dialAt * _mapH);

  Offset _at(_Hub h) => _origin + Offset((h.lon + 180) / 360 * _mapW, (80 - h.lat) / 138 * _mapH);

  Path _curve(Offset a, Offset b, double lift) {
    final mid = Offset.lerp(a, b, .5)!;
    final chord = (b - a).distance;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy - chord * lift, b.dx, b.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final o = _origin;

    // a faint wash along the top edge keeps the page from reading as flat black
    final topRect = Rect.fromLTWH(0, 0, size.width, size.height * .42);
    canvas.drawRect(
      topRect,
      Paint()..shader = ui.Gradient.linear(topRect.topCenter, topRect.bottomCenter, [alpha(wash, washAlpha), alpha(wash, 0)]),
    );

    // land: brightest around the dial, dimmer toward the edges and below it
    final dot = Paint();
    final r = _sp * .31;
    for (final c in _cells) {
      final x = o.dx + c.dx * _sp;
      if (x < -_sp || x > size.width + _sp) continue;
      final y = o.dy + c.dy * _sp;
      final dx = (x - dial.dx) / (size.width * .78);
      final dy = (y - dial.dy) / 210;
      final k = (1 - math.pow(dx * dx + dy * dy, .8).toDouble()).clamp(.25, 1.0);
      final down = ((dial.dy + 60 - y) / 70).clamp(0.0, 1.0);
      final a = (dotAlpha * (.55 + .75 * k) * down).clamp(0.0, 1.0);
      if (a < .01) continue;
      dot.color = alpha(dots, a);
      canvas.drawCircle(Offset(x, y), r, dot);
    }

    // routes between hubs, fading out at both ends
    for (final pair in _arcs) {
      final a = _at(_hubById[pair[0]]!);
      final b = _at(_hubById[pair[1]]!);
      if ((a.dx < -40 && b.dx < -40) || (a.dx > size.width + 40 && b.dx > size.width + 40)) continue;
      canvas.drawPath(
        _curve(a, b, .30),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..shader = ui.Gradient.linear(a, b, [alpha(net, 0), alpha(net, netAlpha), alpha(net, 0)], const [0, .5, 1]),
      );
    }

    // hubs
    final halo = Paint()
      ..color = alpha(net, .30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final pin = Paint()..color = alpha(core, .92);
    for (final h in _hubs) {
      final p = _at(h);
      if (p.dx < -10 || p.dx > size.width + 10) continue;
      canvas.drawCircle(p, 6, halo);
      canvas.drawCircle(p, 1.7, pin);
    }

    // connected: the route from the dial to the hub in the server's country
    final rc = route;
    final hub = exitHub == null ? null : _hubById[exitHub!];
    if (rc != null && hub != null) {
      final e = _at(hub);
      final path = _curve(dial, e, .22);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = alpha(rc, .30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = alpha(rc, .95),
      );
      canvas.drawCircle(e, 9, Paint()..color = alpha(rc, .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(e, 3.2, Paint()..color = rc);
    }
  }

  @override
  bool shouldRepaint(_WorldPainter o) =>
      o.dial != dial ||
      o.dots != dots ||
      o.dotAlpha != dotAlpha ||
      o.net != net ||
      o.netAlpha != netAlpha ||
      o.core != core ||
      o.wash != wash ||
      o.washAlpha != washAlpha ||
      o.route != route ||
      o.exitHub != exitHub;
}
