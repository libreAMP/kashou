import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/invidious_service.dart';
import '../models/track.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late InvidiousService _service;
  List<Map<String, dynamic>> _trending = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _service = InvidiousService(settings.streamUrl);
    _loadTrending();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (_service.baseUrl != settings.streamUrl) {
      _service = InvidiousService(settings.streamUrl);
      _loadTrending();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trending = await _service.getTrending();
      if (mounted) {
        setState(() {
          _trending = trending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load trending videos. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isSearching = true;
        _error = null;
      });
    }
    try {
      final results = await _service.search(query);
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
    final videoId = video['videoId'];
    final details = await _service.getVideoDetails(videoId);
    if (details != null) {
      final streamUrl = _service.getAudioStreamUrl(details);
      if (streamUrl != null) {
        Uint8List? albumArt;
        try {
          final thumbnailResponse = await http.get(Uri.parse('https://img.youtube.com/vi/$videoId/mqdefault.jpg'));
          if (thumbnailResponse.statusCode == 200) {
            albumArt = thumbnailResponse.bodyBytes;
          }
        } catch (e) {
          // Ignore
        }
        final track = Track(
          id: videoId,
          title: video['title'] ?? 'Unknown',
          artist: video['author'] ?? 'Unknown',
          album: video['title'] ?? 'Unknown',
          path: streamUrl,
          duration: Duration(seconds: video['lengthSeconds'] ?? 0),
          albumArt: albumArt,
        );
        audioProvider.playTrack(track);
      }
    }
  }

  Widget _buildVideoTile(Map<String, dynamic> video) {
    final thumbnail = 'https://img.youtube.com/vi/${video['videoId']}/mqdefault.jpg';
    final duration = video['lengthSeconds'] != null ? _formatDuration(video['lengthSeconds']) : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playVideo(video),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      thumbnail,
                      width: 100,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 100,
                        height: 56,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    if (duration.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            duration,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video['author'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${video['viewCount'] != null ? _formatViews(video['viewCount']) : 'N/A'} views',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.primary),
                onPressed: () => _playVideo(video),
                tooltip: 'Play',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  void _showSettingsDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController(text: settings.streamUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invidious Instance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://invidious.example.com',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Change the Invidious instance URL. Popular instances: invidious.snopyta.org, invidious.nerdvpn.de',
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
                  await settings.setStreamUrl(newUrl);
                  // Reinitialize service with new URL
                  setState(() {
                    _service = InvidiousService(newUrl);
                  });
                  _loadTrending();
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Row(
              children: [
                Icon(Icons.cloud, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Stream'),
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search music...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                onSubmitted: _search,
              ),
            ),
          ),
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildContent(),
            ),
          ),
        ],
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
              onPressed: _loadTrending,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final videos = _isSearching ? _searchResults : _trending;
    final title = _isSearching ? 'Search Results' : 'Trending Music';

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No results found' : 'No trending videos',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _isSearching ? () async => _search(_searchController.text) : _loadTrending,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
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
