import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import 'dart:ui';
import 'dart:typed_data';

class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const MiniPlayer({
    super.key,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _dragDistance = 0;
  bool _isSwipingHorizontal = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isSwipingHorizontal) return;
    setState(() {
      _dragDistance += details.primaryDelta ?? 0;
      if (_dragDistance > 0) {
        _slideController.value = (_dragDistance / 100).clamp(0.0, 1.0);
      } else if (_dragDistance < -80) {
        widget.onTap();
        _dragDistance = 0;
        _slideController.value = 0;
      }
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isSwipingHorizontal) return;
    if (_dragDistance > 80) {
      _slideController.forward().then((_) {
        widget.onDismiss();
        _slideController.reset();
      });
    } else {
      _slideController.reverse();
    }
    _dragDistance = 0;
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _isSwipingHorizontal = true;
  }

  void _handleHorizontalDragEnd(
      DragEndDetails details, AudioProvider audioProvider) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 500) {
      _swipeController.forward().then((_) {
        if (velocity < 0) {
          audioProvider.skipNext();
        } else {
          audioProvider.skipPrevious();
        }
        _swipeController.reverse();
      });
    }
    _isSwipingHorizontal = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        if (audioProvider.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = audioProvider.currentTrack!;
        final progress = audioProvider.duration.inMilliseconds > 0
            ? audioProvider.position.inMilliseconds /
                audioProvider.duration.inMilliseconds
            : 0.0;

        final useWhiteText = isDarkMode;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              onHorizontalDragStart: _handleHorizontalDragStart,
              onHorizontalDragEnd: (details) =>
                  _handleHorizontalDragEnd(details, audioProvider),
              child: Container(
                width: MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (track.albumArt != null && isDarkMode)
                        Positioned.fill(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Image.memory(
                              track.albumArt!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                );
                              },
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDarkMode
                                  ? [
                                      Colors.black.withOpacity(0.7),
                                      Colors.black.withOpacity(0.5),
                                    ]
                                  : [
                                      Theme.of(context).colorScheme.surfaceContainerHighest,
                                      Theme.of(context).colorScheme.surfaceContainer,
                                    ],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 2.5,
                            backgroundColor: useWhiteText
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'album_art_${track.id}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: track.albumArt != null
                                          ? Image.memory(
                                              track.albumArt!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.music_note,
                                                  size: 24,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                );
                                              },
                                            )
                                          : Icon(
                                              Icons.music_note,
                                              size: 24,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: useWhiteText
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: useWhiteText
                                              ? Colors.white.withOpacity(0.7)
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    audioProvider.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: useWhiteText
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  iconSize: 26,
                                  onPressed: audioProvider.togglePlayPause,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: useWhiteText
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  iconSize: 26,
                                  onPressed: audioProvider.skipNext,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isAlbumArtDark(Uint8List? albumArt) {
    if (albumArt == null) return true;
    
    try {
      int totalBrightness = 0;
      int sampleCount = 0;
      
      final step = (albumArt.length / 600).ceil().clamp(1, albumArt.length);
      
      for (int i = 0; i < albumArt.length && sampleCount < 200; i += step) {
        if (i + 2 < albumArt.length) {
          final r = albumArt[i];
          final g = albumArt[i + 1];
          final b = albumArt[i + 2];
          final brightness = (0.299 * r + 0.587 * g + 0.114 * b).round();
          totalBrightness += brightness;
          sampleCount++;
        }
      }
      
      if (sampleCount == 0) return true;
      final avgBrightness = totalBrightness / sampleCount;
      return avgBrightness < 140;
    } catch (e) {
      return true;
    }
  }
}
