import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
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
        final isPlaying = audio.currentTrack?.id == widget.track.id && audio.isPlaying;
        final isCurrent = audio.currentTrack?.id == widget.track.id;
        final colorScheme = Theme.of(context).colorScheme;

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
              borderRadius: BorderRadius.circular(rMd),
              splashColor: colorScheme.primary.withValues(alpha: 0.05),
              highlightColor: colorScheme.primary.withValues(alpha: 0.03),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colorScheme.primary.withValues(alpha: 0.14)
                      : (_focused
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(rMd),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: isTv ? 16 : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(rSm),
                      child: Container(
                        width: isTv ? 56 : 48,
                        height: isTv ? 56 : 48,
                        color: colorScheme.surfaceContainerHighest,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _artFor(widget.track, colorScheme),
                            if (isPlaying)
                              Container(
                                color: Colors.black.withValues(alpha: 0.4),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: Colors.white,
                                  size: isTv ? 24 : 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.track.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: isCurrent
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : (isDesktop
                                          ? FontWeight.w600
                                          : FontWeight.w500),
                                  fontSize: isTv ? 16 : null,
                                  height: isDesktop ? null : 1.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(widget.track),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: isTv ? 14 : (isDesktop ? 13 : 12),
                                      height: isDesktop ? null : 1.3,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => Tooltip(
                        message: 'More options',
                        child: Container(
                          width: isTv ? 44 : 36,
                          height: isTv ? 44 : 36,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              final box = buttonContext.findRenderObject()
                                  as RenderBox?;
                              showTrackOptionsSheet(context, widget.track,
                                  playlistId: widget.playlistId,
                                  anchor: box?.localToGlobal(
                                      box.size.bottomLeft(Offset.zero)));
                            },
                            icon: Icon(
                              Icons.more_vert,
                              size: isTv ? 22 : 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                          ),
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

  String _subtitle(Track track) {
    final online = (track.sourceUrl ?? track.path).startsWith('http');
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
    if (track.albumArt != null) {
      return Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }
    final id = _ytId(track);
    if (id != null) {
      return CachedNetworkImage(
        imageUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: colorScheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => Icon(
          Icons.music_note,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }
    return Icon(Icons.music_note,
        color: colorScheme.onSurfaceVariant, size: 24);
  }
}
