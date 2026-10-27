import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import 'now_playing_bars.dart';

class M3ECoverCard extends StatefulWidget {
  const M3ECoverCard({
    super.key,
    required this.art,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onPlay,
    this.playing = false,
    this.width,
    this.radius = rLg,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final Widget art;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final bool playing;
  final double? width;
  final double radius;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  State<M3ECoverCard> createState() => _M3ECoverCardState();
}

class _M3ECoverCardState extends State<M3ECoverCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lifted = _hovered || _focused;
    // touch has no hover so the action stays out
    final showAction =
        widget.onPlay != null && (!isDesktop || lifted || widget.playing);
    final radius = BorderRadius.circular(widget.radius);

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTapUp: widget.onSecondaryTap == null
              ? null
              : (_) => widget.onSecondaryTap!(),
          child: Listener(
            onPointerDown: (_) => setState(() => _down = true),
            onPointerUp: (_) => setState(() => _down = false),
            onPointerCancel: (_) => setState(() => _down = false),
            child: AnimatedScale(
              scale: _down ? 0.975 : (lifted ? 1.012 : 1),
              duration: const Duration(milliseconds: 180),
              curve: _down ? Curves.easeOut : Curves.easeOutBack,
              child: SizedBox(
                width: widget.width,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 140;
                    final actionSize = compact ? 32.0 : 38.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  left: lifted
                                      ? (compact ? 8 : 10)
                                      : (compact ? 12 : 16),
                                  right: lifted
                                      ? (compact ? 8 : 10)
                                      : (compact ? 12 : 16),
                                  bottom: -5,
                                  height: 16,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(rSm),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: AnimatedSlide(
                                    offset: lifted
                                        ? const Offset(0, -0.012)
                                        : Offset.zero,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    child: ClipRRect(
                                      borderRadius: radius,
                                      child: widget.art,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: radius,
                                        border: Border.all(
                                          color: _focused
                                              ? scheme.primary
                                              : scheme.outlineVariant
                                                  .withValues(alpha: 0.24),
                                          width: _focused ? 2 : 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showAction)
                                  Positioned(
                                    right: compact ? 6 : 8,
                                    bottom: compact ? 6 : 8,
                                    child: _PlayAction(
                                      size: actionSize,
                                      playing: widget.playing,
                                      onTap: widget.onPlay!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: compact ? 13.5 : (isDesktop ? 15 : 14),
                              height: 1.3,
                              color: widget.playing
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize:
                                    compact ? 11.5 : (isDesktop ? 12.5 : 12),
                                height: 1.3,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayAction extends StatelessWidget {
  const _PlayAction({
    required this.playing,
    required this.onTap,
    required this.size,
  });

  final bool playing;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: playing ? 'Pause' : 'Play',
      child: Material(
        color: scheme.primary,
        elevation: 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: playing
                  ? NowPlayingBars(
                      color: scheme.onPrimary,
                      size: size * 0.42,
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      size: size * 0.63,
                      color: scheme.onPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
