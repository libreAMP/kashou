import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/artist.dart';
import '../providers/audio_provider.dart';
import '../models/track.dart';
import '../theme/shapes.dart';

class ArtistCard extends StatelessWidget {
  final Artist artist;

  const ArtistCard({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showArtistDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: scheme.primaryContainer,
                alignment: Alignment.center,
                child: Material(
                  color: scheme.primary.withValues(alpha: 0.25),
                  shape: const WavyCircleBorder(),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Center(
                      child: Text(
                        artist.name[0].toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
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
                    artist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${artist.albumCount} albums',
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${artist.trackCount} songs',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArtistDetails(BuildContext context) {
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
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          artist.name[0].toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        artist.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${artist.albumCount} albums • ${artist.trackCount} songs',
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
                              if (artist.tracks.isNotEmpty) {
                                audio.playTrack(
                                  artist.tracks.first,
                                  playlist: artist.tracks,
                                );
                              }
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play All'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              final audio = Provider.of<AudioProvider>(
                                context,
                                listen: false,
                              );
                              final shuffled = List.from(artist.tracks)
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
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: const [
                            Tab(text: 'Albums'),
                            Tab(text: 'Songs'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildAlbumsList(context, scrollController),
                              _buildSongsList(context, scrollController),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumsList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return ListView.builder(
      controller: scrollController,
      itemCount: artist.albums.length,
      itemBuilder: (context, index) {
        final album = artist.albums[index];
        return ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.album,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(album.name),
          subtitle: Text('${album.trackCount} songs'),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              final audio = Provider.of<AudioProvider>(context, listen: false);
              if (album.tracks.isNotEmpty) {
                audio.playTrack(album.tracks.first, playlist: album.tracks);
              }
              Navigator.pop(context);
            },
          ),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildSongsList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return ListView.builder(
      controller: scrollController,
      itemCount: artist.tracks.length,
      itemBuilder: (context, index) {
        final track = artist.tracks[index];
        return ListTile(
          leading: Text(
            '${index + 1}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          title: Text(track.title),
          subtitle: Text(track.album),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
          onTap: () {
            final audio = Provider.of<AudioProvider>(context, listen: false);
            audio.playTrack(track, playlist: artist.tracks);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
