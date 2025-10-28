import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/online_track.dart';

abstract class OnlineMusicService {
  Future<void> initialize();
  Future<List<OnlineTrack>> searchTracks(String query, {int limit = 20});
  Future<String> getStreamUrl(String videoId);
}

class YTMusicApiService implements OnlineMusicService {
  YTMusicApiService({YTMusic? client}) : _client = client;

  YTMusic? _client;
  late YoutubeExplode _yt;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _client ??= await YTMusic.create();
    _yt = YoutubeExplode();
    _isInitialized = true;
  }

  @override
  Future<List<OnlineTrack>> searchTracks(String query, {int limit = 20}) async {
    await initialize();
    final results = await _client!.search(query, limit: limit);

    return results
        .whereType<Map<String, dynamic>>()
        .map(_mapResult)
        .whereType<OnlineTrack>()
        .toList();
  }

  OnlineTrack? _mapResult(Map<String, dynamic> data) {
    final videoId = data['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;

    final title = _parseText(data['title']) ?? 'Unknown';
    final artist = _parseArtists(data['artists']) ?? 'Unknown Artist';
    final album = _parseAlbum(data['album']) ?? 'YouTube Music';
    final duration = _parseDuration(data['duration'] ?? data['duration_seconds']);

    return OnlineTrack(
      id: 'yt_$videoId',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      videoId: videoId,
      thumbnails: data['thumbnails'] as List<dynamic>?,
    );
  }

  String? _parseText(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      if (value['text'] is String) return value['text'] as String;
      final runs = value['runs'];
      if (runs is List && runs.isNotEmpty) {
        final first = runs.first;
        if (first is Map && first['text'] is String) {
          return first['text'] as String;
        }
      }
    }
    return null;
  }

  String? _parseArtists(dynamic value) {
    if (value is List) {
      final names = value
          .map((artist) {
            if (artist is Map && artist['name'] is String) {
              return artist['name'] as String;
            }
            if (artist is Map && artist['text'] is String) {
              return artist['text'] as String;
            }
            if (artist is String) return artist;
            return null;
          })
          .whereType<String>()
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    if (value is String) return value;
    return null;
  }

  String? _parseAlbum(dynamic value) {
    if (value is Map) return _parseText(value);
    if (value is String) return value;
    return null;
  }

  Duration _parseDuration(dynamic value) {
    if (value is int) {
      return Duration(seconds: value);
    }
    if (value is String && value.isNotEmpty) {
      final parts = value.split(':');
      final numbers = parts.map(int.tryParse).whereType<int>().toList();
      if (numbers.length == parts.length) {
        if (numbers.length == 3) {
          return Duration(
            hours: numbers[0],
            minutes: numbers[1],
            seconds: numbers[2],
          );
        }
        if (numbers.length == 2) {
          return Duration(
            minutes: numbers[0],
            seconds: numbers[1],
          );
        }
        if (numbers.length == 1) {
          return Duration(seconds: numbers[0]);
        }
      }
    }
    return Duration.zero;
  }

  @override
  Future<String> getStreamUrl(String videoId) async {
    await initialize();
    try {
      final streamManifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Could not retrieve stream URL: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}
