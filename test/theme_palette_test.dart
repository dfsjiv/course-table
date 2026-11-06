import 'dart:ui';

import 'package:course_table/appearance.dart';
import 'package:course_table/theme_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a 海纳 JSON palette with both modes', () {
    final palette = parsePalette('''{
      "name": "My Theme",
      "light": { "bg": "#fafafa", "surface": "#ffffff", "ink": "#24292f", "accent": "#0969da" },
      "dark":  { "bg": "#0d1117", "surface": "#161b22", "ink": "#e6edf3", "accent": "#58a6ff" }
    }''')!;
    expect(palette.label, 'My Theme');
    expect(palette.light.accent, const Color(0xFF0969DA));
    expect(palette.dark.bg, const Color(0xFF0D1117));
    // Missing fields are derived.
    expect(palette.light.cta, palette.light.accent);
  });

  test('reads a base16 YAML scheme', () {
    final palette = parsePalette('''
scheme: "Tomorrow Night"
base00: "1d1f21"
base01: "282a2e"
base05: "c5c8c6"
base0D: "81a2be"
''')!;
    expect(palette.label, 'Tomorrow Night');
    expect(palette.light.bg, const Color(0xFF1D1F21));
    expect(palette.light.accent, const Color(0xFF81A2BE));
  });

  test('reads CSS variables', () {
    final palette = parsePalette(
      ':root { --bg: #ffffff; --ink: #111111; --accent: #e5484d; }',
    )!;
    expect(palette.light.accent, const Color(0xFFE5484D));
  });

  test('rejects text that is not a palette', () {
    expect(parsePalette('hello'), isNull);
    expect(parsePalette('{"a": 1}'), isNull);
  });

  test('imported palette survives a JSON round trip', () {
    final palette = parsePalette('{"bg":"#fff","ink":"#000","accent":"#f00"}')!;
    final again = AppPalette.fromJson(palette.toJson())!;
    expect(again.light.accent, palette.light.accent);
    expect(again.dark.ink, palette.dark.ink);
  });

  test('unknown palette ids fall back to the default', () {
    const settings = AppearanceSettings(paletteId: 'gone');
    expect(settings.palette.id, defaultPaletteId);
  });

  test('deepen gives white text enough contrast', () {
    for (final palette in builtInPalettes) {
      for (final base in [palette.light, palette.dark]) {
        expect(
          contrast(deepen(base.accent), const Color(0xFFFFFFFF)),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}
