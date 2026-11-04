import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../appearance.dart';
import '../theme_palette.dart';
import 'glass.dart';
import 'tokens.dart';

/// The palette grid in 设置 › 外观, after the 海纳协会 website's picker: one
/// tile per palette with a small preview of its background, card, text and
/// accent in the current mode, plus a tile to import one.
class PaletteGrid extends StatelessWidget {
  const PaletteGrid({
    super.key,
    required this.appearance,
    required this.onPick,
    required this.onImport,
  });

  final AppearanceSettings appearance;
  final ValueChanged<String> onPick;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final dark = MiuixTheme.of(context).brightness == Brightness.dark;
    final custom = appearance.customPalette;
    final tiles = <Widget>[
      for (final palette in builtInPalettes)
        _PaletteTile(
          label: palette.label,
          base: palette.of(dark),
          selected: appearance.paletteId == palette.id,
          onTap: () => onPick(palette.id),
        ),
      if (custom != null)
        _PaletteTile(
          label: custom.label,
          base: custom.of(dark),
          selected: appearance.paletteId == customPaletteId,
          onTap: () => onPick(customPaletteId),
        ),
      _AddTile(label: custom == null ? '导入配色' : '重新导入', onTap: onImport),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final columns = constraints.maxWidth >= 420 ? 4 : 3;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.label,
    required this.base,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ThemeBase base;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Semantics(
      selected: selected,
      child: Tappable(
        onPressed: onTap,
        semanticLabel: '配色 $label',
        feedbackType: MiuixPressFeedbackType.sink,
        shape: MiuixSquircleBorder(cornerRadius: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(
            color: selected ? palette.tint : const Color(0x00000000),
            shape: MiuixSquircleBorder(
              cornerRadius: 16,
              side: BorderSide(
                color: selected ? Brand.accent : palette.line,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 46, child: _Swatch(base)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TypeScale.chip.copyWith(
                  color: palette.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background, a card, a line of text and an accent dot.
class _Swatch extends StatelessWidget {
  const _Swatch(this.base);

  final ThemeBase base;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: ShapeBorderClipper(shape: MiuixSquircleBorder(cornerRadius: 10)),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base.bg),
        Positioned(
          left: 7,
          right: 7,
          bottom: 7,
          height: 16,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: base.surface,
              shape: MiuixSquircleBorder(cornerRadius: 5),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          width: 26,
          height: 5,
          child: ColoredBox(color: base.ink),
        ),
        Positioned(
          right: 8,
          top: 7,
          width: 13,
          height: 13,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: base.accent,
              shape: MiuixSquircleBorder(cornerRadius: 4),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Tappable(
      onPressed: onTap,
      semanticLabel: label,
      feedbackType: MiuixPressFeedbackType.sink,
      shape: MiuixSquircleBorder(cornerRadius: 16),
      child: Container(
        height: 46 + 6 + 18 + 16,
        decoration: ShapeDecoration(
          shape: MiuixSquircleBorder(
            cornerRadius: 16,
            side: BorderSide(color: palette.line),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '+ $label',
          style: TypeScale.chip.copyWith(color: palette.accentText),
        ),
      ),
    );
  }
}

/// Example shown as the placeholder of the import box.
const paletteExample = '''{
  "name": "My Theme",
  "light": { "bg": "#fafafa", "surface": "#ffffff", "ink": "#24292f", "accent": "#0969da" },
  "dark":  { "bg": "#0d1117", "surface": "#161b22", "ink": "#e6edf3", "accent": "#58a6ff" }
}''';
