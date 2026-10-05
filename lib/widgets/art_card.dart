import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import 'square_art.dart';

class ArtCard extends StatefulWidget {
  final String? thumbnail;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double? width;
  final bool emphasized;

  static const double _artGap = 8;
  static const double _titleLine = 22;
  static const double _subLine = 20;

  static double get defaultWidth => isTv ? 210.0 : (isDesktop ? 180.0 : 152.0);

  static double heightFor([double? artWidth, bool emphasized = false]) {
    final base = artWidth ?? defaultWidth;
    final w = (!isDesktop && !isTv && emphasized) ? base * 1.18 : base;
    return w + _artGap + _titleLine + _subLine + 4;
  }

  const ArtCard({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.width,
    this.emphasized = false,
  });

  @override
  State<ArtCard> createState() => _ArtCardState();
}

class _ArtCardState extends State<ArtCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.width ?? ArtCard.defaultWidth;
    final cardWidth = (!isDesktop && !isTv && widget.emphasized) ? base * 1.18 : base;
    final radius = widget.emphasized ? rLg : rMd;
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius + 3),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SquareArt(
                  url: widget.thumbnail,
                  size: cardWidth,
                  radius: radius,
                ),
                const SizedBox(height: ArtCard._artGap),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isTv ? 16 : (isDesktop ? 15 : 14),
                        height: 1.4,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: isTv ? 14 : (isDesktop ? 13 : 12),
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
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
