import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../theme/app_theme.dart';
import '../theme/shapes.dart';

class MorphShape extends StatefulWidget {
  const MorphShape({
    super.key,
    required this.from,
    this.to,
    this.morphed = false,
    required this.size,
    this.color,
    this.child,
    this.spin = false,
    this.onTap,
  });

  final RoundedPolygon from;
  final RoundedPolygon? to;
  final bool morphed;
  final double size;
  final Color? color;
  final Widget? child;
  final bool spin;
  final VoidCallback? onTap;

  @override
  State<MorphShape> createState() => _MorphShapeState();
}

class _MorphShapeState extends State<MorphShape>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  bool _spinning = false;

  void _sync() {
    final on = widget.spin && !MediaQuery.disableAnimationsOf(context);
    if (on == _spinning) return;
    _spinning = on;
    if (on) {
      _spin.repeat();
      return;
    }
    // ease to the nearest quarter turn so square shapes land upright
    _spin.animateTo((_spin.value * 4).round() / 4,
        duration: EMotion.medium, curve: EMotion.standard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MorphShape old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.morphed ? 1 : 0),
      duration: EMotion.medium,
      curve: Curves.easeInOutCubicEmphasized,
      builder: (context, v, _) {
        final shape = PolygonBorder(widget.from, to: widget.to, t: v);
        return SizedBox.square(
          dimension: widget.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: RotationTransition(
                    turns: _spin,
                    child: Material(
                      color: widget.color ?? Colors.transparent,
                      shape: shape,
                      clipBehavior: Clip.antiAlias,
                      child: widget.onTap == null
                          ? null
                          : InkWell(customBorder: shape, onTap: widget.onTap),
                    ),
                  ),
                ),
              ),
              if (widget.child != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: ShapeBorderClipper(shape: shape),
                      child: Center(child: widget.child),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
