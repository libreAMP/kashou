import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:innertube_dart/innertube_dart.dart';
import 'package:kashou/models/youtube_stream_models.dart';
import 'package:kashou/services/potoken/po_token_service.dart';

class YoutubeService {
  static final YoutubeService instance = YoutubeService._();
  YoutubeService._();

  final InnerTube _innerTube = InnerTube();

  final Map<String, CachedStreamData> _streamCache = {};

  static const int _maxCacheSize = 100;

  static const Duration _streamExpiration = Duration(hours: 6);

  Future<void> initialize() async {}

  Future<YoutubeStreamInfo?> fetchStreams(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _getCachedStreams(videoId);
      if (cached != null) {
        debugPrint('[YoutubeService] Using cached streams for: $videoId');
        return cached;
      }
    }
    return await _fetchFresh(videoId);
  }

  Future<YoutubeStreamInfo?> _fetchFresh(String videoId) async {
    try {
      final session = await PoTokenService.instance
          .getSession(videoId: videoId);
      final streamInfo = await _innerTube.player(
        videoId,
        visitorData: session?.visitorData,
        poToken: session?.poToken,
        gvsPoToken: session?.gvsPoToken,
      );

      final result = YoutubeStreamInfo(
        videoId: videoId,
        title: streamInfo.title ?? 'Unknown',
        duration: 0,
        audioStreams: streamInfo.audioStreams,
        videoStreams: streamInfo.videoStreams,
        hasMultipleLanguages: streamInfo.hasMultipleLanguages,
        availableLanguages: streamInfo.availableLanguages,
        thumbnailUrl: null,
        author: null,
        viewCount: null,
        loudnessDb: streamInfo.loudnessDb,
      );

    _cacheStreams(videoId, result);

    return result;
    } catch (e) {
      debugPrint('[YoutubeService] Error fetching streams for $videoId: $e');
      return null;
    }
  }

  YoutubeStreamInfo? _getCachedStreams(String videoId) {
    final cached = _streamCache[videoId];
    if (cached == null) return null;

    if (cached.isExpired) {
      _streamCache.remove(videoId);
      return null;
    }

    return cached.streamInfo;
  }

  void _cacheStreams(String videoId, YoutubeStreamInfo streamInfo) {
    if (_streamCache.length >= _maxCacheSize) {
      final oldestKey = _streamCache.entries
          .reduce(
              (a, b) => a.value.fetchTime.isBefore(b.value.fetchTime) ? a : b)
          .key;
      _streamCache.remove(oldestKey);
    }

    _streamCache[videoId] = CachedStreamData(
      streamInfo: streamInfo,
      fetchTime: DateTime.now(),
      expirationTime: DateTime.now().add(_streamExpiration),
    );
  }

  void clearCache() {
    _streamCache.clear();
    debugPrint('[YoutubeService] Cleared all cache');
  }
}
