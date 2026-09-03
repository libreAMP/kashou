import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const outer = Radius.circular(EShape.lg);
    const inner = Radius.circular(12);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 2));
      BorderRadius shape;
      if (children.length == 1) {
        shape = BorderRadius.all(outer);
      } else if (i == 0) {
        shape = BorderRadius.vertical(top: outer, bottom: inner);
      } else if (i == children.length - 1) {
        shape = BorderRadius.vertical(top: inner, bottom: outer);
      } else {
        shape = BorderRadius.all(inner);
      }
      rows.add(
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: children[i],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedSize(
            duration: EMotion.fast,
            curve: EMotion.standard,
            alignment: Alignment.topCenter,
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.contentPadding,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final EdgeInsetsGeometry? contentPadding;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = subtitle;
    return ListTile(
      contentPadding: contentPadding,
      leading: Icon(icon),
      title: Text(title),
      subtitle: sub != null ? Text(sub) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbIcon: MaterialStateProperty.resolveWith<Icon?>((states) {
          if (states.contains(MaterialState.selected)) {
            return Icon(Icons.check_rounded, size: 16, color: scheme.primary);
          }
          return Icon(
            Icons.close_rounded,
            size: 14,
            color: scheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }
}
