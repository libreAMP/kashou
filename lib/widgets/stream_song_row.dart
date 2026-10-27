import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
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
          ? scheme.primary.withValues(alpha: 0.12)
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
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  children: [
                    Positioned.fill(child: artwork),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (playing)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.38),
                            child: const Center(
                              child:
                                  NowPlayingBars(color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                        color: isCurrent ? scheme.primary : null,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCurrent ? scheme.primary : scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isCurrent
                        ? scheme.onPrimary
                        : scheme.onSecondaryContainer,
                    size: 21,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  tooltip: isDesktop ? (playing ? 'Pause' : 'Play') : null,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
