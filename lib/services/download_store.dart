import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

const _audioExts = {'.m4a', '.webm', '.opus', '.mp3', '.flac', '.ogg', '.aac'};

class DownloadStore {
  static Future<Directory> dir() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}

    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final musicDir = Directory('${externalDir.path}/Music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        return musicDir;
      }
    } catch (_) {}

    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  static Future<List<Track>> tracks() async {
    final d = await dir();
    if (!await d.exists()) return const [];

    final files = d
        .listSync()
        .whereType<File>()
        .where((f) => _audioExts
            .contains(f.path.substring(f.path.lastIndexOf('.')).toLowerCase()))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    final out = <Track>[];
    for (final f in files) {
      Tag? tag;
      try {
        tag = await AudioTags.read(f.path);
      } catch (_) {}
      final name = f.uri.pathSegments.last;
      final stem = name.substring(0, name.lastIndexOf('.'));
      final parts = stem.split(' - ');
      out.add(Track(
        id: f.path,
        title: tag?.title ?? parts.first,
        artist: tag?.trackArtist ??
            (parts.length > 1 ? parts.sublist(1).join(' - ') : 'Unknown'),
        album: tag?.album ?? 'Downloads',
        path: f.path,
        duration: Duration(seconds: tag?.duration ?? 0),
        albumArt: (tag?.pictures.isNotEmpty ?? false)
            ? tag!.pictures.first.bytes
            : null,
      ));
    }
    return out;
  }
}
