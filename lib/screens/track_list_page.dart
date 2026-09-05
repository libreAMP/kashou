import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../widgets/back_chip.dart';
import '../widgets/square_art.dart';
import '../widgets/track_list_item.dart';
import '../widgets/page_mini_player.dart';

// see all target for the local sections
class TrackListPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Track> tracks;
  final String? cover;
  final VoidCallback? onOptions;

  const TrackListPage({
    super.key,
    required this.title,
    required this.tracks,
    this.subtitle,
    this.cover,
    this.onOptions,
  });

  @override
  State<TrackListPage> createState() => _TrackListPageState();
}

class _TrackListPageState extends State<TrackListPage> {
  bool _grid = false;

  Widget _coverArt(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHigh,
      child:
          Icon(Icons.album_rounded, size: 64, color: scheme.onSurfaceVariant),
    );
    Widget img;
    final cover = widget.cover;
    if (cover == null) {
      img = fallback;
    } else if (cover.startsWith('http')) {
      img = CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      );
    } else {
      img = Image.file(
        File(cover),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return ClipRRect(
      borderRadius: EShape.radius(EShape.md),
      child: SizedBox(width: 180, height: 180, child: img),
    );
  }

  String _totalMinutes() {
    final mins = widget.tracks.fold<int>(0, (sum, t) => sum + t.duration.inMinutes);
    return '$mins min';
  }

  String? _ytId(Track track) {
    final uri = Uri.tryParse(track.sourceUrl ?? track.path);
    final v = uri?.queryParameters['v'];
    if (v != null) return v;
    if (uri != null &&
        uri.host.contains('youtu.be') &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  Widget _gridItem(BuildContext context, Track track) {
    final scheme = Theme.of(context).colorScheme;
    final id = _ytId(track);
    return InkWell(
      borderRadius: EShape.radius(EShape.md),
      onTap: () => context
          .read<AudioProvider>()
          .playTrack(track, playlist: widget.tracks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquareArt(
            bytes: track.albumArt,
            url: id != null ? 'https://i.ytimg.com/vi/$id/mqdefault.jpg' : null,
            radius: rMd,
          ),
          const SizedBox(height: 8),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      bottomNavigationBar: const PageMiniPlayer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const BackChip(),
            actions: [
              IconButton(
                icon: Icon(_grid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded),
                onPressed: () => setState(() => _grid = !_grid),
              ),
              if (widget.onOptions != null)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: widget.onOptions,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _coverArt(context)),
                  const SizedBox(height: 24),
                  Text(
                    widget.title,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chip(context, Icons.music_note_rounded,
                          '${widget.tracks.length} songs'),
                      const SizedBox(width: 8),
                      _chip(
                          context, Icons.schedule_rounded, _totalMinutes()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : () => context.read<AudioProvider>().playTrack(
                                    widget.tracks.first,
                                    playlist: widget.tracks,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: EShape.radius(EShape.xl),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : () {
    final shuffled = List<Track>.from(widget.tracks)..shuffle();
                                  context.read<AudioProvider>().playTrack(
                                        shuffled.first,
                                        playlist: shuffled,
                                      );
                                },
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: EShape.radius(EShape.xl),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _gridItem(context, widget.tracks[index]),
                  childCount: widget.tracks.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    TrackListItem(track: widget.tracks[index], index: index + 1),
                childCount: widget.tracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: EShape.radius(EShape.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
