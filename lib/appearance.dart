import 'package:flutter/material.dart';

class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.backgroundPath,
    this.backgroundOpacity = 0.25,
  });

  final ThemeMode themeMode;
  final String? backgroundPath;
  final double backgroundOpacity;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    String? backgroundPath,
    bool removeBackground = false,
    double? backgroundOpacity,
  }) =>
      AppearanceSettings(
        themeMode: themeMode ?? this.themeMode,
        backgroundPath:
            removeBackground ? null : backgroundPath ?? this.backgroundPath,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      );
}
