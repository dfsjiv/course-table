import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../app_state.dart';
import 'glass.dart';
import 'icons.dart';
import 'tokens.dart';

/// Fires when the user taps the tab that is already selected; pages use it
/// to scroll back to the top or return to the current week.
class Reselect extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Messages shown at the bottom of the app.
final appSnackbar = MiuixSnackbarHostState();

void toast(String message) => appSnackbar.showSnackbar(message);

/// Makes the [AppState] reachable from any page and rebuilds dependents when
/// it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// A HyperOS line icon by name (extended set, falling back to OS4).
Widget miuixIcon(String name, {double size = 24, Color? tint}) {
  final vector =
      MiuixIcons.extended.byName(name) ?? MiuixIcons.os4.byName(name);
  return MiuixIcon(
    vector: vector ?? MiuixIcons.basic.arrowRight,
    size: size,
    tint: tint,
  );
}

/// A glass card with the standard 12 dp page margin.
class PageCard extends StatelessWidget {
  const PageCard({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget card = GlassSurface(padding: padding, child: child);
    if (onPressed != null) {
      card = Tappable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        feedbackType: MiuixPressFeedbackType.sink,
        shape: MiuixSquircleBorder(cornerRadius: 24),
        child: card,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: card,
    );
  }
}

/// Section label above a card, aligned with the card's content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.icon});

