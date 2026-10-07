import 'package:flutter/material.dart';
import '../utils/platform.dart';
import 'radii.dart';

// m3 expressive motion tokens
abstract class EMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

SliderThemeData m3eSliderTheme(
  BuildContext context, {
  double trackHeight = 16,
  Size thumbSize = const Size(4, 44),
}) {
  final scheme = Theme.of(context).colorScheme;
  final pressedThumb = Size(2, thumbSize.height);
  return SliderThemeData(
    trackHeight: trackHeight,
    tickMarkShape: const StepDotTickMark(),
    trackShape: const GappedSliderTrackShape(),
    trackGap: 6,
    thumbShape: const HandleThumbShape(),
    thumbSize: WidgetStateProperty.resolveWith<Size?>(
      (states) =>
          states.contains(WidgetState.pressed) ? pressedThumb : thumbSize,
    ),
    activeTrackColor: scheme.primary,
    inactiveTrackColor: scheme.surfaceContainerHighest,
    thumbColor: scheme.primary,
    overlayColor: scheme.primary.withValues(alpha: 0.12),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    valueIndicatorShape: const RoundedRectSliderValueIndicatorShape(),
    showValueIndicator: ShowValueIndicator.onDrag,
  );
}

// flutter skips tick marks it thinks are too dense
class StepDotTickMark extends SliderTickMarkShape {
  const StepDotTickMark({this.radius = 1.5});

  final double radius;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) =>
      const Size(1, 1);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    RoundSliderTickMarkShape(tickMarkRadius: radius).paint(
      context,
      center,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      isEnabled: isEnabled,
    );
  }
}

ThemeData buildKashouTheme(ColorScheme scheme, TextTheme text) {
  var boldText = text.copyWith(
    headlineMedium: text.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  if (isDesktop) {
    boldText = boldText.copyWith(
      titleMedium: boldText.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: boldText.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: boldText.bodyLarge?.copyWith(fontSize: 15),
      bodyMedium: boldText.bodyMedium?.copyWith(fontSize: 13.5),
      bodySmall: boldText.bodySmall?.copyWith(fontSize: 12.5),
      labelLarge: boldText.labelLarge?.copyWith(fontSize: 13.5),
      labelMedium: boldText.labelMedium?.copyWith(fontSize: 12.5),
    );
  }
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
