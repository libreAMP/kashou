import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import 'morph_shape.dart';
import 'now_playing_bars.dart';
import 'track_options_sheet.dart';

class TrackListItem extends StatefulWidget {
  final Track track;
  final int? index;
  final List<Track>? playlist;
  final String? playlistId;

  final int slot;
  final int count;

  const TrackListItem({
    super.key,
    required this.track,
    this.index,
    this.playlist,
    this.playlistId,
    this.slot = -1,
    this.count = 0,
  });

  @override
  State<TrackListItem> createState() => _TrackListItemState();
}

class _TrackListItemState extends State<TrackListItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final isPlaying =
            audio.currentTrack?.id == widget.track.id && audio.isPlaying;
        final isCurrent = audio.currentTrack?.id == widget.track.id;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        const outer = Radius.circular(rMd);
        const inner = Radius.circular(rSm);
        final radius = widget.slot < 0
            ? BorderRadius.circular(rMd)
            : widget.slot == 0
                ? const BorderRadius.vertical(top: outer, bottom: inner)
                : widget.slot == widget.count - 1
                    ? const BorderRadius.vertical(top: inner, bottom: outer)
                    : BorderRadius.all(inner);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: widget.slot < 0
                ? Colors.transparent
                : colorScheme.surfaceContainerLow,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onFocusChange: (f) => setState(() => _focused = f),
              onTap: () {
                final library = Provider.of<LibraryProvider>(
                  context,
                  listen: false,
                );
                audio.playTrack(widget.track,
                    playlist: widget.playlist ?? library.allTracks);
              },
              onLongPress: () => showTrackOptionsSheet(context, widget.track,
                  playlistId: widget.playlistId),
              onSecondaryTapUp: isDesktop
                  ? (_) => showTrackOptionsSheet(context, widget.track,
                      playlistId: widget.playlistId)
                  : null,
              borderRadius: radius,
              hoverColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              splashColor: colorScheme.primary.withValues(alpha: 0.05),
              highlightColor: colorScheme.primary.withValues(alpha: 0.04),
              child: AnimatedContainer(
                duration: EMotion.fast,
                curve: EMotion.standard,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: radius,
                  border: Border.all(
                    color: _focused ? colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.index != null) ...[
                      SizedBox(
                        width: isTv ? 32 : 24,
                        child: Text(
                          '${widget.index}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: isTv ? 16 : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    _artwork(theme, isPlaying, isCurrent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.track.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isCurrent
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurface,
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w600,
                              fontSize: isTv ? 17 : null,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(widget.track),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: isTv ? 14 : (isDesktop ? 12.5 : 12),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedOpacity(
                      duration: EMotion.fast,
                      opacity: isDesktop && !isCurrent ? 0.5 : 0.85,
                      child: IconButton(
                        tooltip: 'More options',
                        onPressed: () {
                          showTrackOptionsSheet(context, widget.track,
                              playlistId: widget.playlistId);
                        },
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: isTv ? 22 : 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: isTv ? 44 : 40,
                          minHeight: isTv ? 44 : 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _artwork(ThemeData theme, bool isPlaying, bool isCurrent) {
    final size = isTv ? 60.0 : 52.0;
    final art = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: _artFor(widget.track, theme.colorScheme),
    );
    if (isCurrent) {
      return MorphShape(
        from: MaterialShapes.square,
        to: MaterialShapes.cookie9Sided,
        morphed: true,
        size: size,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned.fill(child: art),
              if (isPlaying)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.primary.withValues(alpha: 0.55),
                    child: const Center(
                      child: NowPlayingBars(color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final radius = BorderRadius.circular(rMd - 4);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(child: ClipRRect(borderRadius: radius, child: art)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(Track track) {
    final online = track.isOnline;
    final tail = online ? 'YouTube' : track.album;
    return tail.isEmpty ? track.artist : '${track.artist} • $tail';
  }

  String? _ytId(Track track) {
    final uri = Uri.tryParse(track.sourceUrl ?? track.path);
    return uri?.queryParameters['v'] ??
        (uri != null &&
                uri.host.contains('youtu.be') &&
                uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : null);
  }

  Widget _artFor(Track track, ColorScheme colorScheme) {
    final fallback = Center(
      child: Icon(
        Icons.music_note_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
    if (track.albumArt != null) {
      return Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    final id = _ytId(track);
    if (id != null) {
      return CachedNetworkImage(
        imageUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: colorScheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return fallback;
  }
}
