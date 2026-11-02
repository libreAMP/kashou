import 'dart:math' as math;

import 'package:flutter/material.dart';

class M3EProgressBar extends StatelessWidget {
  const M3EProgressBar({
    super.key,
    this.value = 0,
    this.animate = false,
    this.height = 12,
  });

  final double value;
  final bool animate;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: height + 4,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(constraints.maxWidth, height + 4),
            painter: _M3EProgressPainter(
              fraction: value.clamp(0.0, 1.0),
              color: scheme.primary,
              trackColor: scheme.surfaceContainerHighest,
              thickness: height / 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _M3EProgressPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  final double thickness;

  _M3EProgressPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final midY = size.height / 2;
    final radius = Radius.circular(thickness / 2);
    final splitX = (size.width * fraction).clamp(0.0, size.width);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, midY - thickness / 2, size.width, thickness),
        radius,
      ),
      Paint()..color = trackColor,
    );

    if (splitX > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, midY - thickness / 2, splitX, thickness),
          radius,
        ),
        Paint()..color = color,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_M3EProgressPainter old) =>
      old.fraction != fraction || old.color != color;
}

class M3EIndeterminateBar extends StatefulWidget {
  const M3EIndeterminateBar({super.key, this.height = 12});

  final double height;

  @override
  State<M3EIndeterminateBar> createState() => _M3EIndeterminateBarState();
}

class _M3EIndeterminateBarState extends State<M3EIndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _IndeterminatePainter(
            t: _c.value,
            color: scheme.primary,
            trackColor: scheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

class _IndeterminatePainter extends CustomPainter {
  final double t;
  final Color color;
  final Color trackColor;

  _IndeterminatePainter({
    required this.t,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final midY = size.height / 2;
    final thickness = size.height * 0.5;
    final radius = Radius.circular(thickness / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, midY - thickness / 2, size.width, thickness),
        radius,
      ),
      Paint()..color = trackColor,
    );

    const span = 0.32;
    final head = t * (1 + span);
    final rawStart = (head - span) * size.width;
    final rawEnd = head * size.width;
    final start = math.max(0.0, math.min(size.width, rawStart));
    final end = math.max(0.0, math.min(size.width, rawEnd));

    if (end > start) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(start, midY - thickness / 2, end, midY + thickness / 2),
          radius,
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IndeterminatePainter old) => old.t != t;
}
