import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import 'youtube_history_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
                      title: Row(
                        children: [
                          Icon(Icons.library_music,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text('Library'),
                        ],
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            final provider = Provider.of<LibraryProvider>(
                              context,
                              listen: false,
                            );
                            provider.scanLibrary(force: true);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            _showLibraryOptions(context);
                          },
                        ),
                      ],
                      bottom: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: const [
                          Tab(icon: Icon(Icons.favorite), text: 'Liked'),
                          Tab(icon: Icon(Icons.music_note), text: 'Songs'),
                          Tab(icon: Icon(Icons.album), text: 'Albums'),
                          Tab(icon: Icon(Icons.person), text: 'Artists'),
                          Tab(
                              icon: Icon(Icons.playlist_play),
                              text: 'Playlists'),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Consumer<LibraryProvider>(
                        builder: (context, library, child) {
                          final songCount = library.allTracks.length;
                          final albumCount = library.albums.length;
                          final artistCount = library.artists.length;
                          final playlistCount = library.playlists.length;

                          return Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 640;
                                return Align(
                                  alignment: isWide
                                      ? Alignment.topCenter
                                      : Alignment.topLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isWide ? 640 : double.infinity,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.bar_chart,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$songCount songs • $albumCount albums • $artistCount artists',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                  Text(
                                                    '$playlistCount playlists',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Material(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.15),
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.08),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12),
                                                width: 1,
                                              ),
                                            ),
                                            child: SearchBar(
                                              controller: _searchController,
                                              leading: const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8),
                                                child: Icon(Icons.search),
                                              ),
                                              trailing: _searchController
                                                      .text.isNotEmpty
                                                  ? [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.clear),
                                                        onPressed: () {
                                                          _searchController
                                                              .clear();
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ]
                                                  : null,
                                              hintText: 'Search music...',
                                              elevation:
                                                  const WidgetStatePropertyAll(
                                                      0),
                                              shape: WidgetStatePropertyAll(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                              ),
                                              padding:
                                                  const WidgetStatePropertyAll(
                                                EdgeInsets.symmetric(
                                                    horizontal: 16),
                                              ),
                                              onChanged: (value) {
                                                setState(() {});
                                              },
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
                        },
                      ),
                    ),
                  ];
                },
                body: Consumer2<LibraryProvider, AudioProvider>(
                  builder: (context, library, audioProvider, child) {
                    if (library.isScanning) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                value: library.scanProgress),
                            const SizedBox(height: 16),
                            Text(
                              'Scanning library... ${(library.scanProgress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 640;
                        final keyboardHeight =
                            MediaQuery.of(context).viewInsets.bottom;
                        final showMiniPlayer =
                            audioProvider.currentTrack != null &&
                                keyboardHeight == 0;
                        final bottomPadding =
                            MediaQuery.of(context).padding.bottom +
                                (showMiniPlayer ? 96.0 : 16.0);
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isWide ? 640 : double.infinity,
                          ),
                          child: Align(
                            alignment: isWide
                                ? Alignment.topCenter
                                : Alignment.topLeft,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildLikedTab(library, bottomPadding),
                                _buildSongsTab(library, bottomPadding),
                                _buildAlbumsTab(library, bottomPadding),
                                _buildArtistsTab(library, bottomPadding),
                                _buildPlaylistsTab(library, bottomPadding),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLikedTab(LibraryProvider library, double bottomPadding) {
    final favoriteTracks = library.favoriteTracks;

    if (favoriteTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No liked songs yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon on songs you love',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Separate local and online tracks
    final localTracks = favoriteTracks.where((track) {
      return !track.path.contains('youtube.com') &&
          !track.path.contains('youtu.be') &&
          track.album != 'YouTube';
    }).toList();

    final onlineTracks = favoriteTracks.where((track) {
      return track.path.contains('youtube.com') ||
          track.path.contains('youtu.be') ||
          track.album == 'YouTube';
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        if (onlineTracks.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            icon: Icons.cloud_outlined,
            title: 'Online Songs',
            subtitle: '${onlineTracks.length} tracks',
          ),
          const SizedBox(height: 8),
          ...onlineTracks.map((track) => TrackListItem(track: track)),
          if (localTracks.isNotEmpty) const SizedBox(height: 24),
        ],
        if (localTracks.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            icon: Icons.phone_android,
            title: 'Local Songs',
            subtitle: '${localTracks.length} tracks',
          ),
          const SizedBox(height: 8),
          ...localTracks.map((track) => TrackListItem(track: track)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(LibraryProvider library, double bottomPadding) {
    final tracks = _searchController.text.isEmpty
        ? library.allTracks
        : library.searchTracks(_searchController.text);

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.music_note_outlined
                  : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No songs found'
                  : 'No songs match your search',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Add some music to get started'
                  : 'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  library.scanLibrary(force: true);
                },
                child: const Text('Scan Library'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return TrackListItem(track: tracks[index]);
      },
    );
  }

  Widget _buildAlbumsTab(LibraryProvider library, double bottomPadding) {
    final albums = _searchController.text.isEmpty
        ? library.albums
        : library.searchAlbums(_searchController.text);

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.album_outlined
                  : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No albums found'
                  : 'No albums match your search',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return AlbumCard(album: albums[index]);
      },
    );
  }

  Widget _buildArtistsTab(LibraryProvider library, double bottomPadding) {
    final artists = _searchController.text.isEmpty
        ? library.artists
        : library.searchArtists(_searchController.text);

    if (artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.person_outlined
                  : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No artists found'
                  : 'No artists match your search',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        return ArtistCard(artist: artists[index]);
      },
    );
  }

  Widget _buildPlaylistsTab(LibraryProvider library, double bottomPadding) {
    if (library.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first playlist',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                _showCreatePlaylistDialog(context);
              },
              child: const Text('Create Playlist'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      itemCount: library.playlists.length,
      itemBuilder: (context, index) {
        final playlist = library.playlists[index];
        return ListTile(
          title: Text(playlist.name),
          subtitle: Text('${playlist.tracks.length} songs'),
          leading: CircleAvatar(
            child: Text(playlist.name.isNotEmpty
                ? playlist.name[0].toUpperCase()
                : '?'),
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playlist detail coming soon.')),
            );
          },
        );
      },
    );
  }

  void _showLibraryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('YouTube History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const YoutubeHistoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Rescan Library'),
                onTap: () {
                  Navigator.pop(context);
                  final provider = Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  );
                  provider.scanLibrary(force: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('Sort Options'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  ).createPlaylist(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistOptions(BuildContext context, String playlistId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  ).deletePlaylist(playlistId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
