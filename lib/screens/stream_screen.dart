import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../models/youtube_streaming_data.dart';
import '../providers/audio_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../services/ytmusic_service.dart';
import '../theme/radii.dart';
import '../widgets/art_card.dart';
import '../widgets/square_art.dart';
import '../widgets/loading_indicator.dart';
import 'mood_category_screen.dart';
import 'section_page.dart';
import 'youtube_history_screen.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen>
    with AutomaticKeepAliveClientMixin {
  final YtdlWrapperService _service = const YtdlWrapperService();
  final YtMusicService _ytm = const YtMusicService();

  List<Map<String, dynamic>> _homeShelves = const [];
  List<Map<String, dynamic>> _moodSections = const [];
  List<Map<String, dynamic>> _searchResults = const [];
  List<Map<String, dynamic>> _searchPlaylists = const [];
  List<Map<String, dynamic>> _searchAlbums = const [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _exploreOpen = false;
  String _currentQuery = '';
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounceTimer;

  String? _lastTrackId;
  VoidCallback? _audioListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // scrolling closes the keyboard, keep explore open anyway
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_exploreOpen) {
        setState(() => _exploreOpen = true);
      }
    });
    _loadDiscover();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final rec = Provider.of<RecommendationProvider>(context, listen: false);

      rec.loadInitialRecommendations();

      // give stream history a moment to come back from shared prefs
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      if (audioProvider.streamHistory.isNotEmpty) {
        rec.fetchPersonalizedFromHistory(audioProvider.streamHistory);
      }
      if (audioProvider.currentTrack != null) {
        rec.updateRecommendations(audioProvider.currentTrack,
            audioProvider: audioProvider);
      }

      _audioListener = () {
        final current = audioProvider.currentTrack;
        if (current != null && current.id != _lastTrackId) {
          _lastTrackId = current.id;
          rec.updateRecommendations(current, audioProvider: audioProvider);
          if (audioProvider.streamHistory.isNotEmpty) {
            rec.fetchPersonalizedFromHistory(audioProvider.streamHistory);
          }
        }
      };
      audioProvider.addListener(_audioListener!);
    });
  }

  @override
  void dispose() {
    if (_audioListener != null) {
      Provider.of<AudioProvider>(context, listen: false)
          .removeListener(_audioListener!);
    }
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDiscover() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _ytm.getHomeShelves(),
        _ytm.getMoodsAndGenres(),
        _ytm.getNewReleaseAlbums(),
      ]);
      if (!mounted) return;
      setState(() {
        _homeShelves = [
          ...results[0],
          if (results[2].isNotEmpty)
            {'title': 'New albums', 'items': results[2]},
        ];
        _moodSections = results[1];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load discovery. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer =
        Timer(const Duration(milliseconds: 450), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _currentQuery = '';
          _searchResults = const [];
          _searchPlaylists = const [];
          _searchAlbums = const [];
          _isSearching = false;
        });
      }
      return;
    }
    setState(() {
      _currentQuery = query;
      _isSearching = true;
    });
    try {
      final results = await Future.wait([
        _service.search(query, limit: 20, musicOnly: true),
        _ytm.searchPlaylists(query),
        _ytm.searchAlbums(query),
      ]);
      if (mounted) {
        setState(() {
          _searchResults = results[0];
          _searchPlaylists = results[1];
          _searchAlbums = results[2];
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openPlaylist(Map<String, dynamic> playlist) {
    final id = playlist['playlistId'] as String?;
    if (id == null) return;
    final isAlbum = playlist['type'] == 'album';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SectionPage(
        title: playlist['title'] as String? ?? (isAlbum ? 'Album' : 'Playlist'),
        cover: playlist['thumbnail'] as String?,
        itemsFuture:
            isAlbum ? _ytm.getAlbumSongs(id) : _ytm.getPlaylistSongs(id),
        isListView: true,
      ),
    ));
  }

  void _openMood(Map<String, dynamic> mood) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MoodCategoryScreen(
        title: mood['title'] as String? ?? '',
        params: mood['params'] as String,
      ),
    ));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _playVideo(Map<String, dynamic> video) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final videoId = video['id']?.toString() ?? UniqueKey().toString();
    final videoUrl = video['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
    final durationSeconds = _asInt(video['duration']) ?? 0;

    final placeholder = Track(
      id: videoId,
      title: video['title'] as String? ?? 'Unknown',
      artist: video['channel'] as String? ?? 'Unknown',
      album: 'YouTube',
      path: videoUrl,
      duration: Duration(seconds: durationSeconds),
      sourceUrl: videoUrl,
    );

    await audioProvider.prepareTrackLoad(placeholder);

    YouTubeStreamingData? streamingData;
    try {
      streamingData = await _service.fetchStreamingData(videoUrl);
    } catch (_) {
      streamingData = null;
    }

    if (streamingData == null || !streamingData.playable) {
      audioProvider.cancelPendingTrack();
      _snack('Unable to load audio stream.');
      return;
    }

    final selectedFormat =
        streamingData.bestStream ?? streamingData.fallbackStream;
    if (selectedFormat == null) {
      audioProvider.cancelPendingTrack();
      _snack('Audio stream unavailable.');
      return;
    }

    Uint8List? albumArt;
    final thumbUrl = streamingData.thumbnailUrl ?? video['thumbnail'] as String?;
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(thumbUrl));
        if (res.statusCode == 200) albumArt = res.bodyBytes;
      } catch (_) {}
    }

    final finalTrack = placeholder.copyWith(
      title: streamingData.title.isNotEmpty
          ? streamingData.title
          : placeholder.title,
      artist: streamingData.channelName.isNotEmpty
          ? streamingData.channelName
          : placeholder.artist,
      album: 'YouTube',
      path: selectedFormat.url,
      duration: streamingData.duration ?? Duration(seconds: durationSeconds),
      albumArt: albumArt ?? placeholder.albumArt,
      sourceUrl: placeholder.sourceUrl,
    );

    await audioProvider.playTrack(finalTrack);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // mqdefault is clean 16:9, hqdefault has baked black bars
  String? _videoThumb(Map<String, dynamic> v) {
    final id = v['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
    }
    return v['thumbnail'] as String?;
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _exploreOpen = false);
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final searchActive = _exploreOpen || _currentQuery.isNotEmpty;

    // back steps out of search instead of closing the app
    return PopScope(
      canPop: !searchActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildSearchBar(context),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0, 0.04), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_currentQuery.isNotEmpty
                        ? 'results'
                        : _exploreOpen
                            ? 'explore'
                            : 'discover'),
                    child: _buildBody(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _exploreOpen || _currentQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searching
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _closeSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(rMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (!searching) ...[
            const SizedBox(width: 4),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                if (!settings.enableYouTubeIntegration) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'History',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const YoutubeHistoryScreen()),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_currentQuery.isNotEmpty) return _buildSearchResults(context);
    if (_exploreOpen) return _buildExplore(context);
    return _buildDiscover(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_isSearching) {
      return const Center(child: KashouLoader());
    }
    if (_searchResults.isEmpty &&
        _searchPlaylists.isEmpty &&
        _searchAlbums.isEmpty) {
      return _emptyState(Icons.search_off_rounded, 'No results',
          'Try a different search');
    }
    final bottom = _bottomInset(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_searchPlaylists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _sectionTitle('Playlists'),
          ),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _searchPlaylists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => ArtCard(
                thumbnail: _searchPlaylists[i]['thumbnail'] as String?,
                title: _searchPlaylists[i]['title'] as String? ?? '',
                subtitle: _searchPlaylists[i]['subtitle'] as String?,
                onTap: () => _openPlaylist(_searchPlaylists[i]),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_searchAlbums.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _sectionTitle('Albums'),
          ),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _searchAlbums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => ArtCard(
                thumbnail: _searchAlbums[i]['thumbnail'] as String?,
                title: _searchAlbums[i]['title'] as String? ?? '',
                subtitle: _searchAlbums[i]['subtitle'] as String?,
                onTap: () => _openPlaylist(_searchAlbums[i]),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_searchResults.isNotEmpty &&
            (_searchPlaylists.isNotEmpty || _searchAlbums.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: _sectionTitle('Songs'),
          ),
        for (final video in _searchResults)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSongRow(video),
          ),
      ],
    );
  }

  Widget _buildExplore(BuildContext context) {
    if (_moodSections.isEmpty) {
      return const Center(child: KashouLoader());
    }
    final bottom = _bottomInset(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        for (final section in _moodSections) ...[
          _sectionTitle(section['section'] as String? ?? 'Explore'),
          const SizedBox(height: 12),
          _buildMoodGrid((section['items'] as List).cast<Map<String, dynamic>>()),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildMoodGrid(List<Map<String, dynamic>> moods) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width - 40;
    final cardWidth = (width - 12) / 2;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final mood in moods)
          SizedBox(
            width: cardWidth,
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(rMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(rMd),
                onTap: () => _openMood(mood),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Text(
                    mood['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscover(BuildContext context) {
    if (_isLoading) return const Center(child: KashouLoader());
    if (_error != null) {
      return _emptyState(Icons.wifi_off_rounded, 'Offline', _error!,
          onRetry: _loadDiscover);
    }

    final bottom = _bottomInset(context);
    return RefreshIndicator(
      onRefresh: _loadDiscover,
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Discover',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
          Consumer<RecommendationProvider>(
            builder: (context, rec, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rec.recommendations.isNotEmpty)
                  _buildRecCarousel('For you', rec.recommendations),
                if (rec.relatedVideos.isNotEmpty)
                  _buildRecCarousel(
                      'More like what you played', rec.relatedVideos),
              ],
            ),
          ),
          for (final shelf in _homeShelves) _buildPlaylistShelf(shelf),
        ],
      ),
    );
  }

  Widget _buildPlaylistShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(shelf['title'] as String? ?? ''),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecCarousel(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(title),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => ArtCard(
              thumbnail: _videoThumb(items[i]),
              title: items[i]['title'] as String? ?? '',
              subtitle: items[i]['channel'] as String?,
              onTap: () => _playVideo(items[i]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSongRow(Map<String, dynamic> video) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = _videoThumb(video);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playVideo(video),
        borderRadius: BorderRadius.circular(rMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SquareArt(url: thumb, size: 56, radius: rSm),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video['title'] as String? ?? 'Unknown',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video['channel'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.play_arrow_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle,
      {VoidCallback? onRetry}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }

  double _bottomInset(BuildContext context) {
    final audio = Provider.of<AudioProvider>(context, listen: false);
    final safe = MediaQuery.of(context).padding.bottom;
    final mini = audio.currentTrack != null ? 96.0 : 24.0;
    return safe + mini;
  }
}
