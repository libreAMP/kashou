import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/settings_provider.dart';
import '../services/download_manager.dart';
import '../services/ytdl_service.dart';
import '../services/ytmusic_service.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../utils/sheet_scope.dart';
import '../widgets/m3e_badge.dart';
import '../widgets/m3e_refresh.dart';
import '../widgets/art_card.dart';
import '../widgets/dpad_focus.dart';
import '../widgets/square_art.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/fade_rise.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/scrolling_text.dart';
import 'artist_screen.dart';
import 'downloads_screen.dart';
import 'mood_category_screen.dart';
import 'section_page.dart';
import 'youtube_history_screen.dart';

// the skeleton shares these
const int _quickPicksRows = 4;
const double _quickPicksRowHeight = 60;
double get _quickPicksGap => isWideLayout ? 8 : 2;
double get _quickPicksHeight =>
    _quickPicksRows * _quickPicksRowHeight +
    (_quickPicksRows - 1) * _quickPicksGap +
    4;
const EdgeInsets _quickPicksPadding = EdgeInsets.fromLTRB(20, 2, 20, 2);
const EdgeInsets _quickPicksRowPadding = EdgeInsets.fromLTRB(8, 6, 8, 6);
const double _quickPicksColumn = 340;

// width from the layout not MediaQuery
SliverGridDelegate _quickPicksGrid(double width) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _quickPicksRows,
    mainAxisExtent: isWideLayout ? width : width - 48,
    mainAxisSpacing: 12,
    crossAxisSpacing: _quickPicksGap,
  );
}

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

