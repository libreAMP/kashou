import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/online_music_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/online_track_list_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final enableOnline = settings.enableYouTubeIntegration;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search songs...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
            if (enableOnline && _tabController.index == 1) {
              _performOnlineSearch(value);
            }
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
                if (enableOnline) {
                  Provider.of<OnlineMusicProvider>(context, listen: false)
                      .clearResults();
                }
              },
            ),
        ],
        bottom: enableOnline
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Local'),
                  Tab(text: 'YouTube Music'),
                ],
              )
            : null,
      ),
      body: enableOnline
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildLocalResults(),
                _buildOnlineResults(),
              ],
            )
          : _buildLocalResults(),
    );
  }

  Widget _buildLocalResults() {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        if (_searchQuery.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search,
            title: 'Search your library',
          );
        }

        final results = library.searchTracks(_searchQuery);

        if (results.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'No local results',
            subtitle: 'Try a different search term',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          itemBuilder: (context, index) {
            return TrackListItem(track: results[index]);
          },
        );
      },
    );
  }

  Widget _buildOnlineResults() {
    return Consumer<OnlineMusicProvider>(
      builder: (context, provider, child) {
        if (_searchQuery.isEmpty) {
          return _buildEmptyState(
            icon: Icons.cloud_outlined,
            title: 'Search YouTube Music',
            subtitle: 'Millions of tracks at your fingertips',
          );
        }

        if (!provider.isInitialized && provider.error == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.isLoading) {
          return _buildStatusState(
            icon: Icons.cloud_sync,
            message: 'Searching YouTube Music...',
          );
        }

        if (provider.error != null) {
          return _buildStatusState(
            icon: Icons.error_outline,
            message: provider.error!,
            actionLabel: 'Try again',
            onAction: () => _performOnlineSearch(_searchQuery),
          );
        }

        if (provider.searchResults.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'No online results',
            subtitle: 'Try another query',
          );
        }

        final results = provider.searchResults;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final track = results[index];
            return OnlineTrackListItem(track: track);
          },
        );
      },
    );
  }

  Future<void> _performOnlineSearch(String query) async {
    final provider = Provider.of<OnlineMusicProvider>(context, listen: false);
    await provider.search(query, limit: 20);

  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
