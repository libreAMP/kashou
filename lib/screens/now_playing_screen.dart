import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/audio_provider.dart';
import '../theme/radii.dart';
import '../widgets/equalizer_widget.dart';
import 'metadata_editor_screen.dart';
import 'dart:ui';
import '../services/download_manager.dart';
import '../services/lyrics_service.dart';
import '../utils/toast.dart';

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../utils/hero_transitions.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/pressable.dart';
import '../widgets/scrolling_text.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/square_art.dart';
import '../widgets/squiggly_slider.dart';
import '../providers/settings_provider.dart';
import '../services/ytmusic_service.dart';
import '../utils/app_messenger.dart';
import '../utils/platform.dart';
import 'artist_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  final VoidCallback? onCollapse;
  final ValueChanged<double>? onCollapseDragUpdate;
  final ValueChanged<double>? onCollapseDragEnd;

  const NowPlayingScreen({
    super.key,
    this.onCollapse,
    this.onCollapseDragUpdate,
    this.onCollapseDragEnd,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _findingArtist = false;
  double _doubleTapDx = 0;
  int _seekFlash = 1;
  bool _seekFlashOn = false;
  bool _playDown = false;
  Timer? _seekFlashTimer;
  bool _lyricsOpen = false;
  LyricsResult? _lyrics;
  String? _lyricsForId;

  @override
  void dispose() {
    _seekFlashTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleLyrics(Track track) async {
    if (_lyricsOpen) {
      setState(() => _lyricsOpen = false);
      return;
    }
    setState(() => _lyricsOpen = true);
    if (_lyrics == null) {
      final res = await LyricsService.fetch(track.title, track.artist);
      if (!mounted) return;
      setState(() => _lyrics = res);
    }
  }


  Widget _miniArt(Track track) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.music_note, size: 16, color: scheme.onSurfaceVariant);
    if (track.albumArt != null) {
      return Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    final id = _extractYouTubeId(track.sourceUrl ?? track.path);
    if (id != null) {
      return CachedNetworkImage(
        imageUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return fallback;
  }

  Widget _buildLyricsView(
      BuildContext context, AudioProvider audio, Track track) {
    return _LyricsView(
      audio: audio,
      track: track,
      lyrics: _lyrics,
    );
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
    final isOnlineTrack = (track.sourceUrl ?? track.path).startsWith('http');

    if (!isOnlineTrack) {
      showToast('Only online tracks can be downloaded');
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.enableYouTubeIntegration) {
      showToast('YouTube integration is disabled');
      return;
    }

    DownloadManager.instance.enqueue(
      track,
      thumbUrl: _buildYoutubeThumbnailUrl(track),
    );
    showToast('Download started, see Downloads');
  }

  @override
  Widget build(BuildContext context) {
    final screen = Material(
      color: Colors.transparent,
      child: Consumer2<AudioProvider, LibraryProvider>(
        builder: (context, audio, library, child) {
          final track = audio.currentTrack;

          if (track == null) {
            return const Center(child: Text('No track playing'));
          }

          if (_lyricsForId != track.id) {
            _lyricsForId = track.id;
            _lyrics = null;
            _lyricsOpen = false;
          }

          final mediaQuery = MediaQuery.of(context);
          final size = mediaQuery.size;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          // wide desktop windows and landscape phones get a side-by-side player
          final wideLayout = size.width > size.height && size.width >= 640 ||
              (isDesktop && size.width >= 920);

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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: widget.onCollapseDragUpdate == null
                          ? null
                          : (details) =>
                              widget.onCollapseDragUpdate!(details.primaryDelta ?? 0),
                      onVerticalDragEnd: widget.onCollapseDragEnd == null
                          ? null
                          : (details) =>
                              widget.onCollapseDragEnd!(details.primaryVelocity ?? 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isDesktop)
                            Padding(
                              padding: EdgeInsets.only(
                                top: math.max(
                                  MediaQuery.paddingOf(context).top,
                                  MediaQuery.viewPaddingOf(context).top,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(top: 8, bottom: 4),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: _buildTopBar(context, track),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: Column(
                          children: [
                            Expanded(
                              child: wideLayout
                                  ? _buildWideLayout(
                                      context, audio, library, track, size)
                                  : AnimatedSwitcher(
                                      duration: EMotion.medium,
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, anim) =>
                                          FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                                  begin: 0.9, end: 1)
                                              .animate(anim),
                                          child: child,
                                        ),
                                      ),
                                      layoutBuilder: (current, previous) =>
                                          Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ...previous,
                                          if (current != null) current,
                                        ],
                                      ),
                                      child: _lyricsOpen
                                          ? KeyedSubtree(
                                              key: const ValueKey('lyrics'),
                                              child: _buildLyricsView(
                                                  context, audio, track),
                                            )
                                          : KeyedSubtree(
                                              key: const ValueKey('art'),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final maxW =
                                                      (size.width - 40) * 0.92;
                                                  final availableH =
                                                      constraints.maxHeight;
                                                  final dimension = isDesktop
                                                      ? math.min(maxW, 460.0)
                                                      : (availableH > 0
                                                          ? math.min(
                                                              maxW, availableH)
                                                          : maxW);
                                                  return GestureDetector(
                                                    behavior: HitTestBehavior
                                                        .translucent,
                                                    onVerticalDragUpdate:
                                                        widget.onCollapseDragUpdate ==
                                                            null
                                                        ? null
                                                        : (details) => widget
                                                            .onCollapseDragUpdate!(
                                                            details
                                                                    .primaryDelta ??
                                                                0),
                                                    onVerticalDragEnd:
                                                        widget
                                                                    .onCollapseDragEnd ==
                                                                null
                                                            ? null
                                                            : (details) => widget
                                                                .onCollapseDragEnd!(
                                                                details
                                                                        .primaryVelocity ??
                                                                    0),
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 20),
                                                        child: RepaintBoundary(
                                                          child:
                                                              _buildArtworkCard(
                                                            context,
                                                            track,
                                                            size,
                                                            artSize: dimension,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                    ),
                            ),
                            if (!wideLayout)
                              SafeArea(
                              top: false,
                              minimum: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSize(
                                      duration: EMotion.medium,
                                      curve: Curves.easeInOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: _lyricsOpen
                                          ? const SizedBox.shrink()
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                MouseRegion(
                                                  cursor: isDesktop
                                                      ? SystemMouseCursors
                                                          .click
                                                      : MouseCursor.defer,
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _toggleLyrics(track),
                                                    child: _buildTrackMeta(
                                                        context, track, audio),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                            ),
                                    ),
                                    RepaintBoundary(
                                        child:
                                            _buildProgressStrip(context, audio)),
                                    const SizedBox(height: 18),
                                    _buildPrimaryControls(context, audio),
                                    const SizedBox(height: 20),
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
    if (!isDesktop) return screen;
    // desktop: keyboard transport controls for the player window
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          final audio = context.read<AudioProvider>();
          if (audio.currentTrack != null && !audio.isLoadingTrack) {
            audio.togglePlayPause();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(context, -5),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(context, 5),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            () => context.read<AudioProvider>().skipPrevious(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            () => context.read<AudioProvider>().skipNext(),
      },
      child: Focus(autofocus: true, child: screen),
    );
  }

  void _seekBy(BuildContext context, int seconds) {
    final audio = context.read<AudioProvider>();
    if (audio.currentTrack == null || audio.isLoadingTrack) return;
    var target = audio.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > audio.duration) target = audio.duration;
    audio.seek(target);
  }

  // side-by-side player for wide desktop windows and landscape phones: art
  // (or lyrics) on the left, metadata and transport controls on the right
  Widget _buildWideLayout(BuildContext context, AudioProvider audio,
      LibraryProvider library, Track track, Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        // landscape phones are short, so the art yields height to the controls
        final isShort = constraints.maxHeight < 480;
        final artSize = math.min(
          math.min(
            constraints.maxWidth * (isShort ? 0.34 : 0.44),
            constraints.maxHeight * (isShort ? 0.9 : 0.85),
          ),
          520.0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isShort ? 20 : 36,
                4,
                isShort ? 20 : 36,
                isShort ? 8 : 24,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: isShort ? 4 : 5,
                    child: AnimatedSwitcher(
                      duration: EMotion.medium,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale:
                              Tween<double>(begin: 0.9, end: 1).animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.center,
                        children: [
                          ...previous,
                          if (current != null) current,
                        ],
                      ),
                      child: _lyricsOpen
                          ? KeyedSubtree(
                              key: const ValueKey('lyrics'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildLyricsView(context, audio, track),
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('art'),
                              child: Center(
                                child: RepaintBoundary(
                                  child: _buildArtworkCard(
                                      context, track, size,
                                      artSize: artSize),
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: isShort ? 16 : 40),
                  Expanded(
                    flex: isShort ? 6 : 5,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _toggleLyrics(track),
                                  child: _buildTrackMeta(context, track, audio),
                                ),
                              ),
                              const SizedBox(height: 24),
                              RepaintBoundary(
                                  child: _buildProgressStrip(context, audio)),
                              const SizedBox(height: 24),
                              _buildPrimaryControls(context, audio),
                              const SizedBox(height: 28),
                              _buildSecondaryControlRow(context, audio, library),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, Track track) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _buildBarIcon(
          context,
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Collapse player',
          first: true,
          onTap: () => widget.onCollapse != null
              ? widget.onCollapse!()
              : Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 4),
        _buildBarIcon(
          context,
          icon: Icons.equalizer,
          tooltip: 'Equalizer',
          first: false,
          onTap: () => _showEqualizerSheet(context),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleLyrics(track),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _lyricsOpen ? 1 : 0),
                    duration: EMotion.medium,
                    curve: Curves.easeInOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: child,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                              width: 28, height: 28, child: _miniArt(track)),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Now Playing',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        _buildBarIcon(
          context,
          icon: Icons.share,
          tooltip: 'Share',
          first: true,
          onTap: () => _shareTrack(context, track),
        ),
        const SizedBox(width: 4),
        _buildBarIcon(
          context,
          icon: Icons.more_vert,
          tooltip: 'More options',
          first: false,
          onTap: () => _showMoreOptions(context),
        ),
      ],
    );
  }

  Widget _buildBarIcon(BuildContext context,
      {required IconData icon,
      required String tooltip,
      required bool first,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.horizontal(
      left: Radius.circular(first ? 18 : 10),
      right: Radius.circular(first ? 10 : 18),
    );
    return PressableScale(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 44,
              child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkCard(BuildContext context, Track track, Size size,
      {double? artSize}) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimension = artSize ?? (size.width - 40) * 0.92;

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

    final String? videoId = _extractYouTubeId(track.sourceUrl ?? track.path);

    final online = videoId != null;

    Widget lowArt() {
      if (online) {
        // mqdefault has no bars
        return CachedNetworkImage(
          imageUrl: 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
          fit: BoxFit.cover,
          placeholder: (_, __) => buildFallback(),
          errorWidget: (_, __, ___) => buildFallback(),
        );
      }
      if (track.albumArt != null) {
        return Image.memory(
          track.albumArt!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 1200,
          filterQuality: FilterQuality.medium,
        );
      }
      return buildFallback();
    }

    final Widget image;
    if (online) {
      image = CachedNetworkImage(
        imageUrl: 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
        fit: BoxFit.cover,
        placeholder: (_, __) => lowArt(),
        errorWidget: (_, __, ___) => lowArt(),
      );
    } else {
      image = lowArt();
    }

    final card = GestureDetector(
      // onDoubleTap has no position
      onDoubleTapDown: (details) => _doubleTapDx = details.localPosition.dx,
      onDoubleTap: () {
        _triggerSeekFlash(_doubleTapDx < dimension / 2);
        _seekFromDoubleTap(context, dimension);
      },
      // right-click mirrors the more-vert menu on desktop
      onSecondaryTap: isDesktop ? () => _showMoreOptions(context) : null,
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
        child: SizedBox(
          width: dimension,
          height: dimension,
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
    if (!isDesktop) return card;
    return MouseRegion(cursor: SystemMouseCursors.click, child: card);
  }

  void _triggerSeekFlash(bool left) {
    _seekFlashTimer?.cancel();
    setState(() {
      _seekFlash = left ? 1 : 2;
      _seekFlashOn = true;
    });
    _seekFlashTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _seekFlashOn = false);
    });
  }

  Widget _buildSeekFlash(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _seekFlashOn ? 1 : 0,
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
                  color: scheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(rXl),
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
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.surface,
            colorScheme.tertiaryContainer.withValues(alpha: 0.2),
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
            colorScheme.surface.withValues(alpha: 0.88),
            colorScheme.surface.withValues(alpha: 0.94),
            colorScheme.surface,
          ],
        ),
      ),
    );

    Widget? art;
    if (track.albumArt != null) {
      art = Image.memory(
        track.albumArt!,
        fit: BoxFit.cover,
        cacheWidth: 160,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallbackGradient,
      );
    } else if (youtubeThumbnailUrl != null) {
      art = Image.network(
        youtubeThumbnailUrl,
        fit: BoxFit.cover,
        cacheWidth: 160,
        frameBuilder: (context, child, frame, wasSync) =>
            frame != null || wasSync ? child : fallbackGradient,
        errorBuilder: (_, __, ___) => fallbackGradient,
      );
    }
    if (art == null) return fallbackGradient;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
              sigmaX: 48, sigmaY: 48, tileMode: TileMode.decal),
          child: art,
        ),
        scrim,
      ],
    );
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
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
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
              : (value) =>
                  audio.seek(Duration(milliseconds: value.toInt())),
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
        PressableScale(
          child: _buildSeekButton(
            context,
            icon: Icons.skip_previous_outlined,
            tooltip: 'Previous',
            onTap: audio.skipPrevious,
            left: true,
          ),
        ),
        const SizedBox(width: 10),
        PressableScale(child: _buildPlayButton(context, audio)),
        const SizedBox(width: 10),
        PressableScale(
          child: _buildSeekButton(
            context,
            icon: Icons.skip_next_outlined,
            tooltip: 'Next',
            onTap: audio.skipNext,
            left: false,
          ),
        ),
      ],
    );
  }

  Widget _buildSeekButton(BuildContext context,
      {required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      required bool left}) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.horizontal(
      left: Radius.circular(left ? 26 : 14),
      right: Radius.circular(left ? 14 : 26),
    );

    final button = Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, size: 30, color: colorScheme.onSurface),
        ),
      ),
    );
    if (!isDesktop) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildPlayButton(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = audio.isLoadingTrack;
    final isPlaying = audio.isPlaying;

    final button = AnimatedContainer(
      duration: EMotion.fast,
      curve: EMotion.standard,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(_playDown ? 36 : 26),
      ),
      child: InkWell(
        onHighlightChanged: (v) => setState(() => _playDown = v),
        borderRadius: BorderRadius.circular(_playDown ? 36 : 26),
        onTap: isLoading ? null : audio.togglePlayPause,
        child: SizedBox(
          width: 116,
          height: 84,
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
                          ? Icons.pause_outlined
                          : Icons.play_arrow_outlined,
                      key: ValueKey(isPlaying),
                      size: 48,
                      color: colorScheme.onPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
    if (!isDesktop) return button;
    return Tooltip(
      message: isPlaying ? 'Pause' : 'Play',
      child: button,
    );
  }

  Widget _buildSecondaryControlRow(
      BuildContext context, AudioProvider audio, LibraryProvider library) {
    final isShuffle = audio.shuffleMode != ShuffleMode.off;
    final isRepeatActive = audio.repeatMode != RepeatMode.off;
    final isFavorite = library.isTrackFavorite(audio.currentTrack?.id ?? '');
    final isOnlineTrack = audio.currentTrack != null &&
        (audio.currentTrack!.sourceUrl ?? audio.currentTrack!.path)
            .startsWith('http');

    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(rXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSecondaryIconButton(
                  context,
                  icon: _getShuffleIcon(audio.shuffleMode),
                  tooltip: 'Shuffle',
                  active: isShuffle,
                  tileShape: const BorderRadius.horizontal(
                    left: Radius.circular(30),
                    right: Radius.circular(16),
                  ),
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
                  icon: _lyricsOpen ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                  tooltip: _lyricsOpen ? 'Hide lyrics' : 'Lyrics',
                  active: _lyricsOpen,
                  onTap: () {
                    final track = audio.currentTrack;
                    if (track != null) _toggleLyrics(track);
                  },
                ),
                _buildSecondaryIconButton(
                  context,
                  icon: Icons.queue_music_rounded,
                  tooltip: 'View queue',
                  active: false,
                  tileShape: isOnlineTrack
                      ? null
                      : const BorderRadius.horizontal(
                          left: Radius.circular(16),
                          right: Radius.circular(30),
                        ),
                  onTap: () => _showQueueSheet(context),
                ),
                if (isOnlineTrack)
                  _buildSecondaryIconButton(
                    context,
                    icon: Icons.download,
                    tooltip: 'Download track',
                    tileShape: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                      right: Radius.circular(30),
                    ),
                    onTap: () {
                      if (audio.currentTrack != null) {
                        _downloadTrack(context, audio.currentTrack!);
                      }
                    },
                  ),
              ],
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
    BorderRadius? tileShape,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = tileShape ?? BorderRadius.circular(16);
    return PressableScale(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: AnimatedContainer(
              duration: EMotion.fast,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: active
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: shape,
              ),
              child: Icon(
                icon,
                size: 22,
                color: active
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
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

  // desktop presents what mobile shows as bottom sheets in a dialog instead
  Future<T?> _showAdaptiveDialog<T>(BuildContext context, WidgetBuilder builder,
      {double maxWidth = 480}) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
          ),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  void _showEqualizerSheet(BuildContext context) {
    if (isDesktop) {
      _showAdaptiveDialog(
        context,
        (dialogContext) => SizedBox(
          width: double.infinity,
          height: MediaQuery.of(dialogContext).size.height * 0.8,
          child: const EqualizerWidget(),
        ),
        maxWidth: 560,
      );
      return;
    }
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
    if (isDesktop) {
      _showAdaptiveDialog(
        context,
        (dialogContext) => SizedBox(
          width: double.infinity,
          height: MediaQuery.of(dialogContext).size.height * 0.75,
          child: _buildQueueBody(dialogContext),
        ),
        maxWidth: 520,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(rXl)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _buildQueueBody(context, scrollController: scrollController);
          },
        );
      },
    );
  }

  Widget _buildQueueBody(BuildContext context,
      {ScrollController? scrollController}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final count = audio.queue.length;
        return Column(
          children: [
            if (!isDesktop) sheetHandle(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count track${count == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (count > 1)
                    IconButton(
                      icon: const Icon(Icons.clear_all_rounded),
                      tooltip: 'Clear queue',
                      onPressed: () => audio.clearQueueAfterCurrent(),
                    ),
                  if (isDesktop)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            if (isDesktop)
              const Divider(height: 1, thickness: 0.5)
            else
              const SizedBox(height: 6),
            Expanded(
              child: count == 0
                  ? Center(
                      child: Text(
                        'Queue is empty',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      scrollController: scrollController,
                      padding: EdgeInsets.symmetric(vertical: isDesktop ? 6 : 8),
                      itemCount: count,
                      onReorder: audio.moveQueueItem,
                      itemBuilder: (context, index) {
                        final track = audio.queue[index];
                        final isCurrent = index == audio.currentIndex;
                        final radius = isDesktop ? rSm : rMd;
                        final artSize = isDesktop ? 44.0 : 48.0;

                        return Padding(
                          key: ValueKey('${track.id}_$index'),
                          padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 12 : 16, vertical: 2),
                          child: Material(
                            color: isCurrent
                                ? scheme.primaryContainer
                                    .withValues(alpha: 0.35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(radius),
                            child: InkWell(
                              onTap: isCurrent
                                  ? null
                                  : () => audio.playAt(index),
                              borderRadius: BorderRadius.circular(radius),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 8 : 10,
                                    vertical: isDesktop ? 6 : 8),
                                child: Row(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SquareArt(
                                          bytes: track.albumArt,
                                          url: _buildYoutubeThumbnailUrl(track),
                                          size: artSize,
                                          radius: isDesktop ? rSm : 14,
                                        ),
                                        if (isCurrent)
                                          Container(
                                            width: artSize,
                                            height: artSize,
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.45),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      isDesktop ? rSm : 14),
                                            ),
                                            child: Icon(
                                              Icons.equalizer_rounded,
                                              size: 20,
                                              color: scheme.primary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: isCurrent
                                                  ? scheme.primary
                                                  : scheme.onSurface,
                                              fontWeight: isCurrent
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.views != null &&
                                                    track.views!.isNotEmpty
                                                ? '${track.artist} · ${track.views}'
                                                : track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: isCurrent
                                                  ? scheme.primary
                                                      .withValues(alpha: 0.8)
                                                  : scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: isDesktop ? 8 : 12,
                                            vertical: isDesktop ? 8 : 12),
                                        child: Icon(
                                          Icons.reorder_rounded,
                                          size: 20,
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptPlaylistName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
              'New playlist',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
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
    if (isDesktop) {
      _showAdaptiveDialog(
        context,
        (dialogContext) => _buildAddToPlaylistBody(dialogContext, track),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => _buildAddToPlaylistBody(sheetContext, track),
    );
  }

  Widget _buildAddToPlaylistBody(BuildContext sheetContext, Track track) {
    return SafeArea(
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
              if (!isDesktop)
                sheetHandle(sheetContext)
              else
                const SizedBox(height: 20),
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
    );
  }

  void _showMoreOptions(BuildContext context) {
    final rootContext = context;

    if (isDesktop) {
      _showAdaptiveDialog(
        context,
        (dialogContext) => _buildMoreOptionsBody(dialogContext, rootContext),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) =>
          _buildMoreOptionsBody(sheetContext, rootContext),
    );
  }

  Widget _buildMoreOptionsBody(
      BuildContext sheetContext, BuildContext rootContext) {
    final scheme = Theme.of(sheetContext).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDesktop)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 16),
            Padding(
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
          ],
        ),
      ),
    );
  }

  Widget _sheetNowPlayingCard(BuildContext context, Track track) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(rXl),
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
      borderRadius: BorderRadius.circular(rXl),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Future<void> _shareTrack(BuildContext context, Track? track) async {
    if (track == null) return;

    final url = _buildYoutubeMusicUrl(track);

    if (isDesktop) {
      if (url != null) {
        await Clipboard.setData(ClipboardData(text: url));
        showToast('Link copied to clipboard');
        return;
      }
      final file = File(track.path);
      if (!file.existsSync()) {
        showToast('File not found');
        return;
      }
      final dir = file.parent.path;
      if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
      }
      showToast('Opened in file manager');
      return;
    }

    try {
      if (url != null) {
        final by = track.artist.isNotEmpty ? ' by ${track.artist}' : '';
        const repo = 'https://github.com/libreAMP/kashou';
        await SharePlus.instance.share(
          ShareParams(
            text: 'Listen to ${track.title}$by on Kashou:\n$url\n$repo',
            subject: 'Share ${track.title}',
          ),
        );
      } else {
        final file = File(track.path);
        if (file.existsSync()) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(track.path)],
              subject: 'Share ${track.title}',
            ),
          );
        } else {
          showToast('File not found');
        }
      }
    } catch (_) {
      showToast('Unable to share track');
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
    return 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
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
    final ytId = isStream ? _extractYouTubeId(track.sourceUrl ?? track.path) : null;
    final rows = <MapEntry<String, String>>[
      MapEntry('Title', track.title),
      MapEntry('Artist', track.artist),
      if (track.album.isNotEmpty && track.album != 'YouTube')
        MapEntry('Album', track.album),
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
      if (isStream && ytId != null)
        MapEntry('Link', 'https://youtube.com/watch?v=$ytId'),
      if (!isStream) MapEntry('Path', track.path),
    ];

    if (isDesktop) {
      _showAdaptiveDialog(
        context,
        (dialogContext) => SafeArea(
          child: _buildTrackInfoBody(dialogContext, rows),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: _buildTrackInfoBody(sheetContext, rows),
          ),
        );
      },
    );
  }

  Widget _buildTrackInfoBody(
      BuildContext sheetContext, List<MapEntry<String, String>> rows) {
    final scheme = Theme.of(sheetContext).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop)
          sheetHandle(sheetContext)
        else
          const SizedBox(height: 20),
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
                        style: Theme.of(sheetContext).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LyricsView extends StatefulWidget {
  final AudioProvider audio;
  final Track track;
  final LyricsResult? lyrics;

  const _LyricsView({
    required this.audio,
    required this.track,
    required this.lyrics,
  });

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  StreamSubscription<Duration>? _sub;
  Timer? _timer;
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _bind();
    _sync(widget.audio.position);
  }

  void _bind() {
    _sub?.cancel();
    _timer?.cancel();
    _sub = widget.audio.audioPlayer.positionStream.listen((pos) {
      if (mounted) _sync(pos);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (widget.audio.isPlaying) {
        _sync(widget.audio.position);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _active = -1;
      _keys.clear();
      _bind();
    }
    _sync(widget.audio.position);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _sync(Duration pos) {
    final lines = widget.lyrics?.lines;
    if (lines == null || lines.isEmpty) return;

    final adjusted = pos + const Duration(milliseconds: 120);
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= adjusted) {
        active = i;
      } else {
        break;
      }
    }

    if (active != _active) {
      setState(() => _active = active);
      if (active >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = _keys[active]?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.45,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final res = widget.lyrics;
    if (res == null) {
      return const Center(child: KashouLoader());
    }
    if (res.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No lyrics found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    if (res.lines.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          res.plain,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < res.lines.length; i++)
            _line(context, res.lines[i], i, i == _active, scheme),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    LyricLine line,
    int index,
    bool isActive,
    ColorScheme scheme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.audio.seek(line.time),
        child: Container(
          key: _keys.putIfAbsent(index, () => GlobalKey()),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  fontSize: isActive ? 22 : 17,
                  color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                ),
            child: Text(line.text),
          ),
        ),
      ),
    );
  }
}
