import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../providers/audio_provider.dart';
import '../models/track.dart';

class AlbumCard extends StatelessWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          _showAlbumDetails(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: album.albumArt != null
                        ? Image.memory(
                            album.albumArt!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.album,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.album,
                              size: 64,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${album.trackCount} songs',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlbumDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.album,
                          size: 80,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        album.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.artist,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${album.trackCount} songs • ${_formatDuration(album.totalDuration)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              final audio = Provider.of<AudioProvider>(
                                context,
                                listen: false,
                              );
                              if (album.tracks.isNotEmpty) {
                                audio.playTrack(
                                  album.tracks.first,
                                  playlist: album.tracks,
                                );
                              }
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              final audio = Provider.of<AudioProvider>(
                                context,
                                listen: false,
                              );
                              final shuffled = List.from(album.tracks)
                                ..shuffle();
                              if (shuffled.isNotEmpty) {
                                audio.playTrack(
                                  shuffled.first,
                                  playlist: shuffled.cast<Track>(),
                                );
                              }
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Shuffle'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: album.tracks.length,
                    itemBuilder: (context, index) {
                      final track = album.tracks[index];
                      return ListTile(
                        leading: Text(
                          '${index + 1}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        title: Text(track.title),
                        subtitle: Text(_formatDuration(track.duration)),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {},
                        ),
                        onTap: () {
                          final audio = Provider.of<AudioProvider>(
                            context,
                            listen: false,
                          );
                          audio.playTrack(track, playlist: album.tracks);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }
}
