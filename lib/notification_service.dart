import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'plan.dart';
import 'reminders.dart';
import 'custom_event.dart';
import 'platform_capabilities.dart';

/// Notification ids: courses 1..100, custom events 1000..1099, reflection
/// 2001 (morning) and 2002 (evening). Each group only cancels its own range.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  factory NotificationService() => instance;

  static const morningPayload = 'reflection:morning';
  static const eveningPayload = 'reflection:evening';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called with the payload when the user taps a notification while the app
  /// is running or in the background.
  void Function(String payload)? onTap;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'course_reminders',
      '上课提醒',
      channelDescription: '在课程或事件开始前提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _reflectionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reflection',
      '晨间与晚间一分钟',
      channelDescription: '每天早晚提醒花一分钟想想今天',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    if (_ready) return;
    if (!supportsScheduledNotifications()) {
      _ready = true;
      return;
    }
    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
    _ready = true;
  }

  /// The payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload() async {
    if (!supportsScheduledNotifications()) return null;
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  Future<void> requestPermission() async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
  }

  Future<void> schedule(Timetable timetable, int minutesBefore) async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    for (var id = 1; id <= 100; id++) {
      await _plugin.cancel(id: id);
    }
    // Without a start date the week is unknown and every course would be
    // treated as "week 1" forever, so reminders would fire for classes that
    // are not on (every odd/even-week and late-start course, every week).
    if (minutesBefore <= 0 || timetable.startDate == null) return;
    final now = DateTime.now();
    final courses = futureCourses(timetable, now, limit: 100);
    for (var index = 0; index < courses.length; index++) {
      final occurrence = courses[index];
      final notificationTime = occurrence.start.subtract(
        Duration(minutes: minutesBefore),
      );
      if (!notificationTime.isAfter(now)) continue;
      final periods =
          '第${occurrence.course.startPeriod}-${occurrence.course.endPeriod}节';
      await _plugin.zonedSchedule(
        id: index + 1,
        title: '${occurrence.course.name}还有$minutesBefore分钟开始',
        body: occurrence.course.room.isEmpty
            ? periods
            : '${occurrence.course.room} · $periods',
        scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> scheduleCustomEvents(List<CustomEvent> events) async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    for (var id = 1000; id < 1100; id++) {
      await _plugin.cancel(id: id);
    }
    final now = DateTime.now();
    var id = 1000;
    for (var offset = 0; offset <= 120 && id < 1100; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      for (final event in customEventsForDate(events, date)) {
        if (event.reminderMinutes <= 0) continue;
        final notificationTime = event
            .startOn(date)
            .subtract(Duration(minutes: event.reminderMinutes));
        if (!notificationTime.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: id++,
          title: '${event.title}还有${event.reminderMinutes}分钟开始',
          body: event.location.isEmpty ? '自定义事件' : event.location,
          scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        if (id >= 1100) break;
      }
    }
  }

  /// Daily repeating morning / evening reflection prompts.
  Future<void> scheduleReflection(ReflectionSettings settings) async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    await _plugin.cancel(id: 2001);
    await _plugin.cancel(id: 2002);
    if (!settings.enabled) return;
    await _daily(
      2001,
      settings.morningMinutes,
      '晨间一分钟',
      _firstLine(settings.morningPrompt),
      morningPayload,
    );
    await _daily(
      2002,
      settings.eveningMinutes,
      '晚间一分钟',
      _firstLine(settings.eveningPrompt),
      eveningPayload,
    );
  }

  Future<void> _daily(
    int id,
    int minutes,
    String title,
    String body,
    String payload,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var time = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!time.isAfter(now)) time = time.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: time,
      notificationDetails: _reflectionDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String _firstLine(String text) => text.split('\n').first;
}
