import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class M3EButtonGroup extends StatelessWidget {
  const M3EButtonGroup({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.itemKeys,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  final List<IconData>? icons;
  final List<Key>? itemKeys;

  static const double _height = 40;
  static const _full = Radius.circular(_height / 2);
  static const _inner = Radius.circular(12);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          _segment(context, i),
        ],
      ],
    );
  }

  Widget _segment(BuildContext context, int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = i == selected;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : EMotion.medium;
    final radius = isSelected
        ? const BorderRadius.all(_full)
        : BorderRadius.horizontal(
            left: i == 0 ? _full : _inner,
            right: i == labels.length - 1 ? _full : _inner,
          );
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;

    final icon = icons?[i] ?? (isSelected ? Icons.check_rounded : null);

    return Semantics(
      key: itemKeys?[i],
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: duration,
        curve: EMotion.standard,
        height: _height,
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onSelected(i),
            child: AnimatedPadding(
              duration: duration,
              curve: EMotion.standard,
              padding: EdgeInsets.symmetric(horizontal: isSelected ? 24 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: duration,
                    curve: EMotion.standard,
                    child: icon != null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(icon, size: 18, color: foreground),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    labels[i],
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
