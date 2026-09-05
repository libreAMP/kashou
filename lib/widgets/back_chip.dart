import 'package:flutter/material.dart';

class BackChip extends StatelessWidget {
  const BackChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.pop(context),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.arrow_back_rounded, size: 22),
          ),
        ),
      ),
    );
  }
}
