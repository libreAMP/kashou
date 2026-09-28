import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/now_playing_screen.dart';
import 'platform.dart';

// opens the full now-playing experience: full-height drag sheet on mobile,
// centered dialog on desktop. Shared by the main shell and pushed pages so
// both entry points stay in sync.
Future<void> openNowPlaying(BuildContext context) {
  if (isDesktop) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        // wide enough for NowPlayingScreen's two-column desktop layout
        final w = math.min(960.0, size.width - 48);
        final h = math.min(720.0, size.height - 48);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SizedBox(
            width: w,
            height: h,
            // NowPlayingScreen sizes its artwork off MediaQuery, so report
            // the dialog bounds instead of the window bounds
            child: MediaQuery(
              data: MediaQuery.of(dialogContext).copyWith(size: Size(w, h)),
              child: const NowPlayingScreen(),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 300),
    ),
    clipBehavior: Clip.none,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [1.0],
        expand: false,
        builder: (context, scrollController) {
          return const NowPlayingScreen();
        },
      );
    },
  );
}
