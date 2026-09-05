import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/radii.dart';

// no size means fill the parent width
class SquareArt extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final double? size;
  final double radius;
  final IconData fallbackIcon;

  const SquareArt({
    super.key,
    this.url,
    this.bytes,
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

    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } else if (url != null && url!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        // rebuilds kept flashing the placeholder over cached art
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => placeholder(),
        errorWidget: (_, __, ___) => fallback(),
      );
    } else {
      image = fallback();
    }
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: art);
    }
    return AspectRatio(aspectRatio: 1, child: art);
  }
}
