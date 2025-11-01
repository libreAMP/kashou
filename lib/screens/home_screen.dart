import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import '../models/track.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 18) {
      return 'Good afternoon';
    } else if (hour < 22) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
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
                              Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(_getGreeting()),
                            ],
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
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
                                leading: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.search),
                                ),
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
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SearchScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: _buildHomeContent(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildQuickActions(context),
        const SizedBox(height: 40),
        _buildRecentlyPlayed(context),
        const SizedBox(height: 40),
        _buildRecentlyAdded(context),
        const SizedBox(height: 40),
        _buildFavoriteSongs(context),
        const SizedBox(height: 40),
        _buildTopAlbums(context),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.shuffle,
                label: 'Shuffle All',
                onTap: () {
                  final library = Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  );
                  final audio = Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  );

                  if (library.allTracks.isNotEmpty) {
                    final shuffled = List.from(library.allTracks)..shuffle();
                    audio.playTrack(shuffled.first,
                        playlist: shuffled.cast<Track>());
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.play_circle_outline,
                label: 'Play All',
                onTap: () {
                  final library = Provider.of<LibraryProvider>(
                    context,
                    listen: false,
                  );
                  final audio = Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  );

                  if (library.allTracks.isNotEmpty) {
                    audio.playTrack(
                      library.allTracks.first,
                      playlist: library.allTracks,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.15),
                colorScheme.primary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context) {
    return Consumer2<LibraryProvider, AudioProvider>(
      builder: (context, library, audio, child) {
        final recentTracks = audio.getRecentlyPlayedTracks(library);

        if (recentTracks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Played',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No recently played songs',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Play some music to see it here',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Recently Played',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTracks.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return TrackListItem(track: recentTracks[index]);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentlyAdded(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        final recentTracks = library.allTracks.take(10).toList();

        if (recentTracks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.new_releases, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Recently Added',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 165,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentTracks.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 12),
                    child: _buildTrackCard(context, recentTracks[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteSongs(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        final favoriteTracks = library.favoriteTracks;

        if (favoriteTracks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Your Favorite Songs',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No favorite songs yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add songs to favorites to see them here',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Your Favorite Songs',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: favoriteTracks.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return TrackListItem(track: favoriteTracks[index]);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopAlbums(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        final albums = library.albums.take(6).toList();

        if (albums.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.album, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Top Albums',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
          ],
        );
      },
    );
  }

  Widget _buildTrackCard(BuildContext context, track) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          final audio = Provider.of<AudioProvider>(context, listen: false);
          audio.playTrack(track);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 135,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      height: 95,
                      width: 135,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: track.albumArt != null
                          ? Image.memory(
                              track.albumArt!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.music_note,
                                size: 48,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
