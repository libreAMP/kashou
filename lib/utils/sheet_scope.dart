import 'package:flutter/widgets.dart';

class SheetScope extends InheritedWidget {
  const SheetScope({
    super.key,
    required this.open,
    required super.child,
  });

  final bool open;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetScope>()?.open ?? false;

  @override
  bool updateShouldNotify(SheetScope old) => old.open != open;
}