  /// Optional leading icon, one of AppIcons.
  final String? icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 24, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 16, color: palette.secondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              style: TypeScale.section.copyWith(color: palette.secondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Large page title with a meta line above it, used by pages that need
/// controls beside the title instead of a collapsing top bar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.meta,
    this.trailing,
    this.onTitleTap,
  });

  final String title;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meta != null)
          Text(
            meta!,
            style: TypeScale.secondary.copyWith(color: palette.secondary),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TypeScale.page.copyWith(color: palette.ink)),
            if (onTitleTap != null) ...[
              const SizedBox(width: 6),
              CustomPaint(
                size: const Size(14, 9),
                painter: _ChevronDown(palette.secondary),
              ),
            ],
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: onTitleTap == null
                ? titleBlock
                : Tappable(
                    onPressed: onTitleTap,
                    semanticLabel: '选择周次',
                    borderRadius: BorderRadius.circular(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: titleBlock,
                    ),
                  ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Round 44 dp icon button on clear glass.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String icon; // one of AppIcons
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    // 44 dp visual, 48 dp hit area (Android minimum).
    return MergeSemantics(
      child: MiuixPressable(
        onPressed: onPressed,
        semanticLabel: label,
        feedbackType: MiuixPressFeedbackType.sink,
        shape: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Opacity(
              opacity: onPressed == null ? 0.4 : 1,
              child: GlassSurface(
                kind: GlassKind.clear,
                radius: 22,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AppIcon(icon, size: 21, color: palette.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text button on clear glass, e.g. 「本周」 or 「自动排」.
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.accent = false,
    this.icon,
  });

  /// Optional leading icon, one of AppIcons.
  final String? icon;
  final String text;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Tappable(
      onPressed: onPressed,
      feedbackType: MiuixPressFeedbackType.sink,
      shape: MiuixSquircleBorder(cornerRadius: 22),
      semanticLabel: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: GlassSurface(
          kind: GlassKind.clear,
          radius: 22,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      AppIcon(
                        icon!,
                        size: 18,
                        color: accent ? palette.accentText : palette.ink,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      text,
                      style: TypeScale.time.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent ? palette.accentText : palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. the 里 badge.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.leading,
    this.done = false,
  });

  final bool done;

  final String text;
  final Color background;
  final Color foreground;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(leading == null ? 8 : 4, 2, 8, 2),
    decoration: ShapeDecoration(
      color: background,
      shape: MiuixSquircleBorder(cornerRadius: 8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeScale.chip.copyWith(
              color: foreground,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The self-study chip (book-and-spark icon + task) shown inside a class.
class InnerPlanChip extends StatelessWidget {
  const InnerPlanChip({super.key, required this.title, this.done = false});

  final String title;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Semantics(
      label: '自学：$title${done ? '，已完成' : ''}',
      excludeSemantics: true,
      child: Pill(
        text: title,
        done: done,
        background: palette.tint,
        foreground: palette.accentText,
        leading: AppIcon(
          done ? AppIcons.check : AppIcons.study,
          size: 16,
          color: palette.accentText,
          strokeWidth: done ? 2.2 : 1.8,
        ),
      ),
    );
  }
}

/// A plain slide-in page route that needs no Material ancestor.
class SlideRoute<T> extends PageRouteBuilder<T> {
  /// [ambient] paints the app's gradient behind pages that do not bring
  /// their own background.
  SlideRoute(WidgetBuilder builder, {bool ambient = true})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        // Material only supplies the default text style and ink layer that
        // miuix text fields expect; it draws nothing.
        pageBuilder: (context, _, _) => Material(
          type: MaterialType.transparency,
          child: ambient
              ? Stack(
                  fit: StackFit.expand,
                  children: [const AmbientBackground(), builder(context)],
                )
              : builder(context),
        ),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 1, 0.36, 1),
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}

/// Primary (accent gel) full-width button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.expand = true,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool expand;

  /// Optional leading icon, one of AppIcons.
  final String? icon;

  @override
  Widget build(BuildContext context) => GelButton(
    label: text,
    onPressed: onPressed,
    expand: expand,
    icon: icon == null
        ? null
        : AppIcon(icon!, size: 19, color: Brand.ctaInk, strokeWidth: 2),
  );
}

/// Secondary button on clear glass.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.expand = true,
    this.icon,
  });

  /// Optional leading icon, one of AppIcons.
  final String? icon;
  final String text;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final button = Tappable(
      onPressed: onPressed,
      feedbackType: MiuixPressFeedbackType.sink,
      shape: MiuixSquircleBorder(cornerRadius: 18),
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: GlassSurface(
          kind: GlassKind.clear,
          radius: 18,
          shadow: false,
          tint: palette.dark
              ? const Color(0x1FFFFFFF)
              : const Color(0x0F1A1A1A),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    AppIcon(
                      icon!,
                      size: 19,
                      color: palette.ink,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TypeScale.listTitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ChevronDown extends CustomPainter {
  const _ChevronDown(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(1, 1)
        ..lineTo(size.width / 2, size.height - 1)
        ..lineTo(size.width - 1, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronDown old) => old.color != color;
}

/// The one text field the app uses.
///
/// Wraps [MiuixTextField] with two fixes for overlapping text on devices:
///  - the hint is always a placeholder that disappears once there is text.
///    miuix' floating label is drawn 10 px above the first line inside the
///    same 16 px padding; with MiSans' tall line metrics (and with Chinese
///    IME composing text) it lands on top of what is typed.
///  - an explicit line height with even leading, so CJK and Latin glyphs
///    (which come from different fallback fonts with different ascents) sit
///    on one baseline and multi-line text never overlaps the line above.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.singleLine = false,
    this.minLines,
    this.maxLines,
    this.textStyle,
    this.colors,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool singleLine;
  final int? minLines;
  final int? maxLines;
  final TextStyle? textStyle;
  final MiuixTextFieldColors? colors;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final field = MiuixTextField(
      controller: controller,
      label: hint,
      useLabelAsPlaceholder: true,
      singleLine: singleLine,
      minLines: singleLine ? null : minLines,
      maxLines: singleLine ? 1 : maxLines,
      autofocus: autofocus,
      colors: colors,
      textStyle: (textStyle ?? TextStyle(color: palette.ink)).merge(
        const TextStyle(
          // Same size as the miuix placeholder, so nothing jumps when the
          // first character replaces it.
          fontSize: 17,
          height: 24 / 17,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: 0,
        ),
      ),
    );
    // MiuixTextField always paints its text in onBackground and ignores the
    // color in textStyle, so a custom color needs a theme override.
    final ink = textStyle?.color;
    if (ink == null) return field;
    final theme = MiuixTheme.of(context);
    return MiuixTheme(
      data: theme.copyWith(colors: theme.colors.copy(onBackground: ink)),
      child: field,
    );
  }
}
