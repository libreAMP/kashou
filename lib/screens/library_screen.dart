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
            SliverAppBar.large(
              title: Text(
                'Library',
                style: Theme.of(context).textTheme.headlineMedium,
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
                  Tab(text: 'Songs'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Artists'),
                  Tab(text: 'Playlists'),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SearchBar(
                  controller: _searchController,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search),
                  ),
                  hintText: 'Search library...',
                  elevation: const WidgetStatePropertyAll(1),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

            return TabBarView(
              controller: _tabController,
              children: [
                _buildSongsTab(library),
                _buildAlbumsTab(library),
                _buildArtistsTab(library),
                _buildPlaylistsTab(library),
              ],
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
              Icons.music_note_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No songs found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                library.scanLibrary();
              },
              child: const Text('Scan Library'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return TrackListItem(track: tracks[index]);
      },
    );
  }

  Widget _buildAlbumsTab(LibraryProvider library) {
    final albums = _searchController.text.isEmpty
        ? library.albums
        : library.searchAlbums(_searchController.text);

    if (albums.isEmpty) {
      return Center(
        child: Text(
          'No albums found',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return AlbumCard(album: albums[index]);
      },
    );
  }

  Widget _buildArtistsTab(LibraryProvider library) {
    final artists = _searchController.text.isEmpty
        ? library.artists
        : library.searchArtists(_searchController.text);

    if (artists.isEmpty) {
      return Center(
        child: Text(
          'No artists found',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        return ArtistCard(artist: artists[index]);
      },
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      itemCount: library.playlists.length,
      itemBuilder: (context, index) {
        final playlist = library.playlists[index];
        return Card(
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
