import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/equalizer_widget.dart';
import 'metadata_editor_screen.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../utils/hero_transitions.dart';
import '../providers/settings_provider.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  Future<void> _downloadTrack(BuildContext context, Track track) async {
    if (_isDownloading) return;

    // Check if it's an online track
    final isOnlineTrack = track.path.contains('youtube.com') || 
                         track.path.contains('youtu.be') || 
                         !track.path.startsWith('/');

    if (!isOnlineTrack) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only online tracks can be downloaded')),
        );
      }
      return;
    }

    // Check if YouTube integration is enabled
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.enableYouTubeIntegration) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube integration is disabled. Enable it in settings to download online tracks.')),
        );
      }
      return;
    }

    // Request storage permission with user feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Requesting storage permission...')),
      );
    }

    try {
      final status = await Permission.storage.request();
      
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          if (context.mounted) {
            _showPermissionDialog(context);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage permission is required to download. Please grant permission and try again.'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _downloadTrack(context, track),
                ),
              ),
            );
          }
        }
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission granted. Starting download...')),
        );
      }

      // Create safe filename first
      final safeTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final safeArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final extension = _getFileExtension(track.codec);
      final filename = '$safeTitle - $safeArtist$extension';

      // Show progress dialog
      if (context.mounted) {
        _showDownloadProgressDialog(context, filename);
      }

      // Try different storage locations
      Directory? downloadDir;
      
      // Try external storage first
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          downloadDir = Directory('${externalDir.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('External storage not available: $e')),
          );
        }
        // Fallback to application documents directory
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${appDir.path}/Downloads');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
      }

      if (downloadDir == null) {
        throw Exception('Could not access storage directory');
      }

      final filePath = '${downloadDir.path}/$filename';

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File already exists: $filename')),
          );
        }
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        return;
      }

      // Download the file with progress indication
      setState(() {
        _downloadProgress = 0.1; // Starting download
      });

      final response = await http.get(Uri.parse(track.path));
      
      setState(() {
        _downloadProgress = 0.5; // Download in progress
      });
      
      if (response.statusCode == 200) {
        setState(() {
          _downloadProgress = 0.8; // Writing file
        });
        
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0; // Completed
        });

        // Close progress dialog and show success
        if (context.mounted) {
          Navigator.of(context).pop(); // Close progress dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Download complete'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Show File',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved to: ${downloadDir?.path ?? 'Unknown location'}')),
                  );
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      
      // Close progress dialog and show error
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showDownloadProgressDialog(BuildContext context, String filename) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Downloading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filename,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isDownloading ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(_isDownloading ? 'Downloading...' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'Storage permission is needed to download tracks. Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _getFileExtension(String? codec) {
    if (codec == null) return '.mp3';
    
    switch (codec.toLowerCase()) {
      case 'mp3':
        return '.mp3';
      case 'flac':
        return '.flac';
      case 'aac':
      case 'm4a':
        return '.m4a';
      case 'ogg':
        return '.ogg';
      case 'wav':
        return '.wav';
      default:
        return '.mp3';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer2<AudioProvider, LibraryProvider>(
        builder: (context, audio, library, child) {
          final track = audio.currentTrack;

          if (track == null) {
            return const Center(child: Text('No track playing'));
          }

          final mediaQuery = MediaQuery.of(context);
          final size = mediaQuery.size;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final bottomInset = mediaQuery.padding.bottom;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface.withOpacity(0.9),
                  colorScheme.surface,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Ambient background covering entire screen
                Positioned.fill(child: _buildAmbientBackground(context, track)),
                
                // Content overlay
                SafeArea(
                  top: true,
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: _buildTopBar(context, track),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildArtworkCard(context, track, size),
                                const SizedBox(height: 28),
                                _buildTrackMeta(context, track, audio),
                                const SizedBox(height: 28),
                                _buildAudioInfoCard(context, track), // Audio details at bottom
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressStrip(context, audio),
                              const SizedBox(height: 18),
                              _buildPrimaryControls(context, audio),
                              const SizedBox(height: 34),
                              _buildSecondaryControlRow(context, audio, library),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        _buildSurfaceIconButton(
          context,
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Collapse player',
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Now Playing',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              // SizedBox(
              //   width: double.infinity,
              //   child: Text(
              //     track.title,
              //     textAlign: TextAlign.center,
              //     style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              //     maxLines: 1,
              //     overflow: TextOverflow.ellipsis,
              //     softWrap: false,
              //   ),
              // ),
            ],
          ),
        ),
        _buildSurfaceIconButton(
          context,
          icon: Icons.equalizer,
          tooltip: 'Equalizer',
          onPressed: () => _showEqualizerSheet(context),
        ),
        const SizedBox(width: 8),
        _buildSurfaceIconButton(
          context,
          icon: Icons.more_vert,
          tooltip: 'More options',
          onPressed: () => _showMoreOptions(context),
        ),
      ],
    );
  }

  Widget _buildArtworkCard(BuildContext context, Track track, Size size) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimension = size.width * 0.78;
    final borderRadius = BorderRadius.circular(36);

    Widget buildFallback() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: Icon(
          Icons.music_note,
          size: 120,
          color: colorScheme.onPrimaryContainer.withOpacity(0.35),
        ),
      );
    }

    final Widget image = track.albumArt != null
        ? Image.memory(
            track.albumArt!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => buildFallback(),
          )
        : buildFallback();

    return Hero(
      tag: 'album_art_${track.id}',
      createRectTween: albumArtRectTween,
      flightShuttleBuilder: albumArtFlightShuttleBuilder,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: dimension * 0.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientBackground(BuildContext context, Track track) {
    final colorScheme = Theme.of(context).colorScheme;

    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surface,
          ],
        ),
      ),
    );

    if (track.albumArt == null) {
      return placeholder;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          track.albumArt!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => placeholder,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            color: colorScheme.surface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackMeta(BuildContext context, Track track, AudioProvider audio) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          track.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontSize: 20,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        const SizedBox(height: 2),
        Text(
          track.artist,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        const SizedBox(height: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMetaAssistChip(context, icon: Icons.album_rounded, label: track.album),
            const SizedBox(height: 6),
            if (track.genre != null && track.genre!.isNotEmpty)
              _buildMetaAssistChip(context, icon: Icons.style_outlined, label: track.genre!),
            if (track.path.contains('youtube.com') || track.path.contains('youtu.be'))
              _buildMetaAssistChip(context, icon: Icons.play_circle_outline, label: 'YouTube'),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaAssistChip(BuildContext context, {required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStrip(BuildContext context, AudioProvider audio) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final position = audio.position.inMilliseconds.toDouble();
    final duration = audio.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(audio.position),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatDuration(audio.duration),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceVariant.withOpacity(0.4),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.16),
          ),
          child: Slider(
            value: position.clamp(0, duration),
            max: duration,
            onChanged: (value) {
              audio.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryControls(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircleIconButton(
            context,
            icon: Icons.skip_previous_rounded,
            onTap: audio.skipPrevious,
          ),
          const SizedBox(width: 20),
          _buildPlayButton(context, audio),
          const SizedBox(width: 20),
          _buildCircleIconButton(
            context,
            icon: Icons.skip_next_rounded,
            onTap: audio.skipNext,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 24,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = audio.isPlaying;

    final targetSize = 64.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      scale: isPlaying ? 1.04 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: targetSize,
        height: targetSize,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(isPlaying ? 0.32 : 0.22),
              blurRadius: isPlaying ? 24 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: audio.togglePlayPause,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
                  return RotationTransition(
                    turns: Tween<double>(begin: -0.08, end: 0).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.75, end: 1).animate(curved),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey<bool>(isPlaying),
                  size: 30,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryControlRow(BuildContext context, AudioProvider audio, LibraryProvider library) {
    final colorScheme = Theme.of(context).colorScheme;
    final isShuffle = audio.shuffleMode != ShuffleMode.off;
    final isRepeatActive = audio.repeatMode != RepeatMode.off;
    final isFavorite = library.isTrackFavorite(audio.currentTrack?.id ?? '');
    final isOnlineTrack = audio.currentTrack != null && 
                         (audio.currentTrack!.path.contains('youtube.com') || 
                          audio.currentTrack!.path.contains('youtu.be') || 
                          !audio.currentTrack!.path.startsWith('/'));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSecondaryIconButton(
          context,
          icon: _getShuffleIcon(audio.shuffleMode),
          tooltip: 'Shuffle',
          active: isShuffle,
          onTap: () {
            final newMode = audio.shuffleMode == ShuffleMode.off ? ShuffleMode.songs : ShuffleMode.off;
            audio.setShuffleMode(newMode);
          },
        ),
        _buildSecondaryIconButton(
          context,
          icon: _getRepeatIcon(audio.repeatMode),
          tooltip: _repeatLabel(audio.repeatMode),
          active: isRepeatActive,
          onTap: () {
            final modes = RepeatMode.values;
            final currentIndex = modes.indexOf(audio.repeatMode);
            final nextIndex = (currentIndex + 1) % modes.length;
            audio.setRepeatMode(modes[nextIndex]);
          },
        ),
        _buildSecondaryIconButton(
          context,
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          tooltip: isFavorite ? 'Remove from likes' : 'Add to likes',
          active: isFavorite,
          onTap: () {
            if (audio.currentTrack != null) {
              library.toggleFavorite(audio.currentTrack!);
            }
          },
        ),
        _buildSecondaryIconButton(
          context,
          icon: Icons.queue_music_rounded,
          tooltip: 'View queue',
          active: false,
          onTap: () => _showQueueSheet(context),
        ),
        if (isOnlineTrack)
          _buildSecondaryIconButton(
            context,
            icon: _isDownloading ? Icons.downloading : Icons.download,
            tooltip: 'Download track',
            active: _isDownloading,
            onTap: () {
              if (audio.currentTrack != null) {
                _downloadTrack(context, audio.currentTrack!);
              }
            },
          ),
      ],
    );
  }

  Widget _buildAudioInfoCard(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final infoRows = <MapEntry<String, String>>[
      MapEntry('Format', track.codec ?? 'Unknown'),
      MapEntry('Bitrate', track.bitrate != null ? '${track.bitrate} kbps' : 'Unknown'),
      MapEntry('Sample Rate', track.sampleRate != null ? '${track.sampleRate} Hz' : 'Unknown'),
      MapEntry('Duration', _formatDuration(track.duration)),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...infoRows.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        shape: const CircleBorder(),
        color: colorScheme.surfaceContainerHigh,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = active
        ? colorScheme.primary.withOpacity(0.15)
        : colorScheme.surfaceContainerHigh;
    final iconColor = active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }

  String _repeatLabel(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return 'Repeat off';
      case RepeatMode.all:
        return 'Repeat all';
      case RepeatMode.one:
        return 'Repeat one';
    }
  }

  IconData _getShuffleIcon(ShuffleMode mode) {
    switch (mode) {
      case ShuffleMode.off:
        return Icons.shuffle;
      case ShuffleMode.songs:
        return Icons.shuffle_on_outlined;
      case ShuffleMode.categories:
        return Icons.shuffle_on;
    }
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return Icons.repeat;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }

  void _showEqualizerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return const EqualizerWidget();
          },
        );
      },
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<AudioProvider>(
              builder: (context, audio, child) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Queue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: audio.queue.length,
                        itemBuilder: (context, index) {
                          final track = audio.queue[index];
                          final isCurrent = index == audio.currentIndex;

                          return ListTile(
                            leading: Icon(
                              isCurrent
                                  ? Icons.play_circle_filled
                                  : Icons.music_note,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              track.title,
                              style: TextStyle(
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: isCurrent ? FontWeight.bold : null,
                              ),
                            ),
                            subtitle: Text(track.artist),
                            onTap: () {
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMoreOptions(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final track = audioProvider.currentTrack;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Metadata'),
                onTap: () {
                  Navigator.pop(context);
                  if (track != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MetadataEditorScreen(track: track),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Track Info'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
