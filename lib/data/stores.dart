import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:v2ray_box/v2ray_box.dart' as vb;
import '../core/i18n.dart';
import '../core/settings.dart';
import '../data/catalog.dart';
import '../models/proxy_config.dart';
import '../services/engine.dart';
import '../services/subscription_service.dart';

// ───────────────────────── snackbars ─────────────────────────
class Snack {
  final int id;
  final String msg;
  final String tone; // info | ok | warn | err
  final String? actLabel;
  final VoidCallback? act;
  const Snack(this.id, this.msg, this.tone, this.actLabel, this.act);
}

class Toasts extends ChangeNotifier {
  Toasts._();
  static final Toasts I = Toasts._();
  Snack? cur;
  Timer? _t;
  int _n = 0;

  void show(String msg, {String tone = 'info', String? actLabel, VoidCallback? act}) {
    _t?.cancel();
    cur = Snack(++_n, msg, tone, actLabel, act);
    notifyListeners();
    _t = Timer(Duration(milliseconds: actLabel != null ? 5200 : 2800), hide);
  }

  void hide() {
    _t?.cancel();
    if (cur != null) {
      cur = null;
      notifyListeners();
    }
  }
}

void snack(String msg, {String tone = 'info', String? actLabel, VoidCallback? act}) =>
    Toasts.I.show(msg, tone: tone, actLabel: actLabel, act: act);

// ───────────────────────── log ─────────────────────────
class LogLine {
  final DateTime t;
  final String lvl; // info | ok | warn | err
  final String tag;
  final String msg;
  const LogLine(this.t, this.lvl, this.tag, this.msg);
}

class LogStore extends ChangeNotifier {
  LogStore._();
  static final LogStore I = LogStore._();
  final List<LogLine> lines = <LogLine>[];

  void add(String lvl, String tag, String msg) {
    lines.add(LogLine(DateTime.now(), lvl, tag, msg));
    if (lines.length > 300) lines.removeAt(0);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }
}

