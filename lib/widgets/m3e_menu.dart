import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/radii.dart';

class M3EMenuItem {
  const M3EMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.trailing,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;
  final bool destructive;
}

class M3EMenu extends StatelessWidget {
  const M3EMenu({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class M3EMenuRow extends StatefulWidget {
  const M3EMenuRow({super.key, required this.item});

  final M3EMenuItem item;

  @override
  State<M3EMenuRow> createState() => _M3EMenuRowState();
}

class _M3EMenuRowState extends State<M3EMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final item = widget.item;
    final enabled = item.onTap != null;

    final fg = item.destructive
        ? scheme.onErrorContainer
        : item.selected
            ? scheme.onSecondaryContainer
            : scheme.onSurface;

    final bg = item.selected
        ? scheme.secondaryContainer
        : _hovered && enabled
            ? scheme.surfaceContainerHighest
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (item.selected) ...[
                  Icon(Icons.check_rounded, size: 20, color: fg),
                  const SizedBox(width: 12),
                ] else if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled ? fg : scheme.onSurfaceVariant,
                      fontWeight:
                          item.selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.trailing != null) ...[
                  const SizedBox(width: 12),
                  item.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class M3EMenuSeparator extends StatelessWidget {
  const M3EMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
          height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}

Future<void> showM3EMenu(
  BuildContext context, {
  Rect? targetRect,
  Offset? globalPosition,
  required List<Widget> children,
  double minWidth = 160,
  double maxWidth = 280,
  bool alignEnd = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final screen = Overlay.of(context).context.size!;
  final rect =
      targetRect ?? Rect.fromLTWH(globalPosition!.dx, globalPosition.dy, 0, 0);

  // flip above the trigger when there is more room up there
  var estimated = 16.0;
  for (final child in children) {
    estimated += child is M3EMenuSeparator ? 9 : 48;
  }
  final below = screen.height - rect.bottom;
  final top = below >= estimated || below >= rect.top
      ? rect.bottom + 4
      : math.max(8.0, rect.top - estimated - 4);

  // left and right are distances from the viewport edges
  final endGap = math.max(0.0, screen.width - rect.right);
  final canAlignEnd = endGap >= 8;
  final isEnd = alignEnd && canAlignEnd
      ? true
      : alignEnd
          ? false
          : rect.center.dx > screen.width / 2 && canAlignEnd;

  return showMenu<void>(
    context: context,
    color: scheme.surfaceContainerHigh,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
    constraints: BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
    ),
    position: RelativeRect.fromLTRB(
      isEnd ? endGap + 1 : math.max(0.0, rect.left),
      top,
      isEnd ? endGap : math.max(0.0, rect.left) + 1,
      math.max(0.0, screen.height - rect.bottom),
    ),
    items: children
        .whereType<M3EMenuRow>()
        .map((row) => PopupMenuItem<void>(
              padding: EdgeInsets.zero,
              enabled: false,
              height: 48,
              child: row.item.onTap == null
                  ? row
                  : InkWell(
                      onTap: row.item.onTap,
                      child: row,
                    ),
            ))
        .toList(),
  );
}
