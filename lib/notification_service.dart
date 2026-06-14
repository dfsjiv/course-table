import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'reminders.dart';
import 'custom_event.dart';
import 'platform_capabilities.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

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
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
  }

  Future<void> schedule(Timetable timetable, int minutesBefore) async {
    if (!supportsScheduledNotifications()) return;
    await initialize();
    await _plugin.cancelAll();
    if (minutesBefore <= 0) return;
    final now = DateTime.now();
    final courses = futureCourses(timetable, now, limit: 100);
    for (var index = 0; index < courses.length; index++) {
      final occurrence = courses[index];
      final notificationTime =
          occurrence.start.subtract(Duration(minutes: minutesBefore));
      if (!notificationTime.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: index + 1,
        title: '${occurrence.course.name}还有$minutesBefore分钟开始',
        body: occurrence.course.room.isEmpty
            ? '第${occurrence.course.startPeriod}-${occurrence.course.endPeriod}节'
            : '${occurrence.course.room} · 第${occurrence.course.startPeriod}-${occurrence.course.endPeriod}节',
        scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'course_reminders',
            '上课提醒',
            channelDescription: '在课程开始前提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
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
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      for (final event in customEventsForDate(events, date)) {
        if (event.reminderMinutes <= 0) continue;
        final notificationTime =
            event.startOn(date).subtract(Duration(minutes: event.reminderMinutes));
        if (!notificationTime.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: id++,
          title: '${event.title}还有${event.reminderMinutes}分钟开始',
          body: event.location.isEmpty ? '自定义事件' : event.location,
          scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'course_reminders',
              '上课提醒',
              channelDescription: '在课程或事件开始前提醒',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
