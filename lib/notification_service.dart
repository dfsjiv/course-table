import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'reminders.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
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
}
