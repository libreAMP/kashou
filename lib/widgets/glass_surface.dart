import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/radii.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(rXl)),
    this.blur = 24,
    this.tintOpacity = 0.62,
    this.padding = EdgeInsets.zero,
    this.shadow = false,
    this.shadowOffset = const Offset(0, 8),
    this.shadowBlur = 28,
    this.rimOpacity,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double tintOpacity;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final Offset shadowOffset;
  final double shadowBlur;
  final double? rimOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tint = Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? 0.06 : 0.03),
      scheme.surface,
    ).withValues(alpha: tintOpacity);
    final sheen = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: dark ? 0.08 : 0.2),
        Colors.white.withValues(alpha: 0),
        Colors.black.withValues(alpha: dark ? 0.1 : 0.02),
      ],
      stops: const [0, 0.52, 1],
    );
    final rim = Colors.white.withValues(
      alpha: rimOpacity ?? (dark ? 0.16 : 0.6),
    );

    Widget glass = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: ColoredBox(color: tint),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: sheen),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: rim),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shadow) {
      glass = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.32 : 0.14),
              blurRadius: shadowBlur,
              offset: shadowOffset,
            ),
          ],
        ),
        child: glass,
      );
    }

    return glass;
  }
}
