import 'package:flutter/material.dart';

import '../theme/radii.dart';
import 'square_art.dart';

class ArtCard extends StatelessWidget {
  final String? thumbnail;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double width;

  const ArtCard({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.width = 152,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SquareArt(url: thumbnail, size: width, radius: rMd),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
