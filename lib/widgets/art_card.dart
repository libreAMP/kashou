import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import 'square_art.dart';

class ArtCard extends StatelessWidget {
  final String? thumbnail;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double? width;
  final bool emphasized;

  static const double _artGap = 8;
  static const double _titleLine = 22;
  static const double _subLine = 20;

  static double get defaultWidth => isDesktop ? 180.0 : 152.0;

  static double heightFor([double? artWidth, bool emphasized = false]) {
    final base = artWidth ?? defaultWidth;
    final w = (!isDesktop && emphasized) ? base * 1.18 : base;
    return w + _artGap + _titleLine + _subLine;
  }

  const ArtCard({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.width,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = width ?? defaultWidth;
    final cardWidth = (!isDesktop && emphasized) ? base * 1.18 : base;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SquareArt(
              url: thumbnail,
              size: cardWidth,
              radius: emphasized ? rLg : rMd,
            ),
            const SizedBox(height: _artGap),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 15 : 14,
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: isDesktop ? 13 : 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
