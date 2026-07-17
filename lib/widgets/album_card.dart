import 'package:flutter/material.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';
import '../theme/radii.dart';

class AlbumCard extends StatelessWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget fallback() => Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.album_rounded,
              size: 32, color: scheme.onSurfaceVariant),
        );

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen.album(album: album),
          ),
        );
      },
      borderRadius: BorderRadius.circular(rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(rMd),
            child: AspectRatio(
              aspectRatio: 1,
              child: album.albumArt != null
                  ? Image.memory(
                      album.albumArt!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => fallback(),
                    )
                  : fallback(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${album.artist} · ${album.trackCount} songs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
