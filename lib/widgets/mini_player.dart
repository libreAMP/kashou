import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'loading_indicator.dart';
import 'pressable.dart';
import 'scrolling_text.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../services/cast_service.dart';
import '../utils/hero_transitions.dart';
import '../utils/platform.dart';
import '../models/track.dart';

class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final bool embedded;
  final ValueChanged<double>? onSlideProgress;
  final ValueChanged<double>? onExpandDragUpdate;
  final ValueChanged<double>? onExpandDragEnd;

  const MiniPlayer({
    super.key,
    required this.onTap,
    required this.onDismiss,
    this.embedded = false,
    this.onSlideProgress,
    this.onExpandDragUpdate,
    this.onExpandDragEnd,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerSnapshot {
  const _MiniPlayerSnapshot({
    required this.track,
    required this.isLoading,
    required this.isPlaying,
  });

  final Track? track;
  final bool isLoading;
  final bool isPlaying;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MiniPlayerSnapshot) return false;
    return identical(track, other.track) &&
        isLoading == other.isLoading &&
        isPlaying == other.isPlaying;
  }

  @override
  int get hashCode => Object.hash(track, isLoading, isPlaying);
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _dragDistance = 0;
  bool _focused = false;
  bool _isSwipingHorizontal = false;
  bool _reporting = true;
  bool _castingEnabled = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    ));
    _slideController.addListener(_reportSlide);

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _castingEnabled = settings.enableCasting && isMobile;
    if (_castingEnabled) {
      GoogleCastDiscoveryManager.instance.startDiscovery();
    }
  }

  void _reportSlide() {
    if (_reporting) widget.onSlideProgress?.call(_slideController.value);
  }

  @override
  void dispose() {
    _slideController.removeListener(_reportSlide);
    if (_castingEnabled) {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    }
    _slideController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  bool _isExpanding = false;

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isSwipingHorizontal) return;
    final dy = details.primaryDelta ?? 0;
    if (_isExpanding || (_dragDistance <= 0 && dy < 0)) {
      _isExpanding = true;
      _dragDistance += dy;
      widget.onExpandDragUpdate?.call(dy);
      return;
    }
    setState(() {
      _dragDistance += dy;
      if (_dragDistance > 0) {
        _slideController.value = (_dragDistance / 160).clamp(0.0, 1.0);
      }
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isSwipingHorizontal) return;
    if (_isExpanding) {
      _isExpanding = false;
      _dragDistance = 0;
      widget.onExpandDragEnd?.call(details.primaryVelocity ?? 0);
      return;
    }
    if (_dragDistance > 70 ||
        details.primaryVelocity != null && details.primaryVelocity! > 500) {
      _slideController.forward().then((_) {
        widget.onDismiss();
        _reporting = false;
        _slideController.reset();
        _reporting = true;
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
    if (velocity.abs() > 400) {
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


  // desktop: click the progress strip to seek; the bar itself looks the same
  Widget _seekableProgress(int totalMillis, Widget progressBar) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final width = constraints.maxWidth;
              if (width <= 0) return;
              final fraction =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              context.read<AudioProvider>().seek(
                    Duration(milliseconds: (fraction * totalMillis).round()),
                  );
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: progressBar,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AudioProvider, _MiniPlayerSnapshot>(
      selector: (context, provider) => _MiniPlayerSnapshot(
        track: provider.currentTrack,
        isLoading: provider.isLoadingTrack,
        isPlaying: provider.isPlaying,
      ),
      shouldRebuild: (previous, next) => previous != next,
      builder: (context, snapshot, child) {
        if (snapshot.track == null) {
          return const SizedBox.shrink();
        }

        final track = snapshot.track!;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isLoading = snapshot.isLoading;
        final settings = Provider.of<SettingsProvider>(context);

        Widget barCard = Material(
                    color: widget.embedded
                        ? Colors.transparent
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: widget.embedded
                        ? BorderRadius.zero
                        : BorderRadius.circular(rMd),
                    clipBehavior: widget.embedded ? Clip.none : Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'album_art_${track.id}',
                                createRectTween: albumArtRectTween,
                                flightShuttleBuilder:
                                    albumArtFlightShuttleBuilder,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(rSm),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                    ),
                                    child: SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: _miniArt(track, colorScheme),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ScrollingText(
                                      text: track.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artist,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isLoading) ...[
                                KashouLoader(
                                    size: 26, color: colorScheme.primary),
                                const SizedBox(width: 10),
                              ] else ...[
                                if (settings.enableCasting && !isDesktop)
                                  ListenableBuilder(
                                    listenable: CastService.instance,
                                    builder: (context, _) => IconButton(
                                      icon: Icon(
                                        CastService.instance.isCasting
                                            ? Icons.cast_connected
                                            : Icons.cast,
                                        color: CastService.instance.isCasting
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      iconSize: 22,
                                      onPressed: () => _showCastDialog(context),
                                      splashRadius: 22,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: isDesktop ? 'Previous' : null,
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color: colorScheme.onSurface,
                                  ),
                                  iconSize: 26,
                                  onPressed: () => context
                                      .read<AudioProvider>()
                                      .skipPrevious(),
                                  splashRadius: 24,
                                ),
                                IconButton(
                                  tooltip: isDesktop ? 'Next' : null,
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: colorScheme.onSurface,
                                  ),
                                  iconSize: 26,
                                  onPressed: () => context
                                      .read<AudioProvider>()
                                      .skipNext(),
                                  splashRadius: 24,
                                ),
                                const SizedBox(width: 2),
                                PressableScale(
                                  child: Material(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(rMd),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(rMd),
                                      onTap: () => context
                                          .read<AudioProvider>()
                                          .togglePlayPause(),
                                      child: SizedBox(
                                        width: 46,
                                        height: 46,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              left: snapshot.isPlaying
                                                  ? 0
                                                  : 1.5),
                                          child: Icon(
                                            snapshot.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 26,
                                            color: colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              // swipe-down-to-dismiss needs a visible
                              // alternative on desktop
                              if (isDesktop) ...[
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: 'Close player',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  iconSize: 22,
                                  onPressed: widget.onDismiss,
                                  splashRadius: 22,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Selector<AudioProvider, ({double progress, int totalMillis})>(
                          selector: (_, audio) {
                            final dur = audio.duration > Duration.zero
                                ? audio.duration
                                : (audio.currentTrack?.duration ?? Duration.zero);
                            final total = dur.inMilliseconds;
                            return (
                              progress: total > 0
                                  ? (audio.position.inMilliseconds / total)
                                      .clamp(0.0, 1.0)
                                  : 0.0,
                              totalMillis: total,
                            );
                          },
                          builder: (context, data, _) {
                            final progressBar = LinearProgressIndicator(
                              value: data.progress,
                              minHeight: 3,
                              backgroundColor: colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            );
                            return AnimatedSize(
                              duration: EMotion.medium,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.bottomCenter,
                              child: data.totalMillis > 0 && !isLoading
                                  ? (isDesktop
                                      ? _seekableProgress(data.totalMillis, progressBar)
                                      : progressBar)
                                  : const SizedBox.shrink(),
                            );
                          },
                        ),
                      ],
                    ),
                  );

        if (isDesktop) {
          barCard = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: barCard,
          );
        }

        if (_focused) {
          barCard = DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.primary, width: 2),
              borderRadius:
                  widget.embedded ? null : BorderRadius.circular(rMd),
            ),
            child: barCard,
          );
        }

        final gestureArea = FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (focused) =>
              setState(() => _focused = focused),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: _handleVerticalDragUpdate,
            onVerticalDragEnd: _handleVerticalDragEnd,
            onHorizontalDragStart: _handleHorizontalDragStart,
            onHorizontalDragEnd: (details) =>
                _handleHorizontalDragEnd(details, context.read<AudioProvider>()),
            child: RepaintBoundary(
              // full width on desktop everywhere; the mobile pill floats centered
              child: Padding(
                padding: widget.embedded
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: barCard,
              ),
            ),
          ),
        );

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: gestureArea,
          ),
        );
      },
    );
  }

  void _showCastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return StreamBuilder<GoogleCastSession?>(
          stream: GoogleCastSessionManager.instance.currentSessionStream,
          builder: (context, sessionSnapshot) {
            final session = sessionSnapshot.data;
            final connectedDeviceId = session?.device?.deviceID;
            final connectedDeviceName =
                session?.device?.friendlyName ?? 'Cast device';

            Future<void> stopCasting() async {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await CastService.instance.endSession();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Disconnected from $connectedDeviceName')),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(
                'Cast to Device',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (session != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorScheme.primary,
                              radius: 18,
                              child: Icon(
                                Icons.cast_connected,
                                color: colorScheme.onPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    connectedDeviceName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Connected',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: stopCasting,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      ),
                    StreamBuilder<List<GoogleCastDevice>>(
                      stream: GoogleCastDiscoveryManager.instance.devicesStream,
                      builder: (context, snapshot) {
                        final allDevices = snapshot.data ?? [];
                        final availableDevices = allDevices
                            .where((d) => d.deviceID != connectedDeviceId)
                            .toList();

                        if (availableDevices.isEmpty) {
                          if (session != null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cast,
                                  size: 32,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Searching for cast devices...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Text(
                                session != null ? 'Switch device' : 'Available devices',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableDevices.length,
                                itemBuilder: (context, index) {
                                  final device = availableDevices[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.cast,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    title: Text(
                                      device.friendlyName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: device.modelName != null
                                        ? Text(
                                            device.modelName!,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          )
                                        : null,
                                    onTap: () async {
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      try {
                                        await GoogleCastSessionManager.instance
                                            .startSessionWithDevice(device);
                                      } catch (e) {
                                        debugPrint('[Cast] Connection error: $e');
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Widget _miniArt(Track track, ColorScheme colorScheme) {
  if (track.albumArt != null) {
    return Image.memory(
      track.albumArt!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _artFallback(colorScheme),
    );
  }
  final thumb = _ytThumbUrl(track);
  if (thumb == null) return _artFallback(colorScheme);
  return CachedNetworkImage(
    imageUrl: thumb,
    fit: BoxFit.cover,
    fadeInDuration: const Duration(milliseconds: 200),
    fadeOutDuration: Duration.zero,
    placeholderFadeInDuration: Duration.zero,
    useOldImageOnUrlChange: true,
    placeholder: (_, __) => Container(color: colorScheme.primaryContainer),
    errorWidget: (_, __, ___) => _artFallback(colorScheme),
  );
}

Widget _artFallback(ColorScheme colorScheme) => Icon(
      Icons.music_note,
      size: 24,
      color: colorScheme.onPrimaryContainer,
    );

String? _ytThumbUrl(Track track) {
  final url = track.sourceUrl ?? track.path;
  final id = _ytVideoId(url);
  return id == null ? null : 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
}

String? _ytVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  return uri.queryParameters['v'];
}
