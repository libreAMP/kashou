import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';
import '../screens/online_search_screen.dart';
import '../screens/section_page.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../models/track.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    if (_currentQuery.isNotEmpty) {
      _searchController.text = _currentQuery;
    }
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

      final quickPicksFuture = _service.search('popular songs 2024', limit: 20);
      final trendingFuture = _service.search('trending songs 2024', limit: 20);
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

    Map<String, dynamic>? details;
    try {
      details = await _service.fetchAudioDetails(videoUrl);
    } catch (_) {
      details = null;
    }

    if (details == null) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('Unable to load audio stream.');
      return;
    }

    String? downloadUrl;
    final audio = details['audio'];
    if (audio is Map) {
      downloadUrl = audio['download_url'] as String?;
    } else if (audio is String) {
      downloadUrl = audio;
    }
    downloadUrl ??= details['download_url'] as String?;
    downloadUrl ??= details['audio_url'] as String?;
    final download = details['download'];
    if (downloadUrl == null && download is Map) {
      downloadUrl =
          download['url'] as String? ?? download['download_url'] as String?;
    } else if (downloadUrl == null && download is String) {
      downloadUrl = download;
    }

    if (downloadUrl == null) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('Audio stream unavailable.');
      return;
    }

    Uint8List? albumArt;
    final thumbUrl = (details['thumbnail'] ?? video['thumbnail']) as String?;
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      try {
        final thumbnailResponse = await http.get(Uri.parse(thumbUrl));
        if (thumbnailResponse.statusCode == 200) {
          albumArt = thumbnailResponse.bodyBytes;
        }
      } catch (_) {}
    }

    final finalTrack = placeholderTrack.copyWith(
      title: details['title'] as String? ?? placeholderTrack.title,
      artist: details['channel'] as String? ?? placeholderTrack.artist,
      album: 'YouTube',
      path: downloadUrl,
      duration:
          Duration(seconds: _asInt(details['duration']) ?? durationSeconds),
      albumArt: albumArt ?? placeholderTrack.albumArt,
      sourceUrl: placeholderTrack.sourceUrl,
    );

    await audioProvider.playTrack(finalTrack);
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
                          'https://img.youtube.com/vi/${video['id']}/mqdefault.jpg',
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _openSearchScreen(context),
                  tooltip: 'Search music',
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
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
          final bottomPadding = showMiniPlayer ? safeArea + 96.0 : safeArea;

          if (showingSearch) {
            return ListView.separated(
              padding: EdgeInsets.only(bottom: bottomPadding, top: 12),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildVideoTile(_searchResults[index]),
            );
          }

          return ListView(
            padding: EdgeInsets.only(bottom: bottomPadding),
            children: [
              // Quick Picks
              _buildSectionHeader('Quick picks',
                  items: _quickPicks, isListView: false),
              const SizedBox(height: 8),
              _buildHorizontalCarousel(_quickPicks),
              const SizedBox(height: 20),

              // Language Playlists
              ..._buildLanguagePlaylistsSections(),

              // Trending
              _buildSectionHeader('Trending now',
                  items: _trendingSongs.take(6).toList(), isListView: true),
              const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // Quick Picks section
          Container(
            height: 32,
            width: 140,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Horizontal carousel cards
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 0),
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Container(
                              height: 14,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 12,
                              width: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Language sections
          ...List.generate(3, (sectionIndex) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                width: 120,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              // Language carousel
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 0),
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 12,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          )),

          // Trending section
          Container(
            height: 28,
            width: 130,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Trending list items
          ...List.generate(6, (index) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
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
                    ],
                  ),
                ),
                // Play button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<Widget> _buildLanguagePlaylistsSections() {
    final sections = <Widget>[];
    const languages = [
      'Hindi',
      'English',
      'Punjabi',
      'Tamil',
      'Telugu',
      'Kannada',
      'Malayalam',
      'Bengali'
    ];

    for (final language in languages) {
      final playlist = _languagePlaylists[language];
      if (playlist != null && playlist.isNotEmpty) {
        sections.addAll([
          _buildSectionHeader('$language songs',
              items: playlist, isListView: false),
          const SizedBox(height: 8),
          _buildHorizontalCarousel(playlist),
          const SizedBox(height: 20),
        ]);
      }
    }

    return sections;
  }

  Widget _buildSectionHeader(String title,
      {List<Map<String, dynamic>>? items, bool isListView = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: items != null && items.isNotEmpty
          ? () => _openSectionPage(title, items, isListView)
          : null,
      splashColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      highlightColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCarousel(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemCount = items.length > 15 ? 15 : items.length;
    if (itemCount == 0) {
      return _buildEmptySectionCard('Nothing to show yet', height: 140);
    }
    return SizedBox(
      height: 240, // Increased height for larger thumbnails
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 0),
        itemBuilder: (context, index) {
          final item = items[index];
          final thumbnail = item['thumbnail'] as String? ??
              'https://img.youtube.com/vi/${item['id']}/mqdefault.jpg';
          final title = item['title'] as String? ?? 'Unknown';
          final subtitle = item['channel'] as String? ?? 'Unknown artist';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _playVideo(item),
              splashColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              highlightColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 150, // Increased width for larger thumbnails
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Centered square image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Transform.scale(
                          scale: 1.4, // Zoom in by 20% before cropping
                          child: Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              alignment: Alignment.center,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.music_note,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title and subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
}
