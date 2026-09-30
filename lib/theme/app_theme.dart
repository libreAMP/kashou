import 'package:flutter/material.dart';
import 'radii.dart';

// m3 expressive motion tokens
abstract class EMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

class M3ESliderThumbShape extends SliderComponentShape {
  const M3ESliderThumbShape({required this.holeColor});

  final Color holeColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromHeight(28);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: 4, height: 24);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = sliderTheme.thumbColor ?? Colors.black,
    );
  }
}

SliderThemeData m3eSliderTheme(BuildContext context, {Color? holeColor}) {
  final scheme = Theme.of(context).colorScheme;
  return SliderThemeData(
    trackHeight: 16,
    trackShape: const RoundedRectSliderTrackShape(),
    activeTrackColor: scheme.primary,
    inactiveTrackColor: scheme.surfaceContainerHighest,
    thumbColor: scheme.primary,
    overlayColor: scheme.primary.withValues(alpha: 0.12),
    thumbShape: M3ESliderThumbShape(
      holeColor: holeColor ?? scheme.surfaceContainerHigh,
    ),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
  );
}

ThemeData buildKashouTheme(ColorScheme scheme, TextTheme text) {
  final boldText = text.copyWith(
    headlineMedium: text.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: boldText,
    splashFactory: InkSparkle.splashFactory,
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rXl)),
      titleTextStyle: boldText.headlineMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      contentTextStyle: boldText.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(rXl)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rXl),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      textStyle: boldText.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rXl),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
