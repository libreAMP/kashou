import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stream_history_entry.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../services/download_manager.dart';
import '../services/ytdl_service.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/m3e_menu.dart';
import '../widgets/m3e_swipe_actions.dart';
import '../widgets/square_art.dart';
import '../widgets/empty_shape.dart';
import '../widgets/stream_song_row.dart';

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

    final scrollView = CustomScrollView(
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
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyShape(
                  icon: Icons.history_rounded,
                  title: 'no history yet',
                  body: 'what you play from stream shows up here',
                ),
              );
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            String label(DateTime t) {
              final days =
                  today.difference(DateTime(t.year, t.month, t.day)).inDays;
              return days <= 0
                  ? 'today'
                  : days == 1
                      ? 'yesterday'
                      : days < 7
                          ? 'this week'
                          : 'earlier';
            }

            final groups = <String, List<StreamHistoryEntry>>{};
            for (final e in entries) {
              groups.putIfAbsent(label(e.timestamp), () => []).add(e);
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                for (final g in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                    child: Text(g.key,
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800)),
                  ),
                  for (final (i, e) in g.value.indexed)
                    _buildHistoryTile(
                        context, e, colorScheme, i, g.value.length),
                ],
              ]),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    if (!isDesktop) return Scaffold(body: scrollView);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxContentWidth),
          child: scrollView,
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, StreamHistoryEntry entry,
      ColorScheme colorScheme, int slot, int count) {
    final track = entry.track;

    final tile = Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final isCurrent = audio.currentTrack?.id == track.id;
        return StreamSongRow(
          artwork: _buildAlbumArt(track, colorScheme),
          title: track.title,
          subtitle: '${track.artist} · ${_formatTimestamp(entry.timestamp)}',
          isCurrent: isCurrent,
          playing: isCurrent && audio.isPlaying,
          slot: slot,
          count: count,
          onTap: () {
            if (_loadingEntryId != null) return;
            isCurrent ? audio.togglePlayPause() : _playEntry(entry);
          },
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: isDesktop
          ? GestureDetector(
              // swipe-to-dismiss is touch-only so desktop gets a visible remove button
              // right-click mirrors the swipe actions on touch devices
              onSecondaryTapUp: (details) =>
                  _showRemoveMenu(details.globalPosition, track),
              child: tile,
            )
          : M3ESwipeActions(
              actions: [
                M3ESwipeAction(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onPressed: () => DownloadManager.instance.enqueue(track),
                ),
                M3ESwipeAction(
                  icon: Icons.delete_outline,
                  label: 'Remove from history',
                  filled: true,
                  onPressed: () => context
                      .read<AudioProvider>()
                      .removeFromStreamHistory(track.sourceUrl ?? track.path),
                ),
              ],
              child: tile,
            ),
    );
  }

  void _showRemoveMenu(Offset position, Track track) {
    final audioProvider = context.read<AudioProvider>();
    showM3EMenu(
      context,
      globalPosition: position,
      children: [
        M3EMenuRow(
          item: M3EMenuItem(
            label: 'Remove from history',
            icon: Icons.history_toggle_off_rounded,
            destructive: true,
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              audioProvider.removeFromStreamHistory(
                track.sourceUrl ?? track.path,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(Track track, ColorScheme colorScheme) {
    final art = track.albumArt;
    if (art == null) {
      // no stored bytes, the video thumb still exists online
      final id = _videoIdOf(track);
      return SquareArt(
        url: id != null ? 'https://i.ytimg.com/vi/$id/mqdefault.jpg' : null,
        size: 52,
        radius: 16,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
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
