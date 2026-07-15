import 'dart:math';

import 'package:flutter/material.dart';

class WavyCircleBorder extends ShapeBorder {
  final int scallops;
  final double depth;

  const WavyCircleBorder({this.scallops = 12, this.depth = 0.045});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Path _wave(Rect rect) {
    final c = rect.center;
    final base = rect.shortestSide / 2;
    final path = Path();
    for (var i = 0; i <= 360; i += 2) {
      final t = i * pi / 180;
      final r = base * (1 - depth + depth * cos(scallops * t));
      final p = Offset(c.dx + r * cos(t), c.dy + r * sin(t));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _wave(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _wave(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      WavyCircleBorder(scallops: scallops, depth: depth * t);
}
