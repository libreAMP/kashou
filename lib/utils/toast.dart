import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

final toastNavigatorKey = GlobalKey<NavigatorState>();

// snackbars get buried under sheets so this floats above everything
void showToast(String message) {
  final overlay = toastNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  // overlay entries are invisible to screen readers
  SemanticsService.sendAnnouncement(
    View.of(overlay.context),
    message,
    Directionality.of(overlay.context),
  );
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
