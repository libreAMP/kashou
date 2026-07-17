import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import 'track_list_page.dart';
import '../models/track.dart';
import '../theme/radii.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: Text(
          '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
            tooltip: 'Search music',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer2<AudioProvider, LibraryProvider>(
        builder: (context, audioProvider, library, child) {
          final hasMiniPlayer = audioProvider.currentTrack != null;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final showMiniPlayer = hasMiniPlayer && keyboardHeight == 0;
          final safeArea = MediaQuery.of(context).padding.bottom;

          return RefreshIndicator(
            onRefresh: () => library.scanLibrary(force: true),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, showMiniPlayer ? safeArea + 96 : safeArea + 24),
              children: [
                _buildHeroHeader(context, library),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 28),
                _buildRecentlyPlayed(context),
                const SizedBox(height: 28),
                _buildRecentlyAdded(context),
                const SizedBox(height: 28),
                _buildFavoriteSongs(context),
                const SizedBox(height: 28),
                _buildTopAlbums(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Quick Actions',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.shuffle,
                label: 'Shuffle all',
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
                    final shuffled = List<Track>.from(library.allTracks)
                      ..shuffle();
                    audio.playTrack(shuffled.first, playlist: shuffled);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.play_circle_outline,
                label: 'Play library',
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              title: 'Recently played',
              actionLabel: 'See all',
              onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackListPage(
                    title: 'Recently played', tracks: audio.getRecentlyPlayedTracks(library)),
              )),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentTracks.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
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
            _buildSectionHeader(
              context,
              title: 'Recently added',
              actionLabel: 'See all',
              onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackListPage(
                    title: 'Recently added', tracks: library.allTracks.take(50).toList()),
              )),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentTracks.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
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
        // Filter to show only local favorite songs (exclude YouTube/online tracks)
        final localFavoriteTracks = library.favoriteTracks.where((track) {
          return !track.path.contains('youtube.com') &&
              !track.path.contains('youtu.be') &&
              track.album != 'YouTube';
        }).toList();

        // Don't show section at all if no local favorites
        if (localFavoriteTracks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              title: 'Your favorite songs',
              actionLabel: 'See all',
              onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackListPage(
                    title: 'Your favorite songs', tracks: library.favoriteTracks),
              )),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: localFavoriteTracks.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return TrackListItem(track: localFavoriteTracks[index]);
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
            _buildSectionHeader(
              context,
              title: 'Top albums',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                        width: 118, child: AlbumCard(album: albums[index])),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackCard(BuildContext context, track) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget fallback() => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
        );

    return InkWell(
      onTap: () {
        final audio = Provider.of<AudioProvider>(context, listen: false);
        audio.playTrack(track);
      },
      borderRadius: BorderRadius.circular(rMd),
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(rMd),
              child: AspectRatio(
                aspectRatio: 1,
                child: track.albumArt != null
                    ? Image.memory(
                        track.albumArt!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => fallback(),
                      )
                    : fallback(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, LibraryProvider library) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackCount = library.allTracks.length;
    final albumCount = library.albums.length;
    final artistCount = library.artists.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$trackCount tracks, $albumCount albums, $artistCount artists',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }
}
