import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../screens/artist_screen.dart';
import '../screens/metadata_editor_screen.dart';
import '../services/download_manager.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import 'm3e_menu.dart';
import 'sheet_handle.dart';
import 'square_art.dart';
import 'track_info_sheet.dart';

void showTrackOptionsSheet(BuildContext context, Track track,
    {String? playlistId, Offset? anchor}) {
  final isOnline = track.isOnline;
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
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sheetHandle(sheetContext),
            _headerTile(track, isOnline),
            const SizedBox(height: 4),
            ..._optionTiles(sheetContext, track, isOnline, playlistId),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Widget _headerTile(Track track, bool isOnline, {Widget? trailing}) {
  final vid = _videoId(track);
  return ListTile(
    leading: SquareArt(
      bytes: track.albumArt,
      url: isOnline && vid != null
          ? 'https://i.ytimg.com/vi/$vid/mqdefault.jpg'
          : null,
      size: 44,
      radius: rSm,
    ),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing,
  );
}

class _TrackAction {
  const _TrackAction(this.label, this.icon, this.run,
      {this.destructive = false});

  final String label;
  final IconData icon;
  final void Function(BuildContext context) run;
  final bool destructive;
}

List<_TrackAction> _trackActions(
    BuildContext context, Track track, bool isOnline, String? playlistId) {
  final shareUrl = isOnline
      ? 'https://www.youtube.com/watch?v=${_videoId(track)}'
      : '${track.title} - ${track.artist}';
  final audio = Provider.of<AudioProvider>(context, listen: false);

  return [
    _TrackAction('Play', Icons.play_arrow_rounded, (ctx) {
      audio.playTrack(track);
    }),
    _TrackAction('Play next', Icons.playlist_play_rounded, (ctx) {
      audio.playTrackNext(track);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Playing "${track.title}" next'),
          duration: const Duration(seconds: 2),
        ),
      );
    }),
    _TrackAction('Add to queue', Icons.queue_music_rounded, (ctx) {
      audio.addTracksToQueue([track]);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Added "${track.title}" to queue'),
          duration: const Duration(seconds: 2),
        ),
      );
    }),
    _TrackAction('Add to Playlist', Icons.playlist_add_rounded,
        (context) => showAddToPlaylistDialog(context, track)),
    if (isOnline)
      _TrackAction('Download', Icons.download_rounded, (ctx) {
        DownloadManager.instance.enqueue(
          track,
          thumbUrl: 'https://i.ytimg.com/vi/${_videoId(track)}/mqdefault.jpg',
        );
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Download started, see Downloads'),
            duration: Duration(seconds: 2),
          ),
        );
      }),
    if (!isOnline)
      _TrackAction('Edit Metadata', Icons.edit_rounded, (context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MetadataEditorScreen(track: track)),
        );
      }),
    _TrackAction('Share', Icons.share_rounded,
        (_) => SharePlus.instance.share(ShareParams(uri: Uri.parse(shareUrl)))),
    if (isOnline && track.artistId != null)
      _TrackAction('View artist', Icons.person_rounded, (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ArtistScreen(browseId: track.artistId!, name: track.artist),
          ),
        );
      }),
    if (playlistId != null)
      _TrackAction(
          'Remove from playlist',
          Icons.playlist_remove_rounded,
          (context) => Provider.of<LibraryProvider>(context, listen: false)
              .removeFromPlaylist(playlistId, track),
          destructive: true),
    _TrackAction('Track Info', Icons.info_outline,
        (context) => showTrackInfoModal(context, track)),
  ];
}

List<Widget> _optionTiles(
    BuildContext sheetContext, Track track, bool isOnline, String? playlistId) {
  return [
    for (final action
        in _trackActions(sheetContext, track, isOnline, playlistId))
      SheetTile(
        leading: Icon(action.icon),
        title: Text(action.label),
        onTap: () {
          Navigator.pop(sheetContext);
          action.run(sheetContext);
        },
      ),
  ];
}

String? _videoId(Track track) {
  final uri = Uri.tryParse(track.sourceUrl ?? track.path);
  final id = uri?.queryParameters['v'] ??
      (uri?.host.contains('youtu.be') == true && uri!.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null);
  if (id != null && id.isNotEmpty) return id;
  if (track.isOnline && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(track.id)) {
    return track.id;
  }
  return null;
}

List<Widget> _menuRows(
    BuildContext context, Track track, bool isOnline, String? playlistId) {
  final rows = <Widget>[];
  var previous = '';
  for (final action in _trackActions(context, track, isOnline, playlistId)) {
    if (previous.isNotEmpty && action.icon == Icons.person_rounded) {
      rows.add(const M3EMenuSeparator());
    }
    rows.add(
      M3EMenuRow(
        item: M3EMenuItem(
          label: action.label,
          icon: action.icon,
          destructive: action.destructive,
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            action.run(context);
          },
        ),
      ),
    );
    previous = action.label;
  }
  return rows;
}

void showAddToPlaylistDialog(BuildContext context, Track track) {
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
