import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../screens/now_playing_screen.dart';
import 'mini_player.dart';

// pushed pages get the same mini player the main shell has
class PageMiniPlayer extends StatelessWidget {
  const PageMiniPlayer({super.key});

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            top: mediaQuery.viewPadding.top,
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: const NowPlayingScreen(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (audio.currentTrack == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: MiniPlayer(
            onTap: () => _openNowPlaying(context),
            onDismiss: audio.stop,
          ),
        );
      },
    );
  }
}
