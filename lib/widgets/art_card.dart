import 'package:flutter/material.dart';

import '../theme/radii.dart';
import 'square_art.dart';

class ArtCard extends StatelessWidget {
  final String? thumbnail;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double width;

  static const double _artGap = 8;
  static const double _titleLine = 19;
  static const double _subLine = 16;

  // any slack here shows as a gap
  static double heightFor(double artWidth) =>
      artWidth + _artGap + _titleLine + _subLine;

  final bool emphasized;

  const ArtCard({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.width = 152,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardWidth = emphasized ? width * 1.28 : width;
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
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
