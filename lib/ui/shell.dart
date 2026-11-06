import 'dart:io';

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../notification_service.dart';
import 'common.dart';
import 'icons.dart';
import 'glass.dart';
import 'plan_page.dart';
import 'reflection_page.dart';
import 'settings_page.dart';
import 'today_page.dart';
import 'tokens.dart';
import 'week_page.dart';

/// Four tabs under a floating glass navigation bar. The glass samples the
/// page content through [MiuixLayerBackdropCapture].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _backdrop = MiuixLayerBackdrop();
  int _tab = 0;
  final _weekPage = GlobalKey<WeekPageState>();
  final _reselect = List.generate(4, (_) => Reselect());

  static const _tabs = [
    ('今天', AppIcons.today),
    ('课表', AppIcons.week),
    ('自学', AppIcons.study),
    ('设置', AppIcons.settings),
  ];

  @override
  void initState() {
    super.initState();
    final notifications = NotificationService();
    notifications.onTap = _openPayload;
    notifications.launchPayload().then((payload) {
      if (payload != null && mounted) _openPayload(payload);
    });
  }

  @override
  void dispose() {
    _backdrop.dispose();
    for (final notifier in _reselect) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _openPayload(String payload) {
    final evening = payload == NotificationService.eveningPayload;
    if (payload != NotificationService.morningPayload && !evening) return;
    Navigator.of(
      context,
    ).push(SlideRoute((_) => ReflectionPage(evening: evening), ambient: false));
  }

  /// Jumps to the week tab showing [week].
  void showWeek(int week) {
    setState(() => _tab = 1);
    _weekPage.currentState?.jumpToWeek(week);
  }

  String? _checkedBackground;
  bool _backgroundFound = false;

  /// File I/O once per picture, not on every rebuild.
  bool _backgroundExists(String path) {
    if (path != _checkedBackground) {
      _checkedBackground = path;
      _backgroundFound = File(path).existsSync();
    }
    return _backgroundFound;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final background = state.appearance.backgroundPath;
    final pages = [
      TodayPage(
        onOpenWeek: () => setState(() => _tab = 1),
        reselect: _reselect[0],
      ),
      WeekPage(key: _weekPage, reselect: _reselect[1]),
      PlanPage(reselect: _reselect[2]),
      SettingsPage(reselect: _reselect[3]),
    ];
    return Material(
      type: MaterialType.transparency,
      child: MiuixScaffold(
        containerColor: palette.surface,
        snackbarHost: MiuixSnackbarHost(state: appSnackbar, blurSigma: 20),
        bottomBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: MiuixGlassNavigationBar(
              backdrop: _backdrop,
              selectedIndex: _tab,
              onSelect: (index) {
                if (index == _tab) {
                  _reselect[index].fire();
                  return;
                }
                HapticFeedback.selectionClick();
                setState(() => _tab = index);
              },
              items: [
                for (final (label, icon) in _tabs)
                  MiuixGlassNavigationItem(
                    icon: AppIcon(icon, size: 24),
                    label: label,
                  ),
              ],
            ),
          ),
        ),
        content: (padding) {
          final media = MediaQuery.of(context);
          return MiuixLayerBackdropCapture(
            backdrop: _backdrop,
            // The capture snapshots the whole page with toImageSync after
            // every frame that changes it (each scroll frame, each countdown
            // tick). At the device ratio (3x) that is a full-resolution copy
            // of the screen per frame, which is what made scrolling stutter.
            // The bar blurs the snapshot heavily, so 1x looks the same at a
            // ninth of the pixels.
            pixelRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AmbientBackground(),
                if (background != null && _backgroundExists(background)) ...[
                  // Decode at screen size: a camera photo decoded at full
                  // resolution costs tens of MB and slows every frame.
                  Image.file(
                    File(background),
                    fit: BoxFit.cover,
                    cacheHeight: (media.size.height * media.devicePixelRatio)
                        .round(),
                  ),
                  // A wash keeps text readable on any wallpaper; the
                  // "visibility" setting decides how much picture shows.
                  ColoredBox(
                    color: Brand.base(palette.dark).bg.withValues(
                      alpha: 1 - state.appearance.backgroundOpacity,
                    ),
                  ),
                ],
                MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(bottom: padding.bottom),
                  ),
                  child: IndexedStack(index: _tab, children: pages),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
