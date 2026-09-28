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
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final w = math.min(1080.0, math.max(860.0, size.width - 64));
        final h = math.min(760.0, math.max(600.0, size.height - 64));
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SizedBox(
            width: w,
            height: h,
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
