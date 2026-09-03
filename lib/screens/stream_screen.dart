import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/settings_provider.dart';
import '../services/youtube/youtube_service.dart';
import '../services/ytmusic_service.dart';
import '../theme/radii.dart';
import '../widgets/art_card.dart';
import '../widgets/square_art.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/fade_rise.dart';
import 'artist_screen.dart';
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
  final YtMusicService _ytm = const YtMusicService();

  List<Map<String, dynamic>> _homeShelves = const [];
  List<Map<String, dynamic>> _moodSections = const [];
  List<Map<String, dynamic>> _searchResults = const [];
  List<Map<String, dynamic>> _searchPlaylists = const [];
  List<Map<String, dynamic>> _searchAlbums = const [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _songsExpanded = false;
  bool _exploreOpen = false;
  String _currentQuery = '';
  String? _error;
  String _searchFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounceTimer;

  String? _lastTrackId;
  DateTime _lastRecFetch = DateTime.fromMillisecondsSinceEpoch(0);
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

      // history loads async from prefs
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      if (audioProvider.streamHistory.isNotEmpty) {
        rec.fetchPersonalizedFromHistory(audioProvider.streamHistory);
      } else {
        rec.loadInitialRecommendations();
      }
      if (audioProvider.currentTrack != null) {
        rec.updateRecommendations(audioProvider.currentTrack,
            audioProvider: audioProvider);
      }

      _audioListener = () {
        final current = audioProvider.currentTrack;
        if (current == null || current.id == _lastTrackId) return;
        _lastTrackId = current.id;
        // one innertube radio call per track change adds up fast
        if (DateTime.now().difference(_lastRecFetch) <
            const Duration(minutes: 3)) {
          return;
        }
        _lastRecFetch = DateTime.now();
        rec.updateRecommendations(current, audioProvider: audioProvider);
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
      // the service swallows failures into empty lists
      if (results[0].isEmpty && results[1].isEmpty) {
        setState(() {
          _error = 'No internet connection.';
          _isLoading = false;
        });
        return;
      }
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
      _songsExpanded = false;
      _searchFilter = 'All';
    });
    try {
      final results = await Future.wait([
        _ytm.searchSongs(query),
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
    _rememberSearch();
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

  // a tap while a query is live means the search paid off, remember it
  void _rememberSearch() {
    if (_currentQuery.isEmpty) return;
    context.read<SettingsProvider>().addSearchTerm(_currentQuery);
  }

  Future<void> _playVideo(Map<String, dynamic> video) async {
    _rememberSearch();
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
      artistId: video['artistId'] as String?,
      views: video['views'] as String?,
    );

    await audioProvider.prepareTrackLoad(placeholder);

    try {
      var streamInfo = await YoutubeService.instance.fetchStreams(videoId);
      if (streamInfo == null || streamInfo.audioStreams.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 800));
        streamInfo = await YoutubeService.instance
            .fetchStreams(videoId, forceRefresh: true);
      }
      if (streamInfo == null || streamInfo.audioStreams.isEmpty) {
        audioProvider.cancelPendingTrack(videoId);
        _snack('Unable to load audio stream.');
        return;
      }

      final mp4 = streamInfo.audioStreams
          .where((s) => s.mimeType.contains('mp4'))
          .toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final stream = mp4.isNotEmpty ? mp4.first : streamInfo.audioStreams.first;

      final finalTrack = placeholder.copyWith(
        path: stream.url,
        loudnessDb: streamInfo.loudnessDb,
      );

      await audioProvider.playTrack(finalTrack);

      // hqdefault has black bars baked in
      http
          .get(Uri.parse('https://i.ytimg.com/vi/$videoId/maxresdefault.jpg'))
          .then((resp) {
        if (resp.statusCode == 200) {
          audioProvider.updateTrackMetadata(
              finalTrack.copyWith(albumArt: resp.bodyBytes));
        } else {
          return http
              .get(Uri.parse('https://i.ytimg.com/vi/$videoId/mqdefault.jpg'))
              .then((r2) {
            if (r2.statusCode == 200) {
              audioProvider.updateTrackMetadata(
                  finalTrack.copyWith(albumArt: r2.bodyBytes));
            }
          });
        }
      });
    } catch (e) {
      audioProvider.cancelPendingTrack(videoId);
      _snack('Error loading audio: $e');
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // prefer the square music art, fall back to a clean 16:9 frame
  String? _videoThumb(Map<String, dynamic> v) {
    final thumb = v['thumbnail'] as String?;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final id = v['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
    }
    return null;
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
                onSubmitted: (q) {
                  context.read<SettingsProvider>().addSearchTerm(q);
                  _search(q);
                },
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
          ...[
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
        _buildFilterChips(context),
        if (_searchResults.isNotEmpty &&
            (_searchFilter == 'All' || _searchFilter == 'Songs')) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: _sectionTitle('Songs'),
          ),
          for (final video in _songsExpanded
              ? _searchResults
              : _searchResults.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSongRow(video),
            ),
          if (!_songsExpanded && _searchResults.length > 5)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _songsExpanded = true),
                child: Text('Show ${_searchResults.length - 5} more'),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (_searchPlaylists.isNotEmpty &&
            (_searchFilter == 'All' || _searchFilter == 'Playlists')) ...[
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
        if (_searchAlbums.isNotEmpty &&
            (_searchFilter == 'All' || _searchFilter == 'Albums')) ...[
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
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final types = <String>[];
    if (_searchResults.isNotEmpty) types.add('Songs');
    if (_searchPlaylists.isNotEmpty) types.add('Playlists');
    if (_searchAlbums.isNotEmpty) types.add('Albums');
    if (types.length < 2) return const SizedBox.shrink();
    final options = ['All', ...types];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              FilterChip(
                label: Text(options[i]),
                selected: _searchFilter == options[i],
                onSelected: (_) => setState(() => _searchFilter = options[i]),
                showCheckmark: false,
                avatar: Icon(
                  options[i] == 'All'
                      ? Icons.check_rounded
                      : options[i] == 'Songs'
                          ? Icons.music_note_rounded
                          : options[i] == 'Playlists'
                              ? Icons.queue_music_rounded
                              : Icons.album_rounded,
                  size: 18,
                ),
                side: BorderSide.none,
                backgroundColor: scheme.surfaceContainerHigh,
                selectedColor: scheme.secondaryContainer,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: TextStyle(
                  color: _searchFilter == options[i]
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExplore(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final recent =
        settings.enableSearchHistory ? settings.searchHistory : const <String>[];
    if (_moodSections.isEmpty && recent.isEmpty) {
      return const Center(child: KashouLoader());
    }
    final bottom = _bottomInset(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (recent.isNotEmpty) ...[
          _sectionTitle('Recent searches'),
          const SizedBox(height: 4),
          // five on screen, the rest surface as these get removed
          for (final q in recent.take(5)) _buildRecentSearchRow(q),
          const SizedBox(height: 20),
        ],
        for (final section in _moodSections) ...[
          _sectionTitle(section['section'] as String? ?? 'Explore'),
          const SizedBox(height: 12),
          _buildMoodGrid((section['items'] as List).cast<Map<String, dynamic>>()),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildRecentSearchRow(String query) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(rSm),
      onTap: () {
        _searchController.text = query;
        _searchController.selection =
            TextSelection.collapsed(offset: query.length);
        _search(query);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: scheme.onSurfaceVariant,
              tooltip: 'Remove',
              onPressed: () =>
                  context.read<SettingsProvider>().removeSearchTerm(query),
            ),
          ],
        ),
      ),
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
                  _buildQuickPicks(
                      {'title': 'Quick picks', 'items': rec.recommendations}),
                if (rec.relatedVideos.isNotEmpty)
                  _buildRecCarousel(
                      'More like what you played', rec.relatedVideos),
              ],
            ),
          ),
          for (var i = 0; i < _homeShelves.length; i++)
            FadeRise(
              index: i,
              child: _buildPlaylistShelf(_homeShelves[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    if (items.isEmpty) return const SizedBox.shrink();
    if (shelf['kind'] == 'songs') return _buildQuickPicks(shelf);
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

  // four song rows per page
  Widget _buildQuickPicks(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    final pageWidth = MediaQuery.of(context).size.width - 56;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(
              (shelf['title'] as String?)?.isNotEmpty == true
                  ? shelf['title'] as String
                  : 'Quick picks'),
        ),
        SizedBox(
          height: 4 * 72,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: pageWidth,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildSongRow(items[i]),
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

  String _songSubtitle(Map<String, dynamic> video) {
    final channel = video['channel'] as String? ?? '';
    final views = video['views'] as String?;
    if (views == null || views.isEmpty) return channel;
    return '$channel · $views';
  }

  Widget _buildSongRow(Map<String, dynamic> video) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = _videoThumb(video);
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final isCurrent = audio.currentTrack?.id == video['id'];
        final playing = isCurrent && audio.isPlaying;
        return Material(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(rMd),
          child: InkWell(
            onTap: () =>
                isCurrent ? audio.togglePlayPause() : _playVideo(video),
            onLongPress: () => _showSongSheet(video),
            borderRadius: BorderRadius.circular(rMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  Stack(
                    children: [
                      SquareArt(url: thumb, size: 56, radius: rSm),
                      if (playing)
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(rSm),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.4),
                              child: Icon(Icons.graphic_eq_rounded,
                                  color: scheme.primary, size: 24),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: isCurrent
                                    ? scheme.primary
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _songSubtitle(video),
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
                  IconButton(
                    icon: Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: isCurrent
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    onPressed: () => isCurrent
                        ? audio.togglePlayPause()
                        : _playVideo(video),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSongSheet(Map<String, dynamic> video) {
    final artistId = video['artistId'] as String?;
    final channel = video['channel'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: SquareArt(url: _videoThumb(video), size: 44, radius: rSm),
              title: Text(video['title'] as String? ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(channel,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Play'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _playVideo(video);
              },
            ),
            if (artistId != null)
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text('Go to $channel'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        ArtistScreen(browseId: artistId, name: channel),
                  ));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
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
