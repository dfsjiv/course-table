import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class TimetableStorage {
  static const _key = 'timetable';

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
}

