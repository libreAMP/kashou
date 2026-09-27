import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stream_history_entry.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/square_art.dart';

// max width of the history list on wide desktop windows
const double _desktopMaxContentWidth = 900;

class YoutubeHistoryScreen extends StatefulWidget {
  const YoutubeHistoryScreen({super.key});

  @override
  State<YoutubeHistoryScreen> createState() => _YoutubeHistoryScreenState();
}

class _YoutubeHistoryScreenState extends State<YoutubeHistoryScreen> {
  String? _loadingEntryId;

  Future<void> _playEntry(StreamHistoryEntry entry) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.enableYouTubeIntegration) {
      _showSnackBar('YouTube integration is disabled in settings.');
      return;
    }

    final sourceUrl = entry.track.sourceUrl ?? entry.track.path;
    if (sourceUrl.isEmpty) {
      _showSnackBar('Original stream URL is unavailable.');
      return;
    }

    final audioProvider = context.read<AudioProvider>();
    final placeholder = entry.track.copyWith(
      path: sourceUrl,
      sourceUrl: sourceUrl,
    );

    setState(() {
      _loadingEntryId = entry.track.id;
    });

    await audioProvider.prepareTrackLoad(placeholder);

    try {
      // youtube_explode leads on desktop, see resolveAudioStream
      final stream = await YtdlWrapperService.resolveAudioStream(sourceUrl);
      if (stream == null) {
        if (!mounted) return;
        audioProvider.cancelPendingTrack(entry.track.id);
        _showSnackBar('Unable to refresh YouTube stream.');
        setState(() {
          _loadingEntryId = null;
        });
        return;
      }

      final updatedTrack = placeholder.copyWith(
        loudnessDb: stream.loudnessDb,
        path: stream.url,
      );

      await audioProvider.playTrack(updatedTrack);
    } catch (error) {
      _showSnackBar('Failed to start playback: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loadingEntryId = null;
        });
      }
    }
  }

  Future<void> _confirmClearHistory() async {
    final audioProvider = context.read<AudioProvider>();
    if (audioProvider.youtubeStreamHistoryEntries.isEmpty) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              'Clear history?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
          content: const Text('This will remove all YouTube stream history.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      await audioProvider.clearStreamHistory();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('History'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const BackChip(),
            actions: [
              Consumer<AudioProvider>(
                builder: (context, audioProvider, _) {
                  final hasHistory =
                      audioProvider.youtubeStreamHistoryEntries.isNotEmpty;
                  return IconButton(
                    tooltip: 'Clear history',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: hasHistory ? _confirmClearHistory : null,
                  );
                },
              ),
            ],
          ),
          Consumer<AudioProvider>(
            builder: (context, audioProvider, _) {
              final entries = audioProvider.youtubeStreamHistoryEntries;

              if (entries.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 48,
                            color:
                                colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'What you play from Stream shows up here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sliverList = SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildHistoryTile(context, entries[index], colorScheme),
                  childCount: entries.length,
                ),
              );

              if (!isDesktop) {
                return sliverList;
              }

              return SliverLayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = math.max(
                    (constraints.crossAxisExtent - _desktopMaxContentWidth) / 2,
                    0.0,
                  );
                  return SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: sliverList,
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(
      BuildContext context, StreamHistoryEntry entry, ColorScheme colorScheme) {
    final track = entry.track;
    final theme = Theme.of(context);
    final isLoading = _loadingEntryId == track.id;

    final tile = Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final isCurrent = audio.currentTrack?.id == track.id;
        final playing = isCurrent && audio.isPlaying;

        Widget trailing;
        if (isLoading) {
          trailing = KashouLoader(size: 26, color: colorScheme.primary);
        } else {
          final playButton = IconButton(
            tooltip: isDesktop ? (playing ? 'Pause' : 'Play') : null,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () =>
                isCurrent ? audio.togglePlayPause() : _playEntry(entry),
          );
          trailing = isDesktop
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    playButton,
                    // swipe-to-dismiss is touch-only, desktop gets a
                    // visible remove button instead
                    IconButton(
                      tooltip: 'Remove from history',
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => audio.removeFromStreamHistory(
                          track.sourceUrl ?? track.path),
                    ),
                  ],
                )
              : playButton;
        }

        return Material(
          color: isCurrent
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(rMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(rMd),
            onTap: isLoading
                ? null
                : () => isCurrent ? audio.togglePlayPause() : _playEntry(entry),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(rSm),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildAlbumArt(track, colorScheme),
                          if (playing)
                            Container(
                              color: Colors.black.withValues(alpha: 0.4),
                              child: Icon(Icons.graphic_eq,
                                  color: Colors.white, size: 22),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${track.artist} Â· ${_formatTimestamp(entry.timestamp)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: isDesktop
          ? GestureDetector(
              // right-click mirrors the swipe-to-dismiss on touch devices
              onSecondaryTapUp: (details) =>
                  _showRemoveMenu(details.globalPosition, track),
              child: tile,
            )
          : Dismissible(
              key: ValueKey(track.sourceUrl ?? track.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(rMd),
                ),
                child: Icon(Icons.delete_outline,
                    color: colorScheme.onErrorContainer),
              ),
              onDismissed: (_) {
                context
                    .read<AudioProvider>()
                    .removeFromStreamHistory(track.sourceUrl ?? track.path);
              },
              child: tile,
            ),
    );
  }

  void _showRemoveMenu(Offset position, Track track) {
    final audioProvider = context.read<AudioProvider>();
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: 'remove',
          child: Text('Remove from history'),
        ),
      ],
    ).then((value) {
      if (value == 'remove') {
        audioProvider.removeFromStreamHistory(track.sourceUrl ?? track.path);
      }
    });
  }

  Widget _buildAlbumArt(Track track, ColorScheme colorScheme) {
    final art = track.albumArt;
    if (art == null) {
      // no stored bytes, the video thumb still exists online
      final id = _videoIdOf(track);
      return SquareArt(
        url: id != null ? 'https://i.ytimg.com/vi/$id/mqdefault.jpg' : null,
        size: 56,
        radius: rSm,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(rSm),
      child: Container(
        width: 56,
        height: 56,
        color: colorScheme.surfaceContainerHighest,
        child: Image.memory(
          art,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  String? _videoIdOf(Track track) {
    final uri = Uri.tryParse(track.sourceUrl ?? track.path);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else {
      final days = difference.inDays;
      if (days < 7) {
        return '$days day${days == 1 ? '' : 's'} ago';
      }
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

