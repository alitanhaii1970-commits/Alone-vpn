import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/palette.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'core/tokens.dart';
import 'core/typography.dart';
import 'data/stores.dart';
import 'selftest.dart';
import 'ui/kit/chrome.dart';
import 'ui/shell_state.dart';
import 'ui/screens/splash.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // If a widget throws, show the message on screen instead of a blank/grey page.
    ErrorWidget.builder = (details) => Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFF1B1B1F),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              child: Text('ALONE VPN - UI error\n\n${details.exceptionAsString()}',
                  style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12, decoration: TextDecoration.none)),
            ),
          ),
        );
    FlutterError.onError = (d) => debugPrint('FlutterError: ${d.exceptionAsString()}');
    // Never let startup I/O keep the first frame from appearing.
    try {
      await AppSettings.I.load().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('settings load failed: $e');
    }
    debugPrint('ALONE_BOOT onboarded=${AppSettings.I.onboarded} lang=${AppSettings.I.lang} links=${AppSettings.I.serverLinks.length}');
    try {
      ServerStore.I.load();
      Conn.I.listenEngine();
    } catch (e) {
      debugPrint('server store load failed: $e');
    }
    prepareSelfTest();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    runApp(const AloneVpnApp());
    unawaited(runSelfTest());
  }, (error, stack) => debugPrint('Uncaught: $error'));
}

class AloneVpnApp extends StatefulWidget {
  const AloneVpnApp({super.key});
  @override
  State<AloneVpnApp> createState() => _AloneVpnAppState();
}

class _AloneVpnAppState extends State<AloneVpnApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _theme = AnimationController(vsync: this, duration: Tk.spatialSlow, value: 1);
  Pal? _from;
  Pal? _to;
  String _key = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.I.addListener(_onSettings);
  }

  @override
  void dispose() {
    AppSettings.I.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    _theme.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  void _onSettings() => setState(() {});

  Pal _target() {
    final st = AppSettings.I;
    final dark = st.isDark(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    return Pal.build(themeById(st.theme), dark);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppSettings.I;
    final dark = st.isDark(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    final key = '${st.theme}-$dark';
    final target = _target();
    if (_to == null) {
      _from = _to = target;
      _key = key;
    } else if (key != _key) {
      _from = Pal.lerp(_from!, _to!, _theme.value);
      _to = target;
      _key = key;
      _theme.forward(from: 0);
    }
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) {
        final pal = Pal.lerp(_from!, _to!, Curves.easeInOut.transform(_theme.value));
        final ty = Ty.of(st);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: const Color(0x00000000),
          statusBarIconBrightness: pal.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: const Color(0x00000000),
          systemNavigationBarIconBrightness: pal.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'ALONE VPN',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: _to!.dark ? Brightness.dark : Brightness.light,
            colorSchemeSeed: _to!.primary,
            scaffoldBackgroundColor: _to!.surface,
            splashFactory: NoSplash.splashFactory,
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: st.fa ? TextDirection.rtl : TextDirection.ltr,
              child: AppScope(
                pal: pal,
                st: st,
                ty: ty,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: DefaultTextStyle(
                    style: ty(R.bodyM, pal.onSurface),
                    child: Stack(
                      children: [
                        child ?? const SizedBox.shrink(),
                        const StatusPill(),
                        ValueListenableBuilder<bool>(
                          valueListenable: ShellState.onTopLevel,
                          builder: (context, lifted, _) => SnackHost(lifted: lifted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }

}
