import 'theme_palette.dart';

enum AppThemeMode { system, light, dark }

class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.backgroundPath,
    this.backgroundOpacity = 0.25,
    this.paletteId = defaultPaletteId,
    this.customPalette,
    this.fontPath,
    this.fontName,
  });

  final AppThemeMode themeMode;
  final String? backgroundPath;
  final double backgroundOpacity;

  /// One of [builtInPalettes]' ids, or [customPaletteId] for [customPalette].
  final String paletteId;

  /// A palette the user imported (海纳 JSON, base16, VS Code, CSS variables).
  final AppPalette? customPalette;

  /// A font file the user imported, copied into the app's documents folder.
  final String? fontPath;

  /// The font's display name (its file name without the extension).
  final String? fontName;

  AppPalette get palette => paletteById(paletteId, custom: customPalette);

  /// The family the imported font is registered under. Every import gets a
  /// new file name (and so a new family), because the engine cannot replace
  /// a family once it is loaded.
  String? get fontFamily => fontPath == null
      ? null
      : 'UserFont_${fontPath!.split(RegExp(r'[/\\\\]')).last}';

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    String? backgroundPath,
    bool removeBackground = false,
    double? backgroundOpacity,
    String? paletteId,
    AppPalette? customPalette,
    bool removeCustomPalette = false,
    String? fontPath,
    String? fontName,
    bool removeFont = false,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    backgroundPath: removeBackground
        ? null
        : backgroundPath ?? this.backgroundPath,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    paletteId: paletteId ?? this.paletteId,
    customPalette: removeCustomPalette
        ? null
        : customPalette ?? this.customPalette,
    fontPath: removeFont ? null : fontPath ?? this.fontPath,
    fontName: removeFont ? null : fontName ?? this.fontName,
  );
}
