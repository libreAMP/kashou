import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../providers/audio_provider.dart';
import '../services/local_media_server.dart';

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

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
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

    GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
      if (session != null) {
        _onCastConnected();
      } else {
        LocalMediaServer.instance.stop();
        final audioProvider = Provider.of<AudioProvider>(context, listen: false);
        audioProvider.audioPlayer.setVolume(1.0);
        audioProvider.audioPlayer.play();
      }
    });

    GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  Future<void> _onCastConnected() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final track = audioProvider.currentTrack;
    if (track != null) {
      final server = LocalMediaServer.instance;
      final baseUrl = await server.ensureStarted();
      final streamUrl = baseUrl != null ? server.buildStreamUrl(track.path) : null;

      if (streamUrl == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to start local media server for casting.')),
          );
        }
        return;
      }

      await audioProvider.audioPlayer.pause();
      await audioProvider.audioPlayer.setVolume(0.0);

      GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformationIOS(
          contentId: streamUrl,
          streamType: CastMediaStreamType.buffered,
          contentUrl: Uri.parse(streamUrl),
          contentType: _inferTrackMimeType(track.path) ?? 'audio/mpeg',
          metadata: GoogleCastMusicMediaMetadata(
            title: track.title,
            artist: track.artist,
            albumName: track.album,
            images: track.albumArt != null
                ? [GoogleCastImage(url: Uri.parse('data:image/jpeg;base64,${base64Encode(track.albumArt!)}'))]
                : null,
          ),
        ),
        autoPlay: true,
        playPosition: audioProvider.position,
        playbackRate: 1.0,
      );
    }
  }

  @override
  void dispose() {
    GoogleCastDiscoveryManager.instance.stopDiscovery();
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.audioPlayer.setVolume(1.0);
    audioProvider.audioPlayer.play();
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
                                StreamBuilder<GoogleCastSession?>(
                                  stream: GoogleCastSessionManager.instance.currentSessionStream,
                                  builder: (context, snapshot) {
                                    final isConnected = snapshot.data != null;
                                    final iconColor = isConnected
                                        ? Theme.of(context).colorScheme.tertiary
                                        : (useWhiteText
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface);

                                    return IconButton(
                                      icon: Icon(
                                        isConnected ? Icons.cast_connected : Icons.cast,
                                        color: iconColor,
                                      ),
                                      iconSize: 22,
                                      onPressed: () => _showCastDialog(context),
                                    );
                                  },
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
            final connectedDeviceName = session?.device?.friendlyName ?? 'Cast device';

            Future<void> stopCasting() async {
              Future<void> tryStopRemoteMedia() async {
                try {
                  await GoogleCastRemoteMediaClient.instance.stop();
                } catch (_) {
                }
              }

              try {
                await tryStopRemoteMedia();

                final result = await GoogleCastSessionManager.instance.endSessionAndStopCasting();
                final success = result != false;

                if (!success) {
                  final fallback = await GoogleCastSessionManager.instance.endSession();
                  if (fallback == true) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Disconnected from $connectedDeviceName')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not disconnect from $connectedDeviceName')),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Disconnected from $connectedDeviceName')),
                );
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to disconnect: $error')),
                );
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          Icon(Icons.cast_connected, color: colorScheme.primary),
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
                                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
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
                            Icon(Icons.cast, size: 36, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
                        final isConnected = device.deviceID == connectedDeviceId;

                        Future<void> connectToDevice() async {
                          Navigator.of(dialogContext).pop();
                          try {
                            await GoogleCastSessionManager.instance.startSessionWithDevice(device);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connecting to ${device.friendlyName}...')),
                            );
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to connect: $error')),
                            );
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
                              ? OutlinedButton.icon(
                                  onPressed: stopCasting,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Disconnect'),
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