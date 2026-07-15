import 'dart:math';

import 'package:flutter/material.dart';

// morphing blob instead of the stock spinner
class KashouLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const KashouLoader({super.key, this.size = 44, this.color});

  @override
  State<KashouLoader> createState() => _KashouLoaderState();
}

class _KashouLoaderState extends State<KashouLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CookiePainter(t: _controller.value, color: color),
      ),
    );
  }
}

class _CookiePainter extends CustomPainter {
  final double t;
  final Color color;

  _CookiePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final spin = t * 2 * pi;
    final depth = 0.06 + 0.05 * sin(t * 2 * pi * 2);

    final path = Path();
    for (var i = 0; i <= 360; i += 3) {
      final a = i * pi / 180;
      final r = base * (1 - depth + depth * cos(8 * a + spin * 3)) * 0.92;
      final p = Offset(c.dx + r * cos(a + spin), c.dy + r * sin(a + spin));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CookiePainter old) => old.t != t;
}
