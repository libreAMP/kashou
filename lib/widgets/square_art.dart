import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/radii.dart';

// no size means fill the parent width
class SquareArt extends StatelessWidget {
  final String? url;
  final double? size;
  final double radius;
  final IconData fallbackIcon;

  const SquareArt({
    super.key,
    required this.url,
    this.size,
    this.radius = rMd,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget placeholder() => Container(color: scheme.surfaceContainerHighest);
    Widget fallback() => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(fallbackIcon,
              color: scheme.onSurfaceVariant, size: (size ?? 96) * 0.32),
        );

    final art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? fallback()
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => placeholder(),
              errorWidget: (_, __, ___) => fallback(),
            ),
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: art);
    }
    return AspectRatio(aspectRatio: 1, child: art);
  }
}
