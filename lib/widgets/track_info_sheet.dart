import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../utils/toast.dart';
import 'sheet_handle.dart';
import 'square_art.dart';

IconData _trackInfoIcon(String key) {
  switch (key.toLowerCase()) {
    case 'title':
      return Icons.music_note_rounded;
    case 'artist':
      return Icons.person_rounded;
    case 'album':
      return Icons.album_rounded;
    case 'duration':
      return Icons.schedule_rounded;
    case 'genre':
      return Icons.category_rounded;
    case 'year':
      return Icons.calendar_today_rounded;
    case 'format':
      return Icons.audio_file_rounded;
    case 'bitrate':
      return Icons.speed_rounded;
    case 'sample rate':
      return Icons.graphic_eq_rounded;
    case 'loudness':
      return Icons.volume_up_rounded;
    case 'source':
      return Icons.cloud_outlined;
    case 'link':
      return Icons.link_rounded;
    case 'path':
      return Icons.folder_open_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

void showTrackInfoModal(BuildContext context, Track track) {
  final ytId = track.videoId;

  final rows = [
    MapEntry('Title', track.title),
    MapEntry('Artist', track.artist),
    if (track.album.isNotEmpty && track.album != 'YouTube')
      MapEntry('Album', track.album),
    if (track.duration > Duration.zero)
      MapEntry('Duration',
          '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
    if (track.genre != null && track.genre!.isNotEmpty)
      MapEntry('Genre', track.genre!),
    if (track.year != null && track.year! > 0)
      MapEntry('Year', '${track.year}'),
    if (track.codec != null && track.codec!.isNotEmpty)
      MapEntry('Format', track.codec!.toUpperCase()),
    if (track.bitrate != null && track.bitrate! > 0)
      MapEntry('Bitrate', '${track.bitrate} kbps'),
    if (track.sampleRate != null && track.sampleRate! > 0)
      MapEntry('Sample rate', '${track.sampleRate} Hz'),
    if (track.loudnessDb != null)
      MapEntry('Loudness', '${track.loudnessDb!.toStringAsFixed(1)} dB'),
    MapEntry('Source', track.isOnline ? 'YouTube' : 'Local file'),
    if (track.isOnline && (track.sourceUrl != null || ytId != null))
      MapEntry('Link', track.sourceUrl ?? 'https://youtube.com/watch?v=$ytId'),
    if (!track.isOnline && track.path.isNotEmpty)
      MapEntry('Path', track.path),
  ];

  Widget buildBody(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final artUrl = ytId != null ? 'https://i.ytimg.com/vi/$ytId/mqdefault.jpg' : null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: isDesktop
            ? BorderRadius.circular(rXl)
            : const BorderRadius.vertical(top: Radius.circular(rXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop) sheetHandle(ctx) else const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                SquareArt(
                  bytes: track.albumArt,
                  url: artUrl,
                  size: 48,
                  radius: rMd,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: Theme.of(ctx)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                final isFirst = i == 0;
                final isLast = i == rows.length - 1;
                final radius = BorderRadius.vertical(
                  top: isFirst ? const Radius.circular(rLg) : const Radius.circular(4),
                  bottom: isLast ? const Radius.circular(rLg) : const Radius.circular(4),
                );
                final icon = _trackInfoIcon(row.key);

                return Container(
                  margin: const EdgeInsets.only(bottom: 2.5),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: radius,
                  ),
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: row.value));
                      showToast('Copied ${row.key.toLowerCase()}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(rSm),
                            ),
                            child: Icon(icon, size: 18, color: scheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.key,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  row.value,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: SafeArea(child: buildBody(dialogContext)),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: buildBody(sheetContext),
      ),
    ),
  );
}
