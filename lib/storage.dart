import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class TimetableStorage {
  static const _key = 'timetable';
  static const _reminderKey = 'reminderMinutes';

  Future<Timetable?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null
        ? null
        : Timetable.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(Timetable timetable) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(timetable.toJson()));
  }

  Future<int> loadReminderMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_reminderKey) ?? 15;

  Future<void> saveReminderMinutes(int minutes) async {
    await (await SharedPreferences.getInstance()).setInt(_reminderKey, minutes);
  }
}
