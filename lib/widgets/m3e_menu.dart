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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(rMd),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rMd),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
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
  required Offset globalPosition,
  required List<Widget> children,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<void>(
    context: context,
    color: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem<void>(
        padding: EdgeInsets.zero,
        enabled: false,
        child: IgnorePointer(child: M3EMenu(children: children)),
      ),
    ],
  );
}
