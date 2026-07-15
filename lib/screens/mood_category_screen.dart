import 'package:flutter/material.dart';

import '../services/ytmusic_service.dart';
import '../widgets/art_card.dart';
import '../widgets/loading_indicator.dart';
import 'section_page.dart';

// playlists inside one mood or genre, opened from the explore grid
class MoodCategoryScreen extends StatefulWidget {
  final String title;
  final String params;

  const MoodCategoryScreen({
    super.key,
    required this.title,
    required this.params,
  });

  @override
  State<MoodCategoryScreen> createState() => _MoodCategoryScreenState();
}

class _MoodCategoryScreenState extends State<MoodCategoryScreen> {
  final _ytm = const YtMusicService();
  List<Map<String, dynamic>> _shelves = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shelves = await _ytm.getMoodCategory(widget.params);
    if (!mounted) return;
    setState(() {
      _shelves = shelves;
      _loading = false;
    });
  }

  void _openPlaylist(Map<String, dynamic> pl) {
    final id = pl['playlistId'] as String?;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SectionPage(
        title: pl['title'] as String? ?? widget.title,
        cover: pl['thumbnail'] as String?,
        itemsFuture: _ytm.getPlaylistSongs(id),
        isListView: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: KashouLoader())
          : _shelves.isEmpty
              ? Center(
                  child: Text('Nothing here right now',
                      style: Theme.of(context).textTheme.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: _shelves.length,
                  itemBuilder: (context, i) => _buildShelf(_shelves[i]),
                ),
    );
  }

  Widget _buildShelf(Map<String, dynamic> shelf) {
    final items = (shelf['items'] as List).cast<Map<String, dynamic>>();
    final title = shelf['title'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
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
}
