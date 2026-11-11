import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../theme/shapes.dart';

class MoodTile extends StatefulWidget {
  const MoodTile({
    super.key,
    required this.title,
    required this.seed,
    required this.index,
    required this.onTap,
  });

  final String title;
  final Color seed;
  final int index;
  final VoidCallback onTap;

  @override
  State<MoodTile> createState() => _MoodTileState();
}

class _MoodTileState extends State<MoodTile> {
  static final _schemes = <(Color, Brightness), ColorScheme>{};
  static final _shapes = [
    MaterialShapes.cookie9Sided,
    MaterialShapes.clover4Leaf,
    MaterialShapes.sunny,
    MaterialShapes.flower,
    MaterialShapes.softBurst,
    MaterialShapes.cookie6Sided,
    MaterialShapes.pentagon,
    MaterialShapes.cookie4Sided,
  ];

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _schemes.putIfAbsent(
      (widget.seed, theme.brightness),
      () => ColorScheme.fromSeed(
          seedColor: widget.seed, brightness: theme.brightness),
    );
    final duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : EMotion.slow;
    final i = widget.index;

    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(rMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        child: SizedBox(
          height: 96,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -22,
                child: AnimatedRotation(
                  turns: i * 0.07 + (_pressed ? 0.125 : 0),
                  duration: duration,
                  curve: EMotion.emphasized,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: ShapeDecoration(
                      shape: PolygonBorder(_shapes[i % _shapes.length]),
                      color: colors.primaryContainer,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
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
