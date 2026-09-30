import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/radii.dart';

class M3ESearchBar extends StatelessWidget {
  const M3ESearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onBack,
    required this.focusNode,
    this.docked = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final FocusNode focusNode;
  final bool docked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: docked ? 24 : 12),
      child: SizedBox(
        height: 56,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: !docked,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search songs, artists',
            hintStyle: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
            prefixIcon: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: onBack,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 56,
              minHeight: 56,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear',
                    onPressed: onClear,
                  ),
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            contentPadding: EdgeInsets.zero,
            border: _outline(scheme, rFull),
            enabledBorder: _outline(scheme, rFull),
            focusedBorder: _outline(scheme, rFull, width: 2),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _outline(ColorScheme scheme, double radius,
      {double width = 0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: scheme.primary, width: width),
    );
  }
}

class M3ESearchResults extends StatelessWidget {
  const M3ESearchResults(
      {super.key, required this.child, required this.docked});

  final Widget child;
  final bool docked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (docked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
    }
    return ColoredBox(color: scheme.surfaceContainerLow, child: child);
  }
}

class M3ESearchStagger extends StatelessWidget {
  const M3ESearchStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = math.min(index, 8) * 30;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Interval(
        (delay / (260 + delay)).clamp(0.0, 0.9),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
