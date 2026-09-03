import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../services/download_store.dart';
import '../services/ytmusic_service.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../widgets/settings_tiles.dart';
import '../utils/app_messenger.dart';
import '../providers/audio_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import 'track_list_page.dart';
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
  final _chipKeys = List.generate(6, (_) => GlobalKey());
  int _lastChip = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _revealChip(int i) {
    if (i == _lastChip) return;
    _lastChip = i;
    final ctx = _chipKeys[i].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  PreferredSizeWidget _buildChipTabs() {
    const labels = [
      'Liked',
      'Songs',
      'Albums',
      'Artists',
      'Playlists',
      'Downloads',
    ];
    const icons = [
      Icons.favorite_rounded,
      Icons.music_note_rounded,
      Icons.album_rounded,
      Icons.person_rounded,
      Icons.playlist_play_rounded,
      Icons.download_done_rounded,
    ];
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final sel = _tabController.animation!.value.round();
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _revealChip(sel));
          return SizedBox(
            height: 64,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                // without this the chips shrink to text height
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Material(
                      key: _chipKeys[i],
                      color:
                          i == sel ? scheme.primary : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _tabController.animateTo(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(icons[i],
                                  size: 18,
                                  color: i == sel
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  color: i == sel
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
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
                      title: Text(
                        'Library',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
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
                      bottom: _buildChipTabs(),
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
                                        Text(
                                          '$songCount songs, $albumCount albums, $artistCount artists, $playlistCount playlists',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        Material(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHigh,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Container(
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
                                _buildDownloadsTab(bottomPadding),
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
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
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
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        return ArtistCard(artist: artists[index]);
      },
    );
  }

  Widget _buildDownloadsTab(double bottomPadding) {
    return FutureBuilder<List<Track>>(
      future: DownloadStore.tracks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tracks = snapshot.data!;
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_done_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing downloaded yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Songs you download play here without internet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
          itemCount: tracks.length,
          itemBuilder: (context, index) =>
              TrackListItem(track: tracks[index]),
        );
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
          leading: _playlistArt(playlist, Theme.of(context).colorScheme),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TrackListPage(
                title: playlist.name, tracks: playlist.tracks),
          )),
          onLongPress: () => _showPlaylistOptions(context, playlist.id),
        );
      },
    );
  }

  Future<void> _importFromYouTube() async {
    final library = Provider.of<LibraryProvider>(context, listen: false);
    final linkController = TextEditingController();
    final nameController = TextEditingController();
    var useYtName = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          title: Text(
            'Import from YouTube',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Playlist or album link',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(rMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SettingsSwitchTile(
                icon: Icons.title,
                title: 'Use YouTube playlist name',
                value: useYtName,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => useYtName = v),
              ),
              if (!useYtName)
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Name here',
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(rMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final id =
        Uri.tryParse(linkController.text.trim())?.queryParameters['list'];
    if (id == null || id.isEmpty) {
      appMessenger.currentState?.showSnackBar(
          const SnackBar(content: Text('That link has no playlist in it')));
      return;
    }

    appMessenger.currentState
        ?.showSnackBar(const SnackBar(content: Text('Importing...')));
    final songs = await const YtMusicService().getPlaylistSongs(id);
    if (songs.isEmpty) {
      appMessenger.currentState?.showSnackBar(
          const SnackBar(content: Text('Could not read that playlist')));
      return;
    }

    const ytm = YtMusicService();
    final name = useYtName
        ? (await ytm.getPlaylistTitle(id) ?? 'YouTube import')
        : nameController.text.trim().isEmpty
            ? 'YouTube import'
            : nameController.text.trim();
    final cover = await ytm.getPlaylistThumb(id);
    await library.importPlaylist(name, [
      for (final song in songs)
        Track(
          id: song['id'] as String? ?? '',
          title: song['title'] as String? ?? 'Unknown',
          artist: song['channel'] as String? ?? '',
          album: 'YouTube',
          path: song['url'] as String? ??
              'https://www.youtube.com/watch?v=${song['id']}',
          duration: Duration.zero,
          sourceUrl: song['url'] as String? ??
              'https://www.youtube.com/watch?v=${song['id']}',
          artistId: song['artistId'] as String?,
        ),
    ], coverImage: cover);
    appMessenger.currentState?.showSnackBar(
        SnackBar(content: Text('Imported ${songs.length} songs into $name')));
  }

  void _showLibraryOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: EShape.radius(EShape.lg),
                  clipBehavior: Clip.antiAlias,
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
                      Divider(
                          height: 1,
                          indent: 56,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.4)),
                      ListTile(
                        leading: const Icon(Icons.link_rounded),
                        title: const Text('Import from YouTube'),
                        onTap: () {
                          Navigator.pop(context);
                          _importFromYouTube();
                        },
                      ),
                      Divider(
                          height: 1,
                          indent: 56,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.4)),
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
                      Divider(
                          height: 1,
                          indent: 56,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.4)),
                      ListTile(
                        leading: const Icon(Icons.sort),
                        title: const Text('Sort Options'),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _playlistArt(Playlist playlist, ColorScheme scheme) {
    final fallback = CircleAvatar(
      backgroundColor: scheme.surfaceContainerHighest,
      child: Text(playlist.name.isNotEmpty
          ? playlist.name[0].toUpperCase()
          : '?'),
    );
    final cover = playlist.coverImage;
    if (cover == null || cover.isEmpty) return fallback;
    final Widget img = cover.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => fallback,
          )
        : Image.file(
            File(cover),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(rSm),
      child: SizedBox(width: 56, height: 56, child: img),
    );
  }

  void _showRenameDialog(
      BuildContext context, String playlistId, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(rMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Provider.of<LibraryProvider>(context, listen: false)
                  .renamePlaylist(playlistId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: EShape.radius(EShape.lg),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_rounded),
                        title: const Text('Rename Playlist'),
                        onTap: () {
                          Navigator.pop(context);
                          final current = Provider.of<LibraryProvider>(
                            context,
                            listen: false,
                          ).playlists.firstWhere((p) => p.id == playlistId).name;
                          _showRenameDialog(context, playlistId, current);
                        },
                      ),
                      Divider(
                          height: 1,
                          indent: 56,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.4)),
                      ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Change Cover'),
                        onTap: () async {
                          Navigator.pop(context);
                          final picked = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          final src = picked?.files.single.path;
                          if (src == null) return;
                          final dir =
                              await getApplicationDocumentsDirectory();
                          final f =
                              File('${dir.path}/playlist_$playlistId.jpg');
                          await f.writeAsBytes(await File(src).readAsBytes());
                          if (context.mounted) {
                            Provider.of<LibraryProvider>(context,
                                    listen: false)
                                .setPlaylistCover(playlistId, f.path);
                          }
                        },
                      ),
                      Divider(
                          height: 1,
                          indent: 56,
                          color:
                              scheme.outlineVariant.withValues(alpha: 0.4)),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Delete Playlist'),
                        onTap: () async {
                          Navigator.pop(context);
                          final library = Provider.of<LibraryProvider>(
                            context,
                            listen: false,
                          );
                          final name = library.playlists
                              .firstWhere((p) => p.id == playlistId)
                              .name;
                          final remove = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text('Delete $name?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (remove == true) {
                            library.deletePlaylist(playlistId);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
