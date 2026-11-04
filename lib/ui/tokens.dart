import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../theme_palette.dart';
import 'glass.dart';

/// Brand colors, derived from the palette picked in 设置 › 外观 (the same
/// palettes as the 海纳协会 website, see theme_palette.dart).
///
/// [use] is called by the app root on every rebuild, before anything below
/// it builds, so plain getters are enough here.
class Brand {
  static AppPalette palette = builtInPalettes.first;
  static bool _dark = false;

  static void use(AppPalette value, bool dark) {
    palette = value;
    _dark = dark;
  }

  static ThemeBase base(bool dark) => palette.of(dark);

  static final _cache = <(AppPalette, bool), _Derived>{};

  /// Text colors adjusted so they stay readable on every surface the app
  /// draws (each glass kind over each gradient stop, plain and tinted).
  static _Derived _derived(bool dark) =>
      _cache.putIfAbsent((palette, dark), () {
        final b = base(dark);
        final surfaces = [
          for (final kind in GlassKind.values)
            for (final stop in ambientStops(dark))
              over(glassFill(kind, dark), stop),
          b.surface,
          b.bg,
        ];
        final tint = b.accent.withValues(alpha: dark ? 0.18 : 0.14);
        final tinted = [for (final s in surfaces) over(tint, s)];
        final ink = ensureContrast(b.ink, [...surfaces, ...tinted], 7.2);
        final plan = mix(b.surface, b.accent, dark ? 0.28 : 0.2);
        return _Derived(
          ink: ink,
          secondary: ensureContrast(mix(b.ink, b.bg, 0.34), [
            ...surfaces,
            ...tinted,
          ], 4.7),
          text: ensureContrast(b.text, [...surfaces, ...tinted], 4.7),
          planFill: plan,
          planInk: ensureContrast(b.text, [plan], 4.7),
        );
      });

  static Color inkOf(bool dark) => _derived(dark).ink;
  static Color secondaryOf(bool dark) => _derived(dark).secondary;

  /// Accent for lines, bars and borders.
  static Color get accent => base(_dark).accent;

  /// A deep accent that carries white text (the "now" card, today's date).
  static Color get hero => heroOf(_dark);
  static Color heroOf(bool dark) {
    final b = base(dark);
    return deepen(b.accent, toward: dark ? const Color(0xFF000000) : b.ink);
  }

  /// Primary button fill and its text.
  static Color get cta => base(_dark).cta;
  static Color get ctaInk => base(_dark).ctaInk;

  static Color accentText(bool dark) => _derived(dark).text;

  static Color tint(bool dark) =>
      base(dark).accent.withValues(alpha: dark ? 0.18 : 0.14);

  /// Fill and text for a 自学 card in the grid.
  static Color planFill(bool dark) => _derived(dark).planFill;
  static Color planInk(bool dark) => _derived(dark).planInk;

  static MiuixColors light() => _scheme(lightColorScheme(), false);
  static MiuixColors dark() => _scheme(darkColorScheme(), true);

  static MiuixColors _scheme(MiuixColors from, bool dark) {
    final b = base(dark);
    final primary = dark ? b.accent : heroOf(false);
    final secondary = secondaryOf(dark);
    final ink = inkOf(dark);
    return from.copy(
      primary: primary,
      onPrimary: inkOn(primary),
      background: b.bg,
      onBackground: ink,
      surface: b.bg,
      onSurface: ink,
      surfaceContainer: b.surface,
      onSurfaceContainer: ink,
      surfaceVariant: b.surface,
      onSurfaceSecondary: secondary,
      onSurfaceVariantSummary: secondary,
      onBackgroundVariant: secondary,
      secondaryContainer: mix(b.surface, b.ink, dark ? 0.1 : 0.06),
      onSecondaryContainer: secondary,
      dividerLine: b.ink.withValues(alpha: 0.1),
    );
  }
}

class _Derived {
  const _Derived({
    required this.ink,
    required this.secondary,
    required this.text,
    required this.planFill,
    required this.planInk,
  });

  final Color ink;
  final Color secondary;
  final Color text;
  final Color planFill;
  final Color planInk;
}

