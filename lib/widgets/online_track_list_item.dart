import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/online_track.dart';
import '../providers/audio_provider.dart';
import '../providers/online_music_provider.dart';

class OnlineTrackListItem extends StatelessWidget {
  const OnlineTrackListItem({super.key, required this.track, this.onTap});

  final OnlineTrack track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium;

    return ListTile(
      leading: track.thumbnails != null && track.thumbnails!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: track.thumbnails!.first['url'] ?? '',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 48,
                  height: 48,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note, size: 24),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.cloud, size: 24),
                ),
              ),
            )
          : Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Icon(Icons.cloud, size: 24),
            ),
      title: Text(
        track.title,
        style: titleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist} • ${track.album}',
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap ?? () async {
        final audioProvider = context.read<AudioProvider>();
        final onlineProvider = context.read<OnlineMusicProvider>();
        try {
          await audioProvider.playTrack(track, playlist: onlineProvider.searchResults);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback failed: ${e.toString()}')),
          );
        }
      },
    );
  }
}
