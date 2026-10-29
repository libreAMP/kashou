import 'package:flutter/material.dart';

Widget sheetHandle(BuildContext context) {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class SheetTile extends StatelessWidget {
  const SheetTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      minTileHeight: 60,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: IconThemeData(size: 21, color: scheme.onSurfaceVariant),
          child: leading,
        ),
      ),
      title: title,
      titleTextStyle: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurface),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