/// Pastel course colors, each a (fill, ink) pair per brightness.
/// Picked by a stable hash of the course name so a course keeps its color.
class CoursePalette {
  static const _light = [
    (Color(0xFFE3ECFF), Color(0xFF1E4FB0)),
    (Color(0xFFDDF4E8), Color(0xFF14724A)),
    (Color(0xFFFCEFD6), Color(0xFF8A5A06)),
    (Color(0xFFFBE3EE), Color(0xFF9C2F5E)),
    (Color(0xFFECE6FF), Color(0xFF5638B0)),
    (Color(0xFFDDF2F7), Color(0xFF0E6378)),
    (Color(0xFFF3E9DF), Color(0xFF7A4A1E)),
    (Color(0xFFE6F0D9), Color(0xFF3F6A12)),
  ];
  static const _dark = [
    (Color(0xFF1D2B4A), Color(0xFFA9C4FF)),
    (Color(0xFF173A2B), Color(0xFF8FE0B8)),
    (Color(0xFF3E2E10), Color(0xFFF5C873)),
    (Color(0xFF3E1D2C), Color(0xFFF7A6C8)),
    (Color(0xFF2B2347), Color(0xFFC9B5FF)),
    (Color(0xFF183640), Color(0xFF8FD9EC)),
    (Color(0xFF3A2A1C), Color(0xFFE8C29C)),
    (Color(0xFF26331A), Color(0xFFBFE08F)),
  ];

  static (Color fill, Color ink) of(String name, bool dark) {
    // FNV-1a: String.hashCode is not guaranteed stable across runs.
    var hash = 0x811c9dc5;
    for (final unit in name.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final palette = dark ? _dark : _light;
    return palette[hash % palette.length];
  }
}

/// The type scale from the design spec: one family (system MiSans or the
/// font picked in 设置 › 外观), three
/// weights (400 / 500 / 600), nine sizes, 11 at the smallest. Digits are always tabular.
class TypeScale {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(double size, double lineHeight, FontWeight weight) =>
      TextStyle(
        fontSize: size,
        height: lineHeight / size,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: weight,
        fontFeatures: _tabular,
        letterSpacing: 0,
      );

  static final timer = _style(40, 48, FontWeight.w500);
  static final page = _style(32, 40, FontWeight.w600);
  static final prompt = _style(24, 34, FontWeight.w600);
  static final stat = _style(24, 30, FontWeight.w600);
  static final hero = _style(20, 28, FontWeight.w600);
  static final card = _style(18, 26, FontWeight.w600);
  static final listTitle = _style(16, 22, FontWeight.w500);
  static final body = _style(16, 24, FontWeight.w400);
  static final time = _style(14, 20, FontWeight.w500);
  static final value = _style(14, 20, FontWeight.w400);
  static final section = _style(14, 20, FontWeight.w500);
  static final secondary = _style(13, 18, FontWeight.w400);
  static final chip = _style(13, 18, FontWeight.w500);
  static final caption = _style(11, 14, FontWeight.w500);
}

/// Shorthand for the colors pages use most.
class Palette {
  Palette(BuildContext context)
    : colors = MiuixTheme.of(context).colors,
      dark = MiuixTheme.of(context).brightness == Brightness.dark;

  final MiuixColors colors;
  final bool dark;

  static Color inkOf(bool dark) => Brand.inkOf(dark);
  static Color secondaryOf(bool dark) => Brand.secondaryOf(dark);

  Color get ink => inkOf(dark);
  Color get secondary => secondaryOf(dark);
  Color get surface => colors.surface;
  Color get card => colors.surfaceContainer;
  Color get line => colors.dividerLine;
  Color get accentText => Brand.accentText(dark);
  Color get tint => Brand.tint(dark);
  Color get ghostFill {
    final b = Brand.base(dark);
    return mix(b.surface, b.ink, dark ? 0.1 : 0.06);
  }

  Color get ghostInk {
    final b = Brand.base(dark);
    return mix(b.ink, b.bg, 0.5);
  }
}

const weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const weekdayShort = ['一', '二', '三', '四', '五', '六', '日'];

String dateLabel(DateTime date) =>
    '${date.month} 月 ${date.day} 日 ${weekdayNames[date.weekday - 1]}';
