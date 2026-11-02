import 'dart:math' as math;

import 'package:flutter/material.dart';

class M3EMenuItem {
  const M3EMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.hasLeading = false,
    this.trailing,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool hasLeading;
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
  const M3EMenuRow({super.key, required this.item, this.dense = true});

  final M3EMenuItem item;
  final bool dense;

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
    final dense = widget.dense;
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

    final rowRadius = BorderRadius.circular(12);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: bg,
          borderRadius: rowRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: rowRadius,
            onTap: item.onTap,
            splashColor: scheme.primary.withValues(alpha: 0.12),
            highlightColor: scheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: dense ? 9 : 12,
              ),
              child: Row(
                children: [
                  if (item.selected) ...[
                    Icon(
                      Icons.check_rounded,
                      size: dense ? 18 : 20,
                      color: item.destructive
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                  ] else if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: dense ? 18 : 20,
                      color: item.destructive
                          ? scheme.onErrorContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                  ] else if (item.hasLeading) ...[
                    SizedBox(width: (dense ? 18 : 20) + 10),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: (dense
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(
                        color: enabled ? fg : scheme.onSurfaceVariant,
                        fontWeight:
                            item.selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.trailing != null) ...[
                    const SizedBox(width: 10),
                    item.trailing!,
                  ],
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.2),
      ),
    );
  }
}

class _M3EMenuSeparatorEntry extends PopupMenuEntry<void> {
  const _M3EMenuSeparatorEntry();

  @override
  double get height => 9;

  @override
  bool represents(void value) => false;

  @override
  State<_M3EMenuSeparatorEntry> createState() => _M3EMenuSeparatorEntryState();
}

class _M3EMenuSeparatorEntryState extends State<_M3EMenuSeparatorEntry> {
  @override
  Widget build(BuildContext context) {
    return const M3EMenuSeparator();
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
  bool dense = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final screen = Overlay.of(context).context.size!;
  final rect =
      targetRect ?? Rect.fromLTWH(globalPosition!.dx, globalPosition.dy, 0, 0);

  // flip above the trigger when there is more room up there
  var estimated = 16.0;
  final itemH = dense ? 40.0 : 48.0;
  for (final child in children) {
    estimated += child is M3EMenuSeparator ? 9 : itemH;
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
    color: scheme.surfaceContainer,
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.25),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    menuPadding: const EdgeInsets.symmetric(vertical: 8),
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
    items: children.map<PopupMenuEntry<void>>((child) {
      if (child is M3EMenuSeparator) {
        return const _M3EMenuSeparatorEntry();
      }
      return PopupMenuItem<void>(
        padding: EdgeInsets.zero,
        enabled: false,
        height: dense ? 40 : 48,
        child: child,
      );
    }).toList(),
  );
}
