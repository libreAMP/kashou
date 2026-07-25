import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'loading_indicator.dart';
import 'pressable.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/local_media_server.dart';
import '../utils/hero_transitions.dart';
import '../models/track.dart';

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

class _MiniPlayerSnapshot {
  const _MiniPlayerSnapshot({
    required this.track,
    required this.isLoading,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  final Track? track;
  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MiniPlayerSnapshot) return false;
    return identical(track, other.track) &&
        isLoading == other.isLoading &&
        isPlaying == other.isPlaying &&
        position == other.position &&
        duration == other.duration;
  }

  @override
  int get hashCode =>
      Object.hash(track, isLoading, isPlaying, position, duration);
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _dragDistance = 0;
  bool _isSwipingHorizontal = false;
  StreamSubscription<GoogleCastSession?>? _castSessionSubscription;
  bool _castingEnabled = false;
  bool _wasCasting = false;
  Timer? _castConnectionDebounce;
  bool _isCastConnecting = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
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

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _castingEnabled = settings.enableCasting;

    _castSessionSubscription = GoogleCastSessionManager
        .instance.currentSessionStream
        .listen((session) {
      if (!mounted) return;

      if (session != null) {
        debugPrint(
            '[Cast] Session connected to ${session.device?.friendlyName}');
        _wasCasting = true;

        // Debounce to prevent reconnect loops
        _castConnectionDebounce?.cancel();
        _castConnectionDebounce = Timer(const Duration(milliseconds: 500), () {
          if (mounted && !_isCastConnecting) {
            _isCastConnecting = true;
            _onCastConnected().then((_) {
              _isCastConnecting = false;
            }).catchError((e) {
              _isCastConnecting = false;
              debugPrint('[Cast] Connection handler error: $e');
            });
          }
        });
      } else {
        // stream replays null on subscribe
        if (!_wasCasting) return;
        _wasCasting = false;
        debugPrint('[Cast] Session disconnected - restoring local playback');
        _castConnectionDebounce?.cancel();
        _isCastConnecting = false;
        LocalMediaServer.instance.stop();

        // Restore local playback asynchronously
        final audioProvider =
            Provider.of<AudioProvider>(context, listen: false);

        Future.microtask(() async {
          await audioProvider.audioPlayer.setVolume(1.0);

          if (audioProvider.currentTrack != null) {
            try {
              await audioProvider.audioPlayer.play();
              debugPrint('[Cast] Local playback restored');
            } catch (e) {
              debugPrint('[Cast] Failed to restore playback: $e');
            }
          }
        });
      }
    });

