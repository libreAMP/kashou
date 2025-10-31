import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/equalizer_widget.dart';
import 'metadata_editor_screen.dart';
import 'dart:ui';

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../utils/hero_transitions.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

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
            color: colorScheme.surface.withOpacity(0.12),
          ),
        ),
      ],
    );
  }

          final mediaQuery = MediaQuery.of(context);
          final size = mediaQuery.size;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final bottomInset = mediaQuery.padding.bottom;

          return Stack(
            children: [
              Positioned.fill(child: _buildAmbientBackground(context, track)),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.surface.withOpacity(0.85),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
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
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              bottomInset + 212,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildArtworkCard(context, track, size),
                                const SizedBox(height: 28),
                                _buildTrackMeta(context, track, audio),
                                const SizedBox(height: 28),
                                _buildAudioInfoCard(context, track),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProgressStrip(context, audio),
                              const SizedBox(height: 18),
                              _buildPrimaryControls(context, audio),
                              const SizedBox(height: 30),
                              _buildSecondaryControlRow(context, audio, library),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            children: [
              Text(
                'Now Playing',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
            color: colorScheme.surface.withOpacity(0.12),
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
          ),
        ),
        const SizedBox(height: 6),
        Text(
          track.artist,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetaAssistChip(context, icon: Icons.album_rounded, label: track.album),
            if (track.genre != null && track.genre!.isNotEmpty)
              _buildMetaAssistChip(context, icon: Icons.style_outlined, label: track.genre!),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaAssistChip(BuildContext context, {required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleIconButton(
            context,
            icon: Icons.skip_previous_rounded,
            onTap: audio.skipPrevious,
          ),
          _buildPlayButton(context, audio),
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
      color: colorScheme.surfaceContainerHigh.withOpacity(0.8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 24,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, AudioProvider audio) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = audio.isPlaying;

    final targetSize = 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuad,
      width: targetSize,
      height: targetSize,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(isPlaying ? 0.28 : 0.2),
            blurRadius: isPlaying ? 22 : 18,
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
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
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
    );
  }

  Widget _buildSecondaryControlRow(BuildContext context, AudioProvider audio, LibraryProvider library) {
    final colorScheme = Theme.of(context).colorScheme;
    final isShuffle = audio.shuffleMode != ShuffleMode.off;
    final isRepeatActive = audio.repeatMode != RepeatMode.off;
    final isFavorite = library.isTrackFavorite(audio.currentTrack?.id ?? '');

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
                              // Play this track
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
