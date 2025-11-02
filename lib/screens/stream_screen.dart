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
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _service = YtdlWrapperService(settings.ytdlBaseUrl);
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
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (_service.baseUrl != settings.ytdlBaseUrl) {
        _service = YtdlWrapperService(settings.ytdlBaseUrl);
        _loadFeatured();
      }
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

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final featured = await _service.search('latest music "music video" "song"', limit: 12);
      if (mounted) {
        setState(() {
          _featured = featured;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load featured tracks. Check your connection.';
          _isLoading = false;
        });
      }
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
    );

    audioProvider.preparePendingTrack(placeholderTrack);

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
    );

    await audioProvider.playTrack(finalTrack);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                    _service = YtdlWrapperService(newUrl);
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
    final videos = showingSearch ? _searchResults : _featured;
    final title = showingSearch ? 'Search Results' : 'Discover';

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              showingSearch ? 'No results found' : 'No featured tracks',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: showingSearch ? () async => _search(_currentQuery) : _loadFeatured,
      child: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final hasMiniPlayer = audioProvider.currentTrack != null;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final shouldShowMiniPlayer = hasMiniPlayer && keyboardHeight == 0;

          return ListView.builder(
            padding: EdgeInsets.only(
              bottom: shouldShowMiniPlayer ? 120 : 16,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: videos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }
              return _buildVideoTile(videos[index - 1]);
            },
          );
        },
      ),
    );
  }
}