// wide desktop windows get a centered column instead of a stretched phone layout
const double _maxContentWidth = 1200;

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
  AudioProvider? _audioProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // scrolling closes the keyboard, keep explore open anyway
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_exploreOpen) {
        setState(() => _exploreOpen = true);
      } else if (mounted) {
        setState(() {});
      }
    });
    _loadDiscover();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final audioProvider = _audioProvider!;
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
      _audioProvider?.removeListener(_audioListener!);
      _audioListener = null;
    }
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDiscover({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final rec = Provider.of<RecommendationProvider>(context, listen: false);
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      if (refresh) {
        YtMusicService.clearCache();
      }
      final results = await Future.wait([
        _ytm.getHomeShelves(),
        _ytm.getMoodsAndGenres(),
        _ytm.getNewReleaseAlbums(),
        if (refresh)
          audioProvider.streamHistory.isNotEmpty
              ? rec.fetchPersonalizedFromHistory(audioProvider.streamHistory)
              : rec.loadInitialRecommendations(force: true),
        if (refresh) Future.delayed(const Duration(milliseconds: 600)),
      ]);
      if (!mounted) return;
      // the service swallows failures into empty lists
      if (results[0].isEmpty && results[1].isEmpty) {
        if (!refresh) {
          setState(() {
            _error = 'No internet connection.';
            _isLoading = false;
          });
        }
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
      if (!refresh) {
        setState(() {
          _error = 'Could not load discovery. Check your connection.';
          _isLoading = false;
        });
      }
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
    if (playlist['type'] == 'artist') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArtistScreen(
          browseId: id,
          name: playlist['title'] as String?,
        ),
      ));
      return;
    }
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

  void _rememberSearch() {
    if (_currentQuery.isEmpty) return;
    context.read<SettingsProvider>().addSearchTerm(_currentQuery);
  }

  Future<void> _playVideo(Map<String, dynamic> video,
      {List<Track>? playlist}) async {
    _rememberSearch();
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final videoId = video['id']?.toString() ?? UniqueKey().toString();
    final videoUrl = video['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
    final durationSeconds = _asInt(video['duration']) ?? 0;

    final placeholder = Track(
      id: videoId,
      title: video['title'] as String? ?? 'Unknown',
      artist: video['channel'] as String? ?? 'Unknown',
      album: '',
      path: videoUrl,
      duration: Duration(seconds: durationSeconds),
      sourceUrl: videoUrl,
      artistId: video['artistId'] as String?,
      views: video['views'] as String?,
    );

    await audioProvider.prepareTrackLoad(placeholder, playlist: playlist);

    try {
      final stream = await YtdlWrapperService.resolveAudioStream(videoUrl);
      if (stream == null) {
        audioProvider.cancelPendingTrack(videoId);
        _snack('Unable to load audio stream.');
        return;
      }

      final finalTrack = placeholder.copyWith(
        path: stream.url,
        loudnessDb: stream.loudnessDb,
      );

      await audioProvider.playTrack(finalTrack, playlist: playlist);

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

  void _playQuickPicks(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final tracks = items.map((v) {
      final videoId = v['id']?.toString() ?? UniqueKey().toString();
      final videoUrl = v['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
      final durationSeconds = _asInt(v['duration']) ?? 0;
      return Track(
        id: videoId,
        title: v['title'] as String? ?? 'Unknown',
        artist: v['channel'] as String? ?? 'Unknown',
        album: '',
        path: videoUrl,
        duration: Duration(seconds: durationSeconds),
        sourceUrl: videoUrl,
        artistId: v['artistId'] as String?,
        views: v['views'] as String?,
      );
    }).toList();
    _playVideo(items.first, playlist: tracks);
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

    // back leaves search first
    return PopScope(
      canPop: !searchActive && !SheetScope.of(context),
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
                child: _centeredContent(
                  AnimatedSwitcher(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // keeps tight constraints so scrollables inside stay bounded
  Widget _centeredContent(Widget child) {
    if (!isWideLayout) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth - _maxContentWidth;
        if (extra <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _exploreOpen || _currentQuery.isNotEmpty;

    return _centeredContent(
      Padding(
        padding: EdgeInsets.fromLTRB(20, isWideLayout ? 16 : 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: DpadFocus(
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
                      prefixIcon: const Padding(
                        padding: EdgeInsets.fromLTRB(14, 0, 12, 0),
                        child: Icon(Icons.search_rounded),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                          minWidth: 50, maxWidth: 50, minHeight: 0),
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
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
                        borderRadius: BorderRadius.circular(rFull),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: EMotion.fast,
                curve: EMotion.standard,
                alignment: Alignment.centerRight,
                child: searching
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          if (isDesktop)
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Refresh',
                              onPressed: () => _loadDiscover(refresh: true),
                            ),
                          if (!isDesktop)
                            ListenableBuilder(
                            listenable: DownloadManager.instance,
                            builder: (context, _) {
                              final active = DownloadManager.instance.jobs
                                  .where((j) =>
                                      j.status != 'done' &&
                                      j.status != 'failed')
                                  .length;
                              return M3EBadge(
                                count: active,
                                child: IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  tooltip: 'Downloads',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const DownloadsScreen()),
                                  ),
                                ),
                              );
                            },
                          ),
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
                                      builder: (_) =>
                                          const YoutubeHistoryScreen()),
                                ),
                              );
                            },
                          ),
                          if (!isDesktop)
                            IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'Settings',
                            onPressed: () =>
                                Navigator.pushNamed(context, '/settings'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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
      return _emptyState(
          Icons.search_off_rounded, 'No results', 'Try a different search');
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
          for (var i = 0; i < (_songsExpanded ? _searchResults.length : 5); i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 1, 20, 1),
              child: _buildSongRow(
                _searchResults[i],
                i,
                _songsExpanded ? _searchResults.length : 5,
              ),
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
            (_searchFilter == 'All' || _searchFilter == 'Playlists'))
          _buildPlaylistShelf(
              {'title': 'Playlists', 'items': _searchPlaylists}),
        if (_searchAlbums.isNotEmpty &&
            (_searchFilter == 'All' || _searchFilter == 'Albums'))
          _buildPlaylistShelf({'title': 'Albums', 'items': _searchAlbums}),
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
    final chips = [
      for (var i = 0; i < options.length; i++)
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelStyle: TextStyle(
            color: _searchFilter == options[i]
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: isDesktop
          // filter rows are short; wrapping beats a sideways scrollbar
          ? Wrap(spacing: 8, children: chips)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    chips[i],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildExplore(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final recent = settings.enableSearchHistory
        ? settings.searchHistory
        : const <String>[];
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
          const SizedBox(height: 24),
          _buildMoodGrid(
              (section['items'] as List).cast<Map<String, dynamic>>()),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isWideLayout
            ? (constraints.maxWidth / 220).floor().clamp(3, 6).toInt()
            : 2;
        final cardWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
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
      },
    );
  }

  Widget _buildDiscover(BuildContext context) {
    if (_isLoading) return const Center(child: KashouLoader());
    if (_error != null) {
      return _emptyState(Icons.wifi_off_rounded, 'Offline', _error!,
          onRetry: _loadDiscover);
    }

    final bottom = _bottomInset(context);
    return M3ERefresh(
      onRefresh: () => _loadDiscover(refresh: true),
      padding: EdgeInsets.fromLTRB(0, 4, 0, bottom),
      slivers: [
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
              AnimatedSwitcher(
                duration: EMotion.medium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: rec.recommendations.isEmpty && rec.isLoading
                    ? const KeyedSubtree(
                        key: ValueKey('quick_picks_skeleton'),
                        child: _QuickPicksSkeleton(),
                      )
                    : (rec.recommendations.isNotEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('quick_picks_content'),
                            child: _buildQuickPicks({
                              'title': 'Quick picks',
                              'items': rec.recommendations,
                            }),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('quick_picks_empty'))),
              ),
              if (rec.relatedVideos.isNotEmpty)
                _buildRecCarousel(
                    'More like what you played', rec.relatedVideos),
              for (var i = 0; i < _homeShelves.length; i++)
                if (_homeShelves[i]['title'] != 'Quick picks')
                  FadeRise(
                    index: i,
                    child: _buildPlaylistShelf(_homeShelves[i]),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    if (items.isEmpty) return const SizedBox.shrink();
    if (shelf['kind'] == 'songs') return _buildQuickPicks(shelf);
    if (shelf['kind'] == 'artists') return _buildArtistShelf(shelf);
    final title = shelf['title'] as String? ?? '';
    final hasMore = items.length > (isWideLayout ? 6 : 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(
            title,
            trailing: hasMore
                ? TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SectionPage(
                          title: title,
                          items: items,
                        ),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(rFull),
                      ),
                    ),
                    child: const Text('More'),
                  )
                : null,
          ),
        ),
        if (isWideLayout)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - 40;
              final columns = (availableWidth / 170).floor().clamp(4, 6);
              final cardWidth = (availableWidth - (columns - 1) * 16) / columns;
              final rowCount = items.length <= columns ? 1 : 2;
              final maxItems = columns * rowCount;
              final displayItems = items.take(maxItems).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: cardWidth / ArtCard.heightFor(cardWidth),
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (_, i) => ArtCard(
                    thumbnail: displayItems[i]['thumbnail'] as String?,
                    title: displayItems[i]['title'] as String? ?? '',
                    subtitle: displayItems[i]['subtitle'] as String?,
                    onTap: () => _openPlaylist(displayItems[i]),
                    width: cardWidth,
                    emphasized: false,
                  ),
                ),
              );
            },
          )
        else
          SizedBox(
            height: ArtCard.heightFor(),
            child: RepaintBoundary(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length > 10 ? 11 : items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  if (items.length > 10 && i == 10) {
                    return _buildViewAllCard(title, items);
                  }
                  return ArtCard(
                    thumbnail: items[i]['thumbnail'] as String?,
                    title: items[i]['title'] as String? ?? '',
                    subtitle: items[i]['subtitle'] as String?,
                    onTap: () => _openPlaylist(items[i]),
                  );
                },
              ),
            ),
          ),
        SizedBox(height: isDesktop ? 36 : 16),
      ],
    );
  }

  Widget _buildArtistShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strapline = shelf['strapline'] as String?;
    final headerThumb = shelf['headerThumb'] as String?;
    final title = shelf['title'] as String? ?? 'Similar artists';
    final cardSize = isDesktop ? 160.0 : 120.0;
    final cardHeight = cardSize + 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (headerThumb != null) ...[
                ClipOval(
                  child: SquareArt(
                    url: headerThumb,
                    size: 38,
                    radius: 0,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (strapline != null)
                      Text(
                        strapline.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (items.length > 10)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SectionPage(
                        title: title,
                        items: items,
                      ),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    backgroundColor: scheme.surfaceContainerHigh,
                    foregroundColor: scheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(rFull),
                    ),
                  ),
                  child: const Text('More'),
                ),
            ],
          ),
        ),
        if (isWideLayout)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - 40;
              final columns = (availableWidth / 170).floor().clamp(4, 6);
              final cardWidth = (availableWidth - (columns - 1) * 16) / columns;
              final displayItems = items.take(columns).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final a in displayItems)
                      _buildArtistItem(a, cardWidth),
                  ],
                ),
              );
            },
          )
        else
          SizedBox(
            height: cardHeight,
            child: RepaintBoundary(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length > 10 ? 11 : items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  if (items.length > 10 && i == 10) {
                    return _buildViewAllCard(title, items, isCircular: true);
                  }
                  return _buildArtistItem(items[i], cardSize);
                },
              ),
            ),
          ),
        SizedBox(height: isDesktop ? 36 : 16),
      ],
    );
  }

  Widget _buildArtistItem(Map<String, dynamic> artist, double size) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(rMd),
      onTap: () => _openPlaylist(artist),
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SquareArt(
                url: artist['thumbnail'] as String?,
                size: size,
                radius: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist['title'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              artist['subtitle'] as String? ?? 'Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllCard(String title, List<Map<String, dynamic>> items,
      {bool isCircular = false}) {
    final scheme = Theme.of(context).colorScheme;
    final cardW = isDesktop ? 192.0 : 148.0;
    return InkWell(
      borderRadius: BorderRadius.circular(rMd),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionPage(
            title: title,
            items: items,
          ),
        ),
      ),
      child: Container(
        width: cardW,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(isCircular ? rFull : rMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: scheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'View all',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${items.length} items',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // four song rows per page
  Widget _buildQuickPicks(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    final title = (shelf['title'] as String?)?.isNotEmpty == true
        ? shelf['title'] as String
        : 'Quick picks';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(
            title,
            trailing: items.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => _playQuickPicks(items),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Play all'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(rFull),
                      ),
                    ),
                  ),
          ),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth - _quickPicksPadding.horizontal;
          // under two full columns the shelf pages
          final room = (items.length / _quickPicksRows).ceil();
          if (width >= _quickPicksColumn * 2 + _quickPicksGap && room >= 2) {
            final columns = (width / (_quickPicksColumn + _quickPicksGap))
                .floor()
                .clamp(2, 3)
                .clamp(1, room);
            return Padding(
              padding: _quickPicksPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: _quickPicksGap),
                    Expanded(
                      child: Column(
                        children: [
                          for (var r = 0; r < _quickPicksRows; r++)
                            if (c * _quickPicksRows + r < items.length)
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: r == _quickPicksRows - 1
                                        ? 0
                                        : _quickPicksGap),
                                child: _buildSongRow(
                                    items[c * _quickPicksRows + r],
                                    r,
                                    _quickPicksRows),
                              ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          return SizedBox(
            height: _quickPicksHeight,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: _quickPicksPadding,
              gridDelegate: _quickPicksGrid(width),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildSongRow(
                  items[i], i % _quickPicksRows, _quickPicksRows),
            ),
          );
        }),
        SizedBox(height: isDesktop ? 36 : 16),
      ],
    );
  }

  Widget _buildRecCarousel(String title, List<Map<String, dynamic>> items) {
    final hasMore = items.length > 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sectionTitle(
            title,
            trailing: hasMore
                ? TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SectionPage(
                          title: title,
                          items: items,
                        ),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(rFull),
                      ),
                    ),
                    child: const Text('More'),
                  )
                : null,
          ),
        ),
        if (isWideLayout)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - 40;
              final columns = (availableWidth / 170).floor().clamp(4, 6);
              final cardWidth = (availableWidth - (columns - 1) * 16) / columns;
              final rowCount = items.length <= columns ? 1 : 2;
              final maxItems = columns * rowCount;
              final displayItems = items.take(maxItems).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: cardWidth / ArtCard.heightFor(cardWidth),
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (_, i) => ArtCard(
                    thumbnail: _videoThumb(displayItems[i]),
                    title: displayItems[i]['title'] as String? ?? '',
                    subtitle: displayItems[i]['channel'] as String?,
                    onTap: () => _playVideo(displayItems[i]),
                    width: cardWidth,
                    emphasized: false,
                  ),
                ),
              );
            },
          )
        else
          SizedBox(
            height: ArtCard.heightFor(),
            child: RepaintBoundary(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length > 10 ? 11 : items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  if (items.length > 10 && i == 10) {
                    return _buildViewAllCard(title, items);
                  }
                  return ArtCard(
                    thumbnail: _videoThumb(items[i]),
                    title: items[i]['title'] as String? ?? '',
                    subtitle: items[i]['channel'] as String?,
                    onTap: () => _playVideo(items[i]),
                  );
                },
              ),
            ),
          ),
        SizedBox(height: isDesktop ? 36 : 16),
      ],
    );
  }

  String _songSubtitle(Map<String, dynamic> video) {
    final rawChannel = video['channel'] as String? ?? '';
    final channel = rawChannel.replaceAll('Â·', '•').replaceAll('Â', '').trim();
    final rawViews = video['views'] as String?;
    if (rawViews == null || rawViews.isEmpty) return channel;
    final views = rawViews.replaceAll('Â·', '•').replaceAll('Â', '').trim();
    return '$channel • $views';
  }

  Widget _buildSongRow(
    Map<String, dynamic> video, [
    int slot = -1,
    int count = 1,
  ]) {
    if (slot >= 0 && (count <= 1 || slot >= count)) {
      throw ArgumentError('slot $slot out of range for count $count');
    }
    final scheme = Theme.of(context).colorScheme;
    final thumb = _videoThumb(video);
    const outer = Radius.circular(rMd);
    const inner = Radius.circular(rSm);
    final radius = isDesktop
        ? BorderRadius.circular(10)
        : (slot < 0
            ? const BorderRadius.all(inner)
            : slot == 0
                ? const BorderRadius.vertical(top: outer, bottom: inner)
                : slot == count - 1
                    ? const BorderRadius.vertical(top: inner, bottom: outer)
                    : const BorderRadius.all(inner));
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final isCurrent = audio.currentTrack?.id == video['id'];
        final playing = isCurrent && audio.isPlaying;
        return Material(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.12)
              : (isDesktop ? Colors.transparent : scheme.surfaceContainerLow),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            onTap: () =>
                isCurrent ? audio.togglePlayPause() : _playVideo(video),
            onLongPress: () => _showSongSheet(video),
            // right-click mirrors the long-press options on desktop
            onSecondaryTap: isDesktop ? () => _showSongSheet(video) : null,
            child: Padding(
              padding: _quickPicksRowPadding,
              child: Row(
                children: [
                  Stack(
                    children: [
                      SquareArt(url: thumb, size: 48, radius: rSm),
                      if (playing)
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(rSm),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.4),
                              child: Icon(Icons.graphic_eq_rounded,
                                  color: scheme.primary, size: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScrollingText(
                          text: video['title'] as String? ?? 'Unknown',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    color: isCurrent ? scheme.primary : null,
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
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color:
                          isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    iconSize: 22,
                    tooltip: isDesktop ? (playing ? 'Pause' : 'Play') : null,
                    onPressed: () =>
                        isCurrent ? audio.togglePlayPause() : _playVideo(video),
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
    Widget buildContent(BuildContext sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) sheetHandle(sheetContext),
              ListTile(
                leading:
                    SquareArt(url: _videoThumb(video), size: 44, radius: rSm),
                title: Text(video['title'] as String? ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle:
                    Text(channel, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        );
    // bottom sheets are a touch idiom; a dialog fits pointer conventions
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: buildContent(dialogContext),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: buildContent,
    );
  }

  Widget _sectionTitle(String title, {Widget? trailing}) {
    if (trailing == null) {
      return Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
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

class _QuickPicksSkeleton extends StatefulWidget {
  const _QuickPicksSkeleton();

  @override
  State<_QuickPicksSkeleton> createState() => _QuickPicksSkeletonState();
}

class _QuickPicksSkeletonState extends State<_QuickPicksSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final alpha = _pulseAnim.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Quick picks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ),
            LayoutBuilder(builder: (context, constraints) {
              final width =
                  constraints.maxWidth - _quickPicksPadding.horizontal;
              if (width >= _quickPicksColumn * 2 + _quickPicksGap) {
                final columns =
                    (width / (_quickPicksColumn + _quickPicksGap))
                        .floor()
                        .clamp(2, 3);
                return Padding(
                  padding: _quickPicksPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) SizedBox(width: _quickPicksGap),
                        Expanded(
                          child: Column(
                            children: [
                              for (var r = 0; r < _quickPicksRows; r++)
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom: r == _quickPicksRows - 1
                                          ? 0
                                          : _quickPicksGap),
                                  child: _buildSkeletonRow(
                                      scheme, alpha, r, _quickPicksRows),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return SizedBox(
                height: _quickPicksHeight,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: _quickPicksPadding,
                  gridDelegate: _quickPicksGrid(width),
                  itemCount: _quickPicksRows * 2,
                  itemBuilder: (_, i) => _buildSkeletonRow(
                      scheme, alpha, i % _quickPicksRows, _quickPicksRows),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonRow(
    ColorScheme scheme,
    double alpha, [
    int slot = -1,
    int count = _quickPicksRows,
  ]) {
    const outer = Radius.circular(rMd);
    const inner = Radius.circular(rSm);
    final radius = isDesktop
        ? BorderRadius.circular(10)
        : (slot < 0
            ? const BorderRadius.all(inner)
            : slot == 0
                ? const BorderRadius.vertical(top: outer, bottom: inner)
                : slot == count - 1
                    ? const BorderRadius.vertical(top: inner, bottom: outer)
                    : const BorderRadius.all(inner));

    return Material(
      color: isDesktop ? Colors.transparent : scheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: _quickPicksRowPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(rSm),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    margin: const EdgeInsets.only(right: 28),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 110,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: alpha * 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: alpha * 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
