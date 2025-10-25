import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';

class TrackListItem extends StatelessWidget {
  final Track track;

  const TrackListItem({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final isPlaying = audio.currentTrack?.id == track.id && audio.isPlaying;
        final isCurrent = audio.currentTrack?.id == track.id;

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPlaying ? Icons.graphic_eq : Icons.music_note,
              color: isCurrent
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            track.title,
            style: TextStyle(
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
              fontWeight: isCurrent ? FontWeight.w600 : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${track.artist} • ${track.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'play_next',
                child: ListTile(
                  leading: Icon(Icons.queue_play_next),
                  title: Text('Play Next'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'add_to_queue',
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('Add to Queue'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'add_to_playlist',
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('Add to Playlist'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Track Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              _handleMenuAction(context, value.toString());
            },
          ),
          onTap: () {
            final library = Provider.of<LibraryProvider>(
              context,
              listen: false,
            );
            audio.playTrack(track, playlist: library.allTracks);
          },
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
              _buildInfoRow('Album', track.album),
              if (track.year != null)
                _buildInfoRow('Year', track.year.toString()),
              if (track.genre != null) _buildInfoRow('Genre', track.genre!),
              if (track.bitrate != null)
                _buildInfoRow('Bitrate', '${track.bitrate} kbps'),
              if (track.sampleRate != null)
                _buildInfoRow('Sample Rate', '${track.sampleRate} Hz'),
              if (track.codec != null) _buildInfoRow('Format', track.codec!),
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
