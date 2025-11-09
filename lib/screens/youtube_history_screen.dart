import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/stream_history_entry.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ytdl_service.dart';

class YoutubeHistoryScreen extends StatefulWidget {
  const YoutubeHistoryScreen({super.key});

  @override
  State<YoutubeHistoryScreen> createState() => _YoutubeHistoryScreenState();
}

class _YoutubeHistoryScreenState extends State<YoutubeHistoryScreen> {
  String? _loadingEntryId;

  bool get _isLoading => _loadingEntryId != null;

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
    Map<String, dynamic>? details;
    try {
      details = await ytdl.fetchAudioDetails(sourceUrl);
    } catch (_) {
      details = null;
    }

    if (!mounted) {
      return;
    }

    if (details == null) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('Unable to refresh YouTube stream.');
      setState(() {
        _loadingEntryId = null;
      });
      return;
    }

    String? downloadUrl = _extractDownloadUrl(details);
    if (downloadUrl == null) {
      audioProvider.cancelPendingTrack();
      _showSnackBar('YouTube audio stream unavailable.');
      setState(() {
        _loadingEntryId = null;
      });
      return;
    }

    Uint8List? art = entry.track.albumArt;
    final thumbUrl = (details['thumbnail'] ?? details['thumbnails']?.first?['url']) as String?;
    if (art == null && thumbUrl != null && thumbUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(thumbUrl));
        if (response.statusCode == 200) {
          art = response.bodyBytes;
        }
      } catch (_) {
        // Ignore errors fetching artwork; fallback to stored art.
      }
    }

    final updatedTrack = placeholder.copyWith(
      title: details['title'] as String? ?? placeholder.title,
      artist: details['channel'] as String? ?? placeholder.artist,
      album: 'YouTube',
      path: downloadUrl,
      duration: Duration(seconds: _asInt(details['duration']) ?? placeholder.duration.inSeconds),
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

  String? _extractDownloadUrl(Map<String, dynamic> details) {
    String? downloadUrl;
    final audio = details['audio'];
    if (audio is Map) {
      downloadUrl = audio['download_url'] as String?;
    } else if (audio is String) {
      downloadUrl = audio;
    }
    downloadUrl ??= details['download_url'] as String?;
    downloadUrl ??= details['audio_url'] as String?;
    final download = details['download'];
    if (downloadUrl == null && download is Map) {
      downloadUrl = download['url'] as String? ?? download['download_url'] as String?;
    } else if (downloadUrl == null && download is String) {
      downloadUrl = download;
    }
    return downloadUrl;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
        title: const Text('YouTube History'),
        actions: [
          Consumer<AudioProvider>(
            builder: (context, audioProvider, _) {
              final hasHistory = audioProvider.youtubeStreamHistoryEntries.isNotEmpty;
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
                  Icon(Icons.history, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No YouTube history yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start streaming from YouTube to see your history here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildHistoryTile(context, entry, colorScheme);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: entries.length,
          );
        },
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, StreamHistoryEntry entry, ColorScheme colorScheme) {
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        context.read<AudioProvider>().removeFromStreamHistory(track.sourceUrl ?? track.path);
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : () => _playEntry(entry),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _buildAlbumArt(track.albumArt, colorScheme),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(entry.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                isLoading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
                        onPressed: () => _playEntry(entry),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(Uint8List? art, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: colorScheme.surfaceContainerHighest,
        child: art != null
            ? Image.memory(
                art,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
              )
            : Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
      ),
    );
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
