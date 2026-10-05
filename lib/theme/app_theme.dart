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

class M3ESliderThumbShape extends SliderComponentShape {
  const M3ESliderThumbShape({
    this.width = 4,
    this.height = 36,
  });

  final double width;
  final double height;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

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
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      Paint()..color = sliderTheme.thumbColor ?? Colors.black,
    );
  }
}

class M3ESliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const M3ESliderTrackShape({
    this.centered = false,
    this.gap = 5.0,
    this.dotRadius = 2.0,
    this.stepCount = 10,
    this.activeDotColor,
    this.inactiveDotColor,
  });

  final bool centered;
  final double gap;
  final double dotRadius;
  final int stepCount;
  final Color? activeDotColor;
  final Color? inactiveDotColor;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 16.0;
    const horizontalMargin = 2.0;
    final trackLeft = offset.dx + horizontalMargin;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - horizontalMargin * 2;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) return;

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blue;
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey;
    final activeDotPaint = Paint()
      ..color = activeDotColor ??
          (sliderTheme.activeTrackColor != null
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.white);
    final inactiveDotPaint = Paint()
      ..color = inactiveDotColor ??
          (sliderTheme.inactiveTrackColor != null
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.35));

    final r = Radius.circular(5.0);
    final midX = (trackRect.left + trackRect.right) / 2;

    if (centered) {
      if ((thumbCenter.dx - midX).abs() <= gap) {
        final leftInactiveEnd = (midX - gap).clamp(trackRect.left, trackRect.right);
        final rightInactiveStart = (midX + gap).clamp(trackRect.left, trackRect.right);
        if (leftInactiveEnd - trackRect.left >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(trackRect.left, trackRect.top, leftInactiveEnd, trackRect.bottom), r),
            inactivePaint,
          );
        }
        if (trackRect.right - rightInactiveStart >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(rightInactiveStart, trackRect.top, trackRect.right, trackRect.bottom), r),
            inactivePaint,
          );
        }
      } else if (thumbCenter.dx > midX) {
        final leftInactiveEnd = (midX - gap).clamp(trackRect.left, trackRect.right);
        final activeStart = (midX + gap).clamp(trackRect.left, trackRect.right);
        final activeEnd = (thumbCenter.dx - gap).clamp(trackRect.left, trackRect.right);
        final rightInactiveStart = (thumbCenter.dx + gap).clamp(trackRect.left, trackRect.right);

        if (leftInactiveEnd - trackRect.left >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(trackRect.left, trackRect.top, leftInactiveEnd, trackRect.bottom), r),
            inactivePaint,
          );
        }
        if (activeEnd - activeStart >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(activeStart, trackRect.top, activeEnd, trackRect.bottom), r),
            activePaint,
          );
        }
        if (trackRect.right - rightInactiveStart >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(rightInactiveStart, trackRect.top, trackRect.right, trackRect.bottom), r),
            inactivePaint,
          );
        }
      } else {
        final leftInactiveEnd = (thumbCenter.dx - gap).clamp(trackRect.left, trackRect.right);
        final activeStart = (thumbCenter.dx + gap).clamp(trackRect.left, trackRect.right);
        final activeEnd = (midX - gap).clamp(trackRect.left, trackRect.right);
        final rightInactiveStart = (midX + gap).clamp(trackRect.left, trackRect.right);

        if (leftInactiveEnd - trackRect.left >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(trackRect.left, trackRect.top, leftInactiveEnd, trackRect.bottom), r),
            inactivePaint,
          );
        }
        if (activeEnd - activeStart >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(activeStart, trackRect.top, activeEnd, trackRect.bottom), r),
            activePaint,
          );
        }
        if (trackRect.right - rightInactiveStart >= 2.0) {
          context.canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(rightInactiveStart, trackRect.top, trackRect.right, trackRect.bottom), r),
            inactivePaint,
          );
        }
      }
    } else {
      final activeEnd = (thumbCenter.dx - gap).clamp(trackRect.left, trackRect.right);
      final inactiveStart = (thumbCenter.dx + gap).clamp(trackRect.left, trackRect.right);

      if (activeEnd - trackRect.left >= 2.0) {
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(trackRect.left, trackRect.top, activeEnd, trackRect.bottom), r),
          activePaint,
        );
      }
      if (trackRect.right - inactiveStart >= 2.0) {
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(inactiveStart, trackRect.top, trackRect.right, trackRect.bottom), r),
          inactivePaint,
        );
      }
    }

    final dotStartY = trackRect.center.dy;
    final dotStartX = trackRect.left + trackRect.height / 2;
    final dotEndX = trackRect.right - trackRect.height / 2;
    final dotSpan = dotEndX - dotStartX;

    if (stepCount > 1 && dotSpan > 0) {
      for (int i = 0; i < stepCount; i++) {
        final dx = dotStartX + dotSpan * (i / (stepCount - 1));
        if ((dx - thumbCenter.dx).abs() < gap + dotRadius) continue;
        if (centered && (dx - midX).abs() < gap + dotRadius) continue;

        final bool isActive;
        if (centered) {
          if (thumbCenter.dx >= midX) {
            isActive = dx >= midX && dx <= thumbCenter.dx;
          } else {
            isActive = dx <= midX && dx >= thumbCenter.dx;
          }
        } else {
          isActive = dx <= thumbCenter.dx;
        }

        context.canvas.drawCircle(
          Offset(dx, dotStartY),
          dotRadius,
          isActive ? activeDotPaint : inactiveDotPaint,
        );
      }
    }
  }
}

SliderThemeData m3eSliderTheme(
  BuildContext context, {
  bool centered = false,
  double trackHeight = 16,
  double thumbHeight = 34,
  double gap = 4.5,
  int stepCount = 10,
}) {
  final scheme = Theme.of(context).colorScheme;
  return SliderThemeData(
    trackHeight: trackHeight,
    tickMarkShape: SliderTickMarkShape.noTickMark,
    trackShape: M3ESliderTrackShape(
      centered: centered,
      gap: gap,
      dotRadius: 1.6,
      stepCount: stepCount,
      activeDotColor: scheme.onPrimary.withValues(alpha: 0.8),
      inactiveDotColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    activeTrackColor: scheme.primary,
    inactiveTrackColor: scheme.surfaceContainerHighest,
    thumbColor: scheme.primary,
    overlayColor: scheme.primary.withValues(alpha: 0.12),
    thumbShape: M3ESliderThumbShape(
      width: 4,
      height: thumbHeight,
    ),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
  );
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
