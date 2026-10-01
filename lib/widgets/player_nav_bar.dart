import 'package:flutter/material.dart';

import '../screens/downloads_screen.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import 'mini_player.dart';

class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class PlayerNavBar extends StatefulWidget {
  const PlayerNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.hasPlayer,
    required this.onPlayerTap,
    required this.onPlayerDismiss,
    this.onPlayerExpandDragUpdate,
    this.onPlayerExpandDragEnd,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool hasPlayer;
  final VoidCallback onPlayerTap;
  final VoidCallback onPlayerDismiss;
  final ValueChanged<double>? onPlayerExpandDragUpdate;
  final ValueChanged<double>? onPlayerExpandDragEnd;

  @override
  State<PlayerNavBar> createState() => _PlayerNavBarState();
}

class _PlayerNavBarState extends State<PlayerNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  late final CurvedAnimation _expandAnim;
  double _slide = 0;
  double? _compactWidth;
  final _navKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: EMotion.fast,
      value: widget.hasPlayer ? 1 : 0,
    );
    _expandAnim = CurvedAnimation(parent: _expand, curve: EMotion.standard);
    _expand.addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(PlayerNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasPlayer != oldWidget.hasPlayer) {
      if (widget.hasPlayer) {
        _slide = 0;
        _expand.forward();
      } else {
        _slide = 1;
        _expand.reverse();
      }
    }
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      Future.delayed(EMotion.medium, () {
        if (mounted) _measure();
      });
    }
  }

  @override
  void dispose() {
    _expand.dispose();
    _expandAnim.dispose();
    super.dispose();
  }

  void _tick() => setState(() {});

  void _measure() {
    final ctx = _navKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final w = box.getMaxIntrinsicWidth(box.size.height);
    if (w > 0 && w != _compactWidth) setState(() => _compactWidth = w);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final t = (_expandAnim.value * (1 - _slide)).clamp(0.0, 1.0);
    final radius = BorderRadius.vertical(
      top: Radius.circular(rXl + (rLg - rXl) * t),
      bottom: const Radius.circular(rXl),
    );
    final maxW = MediaQuery.of(context).size.width - 32;
    final compact = _compactWidth;
    final double? width = t == 0
        ? null
        : (compact == null ? maxW : compact + (maxW - compact) * t);

    final pill = Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t > 0)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: t,
                child: MiniPlayer(
                  embedded: true,
                  onTap: widget.onPlayerTap,
                  onDismiss: widget.onPlayerDismiss,
                  onSlideProgress: (v) => setState(() => _slide = v),
                  onExpandDragUpdate: widget.onPlayerExpandDragUpdate,
                  onExpandDragEnd: widget.onPlayerExpandDragEnd,
                ),
              ),
            ),
          SizedBox(
            key: _navKey,
            child: _BubbleNavBar(
              items: widget.items,
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onDestinationSelected,
            ),
          ),
        ],
      ),
    );

    final shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: pill,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [SizedBox(width: width, child: shadowed)],
      ),
    );
  }
}

class _BubbleNavBar extends StatelessWidget {
  const _BubbleNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _BubbleNavItem(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _BubbleNavItem extends StatelessWidget {
  const _BubbleNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _NavBubble(item: item, selected: selected, hovered: false),
    );
  }
}

class _NavBubble extends StatelessWidget {
  const _NavBubble({
    required this.item,
    required this.selected,
    required this.hovered,
  });

  final NavItem item;
  final bool selected;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: EMotion.medium,
      curve: EMotion.emphasized,
      padding: EdgeInsets.symmetric(
        horizontal: selected ? 20 : 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer
            : (hovered
                ? scheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(rXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? item.selectedIcon : item.icon,
            color: tint,
            size: 26,
          ),
          AnimatedSize(
            duration: EMotion.medium,
            curve: EMotion.emphasized,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: tint,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class PlayerNavRail extends StatefulWidget {
  const PlayerNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<PlayerNavRail> createState() => _PlayerNavRailState();
}

class _PlayerNavRailState extends State<PlayerNavRail> {
  bool _extended = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: EMotion.medium,
      curve: EMotion.standard,
      width: _extended ? 210.0 : 72.0,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _extended
                                ? Icons.menu_open_rounded
                                : Icons.menu_rounded,
                          ),
                          tooltip:
                              _extended ? 'Collapse sidebar' : 'Expand sidebar',
                          onPressed: () =>
                              setState(() => _extended = !_extended),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, right: 12),
                          child: Text(
                            'Kashou',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.items.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _RailTile(
                  icon: widget.items[i].icon,
                  selectedIcon: widget.items[i].selectedIcon,
                  label: widget.items[i].label,
                  selected: i == widget.selectedIndex,
                  extended: _extended,
                  onTap: () => widget.onDestinationSelected(i),
                ),
              ],
              const Spacer(),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                indent: 4,
                endIndent: 4,
              ),
              const SizedBox(height: 8),
              _RailTile(
                icon: Icons.download_outlined,
                selectedIcon: Icons.download_rounded,
                label: 'Downloads',
                selected: false,
                extended: _extended,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DownloadsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              _RailTile(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                label: 'Settings',
                selected: false,
                extended: _extended,
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  const _RailTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final bg = widget.selected
        ? scheme.primaryContainer
        : (_hovered
            ? scheme.onSurface.withValues(alpha: 0.08)
            : Colors.transparent);

    final content = AnimatedContainer(
      duration: EMotion.fast,
      curve: EMotion.standard,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Center(
              child: Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                color: fg,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight:
                            widget.selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final clickable = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: content,
      ),
    );

    if (!widget.extended) {
      return Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 300),
        child: clickable,
      );
    }
    return clickable;
  }
}

class PlayerDockBar extends StatelessWidget {
  const PlayerDockBar({
    super.key,
    required this.hasPlayer,
    required this.onPlayerTap,
    required this.onPlayerDismiss,
  });

  final bool hasPlayer;
  final VoidCallback onPlayerTap;
  final VoidCallback onPlayerDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.bottomCenter,
        heightFactor: hasPlayer ? 1.0 : 0.0,
        duration: EMotion.fast,
        curve: EMotion.standard,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: MiniPlayer(
            embedded: true,
            onTap: onPlayerTap,
            onDismiss: onPlayerDismiss,
          ),
        ),
      ),
    );
  }
}
