import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/equalizer_widget.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AudioProvider>(
        builder: (context, audio, child) {
          final track = audio.currentTrack;

          if (track == null) {
            return const Center(child: Text('No track playing'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (track.albumArt != null)
                        Image.memory(
                          track.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.primaryContainer,
                                    Theme.of(context).colorScheme.surface,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.music_note,
                                size: 120,
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.music_note,
                            size: 120,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).colorScheme.surface.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.equalizer),
                    onPressed: () {
                      _showEqualizerSheet(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      _showMoreOptions(context);
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artist,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.album,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildProgressBar(context, audio),
                      const SizedBox(height: 32),
                      _buildControls(context, audio),
                      const SizedBox(height: 24),
                      _buildSecondaryControls(context, audio),
                      const SizedBox(height: 32),
                      _buildAudioInfo(context, track),
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

  Widget _buildProgressBar(BuildContext context, AudioProvider audio) {
    final position = audio.position;
    final duration = audio.duration;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: position.inMilliseconds.toDouble(),
            max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
            onChanged: (value) {
              audio.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 48,
          onPressed: audio.skipPrevious,
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 56,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            onPressed: audio.togglePlayPause,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 48,
          onPressed: audio.skipNext,
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(BuildContext context, AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            _getShuffleIcon(audio.shuffleMode),
            color: audio.shuffleMode != ShuffleMode.off
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          onPressed: () {
            final newMode = audio.shuffleMode == ShuffleMode.off
                ? ShuffleMode.songs
                : ShuffleMode.off;
            audio.setShuffleMode(newMode);
          },
        ),
        IconButton(
          icon: Icon(
            _getRepeatIcon(audio.repeatMode),
            color: audio.repeatMode != RepeatMode.off
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          onPressed: () {
            final modes = RepeatMode.values;
            final currentIndex = modes.indexOf(audio.repeatMode);
            final nextIndex = (currentIndex + 1) % modes.length;
            audio.setRepeatMode(modes[nextIndex]);
          },
        ),
        IconButton(
          icon: const Icon(Icons.queue_music),
          onPressed: () {
            _showQueueSheet(context);
          },
        ),
        IconButton(
          icon: const Icon(Icons.favorite_border),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildAudioInfo(BuildContext context, track) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Info',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(context, 'Format', track.codec ?? 'Unknown'),
            _buildInfoRow(
              context,
              'Bitrate',
              track.bitrate != null ? '${track.bitrate} kbps' : 'Unknown',
            ),
            _buildInfoRow(
              context,
              'Sample Rate',
              track.sampleRate != null ? '${track.sampleRate} Hz' : 'Unknown',
            ),
            _buildInfoRow(context, 'Duration', _formatDuration(track.duration)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
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
        return Icons.repeat_on;
      case RepeatMode.one:
        return Icons.repeat_one_on;
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
