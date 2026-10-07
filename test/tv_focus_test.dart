import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kashou/providers/settings_provider.dart';
import 'package:kashou/providers/theme_provider.dart';
import 'package:kashou/screens/personalization_screen.dart';
import 'package:kashou/screens/settings_screen.dart';
import 'package:kashou/utils/platform.dart';
import 'package:kashou/widgets/dpad_focus.dart';
import 'package:kashou/widgets/player_nav_bar.dart';

List<FocusNode> focusables() {
  final nodes = <FocusNode>[];
  for (final node in FocusManager.instance.rootScope.descendants) {
    if (node is FocusScopeNode) continue;
    if (node.context == null) continue;
    if (!node.canRequestFocus) continue;
    nodes.add(node);
  }
  return nodes;
}

FocusNode? firstFocusable() {
  final nodes = focusables();
  return nodes.isEmpty ? null : nodes.first;
}

Future<void> pumpApp(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            navigationMode:
                isTv ? NavigationMode.directional : NavigationMode.traditional,
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pressDown(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
  }
}

void main() {
  tearDown(() => isTv = false);

  testWidgets('tv settings opens as a two pane menu', (tester) async {
    isTv = true;
    await pumpApp(tester, const SettingsScreen());

    expect(find.widgetWithText(ListTile, 'Appearance'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Library'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Audio'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Online'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'About'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Personalization'), findsNWidgets(2));
    expect(find.text('Gapless Playback'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Audio'));
    await tester.pumpAndSettle();

    expect(find.text('Gapless Playback'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Personalization'), findsOneWidget);

    final route = ModalRoute.of(tester.element(find.byType(SettingsScreen)));
    expect(route, isNotNull);
    expect(Navigator.of(tester.element(find.byType(SettingsScreen))).canPop(),
        isFalse);
  });

  testWidgets('tv settings can show personalization in the right pane',
      (tester) async {
    isTv = true;
    await pumpApp(tester, const SettingsScreen());

    await tester.tap(find.widgetWithText(ListTile, 'Personalization').first);
    await tester.pumpAndSettle();

    expect(find.byType(PersonalizationContent), findsOneWidget);
    expect(find.byType(PersonalizationScreen), findsNothing);
    expect(find.text('Colors'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(SettingsScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets('d pad walks past the color radios in tv mode', (tester) async {
    isTv = true;
    await pumpApp(tester, const PersonalizationScreen());

    firstFocusable()?.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    var moves = 0;
    for (var i = 0; i < 8; i++) {
      final before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      if (!identical(before, FocusManager.instance.primaryFocus)) moves++;
    }
    expect(moves, greaterThan(4));

    final primary = FocusManager.instance.primaryFocus!;
    expect(
      primary.context?.findAncestorWidgetOfExactType<RadioGroup<String>>(),
      isNull,
    );
  });

  testWidgets('dpad focus lets a field give its arrow keys back',
      (tester) async {
    isTv = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocus(
            child: Column(
              children: [
                const TextField(),
                const SizedBox(height: 40),
                TextButton(onPressed: () {}, child: const Text('below')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final field = FocusManager.instance.primaryFocus;
    expect(field, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, isNot(same(field)));
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextButton>(),
      isNotNull,
    );
  });

  testWidgets('sidebar grows while focus is inside it', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Row(
          children: [
            PlayerNavRail(
              items: const [
                NavItem(Icons.home_rounded, Icons.home_rounded, 'Home'),
                NavItem(Icons.radio_rounded, Icons.radio_rounded, 'Stream'),
              ],
              selectedIndex: 0,
              onDestinationSelected: _ignore,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('away'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final rail = find.byType(PlayerNavRail);
    expect((tester.renderObject(rail) as RenderBox).size.width, 76);

    FocusNode target = focusables()[1];
    for (final node in focusables()) {
      final chain = <String>[];
      node.context?.visitAncestorElements((el) {
        chain.add(el.widget.runtimeType.toString());
        return chain.length < 12;
      });
      if (chain.contains('_RailTile')) {
        target = node;
        break;
      }
    }
    target.requestFocus();
    await tester.pumpAndSettle();
    expect((tester.renderObject(rail) as RenderBox).size.width, 220);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect((tester.renderObject(rail) as RenderBox).size.width, 76);
  });
}

void _ignore(int index) {}
