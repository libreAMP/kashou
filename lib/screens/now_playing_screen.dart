import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../widgets/loading_indicator.dart';
import '../widgets/squiggly_slider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../services/ytmusic_service.dart';
import 'artist_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _findingArtist = false;

  Future<void> _openArtist(Track track) async {
    if (_findingArtist) return;
    // reuse the id we already have, search is only the fallback
    var browseId = track.artistId;
    if (browseId == null) {
      _findingArtist = true;
      browseId = await const YtMusicService().findArtistId(track.artist);
      _findingArtist = false;
    }
    if (!mounted) return;
    final id = browseId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist not found on YouTube Music')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArtistScreen(browseId: id, name: track.artist),
    ));
  }

  Future<void> _downloadTrack(BuildContext context, Track track) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final isOnlineTrack = track.path.contains('youtube.com') ||
        track.path.contains('youtu.be') ||
        track.album == 'YouTube';

    if (!isOnlineTrack) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only online tracks can be downloaded')),
        );
      }
      setState(() {
        _isDownloading = false;
      });
      return;
    }

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (!settings.enableYouTubeIntegration) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('YouTube integration is disabled')),
          );
        }
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extracting audio stream...')),
        );
      }

      setState(() => _downloadProgress = 0.1);

      const ytdlService = YtdlWrapperService();
      final details = await ytdlService.fetchAudioDetails(track.path);

      if (details == null) {
        throw Exception('Failed to extract audio stream');
      }

      setState(() => _downloadProgress = 0.2);

      String? downloadUrl;
      final audio = details['audio'];

      if (audio is Map<String, dynamic>) {
        downloadUrl = audio['download_url'] as String?;
      } else if (audio is String) {
        downloadUrl = audio;
      }

      downloadUrl ??= details['download_url'] as String?;
      downloadUrl ??= details['audio_url'] as String?;

      if (downloadUrl == null) {
        throw Exception('No audio stream available');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Requesting storage permission...')),
        );
      }

      setState(() => _downloadProgress = 0.3);

      bool hasPermission = false;

      try {
        if (await Permission.manageExternalStorage.isGranted) {
          hasPermission = true;
        } else {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) {
            hasPermission = true;
          } else {
            _showPermissionDialog(context);
            setState(() => _isDownloading = false);
            return;
          }
        }
      } catch (e) {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          hasPermission = true;
        } else if (storageStatus.isPermanentlyDenied) {
          _showPermissionDialog(context);
          setState(() => _isDownloading = false);
          return;
        } else {
          _showPermissionDialog(context);
          setState(() => _isDownloading = false);
          return;
        }
      }

      if (!hasPermission) {
        setState(() => _isDownloading = false);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading...')),
        );
      }

      setState(() => _downloadProgress = 0.4);

      final safeTitle = (details['title'] as String? ?? track.title)
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final safeArtist = (details['channel'] as String? ?? track.artist)
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();

      final codec = details['codec'] as String? ?? 'mp3';
      final extension = _getFileExtension(codec);
      final filename = '$safeTitle - $safeArtist$extension';

      setState(() => _downloadProgress = 0.5);

      final downloadDir = await _getDownloadDirectory();
      final filePath = '${downloadDir.path}/$filename';
      final file = File(filePath);

      setState(() => _downloadProgress = 0.6);

      if (downloadUrl!.contains('.m3u8')) {
        await _downloadHLSStream(downloadUrl!, file, downloadDir.path);
      } else {
        await _downloadDirectFile(downloadUrl!, file, downloadDir.path);
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
    } catch (e) {}

    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final musicDir = Directory('${externalDir.path}/Music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        return musicDir;
      }
    } catch (e) {}

    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final mediaDir =
            Directory('${externalDir.path}/Android/media/com.libreamp.kashou');
        if (!await mediaDir.exists()) {
          await mediaDir.create(recursive: true);
        }
        return mediaDir;
      }
    } catch (e) {}

    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
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
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
              onPressed: _isDownloading
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(_isDownloading ? 'Downloading...' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadHLSStream(
      String playlistUrl, File outputFile, String downloadPath) async {
    final client = http.Client();
    try {
      final playlistResponse = await client.get(Uri.parse(playlistUrl));
      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to download playlist');
      }

      final playlistContent = playlistResponse.body;
      final segmentUrls = <String>[];

      final lines = playlistContent.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('#') &&
            (trimmed.endsWith('.ts') ||
                trimmed.endsWith('.aac') ||
                trimmed.endsWith('.mp4'))) {
          // Convert relative URLs to absolute
          if (trimmed.startsWith('http')) {
            segmentUrls.add(trimmed);
          } else {
            // Handle relative URLs
            final baseUri = Uri.parse(playlistUrl);
            final segmentUri = baseUri.resolve(trimmed);
            segmentUrls.add(segmentUri.toString());
          }
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in playlist');
      }

      final sink = outputFile.openWrite();
      int totalSegments = segmentUrls.length;
      int downloadedSegments = 0;

      for (final segmentUrl in segmentUrls) {
        final segmentResponse = await client.get(Uri.parse(segmentUrl));
        if (segmentResponse.statusCode == 200) {
          sink.add(segmentResponse.bodyBytes);
        }

        downloadedSegments++;
        if (mounted) {
          final progress = 0.6 + (downloadedSegments / totalSegments) * 0.3;
          setState(() => _downloadProgress = progress.clamp(0.6, 0.9));
        }
      }

      await sink.close();

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download completed! Saved to: $downloadPath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> _downloadDirectFile(
      String fileUrl, File outputFile, String downloadPath) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(fileUrl));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        int downloadedBytes = 0;

        final sink = outputFile.openWrite();

        await response.stream.listen(
          (List<int> chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            if (contentLength > 0 && mounted) {
              final progress = 0.6 + (downloadedBytes / contentLength) * 0.3;
              setState(() => _downloadProgress = progress.clamp(0.6, 0.9));
            }
          },
          onDone: () async {
            await sink.close();
            setState(() {
              _isDownloading = false;
              _downloadProgress = 1.0;
            });

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download completed! Saved to: $downloadPath'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
          onError: (error) {
            sink.close();
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0.0;
            });

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download failed: $error'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
        ).asFuture();
      } else {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'To download tracks, the app needs access to your storage.\n\n'
          'On Android 11 and above:\n'
          '1. Go to Settings > Apps > Kashou\n'
          '2. Tap "Permissions" or "Special access"\n'
          '3. Enable "All files access" or "Manage external storage"\n\n'
          'On older Android versions, grant storage permission when prompted.',
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
    return Material(
      color: Colors.transparent,
      child: Consumer2<AudioProvider, LibraryProvider>(
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
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Ambient background covering entire screen
                Positioned.fill(child: _buildAmbientBackground(context, track)),

                // Content overlay
                Column(
                  children: [
                    // Drag handle
                    SafeArea(
                      bottom: false,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: _buildTopBar(context, track),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _buildArtworkCard(context, track, size),
                                      const SizedBox(height: 28),
                                      _buildTrackMeta(context, track, audio),
                                      const SizedBox(height: 28),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SafeArea(
                              top: false,
                              minimum: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildProgressStrip(context, audio),
                                    const SizedBox(height: 18),
                                    _buildPrimaryControls(context, audio),
                                    const SizedBox(height: 34),
                                    _buildSecondaryControlRow(
                                        context, audio, library),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
        const SizedBox(width: 8),
        _buildSurfaceIconButton(
          context,
          icon: Icons.equalizer,
          tooltip: 'Equalizer',
          onPressed: () => _showEqualizerSheet(context),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Now Playing',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
          icon: Icons.share,
          tooltip: 'Share',
          onPressed: () => _shareTrack(context, track),
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
    final dimension = size.width * 0.85;
    final borderRadius = BorderRadius.circular(24);

    Widget buildFallback() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer,
            ],
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: 140,
          color: colorScheme.onPrimaryContainer.withOpacity(0.4),
        ),
      );
    }

    final String? youtubeThumbnailUrl = _buildYoutubeThumbnailUrl(track);

    final Widget image;
    if (youtubeThumbnailUrl != null) {
      image = Image.network(
        youtubeThumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildFallback(),
      );
    } else if (track.albumArt != null) {
      image = Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildFallback(),
      );
    } else {
      image = buildFallback();
    }

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
              color: colorScheme.primary.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 8,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              // Subtle gradient overlay removed for cleaner look
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientBackground(BuildContext context, Track track) {
    final colorScheme = Theme.of(context).colorScheme;
    final String? youtubeThumbnailUrl = _buildYoutubeThumbnailUrl(track);

    Widget fallbackGradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.surface,
            colorScheme.tertiaryContainer.withOpacity(0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );

    if (youtubeThumbnailUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            youtubeThumbnailUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              // Show fallback gradient while loading
              if (loadingProgress != null) {
                return fallbackGradient;
              }
              // Once loaded, show blurred image
              return Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.surface.withOpacity(0.7),
                            colorScheme.surface.withOpacity(0.85),
                            colorScheme.surface.withOpacity(0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            errorBuilder: (_, __, ___) => fallbackGradient,
          ),
        ],
      );
    } else if (track.albumArt != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            track.albumArt!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackGradient,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withOpacity(0.7),
                    colorScheme.surface.withOpacity(0.85),
                    colorScheme.surface.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return fallbackGradient;
  }

  Widget _buildTrackMeta(
      BuildContext context, Track track, AudioProvider audio) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          track.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            fontSize: 22,
            height: 1.2,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openArtist(track),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                track.artist,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // _buildMetaAssistChip(context, icon: Icons.album_rounded, label: track.album),
            const SizedBox(height: 6),
            if (track.genre != null && track.genre!.isNotEmpty)
              _buildMetaAssistChip(context,
                  icon: Icons.style_outlined, label: track.genre!),
            if (track.path.contains('youtube.com') ||
                track.path.contains('youtu.be'))
              _buildMetaAssistChip(context,
                  icon: Icons.play_circle_outline, label: 'YouTube'),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaAssistChip(BuildContext context,
      {required IconData icon, required String label}) {
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
    final isLoading = audio.isLoadingTrack;
    final position = isLoading ? 0.0 : audio.position.inMilliseconds.toDouble();
    final duration = isLoading
        ? 1.0
        : audio.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SquigglySlider(
          value: position.clamp(0, duration),
          max: duration,
          animate: audio.isPlaying && !isLoading,
          onChanged: isLoading
              ? null
              : (value) => audio.seek(Duration(milliseconds: value.toInt())),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(isLoading ? Duration.zero : audio.position),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _formatDuration(isLoading ? Duration.zero : audio.duration),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryControls(BuildContext context, AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleIconButton(
          context,
          icon: Icons.skip_previous_rounded,
          onTap: audio.skipPrevious,
        ),
        const SizedBox(width: 18),
        _buildPlayButton(context, audio),
        const SizedBox(width: 18),
        _buildCircleIconButton(
          context,
          icon: Icons.skip_next_rounded,
          onTap: audio.skipNext,
        ),
      ],
    );
  }

  Widget _buildCircleIconButton(BuildContext context,
      {required IconData icon, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, size: 28, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  // wide pill play, the one loud element in the transport row
  Widget _buildPlayButton(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = audio.isLoadingTrack;
    final isPlaying = audio.isPlaying;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isLoading ? null : audio.togglePlayPause,
        child: SizedBox(
          width: 118,
          height: 64,
          child: Center(
            child: isLoading
                ? KashouLoader(
                    size: 26, color: colorScheme.onPrimaryContainer)
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 34,
                    color: colorScheme.onPrimaryContainer,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryControlRow(
      BuildContext context, AudioProvider audio, LibraryProvider library) {
    final isShuffle = audio.shuffleMode != ShuffleMode.off;
    final isRepeatActive = audio.repeatMode != RepeatMode.off;
    final isFavorite = library.isTrackFavorite(audio.currentTrack?.id ?? '');
    final isOnlineTrack = audio.currentTrack != null &&
        (audio.currentTrack!.path.contains('youtube.com') ||
            audio.currentTrack!.path.contains('youtu.be') ||
            audio.currentTrack!.album == 'YouTube');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSecondaryIconButton(
          context,
          icon: _getShuffleIcon(audio.shuffleMode),
          tooltip: 'Shuffle',
          active: isShuffle,
          onTap: () {
            final newMode = audio.shuffleMode == ShuffleMode.off
                ? ShuffleMode.songs
                : ShuffleMode.off;
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
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final iconColor =
        active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: iconColor, size: 24),
            ),
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
                            onTap: () {},
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
    final rootContext = context;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Metadata'),
                onTap: () {
                  Navigator.pop(context);
                  if (track == null) {
                    return;
                  }

                  final source = track.sourceUrl ?? track.path;
                  final isStream = source.startsWith('http');

                  if (isStream) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text('Online tracks cannot be edited.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MetadataEditorScreen(track: track),
                    ),
                  );
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
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareTrack(rootContext, track);
                },
              ),
              if (track != null &&
                  (track.sourceUrl ?? track.path).startsWith('http'))
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _downloadTrack(rootContext, track);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Track Info'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (track != null) {
                    _showTrackInfo(rootContext, track);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareTrack(BuildContext context, Track? track) async {
    if (track == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing playing to share.')),
        );
      }
      return;
    }

    final url = _buildYoutubeMusicUrl(track);
    final shareText = url != null
        ? 'Listen to ${track.title}${track.artist.isNotEmpty ? ' by ${track.artist}' : ''} on YouTube Music:\n$url'
        : 'Listen to ${track.title}${track.artist.isNotEmpty ? ' by ${track.artist}' : ''}.';

    try {
      await Share.share(shareText, subject: 'Share ${track.title}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to share track: $e')),
        );
      }
    }
  }

  String? _buildYoutubeMusicUrl(Track track) {
    final sourceUrl =
        (track.sourceUrl?.isNotEmpty ?? false) ? track.sourceUrl : null;
    final urlToUse = sourceUrl ?? track.path;
    final videoId = _extractYouTubeId(urlToUse);
    if (videoId == null) return null;

    final uri = Uri.tryParse(urlToUse);
    final playlistId = uri?.queryParameters['list'];

    if (playlistId != null && playlistId.isNotEmpty) {
      return 'https://music.youtube.com/watch?v=$videoId&list=$playlistId';
    }
    return 'https://music.youtube.com/watch?v=$videoId';
  }

  String? _buildYoutubeThumbnailUrl(Track track) {
    final sourceUrl = track.sourceUrl ?? track.path;
    final videoId = _extractYouTubeId(sourceUrl);
    if (videoId == null) return null;
    return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
  }

  String? _extractYouTubeId(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    final host = uri.host.toLowerCase();

    if (host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    final idFromQuery = uri.queryParameters['v'];
    if (idFromQuery != null && idFromQuery.isNotEmpty) {
      return idFromQuery;
    }

    if (uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.first == 'embed' && uri.pathSegments.length >= 2) {
        return uri.pathSegments[1];
      }
      if (uri.pathSegments.first == 'shorts' && uri.pathSegments.length >= 2) {
        return uri.pathSegments[1];
      }
    }

    return null;
  }

  void _showTrackInfo(BuildContext context, Track track) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            final infoRows = <MapEntry<String, String>>[
              MapEntry('Title', track.title),
              MapEntry('Artist', track.artist),
              MapEntry('Album', track.album),
              MapEntry('Format', track.codec ?? 'Unknown'),
              MapEntry('Bitrate',
                  track.bitrate != null ? '${track.bitrate} kbps' : 'Unknown'),
              MapEntry(
                  'Sample Rate',
                  track.sampleRate != null
                      ? '${track.sampleRate} Hz'
                      : 'Unknown'),
              MapEntry('Duration', _formatDuration(track.duration)),
              MapEntry('Path', track.path),
            ];

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Track Information',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Track info summary
                        Row(
                          children: [
                            // Album art
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: track.albumArt != null
                                    ? DecorationImage(
                                        image: MemoryImage(track.albumArt!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: track.albumArt == null
                                    ? colorScheme.primaryContainer
                                    : null,
                              ),
                              child: track.albumArt == null
                                  ? Icon(
                                      Icons.music_note,
                                      color: colorScheme.onPrimaryContainer,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            // Track details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artist,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.album,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Details list
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        ...infoRows.map((entry) => Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.8),
                                    colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${entry.key}:',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
