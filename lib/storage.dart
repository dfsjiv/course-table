import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance.dart';
import 'custom_event.dart';
import 'models.dart';

class TimetableStorage {
  static const _key = 'timetable';
  static const _reminderKey = 'reminderMinutes';
  static const _eventsKey = 'customEvents';
  static const _themeKey = 'themeMode';
  static const _backgroundKey = 'backgroundPath';
  static const _backgroundOpacityKey = 'backgroundOpacity';

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

  Future<List<CustomEvent>> loadCustomEvents() async {
    final value = (await SharedPreferences.getInstance()).getString(_eventsKey);
    if (value == null) return [];
    return (jsonDecode(value) as List)
        .map((item) => CustomEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCustomEvents(List<CustomEvent> events) async {
    await (await SharedPreferences.getInstance())
        .setString(_eventsKey, jsonEncode(events.map((event) => event.toJson()).toList()));
  }

  Future<AppearanceSettings> loadAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    final modeName = preferences.getString(_themeKey) ?? 'system';
    return AppearanceSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => ThemeMode.system,
      ),
      backgroundPath: preferences.getString(_backgroundKey),
      backgroundOpacity: preferences.getDouble(_backgroundOpacityKey) ?? 0.25,
    );
  }

  Future<void> saveAppearance(AppearanceSettings appearance) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, appearance.themeMode.name);
    if (appearance.backgroundPath == null) {
      await preferences.remove(_backgroundKey);
    } else {
      await preferences.setString(_backgroundKey, appearance.backgroundPath!);
    }
    await preferences.setDouble(_backgroundOpacityKey, appearance.backgroundOpacity);
  }
}
