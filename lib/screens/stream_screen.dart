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

class _StreamScreenState extends State<StreamScreen> {
  late YtdlWrapperService _service;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _currentQuery = '';
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  void _onSearchFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _initializeService();
    _searchController.addListener(_onSearchFieldChanged);
  }

  void _initializeService() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _service = YtdlWrapperService(settings.ytdlBaseUrl);
    _loadFeatured();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (_service.baseUrl != settings.ytdlBaseUrl) {
      _service = YtdlWrapperService(settings.ytdlBaseUrl);
      _loadFeatured();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchFieldChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
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
      album: details['title'] as String? ?? placeholderTrack.album,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playVideo(video),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Image.network(
                        thumbnail ?? 'https://img.youtube.com/vi/${video['id']}/mqdefault.jpg',
                        width: 116,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 116,
                          height: 68,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (duration.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              duration,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video['title'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video['channel'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatViews(_asInt(video['views'])),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _playVideo(video),
                  tooltip: 'Play',
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              NestedScrollView(
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
                            elevation: const WidgetStatePropertyAll(1),
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
                  ];
                },
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
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
      ),
    );
  }
}