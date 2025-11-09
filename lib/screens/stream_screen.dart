import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';
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
  List<Map<String, dynamic>> _topArtists = [];
  List<Map<String, dynamic>> _topAlbums = [];
  List<Map<String, dynamic>> _trendingSongs = [];
  List<Map<String, dynamic>> _moodMixes = [];
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
      final featuredFuture = _service.search('Latest music songs', limit: 20);
      final trendingFuture = _service.search('Trending songs 2024', limit: 20);
      final topArtistsFuture = _service.search('Top music artists', limit: 20);
      final topAlbumsFuture = _service.search('Top music albums', limit: 20);
      final moodFuture = _service.search('Chill mix playlist music', limit: 20);

      final results = await Future.wait<List<Map<String, dynamic>>>([
        featuredFuture,
        trendingFuture,
        topArtistsFuture,
        topAlbumsFuture,
        moodFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _featured = results[0];
        _trendingSongs = results[1];
        _topArtists = results[2];
        _topAlbums = results[3];
        _moodMixes = results[4];
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
      downloadUrl = download['url'] as String? ?? download['download_url'] as String?;
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
      duration: Duration(seconds: _asInt(details['duration']) ?? durationSeconds),
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
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVideoTile(Map<String, dynamic> video) {
    final thumbnail = video['thumbnail'] as String?;
    final durationSeconds = _asInt(video['duration']);
    final duration = durationSeconds != null ? _formatDuration(durationSeconds) : '';
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _playVideo(video),
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.05),
          highlightColor: colorScheme.primary.withValues(alpha: 0.03),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surface.withValues(alpha: 0.8),
                  colorScheme.surface.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 120,
                    height: 68,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          thumbnail ?? 'https://img.youtube.com/vi/${video['id']}/mqdefault.jpg',
                          width: 120,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 120,
                            height: 68,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.music_note,
                              color: colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        ),
                        if (duration.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Video info
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
                      const SizedBox(height: 2),
                      Text(
                        _formatViews(_asInt(video['views'])),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
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
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
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
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K views';
    return '$views views';
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
            SliverAppBar.medium(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),  // Top spacing
                  Row(
                    children: [
                      Icon(Icons.cloud, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Stream'),
                    ],
                  ),
                ],
              ),
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _showSettingsDialog,
                  tooltip: 'Settings',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(96),  // Increased height
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),  // Top padding
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: SearchBar(
                        controller: _searchController,
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.search),
                        ),
                        trailing: _searchController.text.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                              ]
                            : null,
                        hintText: 'Search music...',
                        elevation: const WidgetStatePropertyAll(0),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
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
            Icon(Icons.music_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      onRefresh: showingSearch ? () async => _search(_currentQuery) : () => _loadDiscoverSections(forceRefresh: true),
      child: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final hasMiniPlayer = audioProvider.currentTrack != null;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final shouldShowMiniPlayer = hasMiniPlayer && keyboardHeight == 0;

          if (showingSearch) {
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16, top: 12),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildVideoTile(_searchResults[index]),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildSectionHeader('Featured for you'),
              const SizedBox(height: 12),
              _buildHorizontalCarousel(_featured),
              const SizedBox(height: 32),
              _buildSectionHeader('Trending now'),
              const SizedBox(height: 12),
              _buildTileList(_trendingSongs.take(6).toList()),
              const SizedBox(height: 32),
              _buildSectionHeader('Top artists'),
              const SizedBox(height: 12),
              _buildArtistChips(_topArtists),
              const SizedBox(height: 32),
              _buildSectionHeader('Top albums'),
              const SizedBox(height: 12),
              _buildAlbumGrid(_topAlbums.take(6).toList()),
              const SizedBox(height: 32),
              _buildSectionHeader('Mood mixes'),
              const SizedBox(height: 12),
              _buildHorizontalCarousel(_moodMixes),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
      ],
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
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final thumbnail = item['thumbnail'] as String? ?? 'https://img.youtube.com/vi/${item['id']}/hqdefault.jpg';
          final title = item['title'] as String? ?? 'Unknown';
          final subtitle = item['channel'] as String? ?? 'Unknown artist';

          return GestureDetector(
            onTap: () => _playVideo(item),
            child: Container(
              width: 170,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                    colorScheme.surfaceContainer.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          alignment: Alignment.center,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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

  Widget _buildArtistChips(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (items.isEmpty) {
      return _buildEmptySectionCard('No top artists yet', height: 96);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.take(12).map((artist) {
          final name = artist['channel'] as String? ?? artist['title'] as String? ?? 'Unknown Artist';
          final thumbnail = artist['thumbnail'] as String? ?? 'https://img.youtube.com/vi/${artist['id']}/hqdefault.jpg';
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              onPressed: () => _playVideo(artist),
              label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              avatar: CircleAvatar(
                backgroundImage: NetworkImage(thumbnail),
                onBackgroundImageError: (_, __) {},
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              backgroundColor: colorScheme.surfaceContainer,
              side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlbumGrid(List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (items.isEmpty) {
      return _buildEmptySectionCard('No albums available yet');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final album = items[index];
        final thumbnail = album['thumbnail'] as String? ?? 'https://img.youtube.com/vi/${album['id']}/hqdefault.jpg';
        final title = album['title'] as String? ?? 'Unknown album';
        final artist = album['channel'] as String? ?? 'Unknown artist';

        return GestureDetector(
          onTap: () => _playVideo(album),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    thumbnail,
                    height: 112,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      alignment: Alignment.center,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.album, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}