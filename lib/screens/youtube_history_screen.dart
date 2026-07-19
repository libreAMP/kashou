import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stream_history_entry.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';
import '../models/youtube_streaming_data.dart';
import '../theme/radii.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/square_art.dart';

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

    const ytdl = YtdlWrapperService();
    YouTubeStreamingData? streamingData;
    try {
      streamingData = await ytdl.fetchStreamingData(sourceUrl);
    } catch (_) {
      streamingData = null;
    }

    if (!mounted) {
      return;
    }

    if (streamingData == null || !streamingData.playable) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('Unable to refresh YouTube stream.');
      setState(() {
        _loadingEntryId = null;
      });
      return;
    }

    final selectedFormat =
        streamingData.bestStream ?? streamingData.fallbackStream;
    if (selectedFormat == null) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('YouTube audio stream unavailable.');
      setState(() {
        _loadingEntryId = null;
      });
      return;
    }

    Uint8List? art = entry.track.albumArt;
    art ??= await ytdl.fetchVideoArt(streamingData.videoId,
        preferred: streamingData.thumbnailUrl);

    // the entry already knows its names, streaming data only fills gaps
    final knownArtist =
        placeholder.artist.isNotEmpty && placeholder.artist != 'Unknown';
    final updatedTrack = placeholder.copyWith(
      title: placeholder.title != 'Unknown' || streamingData.title.isEmpty
          ? placeholder.title
          : streamingData.title,
      artist: knownArtist ? placeholder.artist : streamingData.channelName,
      loudnessDb: streamingData.loudnessDb,
      album: 'YouTube',
      path: selectedFormat.url,
      duration: streamingData.duration ?? placeholder.duration,
      albumArt: art,
      sourceUrl: sourceUrl,
    );

    try {
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
          title: const Text('Clear history?'),
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
      appBar: AppBar(
        title: const Text('History'),
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
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, _) {
          final entries = audioProvider.youtubeStreamHistoryEntries;

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildHistoryTile(context, entry, colorScheme);
            },
            itemCount: entries.length,
          );
        },
      ),
    );
  }

  Widget _buildHistoryTile(
      BuildContext context, StreamHistoryEntry entry, ColorScheme colorScheme) {
    final track = entry.track;
    final theme = Theme.of(context);
    final isLoading = _loadingEntryId == track.id;

    return Dismissible(
      key: ValueKey(track.sourceUrl ?? track.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(rMd),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        context
            .read<AudioProvider>()
            .removeFromStreamHistory(track.sourceUrl ?? track.path);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(rMd),
          onTap: isLoading ? null : () => _playEntry(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _buildAlbumArt(track, colorScheme),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.artist} · ${_formatTimestamp(entry.timestamp)}',
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
                isLoading
                    ? KashouLoader(size: 26, color: colorScheme.primary)
                    : Icon(Icons.play_arrow_rounded,
                        color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(Track track, ColorScheme colorScheme) {
    final art = track.albumArt;
    if (art == null) {
      // no stored bytes, the video thumb still exists online
      final id = _videoIdOf(track);
      return SquareArt(
        url: id != null ? 'https://i.ytimg.com/vi/$id/hqdefault.jpg' : null,
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
