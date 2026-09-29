import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../screens/artist_screen.dart';
import '../screens/metadata_editor_screen.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import 'm3e_menu.dart';
import 'sheet_handle.dart';
import 'square_art.dart';

void showTrackOptionsSheet(BuildContext context, Track track,
    {String? playlistId, Offset? anchor}) {
  final isOnline = (track.sourceUrl ?? track.path).startsWith('http');
  if (isDesktop && anchor != null) {
    showM3EMenu(
      context,
      globalPosition: anchor,
      children: _menuRows(context, track, isOnline, playlistId),
    );
    return;
  }
  // on desktop a centered, width-constrained dialog replaces the bottom sheet
  if (isDesktop) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _headerTile(track, isOnline,
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                    )),
                const Divider(height: 1),
                ..._optionTiles(dialogContext, track, isOnline, playlistId),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sheetHandle(sheetContext),
          _headerTile(track, isOnline),
          const Divider(height: 1),
          ..._optionTiles(sheetContext, track, isOnline, playlistId),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _headerTile(Track track, bool isOnline, {Widget? trailing}) {
  return ListTile(
    leading: SquareArt(
      bytes: track.albumArt,
      url: isOnline
          ? 'https://i.ytimg.com/vi/${_videoId(track)}/mqdefault.jpg'
          : null,
      size: 44,
      radius: rSm,
    ),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing,
  );
}

List<Widget> _optionTiles(
    BuildContext sheetContext, Track track, bool isOnline, String? playlistId) {
  return [
    if (!isOnline)
      ListTile(
        leading: const Icon(Icons.edit_rounded),
        title: const Text('Edit Metadata'),
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            sheetContext,
            MaterialPageRoute(
                builder: (_) => MetadataEditorScreen(track: track)),
          );
        },
      ),
    ListTile(
      leading: const Icon(Icons.playlist_add_rounded),
      title: const Text('Add to Playlist'),
      onTap: () {
        Navigator.pop(sheetContext);
        _showAddToPlaylist(sheetContext, track);
      },
    ),
    ListTile(
      leading: const Icon(Icons.share_rounded),
      title: const Text('Share'),
      onTap: () {
        Navigator.pop(sheetContext);
        final url = isOnline
            ? 'https://www.youtube.com/watch?v=${_videoId(track)}'
            : '${track.title} - ${track.artist}';
        SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
      },
    ),
    if (isOnline && track.artistId != null)
      ListTile(
        leading: const Icon(Icons.person_rounded),
        title: const Text('View artist'),
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            sheetContext,
            MaterialPageRoute(
              builder: (_) =>
                  ArtistScreen(browseId: track.artistId!, name: track.artist),
            ),
          );
        },
      ),
    if (playlistId != null)
      ListTile(
        leading: const Icon(Icons.playlist_remove_rounded),
        title: const Text('Remove from playlist'),
        onTap: () {
          Navigator.pop(sheetContext);
          Provider.of<LibraryProvider>(sheetContext, listen: false)
              .removeFromPlaylist(playlistId, track);
        },
      ),
    ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Track Info'),
      onTap: () {
        Navigator.pop(sheetContext);
        _showTrackInfo(sheetContext, track, isOnline);
      },
    ),
  ];
}

String? _videoId(Track track) {
  final uri = Uri.tryParse(track.sourceUrl ?? track.path);
  return uri?.queryParameters['v'] ??
      (uri?.host.contains('youtu.be') == true && uri!.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null);
}

List<Widget> _menuRows(
    BuildContext context, Track track, bool isOnline, String? playlistId) {
  void close() => Navigator.of(context, rootNavigator: true).pop();
  final shareUrl = isOnline
      ? 'https://www.youtube.com/watch?v=${_videoId(track)}'
      : '${track.title} - ${track.artist}';

  M3EMenuRow row(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) =>
      M3EMenuRow(
        item: M3EMenuItem(
          label: label,
          icon: icon,
          destructive: destructive,
          onTap: () {
            close();
            onTap();
          },
        ),
      );

  return [
    if (!isOnline)
      row('Edit Metadata', Icons.edit_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MetadataEditorScreen(track: track)),
        );
      }),
    row('Add to Playlist', Icons.playlist_add_rounded, () {
      _showAddToPlaylist(context, track);
    }),
    row('Share', Icons.share_rounded, () {
      SharePlus.instance.share(ShareParams(uri: Uri.parse(shareUrl)));
    }),
    if (isOnline && track.artistId != null) const M3EMenuSeparator(),
    if (isOnline && track.artistId != null)
      row('View artist', Icons.person_rounded, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ArtistScreen(browseId: track.artistId!, name: track.artist),
          ),
        );
      }),
    if (playlistId != null)
      row(
        'Remove from playlist',
        Icons.playlist_remove_rounded,
        () => Provider.of<LibraryProvider>(context, listen: false)
            .removeFromPlaylist(playlistId, track),
        destructive: true,
      ),
    row('Track Info', Icons.info_outline, () {
      _showTrackInfo(context, track, isOnline);
    }),
  ];
}

void _showAddToPlaylist(BuildContext context, Track track) {
  final library = Provider.of<LibraryProvider>(context, listen: false);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        'Add to playlist',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: () async {
                Navigator.pop(dialogContext);
                final name = await _promptName(context);
                if (name == null || name.trim().isEmpty) return;
                await library.createPlaylist(name.trim());
                final created = library.playlists.firstWhere(
                    (p) => p.name == name.trim(),
                    orElse: () => library.playlists.last);
                await library.addToPlaylist(created.id, track);
              },
            ),
            for (final playlist in library.playlists)
              ListTile(
                title: Text(playlist.name),
                subtitle: Text('${playlist.tracks.length} songs'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  library.addToPlaylist(playlist.id, track);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _promptName(BuildContext context) {
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

void _showTrackInfo(BuildContext context, Track track, bool isOnline) {
  final rows = <MapEntry<String, String>>[
    MapEntry('Title', track.title),
    MapEntry('Artist', track.artist),
    if (track.album.isNotEmpty && track.album != 'YouTube')
      MapEntry('Album', track.album),
    if (track.year != null) MapEntry('Year', track.year.toString()),
    if (track.genre != null) MapEntry('Genre', track.genre!),
    MapEntry('Duration',
        '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
    if (track.bitrate != null) MapEntry('Bitrate', '${track.bitrate} kbps'),
    if (track.sampleRate != null)
      MapEntry('Sample Rate', '${track.sampleRate} Hz'),
    if (track.codec != null) MapEntry('Format', track.codec!),
    if (_videoId(track) != null)
      MapEntry('Link', 'https://youtube.com/watch?v=${_videoId(track)}'),
    if (!isOnline) MapEntry('Path', track.path),
  ];
  showDialog(
    context: context,
    builder: (dialogContext) {
      final rowsView = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.key, style: Theme.of(context).textTheme.labelMedium),
                  Text(row.value, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
        ],
      );
      return AlertDialog(
        title: Text(
          'Track info',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        content: isDesktop ? SingleChildScrollView(child: rowsView) : rowsView,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
