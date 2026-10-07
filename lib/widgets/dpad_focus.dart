import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/platform.dart';

// lets up and down leave a field or a radio row instead of being swallowed
class DpadFocus extends StatelessWidget {
  const DpadFocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isTv) return child;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): _up,
        const SingleActivator(LogicalKeyboardKey.arrowDown): _down,
      },
      child: child,
    );
  }

  void _up() => _step(TraversalDirection.up);

  void _down() => _step(TraversalDirection.down);

  void _step(TraversalDirection direction) {
    FocusManager.instance.primaryFocus?.focusInDirection(direction);
  }
}
