import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import 'morph_shape.dart';
import '../theme/app_theme.dart';
import 'now_playing_bars.dart';
import 'scrolling_text.dart';

class StreamSongRow extends StatelessWidget {
  const StreamSongRow({
    super.key,
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.playing,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.slot = -1,
    this.count = 1,
  });

  final Widget artwork;
  final String title;
  final String subtitle;
  final bool isCurrent;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final int slot;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const outer = Radius.circular(rMd);
    const inner = Radius.circular(rSm);
    final radius = isDesktop
        ? BorderRadius.circular(10)
        : (slot < 0
            ? const BorderRadius.all(inner)
            : slot == 0
                ? const BorderRadius.vertical(top: outer, bottom: inner)
                : slot == count - 1
                    ? const BorderRadius.vertical(top: inner, bottom: outer)
                    : const BorderRadius.all(inner));

    return Material(
      color: isCurrent
          ? scheme.secondaryContainer
          : (isDesktop ? Colors.transparent : scheme.surfaceContainerLow),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        hoverColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              MorphArt(art: artwork, current: isCurrent, playing: playing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScrollingText(
                      text: title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 14.5 : 15,
                        height: 1.25,
                        color: isCurrent ? scheme.onSecondaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: isDesktop ? 12.5 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: playing ? 'Pause' : 'Play',
                child: MorphShape(
                  from: MaterialShapes.circle,
                  to: MaterialShapes.cookie9Sided,
                  morphed: playing,
                  spin: playing,
                  size: 40,
                  color: isCurrent ? scheme.primary : scheme.secondaryContainer,
                  onTap: onTap,
                  child: AnimatedSwitcher(
                    duration: EMotion.medium,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween<double>(begin: 0.6, end: 1).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(playing),
                      color: isCurrent
                          ? scheme.onPrimary
                          : scheme.onSecondaryContainer,
                      size: 21,
                    ),
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

class MorphArt extends StatelessWidget {
  const MorphArt({
    super.key,
    required this.art,
    required this.current,
    required this.playing,
    this.size = 52,
  });

  final Widget art;
  final bool current;
  final bool playing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MorphShape(
      from: MaterialShapes.square,
      to: MaterialShapes.cookie9Sided,
      morphed: current,
      size: size,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(child: art),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: playing ? 1 : 0,
                duration: EMotion.medium,
                child: ColoredBox(
                  color: scheme.primary.withValues(alpha: 0.55),
                  child: const Center(
                    child: NowPlayingBars(color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
