import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

final toastNavigatorKey = GlobalKey<NavigatorState>();

// snackbars get buried under sheets so this floats above everything
void showToast(String message) {
  final overlay = toastNavigatorKey.currentState?.overlay;
  if (overlay == null || !overlay.mounted) return;
  // overlay entries are invisible to screen readers
  try {
    final view = View.maybeOf(overlay.context);
    final dir = Directionality.maybeOf(overlay.context);
    if (view != null && dir != null) {
      SemanticsService.sendAnnouncement(view, message, dir);
    }
  } catch (_) {}
  final entry = OverlayEntry(
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: scheme.onInverseSurface),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), entry.remove);
}
