import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'm3e_menu.dart';

class M3ESelect<T> extends StatefulWidget {
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
  State<M3ESelect<T>> createState() => _M3ESelectState<T>();
}

class _M3ESelectState<T> extends State<M3ESelect<T>> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(12);

    final bg = _isOpen
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final fg = _isOpen
        ? scheme.onSecondaryContainer
        : scheme.onSurface;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.labelOf(widget.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubicEmphasized,
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 22,
                    color: _isOpen
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _isOpen = true);
    try {
      await showM3EMenu(
        context,
        targetRect: box.localToGlobal(Offset.zero) & box.size,
        alignEnd: true,
        dense: true,
        minWidth: math.max(160, box.size.width),
        maxWidth: 260,
        children: [
          for (final item in widget.items)
            M3EMenuRow(
              dense: true,
              item: M3EMenuItem(
                label: widget.labelOf(item),
                selected: item == widget.value,
                hasLeading: true,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  if (item != widget.value) widget.onChanged(item);
                },
              ),
            ),
        ],
      );
    } finally {
      if (mounted) {
        setState(() => _isOpen = false);
      }
    }
  }
}