// ───────────────────────── servers ─────────────────────────
String sidOf(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

class Server {
  final String id;
  final ProxyConfig cfg;
  const Server(this.id, this.cfg);

  String get link => cfg.originalLink;
  String get host => cfg.address;
  int get port => cfg.port;

  String get proto {
    switch (cfg.protocol) {
      case ProxyProtocol.shadowsocks:
        return 'ss';
      case ProxyProtocol.unknown:
        final i = link.indexOf('://');
        return i > 0 ? link.substring(0, i).toLowerCase() : '?';
      default:
        return cfg.protocol.name;
    }
  }

  /// Two-letter country code, read from a flag emoji in the config's name.
  String get cc {
    final r = cfg.name.runes.toList();
    for (var i = 0; i + 1 < r.length; i++) {
      if (r[i] >= 0x1F1E6 && r[i] <= 0x1F1FF && r[i + 1] >= 0x1F1E6 && r[i + 1] <= 0x1F1FF) {
        return String.fromCharCodes([r[i] - 0x1F1E6 + 65, r[i + 1] - 0x1F1E6 + 65]);
      }
    }
    return '';
  }

  String get title {
    final cleaned = cfg.name.runes
        .where((r) => !(r >= 0x1F1E6 && r <= 0x1F1FF))
        .map((r) => String.fromCharCode(r))
        .join()
        .trim();
    return cleaned.isEmpty ? host : cleaned;
  }
}

class AddResult {
  final int added;
  final int dup;
  final int bad;
  const AddResult(this.added, this.dup, this.bad);
}

class ServerStore extends ChangeNotifier {
  ServerStore._();
  static final ServerStore I = ServerStore._();

  final List<Server> items = <Server>[];
  final Map<String, int?> lat = <String, int?>{}; // present = tested, null = no answer
  final Set<String> probing = <String>{};
  bool sweeping = false;

  Server? _make(String link) {
    ProxyConfig? c;
    try {
      c = ProxyConfig.parse(link);
    } catch (_) {
      c = null;
    }
    c ??= _fallback(link);
    if (c == null) return null;
    return Server(sidOf(link), c);
  }

  /// Share links the engine understands but the app's own parser does not.
  ProxyConfig? _fallback(String link) {
    final m = RegExp(r'^(hysteria2|hy2|tuic|wireguard|wg|hysteria|hy|socks5|socks|ssh)://', caseSensitive: false).firstMatch(link);
    if (m == null) return null;
    try {
      final u = Uri.parse(link);
      if (u.host.isEmpty) return null;
      final name = u.fragment.isEmpty ? u.host : Uri.decodeComponent(u.fragment);
      return ProxyConfig(
        id: sidOf(link),
        name: name,
        protocol: ProxyProtocol.unknown,
        address: u.host,
        port: u.hasPort ? u.port : 443,
        raw: const <String, dynamic>{},
        originalLink: link,
      );
    } catch (_) {
      return null;
    }
  }

  void load() {
    items.clear();
    for (final l in AppSettings.I.serverLinks) {
      final s = _make(l);
      if (s != null) items.add(s);
    }
    final st = AppSettings.I;
    if (byId(st.activeServer) == null) st.activeServer = items.isEmpty ? '' : items.first.id;
    notifyListeners();
  }

  Server? byId(String id) {
    for (final s in items) {
      if (s.id == id) return s;
    }
    return null;
  }

  Server? get active => byId(AppSettings.I.activeServer);

  void setActive(String id) {
    final st = AppSettings.I;
    st.update(() => st.activeServer = id);
    notifyListeners();
  }

  /// Accepts share links (one or many) and/or subscription URLs.
  Future<AddResult> addText(String text) async {
    final tokens = text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    var bad = 0;
    final found = <String>[];
    for (final tk in tokens) {
      if (RegExp(r'^https?://', caseSensitive: false).hasMatch(tk)) {
        try {
          final list = await SubscriptionService.fetch(tk);
          for (final c in list) {
            found.add(c.originalLink);
          }
        } catch (_) {
          bad++;
        }
      } else {
        found.add(tk);
      }
    }
    final st = AppSettings.I;
    final links = <String>[...st.serverLinks];
    var added = 0;
    var dup = 0;
    for (final l in found) {
      final s = _make(l);
      if (s == null) {
        bad++;
        continue;
      }
      if (links.contains(l)) {
        dup++;
        continue;
      }
      links.add(l);
      items.add(s);
      added++;
    }
    st.update(() {
      st.serverLinks = links;
      if (byId(st.activeServer) == null) st.activeServer = items.isEmpty ? '' : items.first.id;
    });
    notifyListeners();
    return AddResult(added, dup, bad);
  }

  void remove(String id) {
    final s = byId(id);
    if (s == null) return;
    items.remove(s);
    lat.remove(id);
    final st = AppSettings.I;
    st.update(() {
      st.serverLinks = st.serverLinks.where((l) => sidOf(l) != id).toList();
      st.favs.remove(id);
      if (st.activeServer == id) st.activeServer = items.isEmpty ? '' : items.first.id;
    });
    notifyListeners();
  }

  Future<void> probeOne(Server s) async {
    probing.add(s.id);
    notifyListeners();
    int? ms;
    if (AppSettings.I.probe == 'url' && Engine.real) {
      ms = await Engine.I.coreDelay(s.link);
    } else {
      ms = await Engine.tcpPing(s.host, s.port);
    }
    lat[s.id] = ms;
    probing.remove(s.id);
    notifyListeners();
  }

  Future<void> probeAll() async {
    if (sweeping || items.isEmpty) return;
    sweeping = true;
    notifyListeners();
    LogStore.I.add('info', 'probe', tr('log_probe', {'s': AppSettings.I.probe == 'url' ? 'URL' : 'TCP'}));
    final list = <Server>[...items];
    for (var i = 0; i < list.length; i += 4) {
      await Future.wait(list.skip(i).take(4).map(probeOne));
    }
    sweeping = false;
    final f = fastest();
    if (f != null) LogStore.I.add('ok', 'probe', tr('log_probe_done', {'s': f.title}));
    notifyListeners();
  }

  Server? fastest() {
    Server? best;
    var bv = 1 << 30;
    for (final s in items) {
      final v = lat[s.id];
      if (v != null && v < bv) {
        bv = v;
        best = s;
      }
    }
    return best;
  }
}

// ───────────────────────── connection ─────────────────────────
enum CS { off, connecting, on, failed, disconnecting }

/// The connection state machine: off → connecting (resolve → tcp → tls →
/// tunnel) → on, with failed / disconnecting. Resolve and TCP are real
/// probes; TLS and the tunnel are performed by the engine and reported back.
class Conn extends ChangeNotifier {
  Conn._();
  static final Conn I = Conn._();

  CS state = CS.off;
  int hs = -1; // active handshake step 0..3, 4 = complete
  int failStep = -1;
  DateTime? since;

  int rateDown = 0;
  int rateUp = 0;
  int sessDown = 0;
  int sessUp = 0;
  int peakDown = 0;
  final List<double> sparkDown = <double>[];
  final List<double> sparkUp = <double>[];

  Timer? _tick;
  StreamSubscription<vb.VpnStatus>? _statusSub;
  StreamSubscription<vb.VpnStats>? _statsSub;
  StreamSubscription<Map<String, dynamic>>? _alertsSub;
  Completer<bool>? _tunnel;
  Completer<void>? _stopped;
  int _gen = 0;
  bool _attached = false;
  Timer? _stopGrace;
  Timer? _permGrace;
  bool _sawStart = false; // the engine reported starting/started during this attempt
  DateTime _noAdoptUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Subscribe to the engine as soon as the app starts, so the UI follows the real tunnel
  /// state even if the app is reopened while it is running.
  void listenEngine() => _attach();

  int get secs => since == null ? 0 : DateTime.now().difference(since!).inSeconds;
  bool get busy => state == CS.connecting || state == CS.disconnecting;
  Server? get server => ServerStore.I.active;

  void _attach() {
    if (_attached || !Engine.real) return;
    _attached = true;
    _statusSub = Engine.I.status().listen(_onStatus, onError: (Object _) {});
    _statsSub = Engine.I.stats().listen(_onStats, onError: (Object _) {});
    _alertsSub = Engine.I.alerts().listen(_onAlert, onError: (Object _) {});
  }

  void _onStatus(vb.VpnStatus s) {
    if (s == vb.VpnStatus.starting) {
      _sawStart = true;
      return;
    }
    if (s == vb.VpnStatus.started) {
      _sawStart = true;
      _stopGrace?.cancel();
      _permGrace?.cancel();
      if (state == CS.connecting) {
        final tunnel = _tunnel;
        if (tunnel != null && !tunnel.isCompleted) tunnel.complete(true);
      } else if (state == CS.failed || state == CS.off) {
        // The engine is the source of truth. It came up after we gave up (late VPN-consent
        // dialog, service restart) or the app was reopened while it was running -> follow it.
        final srv = server;
        if (srv == null) return;
        if (DateTime.now().isBefore(_noAdoptUntil)) {
          unawaited(Engine.I.stop()); // the user cancelled / disconnected a moment ago
          return;
        }
        _gen++; // invalidate any connect() still in flight
        _up(srv);
      }
    } else if (s == vb.VpnStatus.stopped) {
      if (state == CS.connecting) {
        // A stop *before* the engine ever started is just the initial state (or the consent
        // dialog still being open). A stop *after* it started may be a service restart, so
        // give it a few seconds to come back before calling it a failure.
        if (!_sawStart) return;
        _stopGrace?.cancel();
        _stopGrace = Timer(const Duration(seconds: 9), () {
          final tunnel = _tunnel;
          if (state == CS.connecting && tunnel != null && !tunnel.isCompleted) tunnel.complete(false);
        });
      } else if (state == CS.on) {
        _down(user: false);
        snack(tr('sn_disc'), tone: 'warn');
        Hx.fail();
      } else if (state == CS.disconnecting) {
        final stopped = _stopped;
        if (stopped != null && !stopped.isCompleted) stopped.complete();
      }
    }
  }

  void _onAlert(Map<String, dynamic> event) {
    if (state != CS.connecting) return;
    final alert = event['alert']?.toString();
    if (alert != 'RequestVPNPermission' && alert != 'RequestNotificationPermission') return;
    LogStore.I.add('warn', 'permission', event['message']?.toString() ?? alert!);
    // The permission may still be granted a moment later, and a late "started" is adopted
    // anyway, so wait a few seconds instead of failing instantly.
    _permGrace?.cancel();
    _permGrace = Timer(const Duration(seconds: 4), () {
      final tunnel = _tunnel;
      if (state == CS.connecting && tunnel != null && !tunnel.isCompleted) tunnel.complete(false);
    });
  }

  void _onStats(vb.VpnStats s) {
    if (state != CS.on) return;
    rateDown = s.downlink;
    rateUp = s.uplink;
    sessDown = s.downlinkTotal;
    sessUp = s.uplinkTotal;
    if (rateDown > peakDown) peakDown = rateDown;
    _push(sparkDown, rateDown.toDouble());
    _push(sparkUp, rateUp.toDouble());
    notifyListeners();
  }

  void _push(List<double> l, double v) {
    l.add(v);
    if (l.length > 60) l.removeAt(0);
  }

  Future<void> toggle() async {
    if (state == CS.on) return disconnect();
    if (state == CS.connecting) return cancel();
    if (state == CS.off || state == CS.failed) return connect();
  }

  Future<void> connect() async {
    if (state == CS.on || busy) return;
    final srv = server;
    if (srv == null) {
      snack(trOr('no_server_toast', 'اول یه سرور اضافه یا انتخاب کن', 'Add or pick a server first'), tone: 'warn');
      return;
    }
    final gen = ++_gen;
    _sawStart = false;
    _stopGrace?.cancel();
    _permGrace?.cancel();
    state = CS.connecting;
    hs = 0;
    failStep = -1;
    rateDown = rateUp = sessDown = sessUp = peakDown = 0;
    sparkDown.clear();
    sparkUp.clear();
    notifyListeners();
    Hx.tap();
    LogStore.I.add('info', 'core', tr('log_req', {'s': srv.title}));
    _attach();
    bool alive() => gen == _gen && state == CS.connecting;

    // 1 · resolve
    if (InternetAddress.tryParse(srv.host) == null) {
      try {
        await InternetAddress.lookup(srv.host).timeout(const Duration(seconds: 6));
      } catch (_) {
        if (alive()) _fail(0, srv);
        return;
      }
    }
    if (!alive()) return;
    LogStore.I.add('ok', 'dns', tr('log_step_ok', {'s': tr('hs_resolve')}));
    hs = 1;
    notifyListeners();

    // 2 · tcp (UDP-based protocols such as Hysteria/TUIC/WireGuard have no TCP port to probe)
    final udp = RegExp(r'^(hysteria2?|hy2|tuic|wireguard|wg)://', caseSensitive: false).hasMatch(srv.link.trim());
    int? ms;
    if (!udp) {
      ms = await Engine.tcpPing(srv.host, srv.port, timeoutMs: 4500);
      if (!alive()) return;
      ms ??= await Engine.tcpPing(srv.host, srv.port, timeoutMs: 6000); // one retry before giving up
      if (!alive()) return;
      if (ms == null) {
        _fail(1, srv);
        return;
      }
      ServerStore.I.lat[srv.id] = ms;
    }
    LogStore.I.add('ok', 'tcp', tr('log_step_ok', {'s': tr('hs_tcp')}));
    hs = 2;
    notifyListeners();

    // 3 · TLS + tunnel (inside the engine)
    if (Engine.real) {
      _tunnel = Completer<bool>();
      final started = await _startReal(srv, alive);
      if (!alive()) return;
      if (!started) {
        _fail(2, srv);
        return;
      }
      LogStore.I.add('ok', 'tls', tr('log_step_ok', {'s': tr('hs_tls')}));
      hs = 3;
      notifyListeners();
      final up = await _tunnel!.future.timeout(const Duration(seconds: 60), onTimeout: () => false);
      if (!alive()) return;
      if (!up) {
        await Engine.I.stop();
        _fail(3, srv);
        return;
      }
    } else {
      // No tunnel engine on this platform: preview only, and the log says so.
      LogStore.I.add('warn', 'core', trOr('log_noengine', 'روی این پلتفرم موتور تانل نیست؛ فقط پیش‌نمایش', 'No tunnel engine on this platform — preview only'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!alive()) return;
      hs = 3;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!alive()) return;
    }
    _up(srv);
  }

  Future<bool> _startReal(Server srv, bool Function() alive) async {
    final st = AppSettings.I;
    try {
      // Configure first, then start the engine. On Android the plugin's start
      // method writes the active profile before requesting VpnService consent.
      // Calling requestVpnPermission() separately is unsafe: that plugin method
      // can start the service on ActivityResult before this profile is written.
      await Engine.I.configure(
        dns: st.dnsEngineAddress,
        blockAds: st.rules['ads'] ?? false,
        bypassLan: st.rules['lan'] ?? true,
        strict: st.killswitch,
        splitMode: st.splitMode,
        apps: st.splitApps,
      );
      if (!alive()) return false;
      final started = await Engine.I.start(srv.link, srv.title);
      if (!alive()) {
        // The native start call may have raced with a user cancellation. Stop
        // again after it returns so a late service start cannot be left behind.
        await Engine.I.stop();
        return false;
      }
      if (!started) await Engine.I.stop();
      return started;
    } catch (e) {
      LogStore.I.add('err', 'core', '$e');
      await Engine.I.stop();
      return false;
    }
  }

  void _fail(int step, Server srv) {
    state = CS.failed;
    failStep = step;
    hs = step;
    final stepName = tr(kHsSteps[step]);
    LogStore.I.add('err', 'core', tr('log_step_fail', {'s': stepName}));
    LogStore.I.add('err', 'core', tr('log_fail', {'s': srv.title}));
    snack(tr('sn_fail', {'s': srv.title, 'd': stepName}), tone: 'err');
    Hx.fail();
    notifyListeners();
  }

  void _up(Server srv) {
    state = CS.on;
    hs = 4;
    since = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    LogStore.I.add('ok', 'core', tr('log_up', {'s': srv.title}));
    snack(tr('sn_conn', {'s': srv.title}), tone: 'ok');
    Hx.ok();
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (state != CS.on) return;
    state = CS.disconnecting;
    _noAdoptUntil = DateTime.now().add(const Duration(seconds: 20));
    notifyListeners();
    Hx.tap();
    _stopped = Completer<void>();
    await Engine.I.stop();
    if (Engine.real) {
      await _stopped!.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _down(user: true);
  }

  void _down({required bool user}) {
    _record();
    _tick?.cancel();
    state = CS.off;
    hs = -1;
    since = null;
    rateDown = 0;
    rateUp = 0;
    LogStore.I.add('info', 'core', tr('log_down'));
    if (user) snack(tr('sn_disc'));
    notifyListeners();
  }

  void cancel() {
    if (state != CS.connecting) return;
    _gen++;
    _noAdoptUntil = DateTime.now().add(const Duration(seconds: 20));
    _stopGrace?.cancel();
    _permGrace?.cancel();
    unawaited(Engine.I.stop());
    final tunnel = _tunnel;
    if (tunnel != null && !tunnel.isCompleted) tunnel.complete(false);
    state = CS.off;
    hs = -1;
    LogStore.I.add('warn', 'core', tr('sn_cancel'));
    snack(tr('sn_cancel'));
    notifyListeners();
  }

  void dismissFailure() {
    if (state != CS.failed) return;
    state = CS.off;
    hs = -1;
    failStep = -1;
    notifyListeners();
  }

  void _record() {
    final s = since;
    if (s == null) return;
    final st = AppSettings.I;
    final srv = server;
    st.update(() {
      st.history.insert(0, <String, dynamic>{
        't': s.millisecondsSinceEpoch,
        'secs': secs,
        'down': sessDown,
        'up': sessUp,
        'srv': srv?.title ?? '',
      });
      if (st.history.length > 12) st.history.removeRange(12, st.history.length);
    });
  }
}
