import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'appearance.dart';
import 'custom_event.dart';
import 'models.dart';
import 'plan.dart';
import 'theme_palette.dart';

class TimetableStorage {
  static const _key = 'timetable';
  static const _reminderKey = 'reminderMinutes';
  static const _eventsKey = 'customEvents';
  static const _themeKey = 'themeMode';
  static const _backgroundKey = 'backgroundPath';
  static const _backgroundOpacityKey = 'backgroundOpacity';
  static const _planKey = 'planItems';
  static const _journalKey = 'journal';
  static const _reflectionKey = 'reflection';
  static const _showOtherWeeksKey = 'showOtherWeeks';
  static const _paletteKey = 'palette';
  static const _customPaletteKey = 'customPalette';
  static const _fontPathKey = 'fontPath';
  static const _fontNameKey = 'fontName';

  Future<Timetable?> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null
        ? null
        : Timetable.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(Timetable timetable) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(timetable.toJson()),
    );
  }

  Future<int> loadReminderMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_reminderKey) ?? 15;

  Future<void> saveReminderMinutes(int minutes) async {
    await (await SharedPreferences.getInstance()).setInt(_reminderKey, minutes);
  }

  Future<List<CustomEvent>> loadCustomEvents() async =>
      _loadList(_eventsKey, CustomEvent.fromJson);

  Future<void> saveCustomEvents(List<CustomEvent> events) =>
      _saveList(_eventsKey, events.map((event) => event.toJson()));

  Future<List<PlanItem>> loadPlanItems() async =>
      _loadList(_planKey, PlanItem.fromJson);

  Future<void> savePlanItems(List<PlanItem> items) =>
      _saveList(_planKey, items.map((item) => item.toJson()));

  Future<List<JournalEntry>> loadJournal() async =>
      _loadList(_journalKey, JournalEntry.fromJson);

  Future<void> saveJournal(List<JournalEntry> entries) =>
      _saveList(_journalKey, entries.map((entry) => entry.toJson()));

  Future<ReflectionSettings> loadReflection() async {
    final value = (await SharedPreferences.getInstance()).getString(
      _reflectionKey,
    );
    return value == null
        ? const ReflectionSettings()
        : ReflectionSettings.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          );
  }

  Future<void> saveReflection(ReflectionSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(
      _reflectionKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<bool> loadShowOtherWeeks() async =>
      (await SharedPreferences.getInstance()).getBool(_showOtherWeeksKey) ??
      true;

  Future<void> saveShowOtherWeeks(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(
      _showOtherWeeksKey,
      value,
    );
  }

  Future<AppearanceSettings> loadAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    final modeName = preferences.getString(_themeKey) ?? 'system';
    return AppearanceSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => AppThemeMode.system,
      ),
      backgroundPath: preferences.getString(_backgroundKey),
      backgroundOpacity: preferences.getDouble(_backgroundOpacityKey) ?? 0.25,
      paletteId: preferences.getString(_paletteKey) ?? defaultPaletteId,
      customPalette: _decodePalette(preferences.getString(_customPaletteKey)),
      fontPath: preferences.getString(_fontPathKey),
      fontName: preferences.getString(_fontNameKey),
    );
  }

  static AppPalette? _decodePalette(String? value) {
    if (value == null) return null;
    try {
      return AppPalette.fromJson(
        (jsonDecode(value) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setOrRemove(
    SharedPreferences preferences,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<void> saveAppearance(AppearanceSettings appearance) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, appearance.themeMode.name);
    if (appearance.backgroundPath == null) {
      await preferences.remove(_backgroundKey);
    } else {
      await preferences.setString(_backgroundKey, appearance.backgroundPath!);
    }
    await preferences.setDouble(
      _backgroundOpacityKey,
      appearance.backgroundOpacity,
    );
    await preferences.setString(_paletteKey, appearance.paletteId);
    await _setOrRemove(
      preferences,
      _customPaletteKey,
      appearance.customPalette == null
          ? null
          : jsonEncode(appearance.customPalette!.toJson()),
    );
    await _setOrRemove(preferences, _fontPathKey, appearance.fontPath);
    await _setOrRemove(preferences, _fontNameKey, appearance.fontName);
  }

  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return [];
    return (jsonDecode(value) as List)
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveList(
    String key,
    Iterable<Map<String, dynamic>> items,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(items.toList()),
    );
  }
}
