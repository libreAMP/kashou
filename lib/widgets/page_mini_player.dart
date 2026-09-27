import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../utils/now_playing_modal.dart';
import 'mini_player.dart';

// pushed pages get the same mini player the main shell has
class PageMiniPlayer extends StatelessWidget {
  const PageMiniPlayer({super.key});

  void _openNowPlaying(BuildContext context) {
    openNowPlaying(context);
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
