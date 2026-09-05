import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/album.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';

enum CollectionType { album, playlist }

class AlbumDetailScreen extends StatefulWidget {
  final Album? album;
  final Playlist? playlist;
  final CollectionType type;

  const AlbumDetailScreen.album({
    super.key,
    required this.album,
  })  : playlist = null,
        type = CollectionType.album;

  const AlbumDetailScreen.playlist({
    super.key,
    required this.playlist,
  })  : album = null,
        type = CollectionType.playlist;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;
  bool _showFloatingButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _headerOpacity = (offset / 200).clamp(0.0, 1.0);
      _showFloatingButton = offset > 100;
    });
  }

  String get _title {
    return widget.type == CollectionType.album
        ? widget.album!.name
        : widget.playlist!.name;
  }

  String get _subtitle {
    return widget.type == CollectionType.album
        ? widget.album!.artist
        : '${widget.playlist!.trackCount} songs';
  }

  List<Track> get _tracks {
    return widget.type == CollectionType.album
        ? widget.album!.tracks
        : widget.playlist!.tracks;
  }

  dynamic get _artwork {
    return widget.type == CollectionType.album
        ? widget.album!.albumArt
        : widget.playlist!.coverImage;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tracks = _tracks;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          if (_artwork != null) _buildBackgroundGradient(),

          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                stretch: true,
                backgroundColor:
                    colorScheme.surface.withValues(alpha: _headerOpacity),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showOptions(context),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.zero,
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _headerOpacity,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(56, 0, 56, 16),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  background: _buildHeaderBackground(context),
                ),
              ),

              // Album/Playlist Info Section
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and metadata
                      Text(
                        _title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildMetadataRow(context),
                      const SizedBox(height: 24),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),

              // Track listing
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = tracks[index];
                      return _buildTrackItem(context, track, index);
                    },
                    childCount: tracks.length,
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),

          // Floating play button
          if (_showFloatingButton)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _playAll(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
                elevation: 8,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred background
        if (_artwork != null)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: _buildArtwork(fullSize: true, opacity: 0.3),
            ),
          ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),

        // Main artwork
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Hero(
              tag: 'artwork_${widget.album?.id ?? widget.playlist?.id}',
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 280, maxHeight: 280),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildArtwork(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtwork({bool fullSize = false, double opacity = 1.0}) {
    if (_artwork == null) {
      return Container(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: opacity),
        child: Icon(
          widget.type == CollectionType.album
              ? Icons.album
              : Icons.playlist_play,
          size: fullSize ? 200 : 100,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      );
    }

    if (_artwork is String) {
      return Opacity(
        opacity: opacity,
        child: Image.network(
          _artwork,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildArtwork(),
        ),
      );
    }

    return Opacity(
      opacity: opacity,
      child: Image.memory(
        _artwork,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildArtwork(),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context) {
    final tracks = _tracks;
    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (sum, track) => sum + track.duration,
    );

    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final durationStr = hours > 0 ? '$hours hr $minutes min' : '$minutes min';

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildMetadataChip(
          context,
          Icons.music_note,
          '${tracks.length} songs',
        ),
        _buildMetadataChip(context, Icons.access_time, durationStr),
        if (widget.type == CollectionType.album && widget.album!.year != null)
          _buildMetadataChip(
            context,
            Icons.calendar_today,
            widget.album!.year.toString(),
          ),
      ],
    );
  }

  Widget _buildMetadataChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _playAll(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _shufflePlay(context),
            icon: const Icon(Icons.shuffle),
            label: const Text('Shuffle'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackItem(BuildContext context, Track track, int index) {
    final audioProvider = Provider.of<AudioProvider>(context);
    final isCurrentTrack = audioProvider.currentTrack?.id == track.id;
    final isPlaying = isCurrentTrack && audioProvider.isPlaying;

    return InkWell(
      onTap: () => _playTrack(context, index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            // Track number or playing indicator
            SizedBox(
              width: 40,
              child: Center(
                child: isPlaying
                    ? Icon(
                        Icons.graphic_eq,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isCurrentTrack
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                              fontWeight: isCurrentTrack
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
              ),
            ),

            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: isCurrentTrack
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCurrentTrack
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.type == CollectionType.playlist)
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Duration
            Text(
              _formatDuration(track.duration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),

            const SizedBox(width: 8),

            // More options
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => _showTrackOptions(context, track),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _playAll(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final tracks = _tracks;
    if (tracks.isEmpty) return;

    audioProvider.playTrack(tracks[0], playlist: tracks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing ${tracks.length} songs'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shufflePlay(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final tracks = List<Track>.from(_tracks);
    if (tracks.isEmpty) return;

    tracks.shuffle();
    audioProvider.playTrack(tracks[0], playlist: tracks);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shuffling playback'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _playTrack(BuildContext context, int index) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final tracks = _tracks;

    audioProvider.playTrack(tracks[index], playlist: tracks);
    Navigator.pop(context);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () {
                Navigator.pop(context);
                _addToQueue(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement add to playlist
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share
              },
            ),
            if (widget.type == CollectionType.playlist)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit playlist'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement edit playlist
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (track.albumArt != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        track.albumArt!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note, size: 24),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artist,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () {
                Navigator.pop(context);
                final audioProvider =
                    Provider.of<AudioProvider>(context, listen: false);
                audioProvider.addTracksToQueue([track]);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to queue'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement add to playlist
              },
            ),
            ListTile(
              leading: const Icon(Icons.album),
              title: const Text('Go to album'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement go to album
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Go to artist'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement go to artist
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToQueue(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final tracks = _tracks;

    audioProvider.addTracksToQueue(tracks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${tracks.length} songs to queue'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
