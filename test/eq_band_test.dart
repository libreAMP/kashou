import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashou/widgets/eq_band.dart';

Future<List<double>> _pump(WidgetTester t, double start) async {
  final got = <double>[];
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 30,
          height: 200,
          child: EqBand(value: start, label: '1k', onChanged: got.add),
        ),
      ),
    ),
  ));
  return got;
}

void main() {
  testWidgets('tap near the top asks for the max', (t) async {
    final got = await _pump(t, 0);
    final box = t.getRect(find.byType(EqBand));
    await t.tapAt(box.topCenter + const Offset(0, 14));
    expect(got.last, 12);
  });

  testWidgets('tap near the bottom asks for the min', (t) async {
    final got = await _pump(t, 0);
    final box = t.getRect(find.byType(EqBand));
    await t.tapAt(box.bottomCenter - const Offset(0, 14));
    expect(got.last, -12);
  });

  testWidgets('tap on the middle lands on zero', (t) async {
    final got = await _pump(t, 5);
    await t.tapAt(t.getCenter(find.byType(EqBand)));
    expect(got.last, 0);
  });

  testWidgets('drag follows the finger and clamps', (t) async {
    final got = await _pump(t, 0);
    final g = await t.startGesture(t.getCenter(find.byType(EqBand)));
    await g.moveBy(const Offset(0, -20));
    await t.pump();
    await g.moveBy(const Offset(0, -300));
    await t.pump();
    expect(got.last, 12);
    await g.up();
  });

  testWidgets('disabled band ignores touches', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 30,
            height: 200,
            child: EqBand(value: 3, label: '1k', onChanged: null),
          ),
        ),
      ),
    ));
    await t.tapAt(t.getTopLeft(find.byType(EqBand)) + const Offset(10, 20));
  });
}
