import 'package:flutter/material.dart'
    show MaterialApp, ThemeData, ColorScheme, NoSplash, Typography;
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import 'app_state.dart';
import 'appearance.dart';
import 'island_controller.dart';
import 'ui/common.dart';
import 'ui/shell.dart';
import 'ui/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(CourseTableApp(state: state));
  state.load().then((_) => IslandController().resumeIfEnabled());
}

final navigatorKey = GlobalKey<NavigatorState>();

class CourseTableApp extends StatelessWidget {
  const CourseTableApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final appearance = state.appearance;
          // The miuix schemes are built from Brand, so point Brand at the
          // chosen palette before building them.
          Brand.palette = appearance.palette;
          return MiuixThemeController(
            colorSchemeMode: switch (appearance.themeMode) {
              AppThemeMode.system => MiuixColorSchemeMode.system,
              AppThemeMode.light => MiuixColorSchemeMode.light,
              AppThemeMode.dark => MiuixColorSchemeMode.dark,
            },
            lightColors: Brand.light(),
            darkColors: Brand.dark(),
            child: _ThemedApp(appearance: appearance),
          );
        },
      ),
    );
  }
}

class _ThemedApp extends StatefulWidget {
  const _ThemedApp({required this.appearance});

  final AppearanceSettings appearance;

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  Object? _signature;

  static void _markAll(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markAll);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final appearance = widget.appearance;
    Brand.use(appearance.palette, dark);
    final family = appearance.fontFamily;

    // Many widgets read Brand colors without depending on an inherited
    // theme (const children, painters), so a palette, mode or font change
    // rebuilds the whole tree once. Marking descendants dirty during this
    // build is allowed: they rebuild in the same frame.
    final signature = (appearance.palette, dark, family);
    if (_signature != null && _signature != signature) {
      (context as Element).visitChildren(_markAll);
    }
    _signature = signature;

    // MaterialApp only hosts localizations and text editing for the miuix
    // widgets; every visible control is a Miuix* widget.
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '课表',
      theme: ThemeData(
        brightness: theme.brightness,
        fontFamily: family,
        // The 2014 type set carries no line height or letter spacing, so
        // nothing leaks into miuix text through DefaultTextStyle.
        typography: Typography.material2014(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Brand.accent,
          brightness: theme.brightness,
        ),
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (context, child) => family == null
          ? child!
          : DefaultTextStyle.merge(
              style: TextStyle(fontFamily: family),
              child: child!,
            ),
      home: const AppShell(),
    );
  }
}
