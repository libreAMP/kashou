import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

class KashouLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const KashouLoader({super.key, this.size = 44, this.color});

  // the stock cycle has a pill and an oval that stretch too far
  static final _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
  ];

  @override
  Widget build(BuildContext context) {
    return ExpressiveLoadingIndicator(
      color: color ?? Theme.of(context).colorScheme.primary,
      polygons: _shapes,
      constraints: BoxConstraints.tight(Size.square(size)),
    );
  }
}
