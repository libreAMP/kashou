import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist.dart';
import '../providers/audio_provider.dart';
import '../models/track.dart';
import '../services/ytmusic_service.dart';
import '../screens/album_detail_screen.dart';
import '../theme/radii.dart';
import 'm3e_button_group.dart';
import 'm3e_list.dart';
import 'morph_shape.dart';
import 'square_art.dart';
import 'track_options_sheet.dart';

class ArtistCard extends StatefulWidget {
  final Artist artist;

  const ArtistCard({super.key, required this.artist});

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  static final Map<String, String> _thumbCache = {};
  String? _thumbUrl;
  bool _hovered = false;

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
              color: scheme.onTertiaryContainer,
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
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: LayoutBuilder(
                builder: (_, c) => MorphShape(
                  from: MaterialShapes.cookie12Sided,
                  to: MaterialShapes.circle,
                  morphed: _hovered,
                  size: c.maxWidth,
                  color: scheme.tertiaryContainer,
                  child: SizedBox.square(
                    dimension: c.maxWidth,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: _thumbUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: Duration.zero,
                            placeholderFadeInDuration: Duration.zero,
                            placeholder: (_, __) => _fallbackLetter(scheme),
                            errorWidget: (_, __, ___) =>
                                _fallbackLetter(scheme),
                          )
                        : _fallbackLetter(scheme),
                  ),
                ),
              ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _ArtistSheet(
          artist: widget.artist,
          scrollController: scrollController,
          art: _artistArt(Theme.of(sheetContext).colorScheme),
        ),
      ),
    );
  }

  Widget _artistArt(ColorScheme scheme) {
    final hasImage = _thumbUrl != null && _thumbUrl!.isNotEmpty;
    return MorphShape(
      from: MaterialShapes.cookie12Sided,
      size: 136,
      color: scheme.tertiaryContainer,
      child: SizedBox.square(
        dimension: 136,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: _thumbUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackLetter(scheme),
              )
            : _fallbackLetter(scheme),
      ),
    );
  }
}

class _ArtistSheet extends StatefulWidget {
  const _ArtistSheet({
    required this.artist,
    required this.scrollController,
    required this.art,
  });

  final Artist artist;
  final ScrollController scrollController;
  final Widget art;

  @override
  State<_ArtistSheet> createState() => _ArtistSheetState();
}

class _ArtistSheetState extends State<_ArtistSheet> {
  int _tab = 0;

  List<Track> get _tracks => widget.artist.tracks;

  void _play({bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    final queue = List<Track>.of(_tracks);
    if (shuffle) queue.shuffle();
    context.read<AudioProvider>().playTrack(queue.first, playlist: queue);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final artist = widget.artist;

    final rows = _tab == 0 ? _albumRows() : _songRows();
    final header = [
      Center(child: widget.art),
      const SizedBox(height: 20),
      Text(
        artist.name,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
      ),
      const SizedBox(height: 6),
      Text(
        '${artist.albumCount} albums · ${artist.trackCount} songs',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _tracks.isEmpty ? null : _play,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play all'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _tracks.isEmpty ? null : () => _play(shuffle: true),
            style: IconButton.styleFrom(
              fixedSize: const Size(56, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(rMd)),
            ),
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Shuffle',
          ),
        ],
      ),
      const SizedBox(height: 24),
      Center(
        child: M3EButtonGroup(
          labels: const ['Albums', 'Songs'],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
      ),
      const SizedBox(height: 16),
    ];
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      itemCount: header.length + rows.length,
      itemBuilder: (_, i) =>
          i < header.length ? header[i] : rows[i - header.length],
    );
  }

  List<Widget> _albumRows() {
    final albums = widget.artist.albums;
    return [
      for (var i = 0; i < albums.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: M3EListRow(
            label: albums[i].name,
            supportingText: '${albums[i].trackCount} songs',
            leading: SquareArt(
              bytes: albums[i].albumArt,
              size: 48,
              radius: rSm,
              fallbackIcon: Icons.album_rounded,
            ),
            slot: albums.length > 1 ? i : -1,
            count: albums.length,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AlbumDetailScreen.album(album: albums[i]),
            )),
          ),
        ),
    ];
  }

  List<Widget> _songRows() {
    return [
      for (var i = 0; i < _tracks.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: GestureDetector(
            onLongPress: () => showTrackOptionsSheet(context, _tracks[i]),
            child: M3EListRow(
              label: _tracks[i].title,
              supportingText: _tracks[i].album,
              leading: SquareArt(
                bytes: _tracks[i].albumArt,
                size: 48,
                radius: rSm,
              ),
              slot: _tracks.length > 1 ? i : -1,
              count: _tracks.length,
              onTap: () {
                context
                    .read<AudioProvider>()
                    .playTrack(_tracks[i], playlist: _tracks);
                Navigator.pop(context);
              },
            ),
          ),
        ),
    ];
  }
}
