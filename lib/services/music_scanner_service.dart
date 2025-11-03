import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:audiotags/audiotags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../models/track.dart';
import '../models/album.dart';
import '../models/artist.dart';

class ScanProgress {
  final int current;
  final int total;
  final double progress;

  ScanProgress(this.current, this.total, this.progress);
}

class _ScanMusicParams {
  const _ScanMusicParams({
    required this.sendPort,
    required this.directoryPaths,
    required this.supportedExtensions,
  });

  final SendPort sendPort;
  final List<String> directoryPaths;
  final List<String> supportedExtensions;
}

Future<void> _scanMusicEntryPoint(_ScanMusicParams params) async {
  final sendPort = params.sendPort;
  try {
    final supportedExtensions = params.supportedExtensions.toSet();
    final List<String> filePaths = [];

    for (final path in params.directoryPaths) {
      final directory = Directory(path);
      if (!await directory.exists()) continue;

      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (supportedExtensions.contains(ext)) {
            filePaths.add(entity.path);
          }
        }
      }
    }

    final total = filePaths.length;
    int current = 0;
    final List<Map<String, dynamic>> trackMaps = [];

    for (final path in filePaths) {
      final trackMap = await _parseTrackToMap(path);
      current++;
      sendPort.send({
        'type': 'progress',
        'current': current,
        'total': total,
        'progress': total == 0 ? 1.0 : current / total,
      });

      if (trackMap != null) {
        trackMaps.add(trackMap);
      }
    }

    sendPort.send({'type': 'complete', 'tracks': trackMaps});
  } catch (e) {
    sendPort.send({'type': 'error', 'message': e.toString()});
  }
}

Future<Map<String, dynamic>?> _parseTrackToMap(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;

    final fileName = file.path.split('/').last;
    final titleWithExt = fileName.split('.').first;

    Tag? tag;
    try {
      tag = await AudioTags.read(file.path);
    } catch (_) {}

    Uint8List? albumArtBytes;
    if (tag?.pictures != null && tag!.pictures.isNotEmpty) {
      albumArtBytes = MusicScannerService._compressAlbumArt(tag.pictures.first.bytes);
    }

    String? codec;
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        codec = 'MP3';
        break;
      case 'flac':
        codec = 'FLAC';
        break;
      case 'wav':
        codec = 'WAV';
        break;
      case 'ogg':
        codec = 'OGG Vorbis';
        break;
      case 'opus':
        codec = 'Opus';
        break;
      case 'm4a':
      case 'aac':
        codec = 'AAC';
        break;
      case 'wma':
        codec = 'WMA';
        break;
      case 'ape':
        codec = 'APE';
        break;
      case 'wv':
        codec = 'WavPack';
        break;
      case 'alac':
        codec = 'ALAC';
        break;
      default:
        codec = ext.toUpperCase();
    }

    final track = Track(
      id: file.path.hashCode.toString(),
      title: tag?.title?.isNotEmpty == true ? tag!.title! : titleWithExt,
      artist: tag?.trackArtist?.isNotEmpty == true ? tag!.trackArtist! : 'Unknown Artist',
      album: tag?.album?.isNotEmpty == true ? tag!.album! : 'Unknown Album',
      path: file.path,
      duration: tag?.duration != null ? Duration(seconds: tag!.duration!) : Duration.zero,
      albumArt: albumArtBytes,
      year: tag?.year,
      trackNumber: tag?.trackNumber,
      genre: tag?.genre,
      bitrate: null,
      sampleRate: null,
      codec: codec,
    );

    return track.toMap();
  } catch (e) {
    debugPrint('Error parsing track: $e');
    return null;
  }
}

class MusicScannerService {
  static const List<String> supportedExtensions = [
    'mp3',
    'flac',
    'wav',
    'ogg',
    'opus',
    'm4a',
    'aac',
    'wma',
    'ape',
    'wv',
    'tta',
    'mpc',
    'aiff',
    'alac',
  ];

  List<Track> _tracks = [];

