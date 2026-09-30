import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/radii.dart';
import 'm3e_menu.dart';

class M3ESelect<T> extends StatelessWidget {
  const M3ESelect({
    super.key,
    required this.value,
    required this.labelOf,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String Function(T) labelOf;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(rSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    labelOf(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // anchor to the whole pill
    showM3EMenu(
      context,
      targetRect: box.localToGlobal(Offset.zero) & box.size,
      alignEnd: true,
      minWidth: math.max(160, box.size.width),
      maxWidth: 280,
      children: [
        for (final item in items)
          M3EMenuRow(
            item: M3EMenuItem(
              label: labelOf(item),
              selected: item == value,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (item != value) onChanged(item);
              },
            ),
          ),
      ],
    );
  }
}
