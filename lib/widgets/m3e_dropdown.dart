import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'm3e_menu.dart';

class M3EDropdown<T> extends StatelessWidget {
  const M3EDropdown({
    super.key,
    required this.value,
    required this.labelOf,
    required this.items,
    required this.onChanged,
    this.menuWidth = 200,
  });

  final T value;
  final String Function(T) labelOf;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final double menuWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 132),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        labelOf(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_drop_up_rounded,
                        size: 20, color: scheme.onSurface),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final scheme = Theme.of(context).colorScheme;

    showMenu<T>(
      context: context,
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      position: RelativeRect.fromRect(
        origin & size,
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(
        minWidth: math.max(menuWidth, size.width),
        maxHeight: 320,
      ),
      items: [
        PopupMenuItem<T>(
          padding: EdgeInsets.zero,
          enabled: false,
          child: IgnorePointer(
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
