import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
                  Icon(Icons.library_music, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Library'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    Provider.of<LibraryProvider>(
                      context,
                      listen: false,
                    ).scanLibrary();
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
                  Tab(icon: Icon(Icons.music_note), text: 'Songs'),
                  Tab(icon: Icon(Icons.album), text: 'Albums'),
                  Tab(icon: Icon(Icons.person), text: 'Artists'),
                  Tab(icon: Icon(Icons.playlist_play), text: 'Playlists'),
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
                          alignment: isWide ? Alignment.topCenter : Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isWide ? 640 : double.infinity,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.bar_chart,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$songCount songs • $albumCount albums • $artistCount artists',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            '$playlistCount playlists',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                  setState(() {});
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
        body: Consumer<LibraryProvider>(
          builder: (context, library, child) {
            if (library.isScanning) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(value: library.scanProgress),
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 640 : double.infinity,
                    ),
                    child: Align(
                      alignment: isWide ? Alignment.topCenter : Alignment.topLeft,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSongsTab(library),
                          _buildAlbumsTab(library),
                          _buildArtistsTab(library),
                          _buildPlaylistsTab(library),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
              Consumer<AudioProvider>(
                builder: (context, audioProvider, child) {
                  final hasPlayer = audioProvider.currentTrack != null;
                  
                  return Positioned(
                    right: 16,
                    bottom: hasPlayer ? 94.0 : 16.0,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        _showCreatePlaylistDialog(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New Playlist'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSongsTab(LibraryProvider library) {
    final tracks = _searchController.text.isEmpty
        ? library.allTracks
        : library.searchTracks(_searchController.text);

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty ? Icons.music_note_outlined : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No songs found' : 'No songs match your search',
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
                  library.scanLibrary();
                },
                child: const Text('Scan Library'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          return TrackListItem(track: tracks[index]);
        },
      ),
    );
  }

  Widget _buildAlbumsTab(LibraryProvider library) {
    final albums = _searchController.text.isEmpty
        ? library.albums
        : library.searchAlbums(_searchController.text);

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty ? Icons.album_outlined : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No albums found' : 'No albums match your search',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
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
      ),
    );
  }

  Widget _buildArtistsTab(LibraryProvider library) {
    final artists = _searchController.text.isEmpty
        ? library.artists
        : library.searchArtists(_searchController.text);

    if (artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty ? Icons.person_outlined : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No artists found' : 'No artists match your search',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          return ArtistCard(artist: artists[index]);
        },
      ),
    );
  }

  Widget _buildPlaylistsTab(LibraryProvider library) {
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

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: library.playlists.length,
        itemBuilder: (context, index) {
          final playlist = library.playlists[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.playlist_play,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(playlist.name),
              subtitle: Text('${playlist.trackCount} songs'),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showPlaylistOptions(context, playlist.id);
                },
              ),
              onTap: () {
                // Navigate to playlist detail
              },
            ),
          );
        },
      ),
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
                leading: const Icon(Icons.refresh),
                title: const Text('Rescan Library'),
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  ).scanLibrary();
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
