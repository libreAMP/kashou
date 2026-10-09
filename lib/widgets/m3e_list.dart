import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/radii.dart';

class M3EListRow extends StatefulWidget {
  const M3EListRow({
    super.key,
    required this.label,
    this.supportingText,
    this.leading,
    this.trailingText,
    this.onTap,
    this.selected = false,
    this.slot = -1,
    this.count = 0,
  });

  final String label;
  final String? supportingText;
  final Widget? leading;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool selected;
  final int slot;
  final int count;

  @override
  State<M3EListRow> createState() => _M3EListRowState();
}

class _M3EListRowState extends State<M3EListRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // grouped rows keep the card fill so a pick still reads against it
    final bg = widget.selected
        ? scheme.secondaryContainer
        : _hovered && widget.onTap != null
            ? scheme.surfaceContainerHighest
            : widget.slot < 0
                ? Colors.transparent
                : scheme.surfaceContainerLow;

    final fg = widget.selected ? scheme.onSecondaryContainer : scheme.onSurface;

    const outer = Radius.circular(rMd);
    const inner = Radius.circular(rSm);
    final radius = widget.slot < 0
        ? BorderRadius.zero
        : widget.slot == 0
            ? const BorderRadius.vertical(top: outer, bottom: inner)
            : widget.slot == widget.count - 1
                ? const BorderRadius.vertical(top: inner, bottom: outer)
                : BorderRadius.all(inner);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: radius,
          child: AnimatedContainer(
            duration: EMotion.fast,
            curve: EMotion.standard,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: theme.textTheme.bodyLarge?.copyWith(color: fg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.supportingText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.supportingText!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.selected
                                  ? scheme.onSecondaryContainer
                                      .withValues(alpha: 0.8)
                                  : scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailingText != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      widget.trailingText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.selected ? fg : scheme.onSurfaceVariant,
                      ),
                    ),
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
