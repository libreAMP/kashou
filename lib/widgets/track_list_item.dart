import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../theme/radii.dart';
import 'track_options_sheet.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final int? index;
  final List<Track>? playlist;
  final String? playlistId;

  const TrackListItem({
    super.key,
    required this.track,
    this.index,
    this.playlist,
    this.playlistId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final isPlaying = audio.currentTrack?.id == track.id && audio.isPlaying;
        final isCurrent = audio.currentTrack?.id == track.id;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(rMd),
            child: InkWell(
              onTap: () {
                final library = Provider.of<LibraryProvider>(
                  context,
                  listen: false,
                );
                audio.playTrack(track, playlist: playlist ?? library.allTracks);
              },
              onLongPress: () =>
                  showTrackOptionsSheet(context, track, playlistId: playlistId),
              borderRadius: BorderRadius.circular(rMd),
              splashColor: colorScheme.primary.withValues(alpha: 0.05),
              highlightColor: colorScheme.primary.withValues(alpha: 0.03),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(rMd),
                  ),
                child: Row(
                  children: [
                    if (index != null) ...[
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$index',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(rSm),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: colorScheme.surfaceContainerHighest,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _artFor(track, colorScheme),
                            if (isPlaying)
                              Container(
                                color: Colors.black.withValues(alpha: 0.4),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(track),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => showTrackOptionsSheet(context, track,
                            playlistId: playlistId),
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _subtitle(Track track) {
    final online = (track.sourceUrl ?? track.path).startsWith('http');
    final tail = online ? 'YouTube' : track.album;
    return tail.isEmpty ? track.artist : '${track.artist} • $tail';
  }

  String? _ytId(Track track) {
    final uri = Uri.tryParse(track.sourceUrl ?? track.path);
    return uri?.queryParameters['v'] ??
        (uri != null &&
                uri.host.contains('youtu.be') &&
                uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : null);
  }

  Widget _artFor(Track track, ColorScheme colorScheme) {
    if (track.albumArt != null) {
      return Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }
    final id = _ytId(track);
    if (id != null) {
      return CachedNetworkImage(
        imageUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: colorScheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }
    return Icon(Icons.music_note,
        color: colorScheme.onSurfaceVariant, size: 24);
  }

}
