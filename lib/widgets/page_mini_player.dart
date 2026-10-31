import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../screens/now_playing_screen.dart';
import '../utils/now_playing_modal.dart';
import '../utils/platform.dart';
import 'mini_player.dart';

// pushed pages get the same mini player the main shell has
class PageMiniPlayer extends StatefulWidget {
  const PageMiniPlayer({super.key});

  @override
  State<PageMiniPlayer> createState() => _PageMiniPlayerState();
}

class _PageMiniPlayerState extends State<PageMiniPlayer>
    with SingleTickerProviderStateMixin {
  late final _sheet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 220),
  );
  bool _open = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  double get _height => MediaQuery.of(context).size.height;

  // a real route so sheets and dialogs from the player stack above it
  void _push() {
    if (_open) return;
    _open = true;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      constraints: const BoxConstraints.expand(),
      clipBehavior: Clip.none,
      transitionAnimationController: _sheet,
      builder: (sheetContext) {
        final view = MediaQueryData.fromView(View.of(sheetContext));
        return MediaQuery(
          data: MediaQuery.of(sheetContext).copyWith(
              padding: view.viewPadding, viewPadding: view.viewPadding),
          child: NowPlayingScreen(
            onCollapse: _collapse,
            onCollapseDragUpdate: (dy) => _drag(-dy),
            onCollapseDragEnd: (v) =>
                v > 300 || _sheet.value < 0.65 ? _collapse() : _settle(),
          ),
        );
      },
    ).whenComplete(() => _open = false);
  }

  void _collapse() {
    if (_open) Navigator.of(context, rootNavigator: true).pop();
  }

  void _settle() => _sheet.animateTo(1, curve: Curves.easeOutCubic);

  void _drag(double dy) {
    if (_height <= 0) return;
    _push();
    _sheet.value = (_sheet.value + dy / _height).clamp(0.0, 1.0);
  }

  void _openNowPlaying() => isDesktop ? openNowPlaying(context) : _push();

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (audio.currentTrack == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: MiniPlayer(
            onTap: _openNowPlaying,
            onDismiss: audio.stop,
            onExpandDragUpdate: (dy) => isDesktop ? null : _drag(-dy),
            onExpandDragEnd: (v) {
              if (isDesktop) return;
              v < -300 || _sheet.value > 0.35 ? _settle() : _collapse();
            },
          ),
        );
      },
    );
  }
}
