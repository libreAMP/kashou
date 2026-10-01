import 'dart:ui';

import 'package:flutter/material.dart';

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
    final padding = MediaQuery.of(context).padding;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(12, 12 + padding.top, 12, 12 + padding.bottom),
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: EMotion.medium,
          curve: EMotion.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            // hugs the three destinations
            borderRadius: BorderRadius.circular(rXl),
          ),
          child: NavigationRail(
            selectedIndex: widget.selectedIndex,
            extended: _extended,
            minWidth: 80,
            minExtendedWidth: 240,
            backgroundColor: Colors.transparent,
            // all keeps the rows even
            labelType: _extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            groupAlignment: _extended ? -1.0 : 0.0,
            useIndicator: true,
            indicatorColor: scheme.primaryContainer,
            selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
            unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
            selectedLabelTextStyle: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            onDestinationSelected: widget.onDestinationSelected,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: Icon(
                  _extended ? Icons.menu_open_rounded : Icons.menu_rounded,
                ),
                tooltip: _extended ? 'Collapse menu' : 'Expand menu',
                onPressed: () => setState(() => _extended = !_extended),
              ),
            ),
            destinations: [
              for (final item in widget.items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// desktop: full-window-width player dock pinned under the rail and content,
// the desktop counterpart of the mobile floating pill bar
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
    final radius = const BorderRadius.vertical(top: Radius.circular(rXl));

    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.bottomCenter,
        heightFactor: hasPlayer ? 1.0 : 0.0,
        duration: EMotion.fast,
        curve: EMotion.standard,
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
              child: MiniPlayer(
                embedded: true,
                onTap: onPlayerTap,
                onDismiss: onPlayerDismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