    if (_castingEnabled) {
      GoogleCastDiscoveryManager.instance.startDiscovery();
    }
  }

  Future<void> _onCastConnected() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final track = audioProvider.currentTrack;
    if (track == null) {
      debugPrint('[Cast] No track to cast');
      return;
    }

    try {
      String streamUrl;
      final isRemoteUrl =
          track.path.startsWith('http://') || track.path.startsWith('https://');

      if (isRemoteUrl) {
        // For YouTube/remote streams, cast the URL directly
        streamUrl = track.path;
      } else {
        // For local files, use the media server
        final server = LocalMediaServer.instance;
        final baseUrl = await server.ensureStarted();
        final serverUrl =
            baseUrl != null ? server.buildStreamUrl(track.path) : null;

        if (serverUrl == null) {
          debugPrint('[Cast] Failed to start local media server');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Unable to start local media server for casting.')),
            );
          }
          return;
        }
        streamUrl = serverUrl;
      }

      await audioProvider.audioPlayer.pause();
      await audioProvider.audioPlayer.setVolume(0.0);

      final contentType = _inferTrackMimeType(track.path) ?? 'audio/mpeg';

      // Use generic metadata with explicit duration as int to avoid null Long error
      final metadata = GoogleCastGenericMediaMetadata(
        title: track.title,
        subtitle: track.artist,
        images: track.albumArt != null
            ? [
                GoogleCastImage(
                    url: Uri.parse(
                        'data:image/jpeg;base64,${base64Encode(track.albumArt!)}'))
              ]
            : [],
      );

      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformationIOS(
          contentId: streamUrl,
          streamType: CastMediaStreamType.buffered,
          contentUrl: Uri.parse(streamUrl),
          contentType: contentType,
          metadata: metadata,
        ),
        autoPlay: true,
        playPosition: audioProvider.position,
        playbackRate: 1.0,
      );

      // Wait a moment for media to load on TV, then explicitly send play command
      await Future.delayed(const Duration(milliseconds: 800));

      try {
        await GoogleCastRemoteMediaClient.instance.play();
      } catch (e) {
        debugPrint('[Cast] Play command failed: $e');
      }
    } catch (e) {
      debugPrint('[Cast] Error loading media: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cast error: $e')),
        );
      }
    }
  }

  Future<void> _toggleCastPlayPause() async {
    try {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      if (audioProvider.isPlaying) {
        await GoogleCastRemoteMediaClient.instance.pause();
      } else {
        await GoogleCastRemoteMediaClient.instance.play();
      }
    } catch (e) {
      debugPrint('[Cast] Toggle play/pause error: $e');
    }
  }

  Future<void> _castSkipNext() async {
    try {
      // Stop current cast media
      await GoogleCastRemoteMediaClient.instance.stop();
      debugPrint('[Cast] Stopped current cast media');

      // Skip to next track in local queue
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await audioProvider.skipNext();

      // Wait a moment for the new track to load locally
      await Future.delayed(const Duration(milliseconds: 500));

      // Cast the new track
      await _onCastConnected();
    } catch (e) {
      debugPrint('[Cast] Skip next error: $e');
    }
  }

  @override
  void dispose() {
    _castConnectionDebounce?.cancel();
    _castSessionSubscription?.cancel();
    if (_castingEnabled) {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    }
    _slideController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  String? _inferTrackMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/mp4';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';

    return null;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isSwipingHorizontal) return;
    setState(() {
      _dragDistance += details.primaryDelta ?? 0;
      if (_dragDistance > 0) {
        _slideController.value = (_dragDistance / 160).clamp(0.0, 1.0);
      } else if (_dragDistance < -90) {
        widget.onTap();
        _dragDistance = 0;
        _slideController.value = 0;
      }
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isSwipingHorizontal) return;
    if (_dragDistance > 70 ||
        details.primaryVelocity != null && details.primaryVelocity! > 500) {
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

  @override
  Widget build(BuildContext context) {
    return Selector<AudioProvider, _MiniPlayerSnapshot>(
      selector: (context, provider) => _MiniPlayerSnapshot(
        track: provider.currentTrack,
        isLoading: provider.isLoadingTrack,
        isPlaying: provider.isPlaying,
        position: provider.position,
        duration: provider.duration,
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
        final totalMillis = snapshot.duration.inMilliseconds;
        final progress = totalMillis > 0
            ? snapshot.position.inMilliseconds / totalMillis
            : 0.0;

        final settings = Provider.of<SettingsProvider>(context);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              onHorizontalDragStart: _handleHorizontalDragStart,
              onHorizontalDragEnd: (details) => _handleHorizontalDragEnd(
                  details, context.read<AudioProvider>()),
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Material(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
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
                                  borderRadius: BorderRadius.circular(10),
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
                                    Text(
                                      track.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                if (settings.enableCasting)
                                  IconButton(
                                    icon: Icon(
                                      Icons.cast,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    iconSize: 22,
                                    onPressed: () => _showCastDialog(context),
                                    splashRadius: 22,
                                  ),
                                StreamBuilder<GoogleCastSession?>(
                                  stream: GoogleCastSessionManager
                                      .instance.currentSessionStream,
                                  builder: (context, castSnapshot) {
                                    final isCasting = castSnapshot.data != null;
                                    return IconButton(
                                      icon: Icon(
                                        Icons.skip_next_rounded,
                                        color: colorScheme.onSurface,
                                      ),
                                      iconSize: 26,
                                      onPressed: () => isCasting
                                          ? _castSkipNext()
                                          : context
                                              .read<AudioProvider>()
                                              .skipNext(),
                                      splashRadius: 24,
                                    );
                                  },
                                ),
                                const SizedBox(width: 2),
                                StreamBuilder<GoogleCastSession?>(
                                  stream: GoogleCastSessionManager
                                      .instance.currentSessionStream,
                                  builder: (context, castSnapshot) {
                                    final isCasting = castSnapshot.data != null;
                                    return PressableScale(
                                        child: Material(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => isCasting
                                            ? _toggleCastPlayPause()
                                            : context
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
                                    ));
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        LinearProgressIndicator(
                          value: isLoading ? null : progress,
                          minHeight: 3,
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withOpacity(0.4),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
              debugPrint('[Cast] Stopping cast session...');

              try {
                // Stop remote media first
                try {
                  await GoogleCastRemoteMediaClient.instance.stop();
                  debugPrint('[Cast] Remote media stopped');
                } catch (e) {
                  debugPrint('[Cast] Error stopping remote media: $e');
                }

                // End the cast session
                final result = await GoogleCastSessionManager.instance
                    .endSessionAndStopCasting();
                debugPrint('[Cast] endSessionAndStopCasting result: $result');

                // Wait a bit for session state to update
                await Future.delayed(const Duration(milliseconds: 300));

                if (result == false) {
                  debugPrint('[Cast] Trying fallback endSession()');
                  final fallback =
                      await GoogleCastSessionManager.instance.endSession();
                  debugPrint('[Cast] endSession result: $fallback');

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (fallback == true) {
                    if (dialogContext.mounted)
                      Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Disconnected from $connectedDeviceName')),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Could not disconnect from $connectedDeviceName')),
                    );
                  }
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  return;
                }

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Disconnected from $connectedDeviceName')),
                  );
                }
              } catch (error) {
                debugPrint('[Cast] Disconnect error: $error');
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to disconnect: $error')),
                  );
                }
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cast to Device',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (session != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cast_connected,
                              color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Currently casting',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (session.deviceStatusText.isNotEmpty)
                                  Text(
                                    session.deviceStatusText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer
                                          .withOpacity(0.8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: stopCasting,
                            icon: const Icon(Icons.close),
                            label: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              content: SizedBox(
                height: 280,
                width: 320,
                child: StreamBuilder<List<GoogleCastDevice>>(
                  stream: GoogleCastDiscoveryManager.instance.devicesStream,
                  builder: (context, snapshot) {
                    final devices = snapshot.data ?? [];

                    if (devices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cast,
                                size: 36,
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.5)),
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

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isConnected =
                            device.deviceID == connectedDeviceId;

                        Future<void> connectToDevice() async {
                          debugPrint(
                              '[Cast] Connecting to ${device.friendlyName} (${device.deviceID})');
                          if (dialogContext.mounted)
                            Navigator.of(dialogContext).pop();

                          try {
                            final result = await GoogleCastSessionManager
                                .instance
                                .startSessionWithDevice(device);
                            debugPrint(
                                '[Cast] startSessionWithDevice result: $result');

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Connecting to ${device.friendlyName}...')),
                              );
                            }
                          } catch (error) {
                            debugPrint('[Cast] Connection error: $error');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to connect: $error')),
                              );
                            }
                          }
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isConnected
                                ? colorScheme.primary.withOpacity(0.15)
                                : colorScheme.surfaceContainerHighest,
                            child: Icon(
                              isConnected ? Icons.cast_connected : Icons.cast,
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            device.friendlyName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            isConnected
                                ? 'Connected'
                                : (device.modelName ?? 'Tap to connect'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: isConnected
                              ? Icon(
                                  Icons.cast_connected,
                                  color: colorScheme.primary,
                                )
                              : Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          onTap: isConnected ? null : connectToDevice,
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemCount: devices.length,
                    );
                  },
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
  if (url == null) return null;
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
