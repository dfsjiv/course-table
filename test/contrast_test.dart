import 'dart:math' as math;

import 'package:course_table/theme_palette.dart' hide contrast;
import 'package:course_table/ui/glass.dart';
import 'package:course_table/ui/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source-over compositing of [top] on an opaque [bottom].
Color over(Color top, Color bottom) => Color.from(
  alpha: 1,
  red: top.r * top.a + bottom.r * (1 - top.a),
  green: top.g * top.a + bottom.g * (1 - top.a),
  blue: top.b * top.a + bottom.b * (1 - top.a),
);

/// WCAG 2 contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final palette in builtInPalettes) {
    group(palette.label, () {
      setUp(() => Brand.palette = palette);
      _checks();
    });
  }
}

void _checks() {
  // Text sits on glass, glass sits somewhere on the ambient gradient: check
  // every gradient stop so no part of the screen falls below WCAG AA.
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final kind in GlassKind.values) {
      for (var i = 0; i < 4; i++) {
        test('$mode ${kind.name} glass over gradient stop $i', () {
          final surface = over(glassFill(kind, dark), ambientStops(dark)[i]);
          expect(contrast(Palette.inkOf(dark), surface), greaterThan(7));
          expect(
            contrast(Palette.secondaryOf(dark), surface),
            greaterThanOrEqualTo(4.5),
          );
        });
        test('$mode accent text on tinted ${kind.name} glass $i', () {
          final surface = over(glassFill(kind, dark), ambientStops(dark)[i]);
          final tinted = over(Brand.tint(dark), surface);
          expect(
            contrast(Brand.accentText(dark), tinted),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  }

  test('white text on the hero card and its badge', () {
    Brand.use(Brand.palette, false);
    const white = Color(0xFFFFFFFF);
    expect(contrast(white, Brand.hero), greaterThanOrEqualTo(4.5));
    expect(
      contrast(white, over(const Color(0x33000000), Brand.hero)),
      greaterThanOrEqualTo(4.5),
    );
    // Secondary hero lines are white at 94 %.
    final dim = over(white.withValues(alpha: 0.94), Brand.hero);
    expect(contrast(dim, Brand.hero), greaterThanOrEqualTo(4.5));
  });
}
