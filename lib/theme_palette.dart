import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// Seven base colors for one brightness, the same set the 海纳协会 website
/// uses (palettes.css): page background, card surface, text, accent, accent
/// text, primary button fill and primary button text. Everything else is
/// derived from these, see [ThemeSpec].
class ThemeBase {
  const ThemeBase({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.accent,
    required this.text,
    required this.cta,
    required this.ctaInk,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color accent;
  final Color text;
  final Color cta;
  final Color ctaInk;

  Map<String, String> toJson() => {
    'bg': hexOf(bg),
    'surface': hexOf(surface),
    'ink': hexOf(ink),
    'accent': hexOf(accent),
    'text': hexOf(text),
    'cta': hexOf(cta),
    'ctaInk': hexOf(ctaInk),
  };

  /// Fills in whatever a partial palette leaves out (only bg / ink / accent
  /// are required).
  static ThemeBase? fromMap(Map<String, Object?> map) {
    Color? pick(List<String> keys) {
      for (final key in keys) {
        final color = parseColor(map[key]);
        if (color != null) return color;
      }
      return null;
    }

    final bg = pick(['bg', 'background', 'p-bg']);
    final ink = pick(['ink', 'foreground', 'fg', 'text-color', 'p-ink']);
    final accent = pick(['accent', 'primary', 'p-accent']);
    if (bg == null || ink == null || accent == null) return null;
    final surface =
        pick(['surface', 'card', 'p-surface']) ??
        (luminance(bg) > 0.5
            ? mix(bg, const Color(0xFFFFFFFF), 0.6)
            : mix(bg, ink, 0.06));
    final text =
        pick(['text', 'accentText', 'accent-text', 'p-text']) ?? accent;
    final cta = pick(['cta', 'p-cta']) ?? accent;
    final ctaInk = pick(['ctaInk', 'cta-ink', 'p-cta-ink']) ?? inkOn(cta);
    return ThemeBase(
      bg: bg,
      surface: surface,
      ink: ink,
      accent: accent,
      text: text,
      cta: cta,
      ctaInk: ctaInk,
    );
  }
}

class AppPalette {
  const AppPalette({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String id;
  final String label;
  final ThemeBase light;
  final ThemeBase dark;

  ThemeBase of(bool isDark) => isDark ? dark : light;

  Map<String, Object> toJson() => {
    'name': label,
    'light': light.toJson(),
    'dark': dark.toJson(),
  };

  static AppPalette? fromJson(Map<String, Object?> json) {
    final light = json['light'];
    final dark = json['dark'];
    final lightBase = light is Map ? ThemeBase.fromMap(light.cast()) : null;
    final darkBase = dark is Map ? ThemeBase.fromMap(dark.cast()) : null;
    if (lightBase == null && darkBase == null) return null;
    return AppPalette(
      id: customPaletteId,
      label: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : '导入的配色',
      light: lightBase ?? darkBase!,
      dark: darkBase ?? lightBase!,
    );
  }
}

const customPaletteId = 'custom';
const defaultPaletteId = 'shanmoew-mizu';

ThemeBase _b(
  int bg,
  int surface,
  int ink,
  int accent,
  int text,
  int cta,
  int ctaInk,
) => ThemeBase(
  bg: Color(0xFF000000 | bg),
  surface: Color(0xFF000000 | surface),
  ink: Color(0xFF000000 | ink),
  accent: Color(0xFF000000 | accent),
  text: Color(0xFF000000 | text),
  cta: Color(0xFF000000 | cta),
  ctaInk: Color(0xFF000000 | ctaInk),
);

/// The built-in palettes, copied from the 海纳协会 website
/// (src/client/styles/palettes.css) so the app and the site look alike.
final builtInPalettes = <AppPalette>[
  AppPalette(
    id: 'shanmoew-mizu',
    label: '水色',
    light: _b(
      0xf2f9fa,
      0xffffff,
      0x102c35,
      0x3e9fb8,
      0x1d6b80,
      0xadd8e6,
      0x0e3340,
    ),
    dark: _b(
      0x0c1a20,
      0x13262e,
      0xe3f3f6,
      0xadd8e6,
      0xbce2e8,
      0xbce2e8,
      0x0c1a20,
    ),
  ),
  AppPalette(
    id: 'hiana',
    label: '海纳橙',
    light: _b(
      0xf6f5f3,
      0xffffff,
      0x1b1a19,
      0xf26b1d,
      0xb8460b,
      0xc2410f,
      0xffffff,
    ),
    dark: _b(
      0x0e0d0c,
      0x1c1a19,
      0xf3f1ee,
      0xff7a2e,
      0xff9a5c,
      0xc2410f,
      0xffffff,
    ),
  ),
  AppPalette(
    id: 'nord',
    label: 'Nord',
    light: _b(
      0xeceff4,
      0xffffff,
      0x2e3440,
      0x5e81ac,
      0x4c6a91,
      0x5e81ac,
      0xffffff,
    ),
    dark: _b(
      0x2e3440,
      0x3b4252,
      0xeceff4,
      0x88c0d0,
      0x88c0d0,
      0x88c0d0,
      0x2e3440,
    ),
  ),
  AppPalette(
    id: 'catppuccin',
    label: 'Catppuccin',
    light: _b(
      0xeff1f5,
      0xffffff,
      0x4c4f69,
      0x8839ef,
      0x8839ef,
      0x8839ef,
      0xffffff,
    ),
    dark: _b(
      0x1e1e2e,
      0x313244,
      0xcdd6f4,
      0xcba6f7,
      0xcba6f7,
      0xcba6f7,
      0x1e1e2e,
    ),
  ),
  AppPalette(
    id: 'tokyo-night',
    label: 'Tokyo Night',
    light: _b(
      0xe6e7ed,
      0xffffff,
      0x343b58,
      0x2e7de9,
      0x2563c9,
      0x2e7de9,
      0xffffff,
    ),
    dark: _b(
      0x1a1b26,
      0x24283b,
      0xc0caf5,
      0x7aa2f7,
      0x7aa2f7,
      0x7aa2f7,
      0x1a1b26,
    ),
  ),
  AppPalette(
    id: 'dracula',
    label: 'Dracula',
    light: _b(
      0xfffbeb,
      0xffffff,
      0x1f1f1f,
      0x644ac9,
      0x644ac9,
      0x644ac9,
      0xffffff,
    ),
    dark: _b(
      0x282a36,
      0x343746,
      0xf8f8f2,
      0xbd93f9,
      0xbd93f9,
      0xbd93f9,
      0x282a36,
    ),
  ),
  AppPalette(
    id: 'gruvbox',
    label: 'Gruvbox',
    light: _b(
      0xfbf1c7,
      0xf9f5d7,
      0x3c3836,
      0xb57614,
      0x9d5f0d,
      0xb57614,
      0xfbf1c7,
    ),
    dark: _b(
      0x282828,
      0x3c3836,
      0xebdbb2,
      0xfabd2f,
      0xfabd2f,
      0xd79921,
      0x282828,
    ),
  ),
  AppPalette(
    id: 'one',
    label: 'One',
    light: _b(
      0xfafafa,
      0xffffff,
      0x383a42,
      0x4078f2,
      0x3366d6,
      0x4078f2,
      0xffffff,
    ),
    dark: _b(
      0x282c34,
      0x2f343e,
      0xabb2bf,
      0x61afef,
      0x61afef,
      0x61afef,
      0x282c34,
    ),
  ),
  AppPalette(
    id: 'solarized',
    label: 'Solarized',
    light: _b(
      0xfdf6e3,
      0xeee8d5,
      0x073642,
      0x268bd2,
      0x1a6fae,
      0x268bd2,
      0xfdf6e3,
    ),
    dark: _b(
      0x002b36,
      0x073642,
      0x93a1a1,
      0x268bd2,
      0x4aa3e0,
      0x268bd2,
      0xfdf6e3,
    ),
  ),
  AppPalette(
    id: 'kanagawa',
    label: 'Kanagawa',
    light: _b(
      0xf2ecbc,
      0xf9f4d2,
      0x545464,
      0x4d699b,
      0x43598a,
      0x4d699b,
      0xf9f4d2,
    ),
    dark: _b(
      0x1f1f28,
      0x2a2a37,
      0xdcd7ba,
      0x7e9cd8,
      0x7e9cd8,
      0x7e9cd8,
      0x1f1f28,
    ),
  ),
  AppPalette(
    id: 'rose-pine',
    label: 'Rosé Pine',
    light: _b(
      0xfaf4ed,
      0xfffaf3,
      0x575279,
      0x907aa9,
      0x7a6592,
      0x7a6592,
      0xfffaf3,
    ),
    dark: _b(
      0x191724,
      0x1f1d2e,
      0xe0def4,
      0xc4a7e7,
      0xc4a7e7,
      0xc4a7e7,
      0x191724,
    ),
  ),
  AppPalette(
    id: 'vesper',
    label: 'Vesper',
    light: _b(
      0xf6f1ea,
      0xffffff,
      0x1c1c1c,
      0xc2662a,
      0xa4521d,
      0xa4521d,
      0xffffff,
    ),
    dark: _b(
      0x101010,
      0x1a1a1a,
      0xe6e6e6,
      0xffc799,
      0xffc799,
      0xffc799,
      0x101010,
    ),
  ),
];

/// Looks up a palette, falling back to the default.
AppPalette paletteById(String id, {AppPalette? custom}) {
  if (id == customPaletteId && custom != null) return custom;
  return builtInPalettes.firstWhere(
    (palette) => palette.id == id,
    orElse: () => builtInPalettes.first,
  );
}

// ---- color math ----

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// WCAG relative luminance.
double luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final x = luminance(a);
  final y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Black or white, whichever reads better on [background].
Color inkOn(Color background) =>
    contrast(background, const Color(0xFFFFFFFF)) >=
        contrast(background, const Color(0xFF111111))
    ? const Color(0xFFFFFFFF)
    : const Color(0xFF111111);

/// Darkens [color] just enough for white text on it to clear 4.5:1, with a
/// margin so slightly dimmed white (94 %) still passes.
Color deepen(Color color, {Color toward = const Color(0xFF000000)}) {
  var result = color;
  for (var step = 1; step <= 20; step++) {
    if (contrast(result, const Color(0xFFFFFFFF)) >= 5) return result;
    result = mix(color, toward, step * 0.05);
  }
  return result;
}

/// Source-over compositing of [top] on an opaque [bottom].
Color over(Color top, Color bottom) => Color.from(
  alpha: 1,
  red: top.r * top.a + bottom.r * (1 - top.a),
  green: top.g * top.a + bottom.g * (1 - top.a),
  blue: top.b * top.a + bottom.b * (1 - top.a),
);

/// Moves [fg] toward black (on light backgrounds) or white (on dark ones)
/// until it reaches [ratio] against every one of [backgrounds]. Imported and
/// low-contrast palettes (Nord, Solarized ...) stay readable this way.
Color ensureContrast(Color fg, List<Color> backgrounds, double ratio) {
  double worst(Color c) =>
      backgrounds.map((b) => contrast(c, b)).reduce(math.min);
  if (worst(fg) >= ratio) return fg;
  final light =
      backgrounds.map(luminance).reduce((a, b) => a + b) / backgrounds.length >
      0.25;
  final target = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  for (var step = 1; step <= 20; step++) {
    final candidate = mix(fg, target, step * 0.05);
    if (worst(candidate) >= ratio) return candidate;
  }
  return target;
}

String hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

final _hex = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

Color? parseColor(Object? value) {
  if (value is! String) return null;
  final text = value.trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
  final match = _hex.firstMatch(text);
  if (match == null) return null;
  var hex = match.group(1)!;
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  return Color(0xFF000000 | int.parse(hex.substring(0, 6), radix: 16));
}

// ---- import ----

/// Reads a palette pasted or picked by the user. Accepts the same formats as
/// the 海纳协会 website:
///  - 海纳 JSON `{ "name", "light": { bg, surface, ink, accent, ... }, "dark": {...} }`
///    (one set is enough);
///  - base16 / base24 schemes, YAML or JSON (`base00` ... `base0F`, also the
///    newer `palette:` layout);
///  - VS Code color theme JSON (`colors` field);
///  - CSS variables `--bg`, `--surface`, `--ink`, `--accent` or `--p-bg` ...
AppPalette? parsePalette(String source, {String fallbackName = '导入的配色'}) {
  final text = source.trim();
  if (text.isEmpty) return null;
  Object? json;
  try {
    json = jsonDecode(_stripJsonComments(text));
  } catch (_) {
    json = null;
  }
  if (json is Map) {
    final map = json.cast<String, Object?>();
    if (map['light'] is Map || map['dark'] is Map) {
      final palette = AppPalette.fromJson({'name': fallbackName, ...map});
      if (palette != null) return palette;
    }
    final base = ThemeBase.fromMap(map);
    if (base != null) {
      return _single(map['name'] as String? ?? fallbackName, base);
    }
    final base16 = _fromBase16(_flatten(map));
    if (base16 != null) {
      return _single(_nameOf(map) ?? fallbackName, base16);
    }
    final colors = map['colors'];
    if (colors is Map) {
      final vscode = _fromVsCode(colors.cast());
      if (vscode != null) return _single(_nameOf(map) ?? fallbackName, vscode);
    }
    return null;
  }
  // YAML (base16) or CSS: collect `key: value` pairs line by line.
  final pairs = <String, Object?>{};
  for (final match in RegExp(
    r'''^\s*(?:--)?([\w-]+)\s*:\s*["']?(#?[0-9a-fA-F]{3,8}|[^"'\n;]+)["']?\s*;?\s*(?:#.*)?$''',
    multiLine: true,
  ).allMatches(text.replaceAll(RegExp(r'[;{}]'), '\n'))) {
    pairs[match.group(1)!] = match.group(2)!.trim();
  }
  final name = (pairs['scheme'] ?? pairs['name']) as String?;
  final base16 = _fromBase16(pairs);
  if (base16 != null) return _single(name ?? fallbackName, base16);
  final css = ThemeBase.fromMap(pairs);
  if (css != null) return _single(name ?? fallbackName, css);
  return null;
}

String _stripJsonComments(String text) => text
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
    .replaceAll(RegExp(r',(\s*[}\]])'), r'$1');

String? _nameOf(Map<String, Object?> map) =>
    (map['name'] ?? map['scheme']) as String?;

Map<String, Object?> _flatten(Map<String, Object?> map) {
  final palette = map['palette'];
  return palette is Map ? {...map, ...palette.cast<String, Object?>()} : map;
}

ThemeBase? _fromBase16(Map<String, Object?> map) {
  Color? at(String key) =>
      parseColor(map[key]) ?? parseColor(map[key.toLowerCase()]);
  final bg = at('base00');
  final surface = at('base01');
  final ink = at('base05');
  final accent = at('base0D');
  if (bg == null || ink == null || accent == null) return null;
  return ThemeBase(
    bg: bg,
    surface: surface ?? bg,
    ink: ink,
    accent: accent,
    text: accent,
    cta: accent,
    ctaInk: inkOn(accent),
  );
}

ThemeBase? _fromVsCode(Map<String, Object?> colors) {
  final bg = parseColor(colors['editor.background']);
  final ink = parseColor(colors['editor.foreground'] ?? colors['foreground']);
  final accent = parseColor(
    colors['button.background'] ??
        colors['focusBorder'] ??
        colors['textLink.foreground'],
  );
  if (bg == null || ink == null || accent == null) return null;
  final cta = accent;
  return ThemeBase(
    bg: bg,
    surface:
        parseColor(
          colors['sideBar.background'] ?? colors['editorWidget.background'],
        ) ??
        bg,
    ink: ink,
    accent: accent,
    text: parseColor(colors['textLink.foreground']) ?? accent,
    cta: cta,
    ctaInk: parseColor(colors['button.foreground']) ?? inkOn(cta),
  );
}

/// A single color set serves both modes (as on the website).
AppPalette _single(String name, ThemeBase base) =>
    AppPalette(id: customPaletteId, label: name, light: base, dark: base);
