import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/audio_provider.dart';
import '../widgets/equalizer_widget.dart';
import 'metadata_editor_screen.dart';
import 'dart:ui';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../utils/hero_transitions.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/pressable.dart';
import '../widgets/scrolling_text.dart';
import '../widgets/squiggly_slider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../services/ytmusic_service.dart';
import '../services/download_store.dart';
import '../utils/app_messenger.dart';
import 'artist_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  // static so a reopened player picks the running download back up
  static final ValueNotifier<double?> _downloadProgress = ValueNotifier(null);
  bool _findingArtist = false;
  double _doubleTapDx = 0;
  int _seekFlash = 0;
  Timer? _seekFlashTimer;

  @override
  void dispose() {
    _seekFlashTimer?.cancel();
    super.dispose();
  }

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
    if (_downloadProgress.value != null) return;
    _downloadProgress.value = 0;

    final isOnlineTrack = track.path.contains('youtube.com') ||
        track.path.contains('youtu.be') ||
        track.album == 'YouTube';

    if (!isOnlineTrack) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only online tracks can be downloaded')),
        );
      }
      _downloadProgress.value = null;
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
        _downloadProgress.value = null;
        return;
      }

      const ytdlService = YtdlWrapperService();
      final details =
          await ytdlService.fetchAudioDetails(track.sourceUrl ?? track.path);

      if (details == null) {
        throw Exception('Failed to extract audio stream');
      }

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

      final safeTitle = (details['title'] as String? ?? track.title)
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final rawArtist = (details['channel'] as String? ?? '').trim();
      final safeArtist = (rawArtist.isEmpty ? track.artist : rawArtist)
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();

      final codec = details['codec'] as String? ?? 'mp3';
      final extension = _getFileExtension(codec);
      final filename = '$safeTitle - $safeArtist$extension';

      final downloadDir = await DownloadStore.dir();
      final filePath = '${downloadDir.path}/$filename';
      final file = File(filePath);

      if (downloadUrl!.contains('.m3u8')) {
        await _downloadHLSStream(downloadUrl!, file);
      } else {
        await _downloadDirectFile(downloadUrl!, file);
      }

      // tags and art so the file stands on its own offline
      try {
        final art = track.albumArt ??
            await ytdlService.fetchVideoArt(details['id'] as String? ?? '',
                preferred: details['thumbnail'] as String?);
        await AudioTags.write(
          filePath,
          Tag(
            title: details['title'] as String? ?? track.title,
            trackArtist: safeArtist,
            pictures: [
              if (art != null)
                Picture(
                  bytes: art,
                  mimeType: MimeType.jpeg,
                  pictureType: PictureType.coverFront,
                ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('[Download] tagging failed: $e');
      }

      _downloadProgress.value = null;
      appMessenger.currentState?.showSnackBar(
        SnackBar(
          content: Text('Saved $filename'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _downloadProgress.value = null;
      appMessenger.currentState?.showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _downloadHLSStream(String playlistUrl, File outputFile) async {
    final client = http.Client();
    try {
      final playlistResponse = await client.get(Uri.parse(playlistUrl));
      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to download playlist');
      }

      final segmentUrls = <String>[];
      for (final line in playlistResponse.body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('#') &&
            (trimmed.endsWith('.ts') ||
                trimmed.endsWith('.aac') ||
                trimmed.endsWith('.mp4'))) {
          segmentUrls.add(trimmed.startsWith('http')
              ? trimmed
              : Uri.parse(playlistUrl).resolve(trimmed).toString());
        }
      }
      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in playlist');
      }

      final sink = outputFile.openWrite();
      var done = 0;
      try {
        for (final segmentUrl in segmentUrls) {
          final segment = await client.get(Uri.parse(segmentUrl));
          if (segment.statusCode == 200) {
            sink.add(segment.bodyBytes);
          }
          done++;
          _downloadProgress.value = (done / segmentUrls.length).clamp(0.0, 1.0);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _downloadDirectFile(String fileUrl, File outputFile) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(fileUrl));
      request.headers['User-Agent'] = 'Mozilla/5.0';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final sink = outputFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (contentLength > 0) {
            _downloadProgress.value =
                (downloadedBytes / contentLength).clamp(0.0, 1.0);
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  String _getFileExtension(String? codec) {
    if (codec == null) return '.mp3';
    final c = codec.toLowerCase();
    if (c.startsWith('mp4a') || c.startsWith('m4a')) return '.m4a';

    switch (c) {
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
                Positioned.fill(
                    child: RepaintBoundary(
                        child: _buildAmbientBackground(context, track))),

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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                      const SizedBox(height: 8),
                                      RepaintBoundary(
                                          child: _buildArtworkCard(
                                              context, track, size)),
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
                                    RepaintBoundary(
                                        child:
                                            _buildProgressStrip(context, audio)),
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
    final dimension = (size.width - 40) * 0.92;

    Widget buildFallback() {
      return Container(
        color: colorScheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Icon(
          Icons.music_note_rounded,
          size: 96,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final String? youtubeThumbnailUrl = _buildYoutubeThumbnailUrl(track);

    final Widget image;
    if (track.albumArt != null) {
      image = Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => buildFallback(),
      );
    } else if (youtubeThumbnailUrl != null) {
      image = Image.network(
        youtubeThumbnailUrl,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSync) =>
            frame != null || wasSync ? child : buildFallback(),
        // maxres is missing for a lot of videos
        errorBuilder: (_, __, ___) => Image.network(
          youtubeThumbnailUrl.replaceFirst('maxresdefault', 'hqdefault'),
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSync) =>
              frame != null || wasSync ? child : buildFallback(),
          errorBuilder: (_, __, ___) => buildFallback(),
        ),
      );
    } else {
      image = buildFallback();
    }

    return GestureDetector(
      // onDoubleTap has no position
      onDoubleTapDown: (details) => _doubleTapDx = details.localPosition.dx,
      onDoubleTap: () {
        _triggerSeekFlash(_doubleTapDx < dimension / 2);
        _seekFromDoubleTap(context, dimension);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 400) return;
        final audio = context.read<AudioProvider>();
        velocity < 0 ? audio.skipNext() : audio.skipPrevious();
      },
      child: Stack(
        children: [
          Hero(
        tag: 'album_art_${track.id}',
        createRectTween: albumArtRectTween,
        flightShuttleBuilder: albumArtFlightShuttleBuilder,
        child: Container(
          width: dimension,
          height: dimension,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: image,
            ),
          ),
          ),
          _buildSeekFlash(context),
        ],
      ),
    );
  }

  void _triggerSeekFlash(bool left) {
    _seekFlashTimer?.cancel();
    setState(() => _seekFlash = left ? 1 : 2);
    _seekFlashTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _seekFlash = 0);
    });
  }

  Widget _buildSeekFlash(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _seekFlash == 0 ? 0 : 1,
          child: Align(
            alignment: _seekFlash == 1
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.75),
                  borderRadius: EShape.radius(EShape.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _seekFlash == 1
                          ? Icons.fast_rewind_rounded
                          : Icons.fast_forward_rounded,
                      size: 30,
                      color: scheme.onSurface,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _seekFlash == 1 ? '-5s' : '+5s',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
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
  }

  void _seekFromDoubleTap(BuildContext context, double dimension) {
    final audio = context.read<AudioProvider>();
    final step = Duration(seconds: _doubleTapDx < dimension / 2 ? -5 : 5);
    var target = audio.position + step;
    if (target < Duration.zero) target = Duration.zero;
    if (target > audio.duration) target = audio.duration;
    audio.seek(target);
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

    final scrim = Container(
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
    );

    // a 40px decode stretched over the screen is blurry on its own
    Widget? art;
    if (track.albumArt != null) {
      art = Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        cacheWidth: 40,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallbackGradient,
      );
    } else if (youtubeThumbnailUrl != null) {
      art = Image.network(
        youtubeThumbnailUrl,
        fit: BoxFit.cover,
        cacheWidth: 40,
        frameBuilder: (context, child, frame, wasSync) =>
            frame != null || wasSync ? child : fallbackGradient,
        errorBuilder: (_, __, ___) => fallbackGradient,
      );
    }
    if (art == null) return fallbackGradient;
    return Stack(fit: StackFit.expand, children: [art, scrim]);
  }

  Widget _buildTrackMeta(
      BuildContext context, Track track, AudioProvider audio) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        ScrollingText(
          text: track.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            fontSize: 22,
            height: 1.2,
          ),
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
    final trackDur = audio.currentTrack?.duration ?? Duration.zero;
    final liveDur = audio.duration > Duration.zero ? audio.duration : trackDur;
    final position = isLoading ? 0.0 : audio.position.inMilliseconds.toDouble();
    final duration = isLoading
        ? 1.0
        : liveDur.inMilliseconds.toDouble().clamp(1.0, double.infinity);

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
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatDuration(isLoading ? Duration.zero : audio.duration),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
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
        PressableScale(child: _buildPlayButton(context, audio)),
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

  Widget _buildPlayButton(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = audio.isLoadingTrack;
    final isPlaying = audio.isPlaying;

    return Material(
      color: colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : audio.togglePlayPause,
        child: SizedBox(
          width: 78,
          height: 78,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: isLoading
                  ? KashouLoader(
                      key: const ValueKey('pl_load'),
                      size: 26,
                      color: colorScheme.onPrimaryContainer)
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(isPlaying),
                      size: 40,
                      color: colorScheme.onPrimary,
                    ),
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
          ValueListenableBuilder<double?>(
            valueListenable: _downloadProgress,
            builder: (context, progress, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: progress != null
                  ? Tooltip(
                      key: const ValueKey('dl_ring'),
                      message: 'Downloading',
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            value: progress > 0 ? progress : null,
                          ),
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('dl_idle'),
                      child: _buildSecondaryIconButton(
                        context,
                        icon: Icons.download,
                        tooltip: 'Download track',
                        onTap: () {
                          if (audio.currentTrack != null) {
                            _downloadTrack(context, audio.currentTrack!);
                          }
                        },
                      ),
                    ),
            ),
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(
              icon,
              size: 24,
              color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        itemCount: audio.queue.length,
                        onReorder: audio.moveQueueItem,
                        itemBuilder: (context, index) {
                          final track = audio.queue[index];
                          final isCurrent = index == audio.currentIndex;

                          return ListTile(
                            key: ValueKey('${track.id}_$index'),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: isCurrent ? FontWeight.bold : null,
                              ),
                            ),
                            subtitle: Text(
                              track.views != null && track.views!.isNotEmpty
                                  ? '${track.artist} · ${track.views}'
                                  : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle_rounded),
                            ),
                            onTap: isCurrent ? null : () => audio.playAt(index),
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

  Future<String?> _promptPlaylistName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Consumer<LibraryProvider>(
          builder: (context, library, _) {
            Future<void> add(String playlistId, String name) async {
              final playlist =
                  library.playlists.firstWhere((p) => p.id == playlistId);
              if (playlist.tracks.any((t) => t.id == track.id)) {
                appMessenger.currentState?.showSnackBar(
                    SnackBar(content: Text('Already in $name')));
              } else {
                await library.addToPlaylist(playlistId, track);
                appMessenger.currentState?.showSnackBar(
                    SnackBar(content: Text('Added to $name')));
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add to playlist',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('New playlist'),
                  onTap: () async {
                    final name = await _promptPlaylistName(sheetContext);
                    if (name == null || name.trim().isEmpty) return;
                    await library.createPlaylist(name.trim());
                    await add(library.playlists.last.id, name.trim());
                  },
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in library.playlists)
                        ListTile(
                          leading: const Icon(Icons.queue_music_rounded),
                          title: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${p.trackCount} songs'),
                          onTap: () => add(p.id, p.name),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final rootContext = context;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Consumer<AudioProvider>(
                builder: (context, audio, _) {
                  final current = audio.currentTrack;
                  if (current == null) return const SizedBox.shrink();
                  final isOnline = current.path.contains('youtube.com') ||
                      current.path.contains('youtu.be') ||
                      current.album == 'YouTube';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetNowPlayingCard(context, current),
                      const SizedBox(height: 12),
                      _sheetCard(context, [
                        if (!isOnline)
                          ListTile(
                            leading: const Icon(Icons.edit_rounded),
                            title: const Text('Edit Metadata'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                rootContext,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MetadataEditorScreen(track: current),
                                ),
                              );
                            },
                          ),
                        ListTile(
                          leading: const Icon(Icons.playlist_add_rounded),
                          title: const Text('Add to Playlist'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showAddToPlaylist(rootContext, current);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share_rounded),
                          title: const Text('Share'),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _shareTrack(rootContext, current);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_rounded),
                          title: const Text('View artist'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openArtist(current);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Track Info'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showTrackInfo(rootContext, current);
                          },
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetNowPlayingCard(BuildContext context, Track track) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: EShape.radius(EShape.lg),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: track.albumArt != null
                  ? Image.memory(
                      track.albumArt!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(Icons.music_note,
                          color: scheme.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now Playing',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetCard(BuildContext context, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 1, indent: 56, color: scheme.outlineVariant.withValues(alpha: 0.4)));
      }
      rows.add(children[i]);
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: EShape.radius(EShape.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
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
    final isStream = (track.sourceUrl ?? track.path).startsWith('http');
    final rows = <MapEntry<String, String>>[
      MapEntry('Title', track.title),
      MapEntry('Artist', track.artist),
      if (track.album.isNotEmpty) MapEntry('Album', track.album),
      if (track.duration > Duration.zero)
        MapEntry('Duration', _formatDuration(track.duration)),
      if (track.genre != null && track.genre!.isNotEmpty)
        MapEntry('Genre', track.genre!),
      if (track.year != null) MapEntry('Year', '${track.year}'),
      if (track.codec != null) MapEntry('Format', track.codec!),
      if (track.bitrate != null) MapEntry('Bitrate', '${track.bitrate} kbps'),
      if (track.sampleRate != null)
        MapEntry('Sample rate', '${track.sampleRate} Hz'),
      if (track.loudnessDb != null)
        MapEntry('Loudness', '${track.loudnessDb!.toStringAsFixed(1)} dB'),
      MapEntry('Source', isStream ? 'YouTube' : 'Local file'),
      MapEntry(isStream ? 'Link' : 'Path', track.sourceUrl ?? track.path),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Track info',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.key,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row.value,
                                style:
                                    Theme.of(sheetContext).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
