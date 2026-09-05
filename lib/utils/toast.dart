import 'package:flutter/material.dart';

final toastNavigatorKey = GlobalKey<NavigatorState>();

// floats above everything, snackbars get buried under sheets and nav bars
void showToast(String message) {
  final overlay = toastNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  final entry = OverlayEntry(
    builder: (context) {
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
                  color: const Color(0xE6616161),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
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
