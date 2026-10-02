import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../providers/audio_provider.dart';
import '../services/ytdl_service.dart';
import '../models/track.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/square_art.dart';
import '../widgets/page_mini_player.dart';
import '../services/ytmusic_service.dart';
import 'artist_screen.dart';

enum ViewMode { grid, list }

class SectionPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Future<List<Map<String, dynamic>>>? itemsFuture;
  final String? cover;
  final bool isListView;

  const SectionPage({
    super.key,
    required this.title,
    this.items = const [],
    this.itemsFuture,
    this.cover,
    this.isListView = false,
  });

  @override
  State<SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<SectionPage> {
  // wide desktop windows center the content instead of stretching it
  static const double _maxContentWidth = 1200;

  ViewMode _viewMode = ViewMode.grid;
  bool _searchOpen = false;
  bool _loadingItems = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Track _trackFor(Map<String, dynamic> video) {
    final videoId = video['id']?.toString() ?? UniqueKey().toString();
    final videoUrl = video['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
    return Track(
      id: videoId,
      title: video['title'] as String? ?? 'Unknown',
      artist: video['channel'] as String? ?? 'Unknown',
      album: '',
      path: videoUrl,
      duration: Duration(seconds: _asInt(video['duration'])),
      sourceUrl: videoUrl,
    );
  }

  Future<void> _playVideo(Map<String, dynamic> video,
      [List<Map<String, dynamic>>? order]) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final tracks = (order ?? _filteredItems).map(_trackFor).toList();
    final id = video['id']?.toString();
    final placeholderTrack = tracks.firstWhere(
      (t) => t.id == id,
      orElse: () => _trackFor(video),
    );

    await audioProvider.prepareTrackLoad(placeholderTrack, playlist: tracks);

    try {
      // youtube_explode leads on desktop, see resolveAudioStream
      final stream = await YtdlWrapperService.resolveAudioStream(
          placeholderTrack.sourceUrl ?? placeholderTrack.path);
      if (stream == null) {
        audioProvider.cancelPendingTrack(placeholderTrack.id);
        _showSnackBar('Unable to load audio stream.');
        return;
      }

      final finalTrack = placeholderTrack.copyWith(
        path: stream.url,
      );

      await audioProvider.playTrack(finalTrack, playlist: tracks);

      final thumb = video['thumbnail'] as String? ??
          'https://i.ytimg.com/vi/${placeholderTrack.id}/hqdefault.jpg';
      http.get(Uri.parse(thumb)).then((resp) {
        if (resp.statusCode == 200) {
          audioProvider.updateTrackMetadata(
              finalTrack.copyWith(albumArt: resp.bodyBytes));
        }
      });
    } catch (e) {
      audioProvider.cancelPendingTrack(placeholderTrack.id);
      _showSnackBar('Error loading audio: $e');
    }
  }
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    _filteredItems = _items;
    _viewMode = widget.isListView ? ViewMode.list : ViewMode.grid;
    _searchController.addListener(_filterItems);

    if (widget.itemsFuture != null) {
      _loadingItems = true;
      widget.itemsFuture!.then((items) {
        if (!mounted) return;
        setState(() {
          _items = items;
          _filteredItems = items;
          _loadingItems = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _loadingItems = false);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((item) {
          final title = (item['title'] as String? ?? '').toLowerCase();
          final channel = (item['channel'] as String? ?? '').toLowerCase();
          return title.contains(query) || channel.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _playAll() async {
    if (_filteredItems.isEmpty) return;
    await _playVideo(_filteredItems.first);
  }

  Future<void> _shufflePlay() async {
    if (_filteredItems.isEmpty) return;
    final shuffled = List<Map<String, dynamic>>.from(_filteredItems)..shuffle();
    await _playVideo(shuffled.first, shuffled);
  }

  // tooltips are desktop-only: on mobile long-press would newly trigger them
  Widget _desktopTooltip(String message, Widget child) {
    if (!isDesktop) return child;
    return Tooltip(message: message, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final Widget body = _loadingItems
        ? Column(
            children: [
              _buildHeader(colorScheme, theme),
              Expanded(child: _buildShimmer(colorScheme)),
            ],
          )
        : _filteredItems.isEmpty && _searchController.text.isEmpty
            ? _buildEmptyState(colorScheme, theme)
            : Column(
                children: [
                  _buildHeader(colorScheme, theme),
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? _buildNoResultsState(colorScheme, theme)
                        : _viewMode == ViewMode.grid
                            ? _buildResponsiveGrid(screenWidth)
                            : _buildEnhancedList(),
                  ),
                ],
              );

    return Scaffold(
      bottomNavigationBar: const PageMiniPlayer(),
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const BackChip(),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchController.clear();
              });
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon:
                Icon(_viewMode == ViewMode.grid ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _viewMode =
                    _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
              });
            },
            tooltip: _viewMode == ViewMode.grid ? 'List view' : 'Grid view',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _maxContentWidth),
                child: body,
              ),
            )
          : body,
    );
  }

  Widget _buildShimmer(ColorScheme colorScheme) {
    Widget bar(double w) => Container(
          width: w,
          height: 12,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: 9,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(rSm),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(190), const SizedBox(height: 8), bar(110)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No items in this section',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme) {
    final cover = widget.cover ??
        (_items.isNotEmpty ? _items.first['thumbnail'] as String? : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SquareArt(url: cover, size: 116, radius: rMd),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadingItems
                          ? 'loading'
                          : '${_items.length} ${_items.isNotEmpty && _items.any((it) => it['playlistId'] != null) ? "items" : "songs"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_items.isEmpty || _items.every((it) => it['playlistId'] == null)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Material(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _filteredItems.isEmpty ? null : _playAll,
                    child: _desktopTooltip(
                      'Play all',
                      SizedBox(
                        width: 104,
                        height: 52,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 30,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: colorScheme.surfaceContainerHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _filteredItems.isEmpty ? null : _shufflePlay,
                    child: _desktopTooltip(
                      'Shuffle play',
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(Icons.shuffle_rounded,
                            size: 22, color: colorScheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_searchOpen) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search in ${widget.title}',
                prefixIcon:
                    Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(rMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid(double screenWidth) {
    // Determine column count based on screen width
    int crossAxisCount;
    double childAspectRatio;

    if (isDesktop) {
      // on desktop the content is centered and capped, so measure the
      // effective content width and allow denser multi-column layouts
      final contentWidth = math.min(screenWidth, _maxContentWidth);
      if (contentWidth >= 1100) {
        crossAxisCount = 6;
        childAspectRatio = 0.68;
      } else if (contentWidth >= 900) {
        crossAxisCount = 5;
        childAspectRatio = 0.69;
      } else if (contentWidth >= 700) {
        crossAxisCount = 4;
        childAspectRatio = 0.70;
      } else {
        crossAxisCount = 3;
        childAspectRatio = 0.72;
      }
    } else if (screenWidth >= 1200) {
      crossAxisCount = 5;
      childAspectRatio = 0.68;
    } else if (screenWidth >= 900) {
      crossAxisCount = 4;
      childAspectRatio = 0.70;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 0.72;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildEnhancedGridItem(_filteredItems[index], index);
      },
    );
  }

  Widget _buildEnhancedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildEnhancedListTile(_filteredItems[index], index);
      },
    );
  }

  Widget _buildEnhancedListTile(Map<String, dynamic> video, int index) {
    final thumbnail = video['thumbnail'] as String?;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playVideo(video),
          borderRadius: BorderRadius.circular(rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SquareArt(
                  url: thumbnail ??
                      'https://i.ytimg.com/vi/${video['id']}/mqdefault.jpg',
                  size: 56,
                  radius: rSm,
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video['title'] ?? 'Unknown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video['channel'] ?? 'Unknown',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Play button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                    onPressed: () => _playVideo(video),
                    padding: EdgeInsets.zero,
                    tooltip: isDesktop ? 'Play' : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedGridItem(Map<String, dynamic> item, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArtist = item['type'] == 'artist';
    final thumbnail = item['thumbnail'] as String? ??
        (item['id'] != null
            ? 'https://img.youtube.com/vi/${item['id']}/maxresdefault.jpg'
            : null);
    final title = item['title'] as String? ?? 'Unknown';
    final subtitle =
        item['channel'] as String? ?? item['subtitle'] as String? ?? '';

    final content = Column(
      crossAxisAlignment:
          isArtist ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (isArtist)
          Center(
            child: ClipOval(
              child: SquareArt(url: thumbnail, radius: 0),
            ),
          )
        else
          SquareArt(url: thumbnail, radius: rMd),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Column(
            crossAxisAlignment: isArtist
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: isArtist ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: isArtist ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(rSm),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: content,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: content,
    );
  }

  void _handleItemTap(Map<String, dynamic> item) {
    if (item['type'] == 'artist') {
      final id = item['playlistId'] as String? ?? item['id'] as String?;
      if (id == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            browseId: id,
            name: item['title'] as String?,
          ),
        ),
      );
      return;
    }
    final playlistId = item['playlistId'] as String?;
    if (playlistId != null) {
      final isAlbum = item['type'] == 'album';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionPage(
            title: item['title'] as String? ?? (isAlbum ? 'Album' : 'Playlist'),
            cover: item['thumbnail'] as String?,
            itemsFuture: isAlbum
                ? const YtMusicService().getAlbumSongs(playlistId)
                : const YtMusicService().getPlaylistSongs(playlistId),
            isListView: true,
          ),
        ),
      );
      return;
    }
    _playVideo(item);
  }
}