  Stream<ScanProgress> scanMusic() async* {
    _tracks.clear();

    try {
      final directories = await _getMusicDirectories();
      final directoryPaths = directories.map((dir) => dir.path).toList();

      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn<_ScanMusicParams>(
        _scanMusicEntryPoint,
        _ScanMusicParams(
          sendPort: receivePort.sendPort,
          directoryPaths: directoryPaths,
          supportedExtensions: supportedExtensions,
        ),
      );

      await for (final message in receivePort) {
        if (message is Map) {
          final type = message['type'];
          if (type == 'progress') {
            final current = message['current'] as int? ?? 0;
            final total = message['total'] as int? ?? 0;
            final progress = (message['progress'] as num?)?.toDouble() ??
                (total == 0 ? 1.0 : current / total);
            yield ScanProgress(current, total, progress);
          } else if (type == 'complete') {
            final tracks = (message['tracks'] as List)
                .cast<Map<String, dynamic>>()
                .map(Track.fromMap)
                .toList();
            _tracks = tracks;
            receivePort.close();
          } else if (type == 'error') {
            receivePort.close();
            throw Exception(message['message']);
          }
        }
      }

      isolate.kill(priority: Isolate.immediate);
    } catch (e) {
      debugPrint('Error scanning music: $e');
    }
  }

  Future<List<Directory>> _getMusicDirectories() async {
    Set<String> uniquePaths = {};

    try {
      // Load custom directories from preferences
      final prefs = await SharedPreferences.getInstance();
      final customPaths = prefs.getStringList('custom_music_paths') ?? [];
      
      for (var path in customPaths) {
        uniquePaths.add(path);
      }

      // Common music directories
      uniquePaths.add('/storage/emulated/0/Music');
      uniquePaths.add('/storage/emulated/0/Download');
      uniquePaths.add('/storage/emulated/0/Podcasts');
      uniquePaths.add('/storage/emulated/0/Audiobooks');
    } catch (e) {
      debugPrint('Error getting music directories: $e');
    }

    return uniquePaths.map((path) => Directory(path)).toList();
  }

  Future<List<Track>> getAllTracks() async {
    return _tracks;
  }

  Future<List<Album>> getAlbums() async {
    Map<String, List<Track>> albumMap = {};

    for (var track in _tracks) {
      final key = '${track.album}_${track.artist}';
      if (!albumMap.containsKey(key)) {
        albumMap[key] = [];
      }
      albumMap[key]!.add(track);
    }

    return albumMap.entries.map((entry) {
      final tracks = entry.value;
      return Album(
        id: entry.key,
        name: tracks.first.album,
        artist: tracks.first.artist,
        tracks: tracks,
        albumArt: tracks.first.albumArt,
        year: tracks.first.year,
      );
    }).toList();
  }

  Future<List<Artist>> getArtists() async {
    Map<String, List<Track>> artistMap = {};

    for (var track in _tracks) {
      if (!artistMap.containsKey(track.artist)) {
        artistMap[track.artist] = [];
      }
      artistMap[track.artist]!.add(track);
    }

    List<Artist> artists = [];
    for (var entry in artistMap.entries) {
      final tracks = entry.value;
      final albums = await _getAlbumsForArtist(entry.key);

      artists.add(
        Artist(id: entry.key, name: entry.key, albums: albums, tracks: tracks),
      );
    }

    return artists;
  }

  Future<List<Album>> _getAlbumsForArtist(String artistName) async {
    final artistTracks = _tracks.where((t) => t.artist == artistName).toList();
    Map<String, List<Track>> albumMap = {};

    for (var track in artistTracks) {
      if (!albumMap.containsKey(track.album)) {
        albumMap[track.album] = [];
      }
      albumMap[track.album]!.add(track);
    }

    return albumMap.entries.map((entry) {
      return Album(
        id: entry.key,
        name: entry.key,
        artist: artistName,
        tracks: entry.value,
        albumArt: entry.value.first.albumArt,
      );
    }).toList();
  }

  static Uint8List? _compressAlbumArt(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      if (bytes.length < 100000) {
        return bytes;
      }

      final resized = img.copyResize(image, width: 500);
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      
      return compressed;
    } catch (e) {
      debugPrint('Error compressing album art: $e');
      return bytes;
    }
  }
}
