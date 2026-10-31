import 'package:flutter/material.dart';

import '../theme/radii.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -0.6),
              ),
              if (subtitle != null)
                Text(subtitle!,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

InputDecoration searchDecoration(BuildContext context, String hint,
    {Widget? suffix}) {
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    prefixIcon: const Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 12, 0),
      child: Icon(Icons.search_rounded),
    ),
    prefixIconConstraints:
        const BoxConstraints(minWidth: 50, maxWidth: 50, minHeight: 0),
    hintStyle: Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(color: scheme.onSurfaceVariant),
    suffixIcon: suffix,
    filled: true,
    fillColor: scheme.surfaceContainerHigh,
    contentPadding: EdgeInsets.zero,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(rFull),
      borderSide: BorderSide.none,
    ),
  );
}
