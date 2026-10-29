import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashou/theme/shapes.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

void main() {
  test('polygon border path stays inside its rect', () {
    const rect = Rect.fromLTWH(10, 10, 100, 100);
    final b =
        PolygonBorder(MaterialShapes.circle).getOuterPath(rect).getBounds();
    expect(rect.inflate(1).contains(b.topLeft), isTrue);
    expect(rect.inflate(1).contains(b.bottomRight), isTrue);
  });
}
