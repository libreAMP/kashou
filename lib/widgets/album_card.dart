import 'package:flutter/material.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';

class AlbumCard extends StatefulWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _focused = false;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen.album(album: widget.album),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget fallback() => Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.album_rounded,
              size: 32, color: scheme.onSurfaceVariant),
        );

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _open(context),
        ),
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(rMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rMd + 3),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(rMd),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: widget.album.albumArt != null
                        ? Image.memory(
                            widget.album.albumArt!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => fallback(),
                          )
                        : fallback(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isTv ? 14 : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.album.artist} · ${widget.album.trackCount} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: isTv ? 13 : null,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
