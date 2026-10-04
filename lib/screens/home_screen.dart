import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/m3e_refresh.dart';
import '../widgets/track_list_item.dart';
import '../widgets/album_card.dart';
import '../widgets/track_options_sheet.dart';
import 'track_list_page.dart';
import '../models/track.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _maxContentWidth = 1200;

  Widget _centeredContent(Widget child) {
    if (!isDesktop) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth - _maxContentWidth;
        if (extra <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: _centeredContent(
                Consumer2<AudioProvider, LibraryProvider>(
                  builder: (context, audioProvider, library, child) {
                    final hasMiniPlayer = audioProvider.currentTrack != null;
                    final keyboardHeight =
                        MediaQuery.of(context).viewInsets.bottom;
                    final showMiniPlayer = hasMiniPlayer && keyboardHeight == 0;
                    final safeArea = MediaQuery.of(context).padding.bottom;

                    return M3ERefresh(
                      onRefresh: () => library.scanLibrary(force: true),
                      padding: EdgeInsets.fromLTRB(0, 4, 0,
                          showMiniPlayer ? safeArea + 96 : safeArea + 24),
                      slivers: [
                        _padded(context, _buildHeroHeader(context, library)),
                        const SizedBox(height: 24),
                        _padded(context, _buildQuickActions(context)),
                        _buildRecentlyPlayed(context),
                        _buildRecentlyAdded(context),
                        _padded(context, _buildFavoriteSongs(context)),
                        _buildTopAlbums(context),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padded(BuildContext context, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      );

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _centeredContent(
      Padding(
        padding: EdgeInsets.fromLTRB(20, isDesktop ? 16 : 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  readOnly: true,
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 280),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 220),
                      pageBuilder: (_, animation, __) => const SearchScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        final move = Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ));
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: move, child: child),
                        );
                      },
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search your music',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 12, 0),
                      child: Icon(Icons.search_rounded),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 50, maxWidth: 50, minHeight: 0),
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(rFull),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh library',
              onPressed: () => Provider.of<LibraryProvider>(
                context,
                listen: false,
              ).scanLibrary(force: true),
            ),
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
        ],
      ),
    ));
  }

  Widget _buildQuickActions(BuildContext context) {
    final library = Provider.of<LibraryProvider>(context, listen: false);
    final audio = Provider.of<AudioProvider>(context, listen: false);
    final tracks = library.allTracks;

    void shuffle() {
      if (tracks.isEmpty) return;
      final shuffled = List<Track>.from(tracks)..shuffle();
      audio.playTrack(shuffled.first, playlist: shuffled);
    }

    void playAll() {
      if (tracks.isEmpty) return;
      audio.playTrack(tracks.first, playlist: tracks);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title: 'Quick Actions'),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _actionCard(
                  context,
                  icon: Icons.shuffle_rounded,
                  title: 'Shuffle all',
                  subtitle: tracks.isEmpty
                      ? 'Nothing in the library'
                      : '${tracks.length} tracks in library',
                  onTap: shuffle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _actionCard(
                  context,
                  icon: Icons.play_arrow_rounded,
                  title: 'Play library',
                  subtitle:
                      tracks.isEmpty ? 'Add some music first' : 'Play in order',
                  onTap: playAll,
                  primary: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: primary ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(rLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontSize: isDesktop ? 13 : null,
                  height: isDesktop ? null : 1.2,
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
            const SizedBox(height: 24),
            _padded(
              context,
              _buildSectionHeader(
                context,
                title: 'Recently played',
                actionLabel: 'More',
                onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TrackListPage(
                      title: 'Recently played',
                      tracks: audio.getRecentlyPlayedTracks(library)),
                )),
              ),
            ),
            const SizedBox(height: 12),
            _buildTrackCardShelf(context, recentTracks),
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
            const SizedBox(height: 24),
            _padded(
              context,
              _buildSectionHeader(
                context,
                title: 'Recently added',
                actionLabel: 'More',
                onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TrackListPage(
                      title: 'Recently added',
                      tracks: library.allTracks.take(50).toList()),
                )),
              ),
            ),
            const SizedBox(height: 12),
            _padded(context, _buildRecentlyAddedList(context, recentTracks)),
          ],
        );
      },
    );
  }

  Widget _buildRecentlyAddedList(BuildContext context, List<Track> tracks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return TrackListItem(
          track: tracks[index],
          playlist: tracks,
          slot: index,
          count: tracks.length,
        );
      },
    );
  }

  // desktop shelves become full width grids
  Widget _buildTrackCardShelf(BuildContext context, List<Track> tracks) {
    if (isDesktop) {
      return _padded(
        context,
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 140).floor().clamp(4, 12);
            final cellWidth =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // art is square plus two text lines
                childAspectRatio: cellWidth / (cellWidth + 48),
              ),
              itemCount: tracks.length,
              itemBuilder: (context, index) =>
                  _buildTrackCard(context, tracks[index]),
            );
          },
        ),
      );
    }
    return _buildShelf(
      context,
      count: tracks.length,
      item: (index) => _buildTrackCard(context, tracks[index]),
    );
  }

  Widget _buildShelf(
    BuildContext context, {
    required int count,
    required Widget Function(int index) item,
  }) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => item(index),
      ),
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
            const SizedBox(height: 24),
            _buildSectionHeader(
              context,
              title: 'Your favorite songs',
              actionLabel: 'More',
              onActionTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackListPage(
                    title: 'Your favorite songs',
                    tracks: library.favoriteTracks),
              )),
            ),
            const SizedBox(height: 12),
            _buildFavoriteTracksList(context, localFavoriteTracks),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteTracksList(BuildContext context, List<Track> tracks) {
    return _padded(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = isDesktop && constraints.maxWidth >= 760;

          if (!twoColumns) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return TrackListItem(track: tracks[index]);
              },
            );
          }

          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            children: [
              for (final track in tracks)
                SizedBox(width: itemWidth, child: TrackListItem(track: track)),
            ],
          );
        },
      ),
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
            const SizedBox(height: 24),
            _padded(
              context,
              _buildSectionHeader(
                context,
                title: 'Top albums',
              ),
            ),
            const SizedBox(height: 12),
            if (isDesktop)
              _padded(
                context,
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        (constraints.maxWidth / 180).floor().clamp(3, 8);
                    final cellWidth =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        // art is square plus two text lines
                        childAspectRatio: cellWidth / (cellWidth + 48),
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) =>
                          AlbumCard(album: albums[index]),
                    );
                  },
                ),
              )
            else
              _buildShelf(
                context,
                count: albums.length,
                item: (index) => SizedBox(
                    width: 118, child: AlbumCard(album: albums[index])),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTrackCard(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget fallback() => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(rLg),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(rMd),
              ),
              child: Icon(Icons.music_note_rounded,
                  size: 24, color: scheme.onSecondaryContainer),
            ),
          ),
        );

    return InkWell(
      onTap: () {
        final audio = Provider.of<AudioProvider>(context, listen: false);
        audio.playTrack(track);
      },
      // desktop pointer alternative to the long-press options menu
      onSecondaryTapUp:
          isDesktop ? (_) => showTrackOptionsSheet(context, track) : null,
      borderRadius: BorderRadius.circular(rMd),
      child: SizedBox(
        // desktop grids give each card a cell width; mobile carousels fix it
        width: isDesktop ? null : 118,
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
              style: (isDesktop
                      ? theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)
                      : theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: isDesktop ? 12.5 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, LibraryProvider library) {
    final trackCount = library.allTracks.length;
    final albumCount = library.albums.length;
    final artistCount = library.artists.length;
    final playlistCount = library.playlists.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          child: Text(
            'Local',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                context,
                Icons.music_note_rounded,
                trackCount,
                'songs',
                onTap: trackCount > 0
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TrackListPage(
                            title: 'Songs',
                            tracks: library.allTracks,
                          ),
                        ))
                    : null,
              ),
              const SizedBox(width: 8),
              _chip(context, Icons.album_rounded, albumCount, 'albums'),
              const SizedBox(width: 8),
              _chip(context, Icons.person_rounded, artistCount, 'artists'),
              if (playlistCount > 0) ...[
                const SizedBox(width: 8),
                _chip(context, Icons.playlist_play_rounded, playlistCount,
                    'playlists'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    int count,
    String label, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(rSm),
      clipBehavior: Clip.antiAlias,
      child: onTap != null ? InkWell(onTap: onTap, child: content) : content,
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              backgroundColor: colorScheme.surfaceContainerHigh,
              foregroundColor: colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(rFull),
              ),
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }
}
