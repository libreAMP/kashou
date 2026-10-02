import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/now_playing_screen.dart';
import 'platform.dart';

// full-height sheet on mobile, centered dialog on desktop
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
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 350),
      reverseDuration: Duration(milliseconds: 300),
    ),
    constraints: const BoxConstraints.expand(),
    clipBehavior: Clip.none,
    builder: (sheetContext) {
      final mq = MediaQuery.of(sheetContext);
      return MediaQuery(
        data: mq.copyWith(padding: mq.viewPadding),
        child: const NowPlayingScreen(),
      );
    },
  );
}
