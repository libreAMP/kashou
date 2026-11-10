import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashou/widgets/m3e_button_group.dart';

void main() {
  Future<int?> pump(WidgetTester tester, {List<IconData>? icons}) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: M3EButtonGroup(
          labels: const ['All', 'Songs', 'Albums'],
          selected: 1,
          icons: icons,
          onSelected: (i) => tapped = i,
        ),
      ),
    ));
    await tester.tap(find.text('Albums'));
    return tapped;
  }

  testWidgets('only the selected item shows a check and taps report the index',
      (tester) async {
    expect(await pump(tester), 2);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.getSemantics(find.text('Songs')),
        isSemantics(isSelected: true));
  });

  testWidgets('given icons, every item shows its own icon and no check',
      (tester) async {
    await pump(tester, icons: const [Icons.home, Icons.music_note, Icons.album]);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.album), findsOneWidget);
  });
}
