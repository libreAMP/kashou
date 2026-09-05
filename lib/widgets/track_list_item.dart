import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../theme/radii.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final int? index;

  const TrackListItem({super.key, required this.track, this.index});

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
                audio.playTrack(track, playlist: library.allTracks);
              },
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
                    // Track info
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
                    // Menu button with enhanced styling
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'play_next',
                            child: ListTile(
                              leading: Icon(Icons.queue_play_next, size: 20),
                              title: Text('Play Next', style: TextStyle(fontSize: 14)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'add_to_queue',
                            child: ListTile(
                              leading: Icon(Icons.playlist_add, size: 20),
                              title: Text('Add to Queue', style: TextStyle(fontSize: 14)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'add_to_playlist',
                            child: ListTile(
                              leading: Icon(Icons.playlist_add, size: 20),
                              title: Text('Add to Playlist', style: TextStyle(fontSize: 14)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'info',
                            child: ListTile(
                              leading: Icon(Icons.info_outline, size: 20),
                              title: Text('Track Info', style: TextStyle(fontSize: 14)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          _handleMenuAction(context, value.toString());
                        },
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

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'play_next':
        break;
      case 'add_to_queue':
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context);
        break;
      case 'info':
        _showTrackInfo(context);
        break;
    }
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    final library = Provider.of<LibraryProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: library.playlists.length,
              itemBuilder: (context, index) {
                final playlist = library.playlists[index];
                return ListTile(
                  title: Text(playlist.name),
                  onTap: () {
                    library.addToPlaylist(playlist.id, track);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${playlist.name}')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showTrackInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Track Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Title', track.title),
              _buildInfoRow('Artist', track.artist),
              if (track.album.isNotEmpty && track.album != 'YouTube')
                _buildInfoRow('Album', track.album),
              if (track.year != null)
                _buildInfoRow('Year', track.year.toString()),
              if (track.genre != null) _buildInfoRow('Genre', track.genre!),
              if (track.bitrate != null)
                _buildInfoRow('Bitrate', '${track.bitrate} kbps'),
              if (track.sampleRate != null)
                _buildInfoRow('Sample Rate', '${track.sampleRate} Hz'),
              if (track.codec != null) _buildInfoRow('Format', track.codec!),
              if (_ytId(track) != null)
                _buildInfoRow(
                    'Link', 'https://youtube.com/watch?v=${_ytId(track)}'),
              if (!(track.sourceUrl ?? track.path).startsWith('http'))
                _buildInfoRow('Path', track.path),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
