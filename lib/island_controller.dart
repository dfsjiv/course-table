import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the current device can do with the Xiaomi HyperOS island.
///
/// [protocol] is HyperOS' `notification_focus_protocol`: 0 = no focus
/// notification support, 1 = OS1, 2 = OS2, 3 = OS3. Only OS3 renders the
/// super island; OS2 falls back to the focus notification.
class IslandCapability {
  const IslandCapability({
    required this.protocol,
    required this.supportsIsland,
    required this.hasFocusPermission,
    required this.manufacturer,
  });

  final int protocol;
  final bool supportsIsland;
  final bool hasFocusPermission;
  final String manufacturer;

  bool get isHyperOs => protocol >= 1;

  factory IslandCapability.fromMap(Map<Object?, Object?> map) =>
      IslandCapability(
        protocol: (map['protocol'] as num?)?.toInt() ?? 0,
        supportsIsland: map['supportsIsland'] as bool? ?? false,
        hasFocusPermission: map['hasFocusPermission'] as bool? ?? false,
        manufacturer: map['manufacturer'] as String? ?? '',
      );

  /// A short, user-facing description of what the island will look like.
  String get description {
    if (supportsIsland) {
      return hasFocusPermission ? '运行中，显示为小米超级岛' : '运行中，但未开启焦点通知权限，将显示为普通通知';
    }
    if (isHyperOs) {
      return hasFocusPermission
          ? '运行中，显示为焦点通知（本机型不支持超级岛）'
          : '运行中，但未开启焦点通知权限，将显示为普通通知';
    }
    return '运行中，${manufacturer.isEmpty ? '当前系统' : manufacturer} 不支持超级岛，将显示为普通通知';
  }
}

/// Controls the HyperOS focus notification / super island on Android.
///
/// The island itself is rendered by HyperOS from the notification that
/// [IslandService] posts; this class only drives the service and reports
/// whether the device will actually show an island. All methods are no-ops on
/// other platforms.
class IslandController {
  static const _channel = MethodChannel('cn.hieu.course_table/island');
  static const _enabledKey = 'islandEnabled';

  Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    return (await SharedPreferences.getInstance()).getBool(_enabledKey) ??
        false;
  }

  Future<IslandCapability?> capability() async {
    if (!Platform.isAndroid) return null;
    final map = await _channel.invokeMethod<Map<Object?, Object?>>(
      'capability',
    );
    return map == null ? null : IslandCapability.fromMap(map);
  }

  /// Returns false when the device has no activity for the notification page.
  Future<bool> openNotificationSettings() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }

  /// Returns false when neither the MIUI autostart page nor the app details page
  /// could be opened.
  Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('openAutostartSettings') ?? false;
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, true);
    await _channel.invokeMethod<void>('startIsland');
  }

  /// Restarts the service on launch when the user turned the island on: the
  /// system may have killed it (battery saver, swipe from recents, update),
  /// and nothing else would bring it back until the next reboot.
  Future<void> resumeIfEnabled() async {
    if (!await isEnabled()) return;
    try {
      await _channel.invokeMethod<void>('startIsland');
    } on PlatformException {
      // Android refuses background starts in some states; the next launch or
      // toggle will try again.
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
    await _channel.invokeMethod<void>('stopIsland');
  }

  /// Tells the service to re-read the timetable after import or event edits.
  /// No-op when the island is disabled.
  Future<void> refresh() async {
    if (!Platform.isAndroid || !await isEnabled()) return;
    try {
      await _channel.invokeMethod<void>('refreshIsland');
    } on PlatformException {
      // The service is not running; it reloads the timetable when it starts.
    }
  }
}
