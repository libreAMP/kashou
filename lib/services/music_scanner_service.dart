import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
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

class MusicScannerService {
  final List<String> _supportedExtensions = [
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
      // Get common music directories
      final directories = await _getMusicDirectories();
      List<FileSystemEntity> allFiles = [];

      for (var dir in directories) {
        if (await dir.exists()) {
          allFiles.addAll(
            dir.listSync(recursive: true).where((entity) {
              if (entity is File) {
                final ext = entity.path.split('.').last.toLowerCase();
                return _supportedExtensions.contains(ext);
              }
              return false;
            }),
          );
        }
      }

      final total = allFiles.length;
      int current = 0;

      for (var file in allFiles) {
        try {
          final track = await _parseTrack(file as File);
          if (track != null) {
            _tracks.add(track);
          }
        } catch (e) {
          debugPrint('Error parsing file ${file.path}: $e');
        }

        current++;
        yield ScanProgress(current, total, current / total);
      }
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

  Future<Track?> _parseTrack(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final titleWithExt = fileName.split('.').first;
      
      Tag? tag;
      try {
        tag = await AudioTags.read(file.path);
      } catch (e) {
        debugPrint('Error reading tags for ${file.path}: $e');
      }

      Uint8List? albumArtBytes;
      if (tag?.pictures != null && tag!.pictures.isNotEmpty) {
        albumArtBytes = _compressAlbumArt(tag.pictures.first.bytes);
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

      return Track(
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
    } catch (e) {
      debugPrint('Error parsing track: $e');
      return null;
    }
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

  Uint8List? _compressAlbumArt(Uint8List bytes) {
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
