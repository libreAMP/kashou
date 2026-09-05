import 'dart:convert';
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Map<String, String> _artIds = {};
  static bool _artIdsLoaded = false;

  // m4a picture tags dont survive the tagger so keep the video id
  static Future<void> _ensureArtIds() async {
    if (_artIdsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _artIds = Map<String, String>.from(jsonDecode(prefs.getString('dl_art') ?? '{}'));
    _artIdsLoaded = true;
  }

  static Future<Map<String, String>> loadArtIds() async {
    await _ensureArtIds();
    return _artIds;
  }

  static Future<void> rememberArt(String path, String videoId) async {
    await _ensureArtIds();
    _artIds[path] = videoId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dl_art', jsonEncode(_artIds));
  }

  static Future<List<Track>> tracks() async {
    final d = await dir();
    if (!await d.exists()) return const [];
    final artIds = await loadArtIds();

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
      final hasArt = tag?.pictures.isNotEmpty ?? false;
      final vid = hasArt ? null : artIds[f.path];
      out.add(Track(
        id: f.path,
        title: tag?.title ?? parts.first,
        artist: tag?.trackArtist ??
            (parts.length > 1 ? parts.sublist(1).join(' - ') : 'Unknown'),
        album: tag?.album ?? 'Downloads',
        path: f.path,
        duration: Duration(seconds: tag?.duration ?? 0),
        albumArt: hasArt ? tag!.pictures.first.bytes : null,
        sourceUrl: vid != null ? 'https://www.youtube.com/watch?v=$vid' : null,
      ));
    }
    return out;
  }
}
