import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../services/ytmusic_service.dart';
import '../theme/radii.dart';
import '../widgets/art_card.dart';
import '../widgets/back_chip.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/square_art.dart';
import 'section_page.dart';

class ArtistScreen extends StatefulWidget {
  final String browseId;
  final String? name;

  const ArtistScreen({super.key, required this.browseId, this.name});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final _ytm = const YtMusicService();
  Map<String, dynamic>? _artist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await _ytm.getArtist(widget.browseId);
    if (!mounted) return;
    setState(() {
      _artist = a;
      _loading = false;
    });
  }

  void _openPlaylist(Map<String, dynamic> pl) {
    final id = pl['playlistId'] as String?;
    if (id == null) return;
    final isAlbum = pl['type'] == 'album';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SectionPage(
        title: pl['title'] as String? ?? 'Album',
        cover: pl['thumbnail'] as String?,
        itemsFuture: isAlbum ? _ytm.getAlbumSongs(id) : _ytm.getPlaylistSongs(id),
        isListView: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _artist?['name'] as String? ?? widget.name ?? 'Artist';
    final songs = (_artist?['songs'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final shelves =
        (_artist?['shelves'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    // creators without a real artist page give us nothing to show
    if (!_loading && songs.isEmpty && shelves.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(name),
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: const BackChip(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_rounded,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No artist page',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '$name doesn\'t have an artist page on YouTube Music.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _loading
          ? const Center(child: KashouLoader())
          : CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: const BackChip(),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    background: _artist?['thumbnail'] != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              SquareArt(
                                  url: _artist!['thumbnail'] as String?,
                                  radius: 0),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black54],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(color: scheme.surfaceContainerHigh),
                  ),
                ),
                if (songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Songs',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: songs.length,
                    itemBuilder: (_, i) => _songRow(songs[i], songs),
                  ),
                ],
                for (final shelf in shelves)
                  SliverToBoxAdapter(child: _buildShelf(shelf)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Track _toTrack(Map<String, dynamic> song) {
    final url = song['url'] as String? ??
        'https://www.youtube.com/watch?v=${song['id']}';
    return Track(
      id: song['id'] as String? ?? '',
      title: song['title'] as String? ?? 'Unknown',
      artist: song['channel'] as String? ?? '',
      album: '',
      path: url,
      duration: Duration.zero,
      sourceUrl: url,
      artistId: song['artistId'] as String? ?? widget.browseId,
      views: song['views'] as String?,
    );
  }

  void _play(Map<String, dynamic> song, List<Map<String, dynamic>> all) {
    final audio = Provider.of<AudioProvider>(context, listen: false);
    audio.playTrack(_toTrack(song), playlist: all.map(_toTrack).toList());
  }

  Widget _songRow(Map<String, dynamic> song, List<Map<String, dynamic>> all) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => _play(song, all),
      leading: SquareArt(
          url: song['thumbnail'] as String?, size: 48, radius: rSm),
      title: Text(song['title'] as String? ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song['channel'] as String? ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Icon(Icons.play_arrow_rounded, color: scheme.onSurfaceVariant),
    );
  }

  Widget _buildShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    final title = shelf['title'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => ArtCard(
              thumbnail: items[i]['thumbnail'] as String?,
              title: items[i]['title'] as String? ?? '',
              subtitle: items[i]['subtitle'] as String?,
              onTap: () => _openPlaylist(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

