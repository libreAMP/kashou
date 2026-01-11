import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';
import 'online_search_screen.dart';
import 'section_page.dart';
import 'youtube_history_screen.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/recommendation_provider.dart';
import '../services/ytdl_service.dart';
import '../models/track.dart';
import '../models/youtube_streaming_data.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen>
    with AutomaticKeepAliveClientMixin {
  late YtdlWrapperService _service;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _quickPicks = [];
  Map<String, List<Map<String, dynamic>>> _languagePlaylists = {};
  List<Map<String, dynamic>> _trendingSongs = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _currentQuery = '';
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  bool _isInitialized = false;
  String? _lastTrackId; // Track the last track to avoid duplicate updates

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    if (_currentQuery.isNotEmpty) {
      _searchController.text = _currentQuery;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final recommendationProvider =
          Provider.of<RecommendationProvider>(context, listen: false);

      recommendationProvider.loadInitialRecommendations();

      // Wait a bit for stream history to load from SharedPreferences
      await Future.delayed(const Duration(milliseconds: 500));

      if (audioProvider.streamHistory.isNotEmpty) {
        recommendationProvider.fetchPersonalizedFromHistory(
          audioProvider.streamHistory,
        );
      }

      if (audioProvider.currentTrack != null) {
        recommendationProvider.updateRecommendations(
          audioProvider.currentTrack,
          audioProvider: audioProvider,
        );
      }

      audioProvider.addListener(() {
        final currentTrack = audioProvider.currentTrack;

        if (currentTrack != null && currentTrack.id != _lastTrackId) {
          _lastTrackId = currentTrack.id;

          recommendationProvider.updateRecommendations(
            currentTrack,
            audioProvider: audioProvider,
          );

          if (audioProvider.streamHistory.isNotEmpty) {
            recommendationProvider.fetchPersonalizedFromHistory(
              audioProvider.streamHistory,
            );
          }
        }
      });
    });
  }

  void _initializeService() {
    if (_isInitialized) return;

    _service = const YtdlWrapperService();
    _isInitialized = true;
    _loadFeatured();
  }

  @override
  void didUpdateWidget(StreamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentQuery.isNotEmpty && _searchController.text != _currentQuery) {
      _searchController.text = _currentQuery;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeService();
    } else {
      // Service has no dynamic configuration; nothing to update here.
    }
    if (_currentQuery.isNotEmpty && _searchController.text != _currentQuery) {
      _searchController.text = _currentQuery;
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    if (_featured.isNotEmpty) return;
    await _loadDiscoverSections(forceRefresh: true);
  }

  Future<void> _loadDiscoverSections({bool forceRefresh = false}) async {
    if (!forceRefresh && _featured.isNotEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final languages = [
        'Hindi',
        'English',
        'Punjabi',
        'Tamil',
        'Telugu',
        'Kannada',
        'Malayalam',
        'Bengali'
      ];

      final quickPicksFuture = _service.search('popular songs', limit: 20);
      final trendingFuture = _service.search('trending songs', limit: 20);
      final featuredFuture = _service.search('latest music songs', limit: 20);

      final languageFutures = languages
          .map((lang) => _service.search('$lang music playlist', limit: 15))
          .toList();

      final results = await Future.wait([
        quickPicksFuture,
        trendingFuture,
        featuredFuture,
        ...languageFutures,
      ]);

      if (!mounted) return;

      setState(() {
        _quickPicks = results[0];
        _trendingSongs = results[1];
        _featured = results[2];

        for (int i = 0; i < languages.length; i++) {
          _languagePlaylists[languages[i]] = results[3 + i];
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load discovery content. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _currentQuery = '';
          _searchResults = [];
          _isSearching = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _currentQuery = query;
        _isSearching = true;
        _error = null;
      });
    }
    try {
      final results = await _service.search(query, limit: 15);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed. Try again.';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _playVideo(Map<String, dynamic> video) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final videoId = video['id']?.toString() ?? UniqueKey().toString();
    final videoUrl = video['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
    final durationSeconds = _asInt(video['duration']) ?? 0;

    final placeholderTrack = Track(
      id: videoId,
      title: video['title'] as String? ?? 'Unknown',
      artist: video['channel'] as String? ?? 'Unknown',
      album: video['title'] as String? ?? 'YouTube',
      path: videoUrl,
      duration: Duration(seconds: durationSeconds),
      sourceUrl: videoUrl,
    );

    await audioProvider.prepareTrackLoad(placeholderTrack);

    YouTubeStreamingData? streamingData;
    try {
      streamingData = await _service.fetchStreamingData(videoUrl);
    } catch (_) {
      streamingData = null;
    }

    if (streamingData == null || !streamingData.playable) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('Unable to load audio stream.');
      return;
    }

    final selectedFormat =
        streamingData.bestStream ?? streamingData.fallbackStream;
    if (selectedFormat == null) {
      print('[stream_screen] No audio format found!');
      print(
          '[stream_screen] Primary streams: ${streamingData.primaryStreams.length}');
      print(
          '[stream_screen] Fallback streams: ${streamingData.fallbackStreams.length}');
      audioProvider.cancelPendingTrack();
      _showSnackBar('Audio stream unavailable.');
      return;
    }

    print(
        '[stream_screen] Selected format: itag=${selectedFormat.itag}, bitrate=${selectedFormat.bitrateKbps}kbps, type=${selectedFormat.type}');
    print(
        '[stream_screen] Audio URL: ${selectedFormat.url.substring(0, selectedFormat.url.length > 150 ? 150 : selectedFormat.url.length)}...');

    Uint8List? albumArt;
    final thumbUrl =
        streamingData.thumbnailUrl ?? video['thumbnail'] as String?;
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      try {
        final thumbnailResponse = await http.get(Uri.parse(thumbUrl));
        if (thumbnailResponse.statusCode == 200) {
          albumArt = thumbnailResponse.bodyBytes;
        }
      } catch (_) {}
    }

    final finalTrack = placeholderTrack.copyWith(
      title: streamingData.title.isNotEmpty
          ? streamingData.title
          : placeholderTrack.title,
      artist: streamingData.channelName.isNotEmpty
          ? streamingData.channelName
          : placeholderTrack.artist,
      album: 'YouTube',
      path: selectedFormat.url,
      duration: streamingData.duration ?? Duration(seconds: durationSeconds),
      albumArt: albumArt ?? placeholderTrack.albumArt,
      sourceUrl: placeholderTrack.sourceUrl,
    );

    print(
        '[stream_screen] Final track path: ${finalTrack.path.substring(0, finalTrack.path.length > 100 ? 100 : finalTrack.path.length)}...');
    print('[stream_screen] Calling audioProvider.playTrack()');
    await audioProvider.playTrack(finalTrack);
    print('[stream_screen] audioProvider.playTrack() completed');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildEmptySectionCard(String message, {double height = 120}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildVideoTile(Map<String, dynamic> video) {
    final thumbnail = video['thumbnail'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playVideo(video),
          splashColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          highlightColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Square thumbnail
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      thumbnail ??
                          'https://img.youtube.com/vi/${video['id']}/maxresdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        alignment: Alignment.center,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.music_note,
                          color: colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video['title'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video['channel'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.3,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        onPressed: () => _playVideo(video),
                        tooltip: 'Play',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatViews(int? views) {
    if (views == null || views < 0) return 'N/A views';
    if (views >= 1000000)
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K views';
    return '$views views';
  }

  void _openSearchScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OnlineSearchScreen(),
      ),
    );
  }

  void _openSectionPage(
      String title, List<Map<String, dynamic>> items, bool isListView) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectionPage(
          title: title,
          items: items,
          isListView: isListView,
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController(text: settings.ytdlBaseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('YTDL Wrapper Base URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://ytdl-wrapper.onrender.com',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Update the YTDL wrapper base URL if you host your own instance.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty) {
                  await settings.setYtdlBaseUrl(newUrl);
                  setState(() {
                    _service = const YtdlWrapperService();
                  });
                  _loadFeatured();
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              title: _buildSearchField(context),
              actions: [
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    if (!settings.enableYouTubeIntegration)
                      return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const YoutubeHistoryScreen(),
                          ),
                        );
                      },
                      tooltip: 'YouTube History',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  tooltip: 'Settings',
                ),
              ],
            ),
          ];
        },
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadFeatured,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentQuery.isNotEmpty && _isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final showingSearch = _currentQuery.isNotEmpty;
    if (showingSearch && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: showingSearch
          ? () async => _search(_currentQuery)
          : () => _loadDiscoverSections(forceRefresh: true),
      child: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final hasMiniPlayer = audioProvider.currentTrack != null;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final showMiniPlayer = hasMiniPlayer && keyboardHeight == 0;
          final safeArea = MediaQuery.of(context).padding.bottom;
          final bottomPadding =
              showMiniPlayer ? safeArea + 96.0 : safeArea + 24;

          if (showingSearch) {
            return ListView.separated(
              padding: EdgeInsets.only(bottom: bottomPadding, top: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildVideoTile(_searchResults[index]),
            );
          }

          return ListView(
            padding: EdgeInsets.only(bottom: bottomPadding, top: 16),
            children: [
              _buildHeroHeader(context),
              const SizedBox(height: 24),

              Consumer<RecommendationProvider>(
                builder: (context, recommendationProvider, child) {
                  final relatedVideos = recommendationProvider.relatedVideos;
                  final recommendations =
                      recommendationProvider.recommendations;
                  final isLoading = recommendationProvider.isLoading;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (relatedVideos.isNotEmpty) ...[
                        _buildSectionHeader('Now Playing Radio',
                            items: relatedVideos, isListView: false),
                        const SizedBox(height: 12),
                        _buildHorizontalCarousel(relatedVideos),
                        const SizedBox(height: 28),
                      ],

                      // Personalized recommendations (grid layout)
                      if (recommendations.isNotEmpty) ...[
                        _buildSectionHeader('Personalized for You',
                            items: recommendations, isListView: false),
                        const SizedBox(height: 12),
                        _buildGridCarousel(recommendations),
                        const SizedBox(height: 28),
                      ],

                      if (isLoading &&
                          relatedVideos.isEmpty &&
                          recommendations.isEmpty) ...[
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ],
                  );
                },
              ),

              _buildSectionHeader('Quick picks',
                  items: _quickPicks, isListView: false),
              const SizedBox(height: 12),
              _buildHorizontalCarousel(_quickPicks),
              const SizedBox(height: 28),

              // Trending section
              _buildSectionHeader('Trending now',
                  items: _trendingSongs.take(6).toList(), isListView: true),
              const SizedBox(height: 12),
              _buildTileList(_trendingSongs.take(6).toList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
      highlightColor: colorScheme.surfaceContainerHighest.withOpacity(0.7),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120, top: 16),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: colorScheme.surface,
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: 200,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(
                    3,
                    (index) => Container(
                      height: 38,
                      width: 110,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            height: 28,
            width: 160,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Horizontal carousel cards with modern design
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              padding: const EdgeInsets.symmetric(vertical: 4),
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 126,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // More sections
          ...List.generate(
            3,
            (sectionIndex) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  width: 140,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // Carousel
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    separatorBuilder: (_, __) => const SizedBox(width: 18),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 150,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 126,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 14,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 14,
                              width: 100,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 12,
                              width: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Trending section header
          Container(
            height: 28,
            width: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Trending tiles
          ...List.generate(
            5,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 15,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 13,
                          width: 120,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
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
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLanguagePlaylistsSections() {
    final widgets = <Widget>[];

    _languagePlaylists.forEach((language, playlist) {
      if (playlist.isEmpty) return;

      widgets.addAll([
        _buildSectionHeader('$language songs',
            items: playlist, isListView: false),
        const SizedBox(height: 8),
        _buildHorizontalCarousel(playlist),
        const SizedBox(height: 20),
      ]);
    });

    return widgets;
  }

  Widget _buildHorizontalCarousel(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemCount = items.length > 15 ? 15 : items.length;

    if (itemCount == 0) {
      return _buildEmptySectionCard('Nothing to show right now');
    }

    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final cardWidth = (maxWidth * 0.42).clamp(132.0, 168.0);
          final imageSize = cardWidth - 24;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final item = items[index];
              final thumbnail = item['thumbnail'] as String?;
              final title = item['title'] as String? ?? 'Unknown';
              final channel = item['channel'] as String? ?? 'Unknown';

              return SizedBox(
                width: cardWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _playVideo(item),
                    splashColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.18),
                    highlightColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.surfaceContainerHigh,
                            colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: imageSize,
                              height: imageSize,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: Image.network(
                                  thumbnail ??
                                      'https://img.youtube.com/vi/${item['id']}/maxresdefault.jpg',
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    alignment: Alignment.center,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.music_note,
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            channel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              height: 1.1,
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTileList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _buildEmptySectionCard('Nothing trending right now');
    }
    return Column(children: items.map(_buildVideoTile).toList(growable: false));
  }

  Widget _buildHeroHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.primaryContainer.withValues(alpha: 0.34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore,
                  color: colorScheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Discover something new',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Curated picks, fresh tracks, and playlists tailored for every moment.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroChip(context, Icons.flash_on, 'Trending hits'),
              _buildHeroChip(context, Icons.playlist_play, 'Mood playlists'),
              _buildHeroChip(context, Icons.public, 'Global picks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: (_isSearching || _currentQuery.isNotEmpty)
              ? IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                    _searchDebounceTimer?.cancel();
                    _search('');
                  },
                )
              : null,
          hintText: 'Search YouTube music…',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withOpacity(0.8),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    required List<Map<String, dynamic>> items,
    required bool isListView,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isListView ? Icons.bar_chart : Icons.queue_music,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
        if (items.isNotEmpty)
          TextButton(
            onPressed: () => _openSectionPage(title, items, isListView),
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            child: const Text('See all'),
          ),
      ],
    );
  }

  Widget _buildGridCarousel(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemCount = items.length > 15 ? 15 : items.length;

    if (itemCount == 0) {
      return _buildEmptySectionCard('Nothing to show right now', height: 400);
    }

    // Group items into columns of 3
    final columns = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < itemCount; i += 3) {
      final end = (i + 3) > itemCount ? itemCount : i + 3;
      columns.add(items.sublist(i, end));
    }

    return SizedBox(
      height: 240, // Height for 3 items vertically
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: columns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, columnIndex) {
          final columnItems = columns[columnIndex];

          return SizedBox(
            width: 300, // Width of each column
            child: Column(
              children: columnItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isLast = entry.key == columnItems.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: SizedBox(
                    height: 72,
                    child: _buildGridItem(item, colorScheme, theme),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridItem(
    Map<String, dynamic> item,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final thumbnail = item['thumbnail'] as String?;
    final title = item['title'] as String? ?? 'Unknown';
    final channel = item['channel'] as String? ?? 'Unknown';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playVideo(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  width: 65,
                  height: 65,
                  child: Image.network(
                    thumbnail ??
                        'https://img.youtube.com/vi/${item['id']}/default.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // Title and artist
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        channel,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
