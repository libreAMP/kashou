import 'package:flutter/material.dart';

// expressive shape scale, kept apart from the legacy radii.dart so nothing breaks
abstract class EShape {
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 28;
  static const double xl = 36;

  static BorderRadius radius(double r) => BorderRadius.circular(r);
}

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
      const Size.fromRadius(13);

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
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      13,
      Paint()..color = sliderTheme.thumbColor ?? Colors.black,
    );
    canvas.drawCircle(center, 5.5, Paint()..color = holeColor);
  }
}

SliderThemeData m3eSliderTheme(BuildContext context, {Color? holeColor}) {
  final scheme = Theme.of(context).colorScheme;
  return SliderThemeData(
    trackHeight: 12,
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
      shape: RoundedRectangleBorder(borderRadius: EShape.radius(EShape.lg)),
      titleTextStyle: boldText.headlineSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(EShape.lg)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: EShape.radius(20)),
      textStyle: boldText.bodyLarge?.copyWith(color: scheme.onSurface),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
