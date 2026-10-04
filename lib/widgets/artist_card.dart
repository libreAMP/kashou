import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist.dart';
import '../providers/audio_provider.dart';
import '../models/track.dart';
import '../services/ytmusic_service.dart';
import '../theme/shapes.dart';

class ArtistCard extends StatefulWidget {
  final Artist artist;

  const ArtistCard({super.key, required this.artist});

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  static final Map<String, String> _thumbCache = {};
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void didUpdateWidget(ArtistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.name != widget.artist.name) {
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    final name = widget.artist.name.trim();
    if (name.isEmpty ||
        name.toLowerCase() == 'unknown' ||
        name.toLowerCase() == 'unknown artist') {
      return;
    }
    if (_thumbCache.containsKey(name)) {
      final cached = _thumbCache[name];
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() => _thumbUrl = cached);
      }
      return;
    }

    final key = 'artist_thumb_${name.toLowerCase()}';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(key);
    if (saved != null) {
      _thumbCache[name] = saved;
      if (saved.isNotEmpty && mounted) {
        setState(() => _thumbUrl = saved);
      }
      return;
    }

    final thumb = await const YtMusicService().findArtistThumb(name);
    _thumbCache[name] = thumb ?? '';
    await prefs.setString(key, thumb ?? '');
    if (thumb != null && mounted) {
      setState(() => _thumbUrl = thumb);
    }
  }

  Widget _fallbackLetter(ColorScheme scheme) {
    return Center(
      child: Text(
        widget.artist.name.isNotEmpty
            ? widget.artist.name[0].toUpperCase()
            : '?',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = _thumbUrl != null && _thumbUrl!.isNotEmpty;

    return InkWell(
      onTap: () => _showArtistDetails(context),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: scheme.primaryContainer,
              shape: const WavyCircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: _thumbUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      placeholder: (_, __) => _fallbackLetter(scheme),
                      errorWidget: (_, __, ___) => _fallbackLetter(scheme),
                    )
                  : _fallbackLetter(scheme),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.artist.trackCount} songs',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showArtistDetails(BuildContext context) {
    final hasImage = _thumbUrl != null && _thumbUrl!.isNotEmpty;
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
                        backgroundImage: hasImage
                            ? CachedNetworkImageProvider(_thumbUrl!)
                            : null,
                        child: !hasImage
                            ? Text(
                                widget.artist.name.isNotEmpty
                                    ? widget.artist.name[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.artist.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.artist.albumCount} albums • ${widget.artist.trackCount} songs',
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
                              if (widget.artist.tracks.isNotEmpty) {
                                audio.playTrack(
                                  widget.artist.tracks.first,
                                  playlist: widget.artist.tracks,
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
                              final shuffled = List.from(widget.artist.tracks)
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
      itemCount: widget.artist.albums.length,
      itemBuilder: (context, index) {
        final album = widget.artist.albums[index];
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
      itemCount: widget.artist.tracks.length,
      itemBuilder: (context, index) {
        final track = widget.artist.tracks[index];
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
            audio.playTrack(track, playlist: widget.artist.tracks);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
