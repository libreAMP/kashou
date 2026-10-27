import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import 'm3e_cover_card.dart';
import 'square_art.dart';

class ArtCard extends StatelessWidget {
  final String? thumbnail;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final bool playing;
  final double? width;
  final bool emphasized;

  static const double _artGap = 6;
  static const double _titleLine = 19;
  static const double _subLine = 17;

  static double get defaultWidth => isTv ? 210.0 : (isDesktop ? 180.0 : 152.0);

  static double heightFor([double? artWidth, bool emphasized = false]) {
    final base = artWidth ?? defaultWidth;
    final w = (!isDesktop && !isTv && emphasized) ? base * 1.18 : base;
    return w + _artGap + _titleLine + 2 + _subLine + 4;
  }

  const ArtCard({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onPlay,
    this.playing = false,
    this.width,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = width ?? ArtCard.defaultWidth;
    final cardWidth = (!isDesktop && !isTv && emphasized) ? base * 1.18 : base;
    return M3ECoverCard(
      art: SquareArt(url: thumbnail, radius: 0),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      onPlay: onPlay,
      playing: playing,
      width: cardWidth,
      radius: rLg,
    );
  }
}
