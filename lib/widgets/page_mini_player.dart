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
  late final AnimationController _sheetController;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _sheetController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _ensureOverlay() {
    if (_overlayEntry != null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final mq = MediaQuery.of(overlayContext);
        final screenHeight = mq.size.height;
        return AnimatedBuilder(
          animation: _sheetController,
          builder: (context, _) {
            final t = _sheetController.value;
            if (t == 0) return const SizedBox.shrink();
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _collapseNowPlaying,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5 * t),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, (1.0 - t) * screenHeight),
                  child: RepaintBoundary(
                    child: MediaQuery(
                      data: mq.copyWith(padding: mq.viewPadding),
                      child: SizedBox(
                        height: screenHeight,
                        width: mq.size.width,
                        child: PopScope(
                          canPop: false,
                          onPopInvokedWithResult: (didPop, _) {
                            if (!didPop) _collapseNowPlaying();
                          },
                          child: NowPlayingScreen(
                            onCollapse: _collapseNowPlaying,
                            onCollapseDragUpdate:
                                _onNowPlayingCollapseDragUpdate,
                            onCollapseDragEnd: _onNowPlayingCollapseDragEnd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    overlay.insert(entry);
    _overlayEntry = entry;
  }

  void _openNowPlaying() {
    if (isDesktop) {
      openNowPlaying(context);
      return;
    }
    _ensureOverlay();
    _sheetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _collapseNowPlaying() {
    _sheetController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (!mounted) return;
      if (_sheetController.value == 0) {
        _removeOverlay();
      }
    });
  }

  void _onPlayerExpandDragUpdate(double dy) {
    if (isDesktop) return;
    final screenH = MediaQuery.of(context).size.height;
    if (screenH <= 0) return;
    _ensureOverlay();
    _sheetController.value =
        (_sheetController.value - dy / screenH).clamp(0.0, 1.0);
  }

  void _onPlayerExpandDragEnd(double velocity) {
    if (isDesktop) return;
    if (velocity < -300 || _sheetController.value > 0.35) {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _collapseNowPlaying();
    }
  }

  void _onNowPlayingCollapseDragUpdate(double dy) {
    final screenH = MediaQuery.of(context).size.height;
    if (screenH <= 0) return;
    _sheetController.value =
        (_sheetController.value - dy / screenH).clamp(0.0, 1.0);
  }

  void _onNowPlayingCollapseDragEnd(double velocity) {
    if (velocity > 300 || _sheetController.value < 0.65) {
      _collapseNowPlaying();
    } else {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
            onExpandDragUpdate: _onPlayerExpandDragUpdate,
            onExpandDragEnd: _onPlayerExpandDragEnd,
          ),
        );
      },
    );
  }
}
