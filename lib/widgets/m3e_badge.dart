import 'package:flutter/material.dart';

class M3EBadge extends StatelessWidget {
  const M3EBadge({
    super.key,
    required this.child,
    this.count,
    this.dot = false,
  });

  final Widget child;

  final int? count;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    if (!dot && (count == null || count! <= 0)) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
