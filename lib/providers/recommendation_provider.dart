import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/ytmusic_service.dart';
import 'audio_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  final YtMusicService _ytm = const YtMusicService();

  // off by default, the fan-out (searches + 10 fetches per play) trips youtube's bot detection
  bool _autoQueueRecommendations = true;

  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _relatedVideos = [];
  bool _isLoading = false;
  String? _lastVideoId;

  List<Map<String, dynamic>> get recommendations => _recommendations;
  List<Map<String, dynamic>> get relatedVideos => _relatedVideos;
  bool get isLoading => _isLoading;
  bool get autoQueueRecommendations => _autoQueueRecommendations;

  void setAutoQueueRecommendations(bool value) {
    _autoQueueRecommendations = value;
    notifyListeners();
  }

  Future<void> loadInitialRecommendations() async {
    if (_recommendations.isNotEmpty) return; // Already loaded

    _isLoading = true;
    notifyListeners();

    try {
      _recommendations = await _ytm.searchSongs('top songs today', limit: 15);
      debugPrint(
          '[Recommendations] Loaded ${_recommendations.length} initial recommendations');
    } catch (e) {
      debugPrint('Error loading initial recommendations: $e');
      _recommendations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRecommendations(Track? currentTrack,
      {AudioProvider? audioProvider}) async {
    if (currentTrack == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final videoId = _extractVideoId(currentTrack);

      if (videoId != null && videoId != _lastVideoId) {
        _lastVideoId = videoId;

        await _fetchRelatedVideos(videoId);

        if (_autoQueueRecommendations && audioProvider != null) {
          await _queueRecommendations(audioProvider);
        }
      } else if (!_isYouTubeTrack(currentTrack)) {
        await _fetchLocalTrackRecommendations(currentTrack);

        if (_autoQueueRecommendations && audioProvider != null) {
          await _queueRecommendations(audioProvider);
        }
      }
    } catch (e) {
      debugPrint('Error updating recommendations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchRelatedVideos(String videoId) async {
    try {
      final radio = await _ytm.getSongRadio(videoId);
      _relatedVideos =
          radio.where((v) => v['id'] != videoId).take(15).toList();
      debugPrint(
          '[Recommendations] Found ${_relatedVideos.length} related tracks');
    } catch (e) {
      debugPrint('Error fetching related tracks: $e');
      _relatedVideos = [];
    }
  }

  Future<void> fetchPersonalizedFromHistory(
      List<Map<String, dynamic>> recentHistory) async {
    if (recentHistory.isEmpty) {
      _recommendations = [];
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final personalized = <Map<String, dynamic>>[];
      final seen = <String>{};

      // random picks from recent history, always seeding the newest two got stale
      final ids = recentHistory
          .map((e) => _historyVideoId(e))
          .whereType<String>()
          .toSet()
          .toList()
        ..shuffle();
      final seeds = ids.take(3);

      for (final seed in seeds) {
        final radio = await _ytm.getSongRadio(seed, limit: 12);
        for (final t in radio) {
          if (seen.add(t['id'] as String? ?? '')) personalized.add(t);
        }
      }

      // no ids to seed from, fall back to the top artists
      if (personalized.isEmpty) {
        final artists = recentHistory
            .map((e) => e['artist'] as String?)
            .where((a) => a != null && a != 'Unknown' && a.isNotEmpty)
            .cast<String>()
            .toSet()
            .take(2);
        for (final artist in artists) {
          for (final t in await _ytm.searchSongs(artist, limit: 8)) {
            if (seen.add(t['id'] as String? ?? '')) personalized.add(t);
          }
        }
      }

      personalized.shuffle();
      _recommendations = personalized.take(15).toList();

      debugPrint(
          '[Recommendations] Generated ${_recommendations.length} personalized from history');
    } catch (e) {
      debugPrint('Error fetching personalized recommendations: $e');
      _recommendations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchLocalTrackRecommendations(Track track) async {
    try {
      final query = track.artist != 'Unknown' && track.artist.isNotEmpty
          ? '${track.artist} ${track.title}'
          : track.title;
      _recommendations = await _ytm.searchSongs(query, limit: 15);

      debugPrint(
          '[Recommendations] Found ${_recommendations.length} recommendations for local track');
    } catch (e) {
      debugPrint('Error fetching local track recommendations: $e');
      _recommendations = [];
    }
  }

  void clearRecommendations() {
    _recommendations = [];
    _relatedVideos = [];
    _lastVideoId = null;
    notifyListeners();
  }

  bool _isYouTubeTrack(Track track) {
    return track.path.contains('youtube.com') ||
        track.path.contains('youtu.be') ||
        track.sourceUrl?.contains('youtube') == true;
  }

  Future<void> _queueRecommendations(AudioProvider audioProvider) async {
    try {
      final tracksToQueue = <Map<String, dynamic>>[
        ..._relatedVideos.take(5),
        ..._recommendations.take(5),
      ];

      if (tracksToQueue.isEmpty) return;

      final tracks = <Track>[];
      for (final video in tracksToQueue) {
        final track = await _convertVideoToTrack(video);
        if (track != null) {
          tracks.add(track);
        }
      }

      if (tracks.isNotEmpty) {
        audioProvider.addTracksToQueue(tracks);
        debugPrint('[Recommendations] Added ${tracks.length} tracks to queue');
      }
    } catch (e) {
      debugPrint('Error queuing recommendations: $e');
    }
  }

  Future<Track?> _convertVideoToTrack(Map<String, dynamic> video) async {
    try {
      final videoId = video['id']?.toString() ?? '';
      if (videoId.isEmpty) return null;

      final videoUrl =
          video['url'] ?? 'https://www.youtube.com/watch?v=$videoId';
      final durationSeconds = _asInt(video['duration']) ?? 0;

      final track = Track(
        id: videoId,
        title: video['title'] as String? ?? 'Unknown',
        artist: video['channel'] as String? ?? 'Unknown',
        album: 'YouTube',
        path: videoUrl,
        duration: Duration(seconds: durationSeconds),
        sourceUrl: videoUrl,
        artistId: video['artistId'] as String?,
        views: video['views'] as String?,
      );

      return track;
    } catch (e) {
      debugPrint('Error converting video to track: $e');
      return null;
    }
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _extractVideoId(Track track) {
    final url = track.sourceUrl ?? track.path;
    if (!url.contains('youtube') && !url.contains('youtu.be')) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // From youtu.be short URLs
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    // From query parameter
    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) {
      return videoId;
    }

    // From embed or shorts URLs
    if (uri.pathSegments.length >= 2) {
      if (uri.pathSegments[0] == 'embed' || uri.pathSegments[0] == 'shorts') {
        return uri.pathSegments[1];
      }
    }

    return null;
  }

  String? _historyVideoId(Map<String, dynamic> entry) {
    final id = entry['id'] as String?;
    if (id != null && id.length == 11) return id;
    final url = entry['sourceUrl'] as String? ?? entry['url'] as String?;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }
}
