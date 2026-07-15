import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import '../services/ytdl_service.dart';
import 'audio_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();
  final YtdlWrapperService _ytdl = const YtdlWrapperService();

  // off by default, the fan-out (searches + 10 fetches per play) trips youtube's bot detection
  bool _autoQueueRecommendations = false;

  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _relatedVideos = [];
  bool _isLoading = false;
  String? _lastVideoId;
  String? _lastArtist;

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
      final trendingResults = await _ytdl.search('popular songs', limit: 15, musicOnly: true);
      _recommendations = trendingResults;
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

        if (currentTrack.artist != _lastArtist) {
          _lastArtist = currentTrack.artist;
          await _fetchArtistRecommendations(currentTrack.artist);
        }

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
      final video = await _yt.videos.get(videoId);

      final List<Map<String, dynamic>> mixedResults = [];

      final artistQuery = '${video.author} music';
      final artistResults = await _ytdl.search(artistQuery, limit: 10, musicOnly: true);
      mixedResults.addAll(artistResults);

      final seen = <String>{};
      _relatedVideos = mixedResults
          .where((v) => v['id'] != videoId && seen.add(v['id'] ?? ''))
          .take(10)
          .toList();

      debugPrint(
          '[Recommendations] Found ${_relatedVideos.length} related videos');
    } catch (e) {
      debugPrint('Error fetching related videos: $e');
      _relatedVideos = [];
    }
  }

  Future<void> _fetchArtistRecommendations(String artist) async {
    if (artist == 'Unknown' || artist.isEmpty) {
      _recommendations = [];
      return;
    }

    try {
      final List<Map<String, dynamic>> mixedResults = [];

      final artistQuery = '$artist official audio';
      final artistResults = await _ytdl.search(artistQuery, limit: 6, musicOnly: true);
      mixedResults.addAll(artistResults);

      final similarQuery = 'artists like $artist';
      final similarResults = await _ytdl.search(similarQuery, limit: 5, musicOnly: true);
      mixedResults.addAll(similarResults);

      final seen = <String>{};
      _recommendations =
          mixedResults.where((v) => seen.add(v['id'] ?? '')).take(15).toList();

      debugPrint(
          '[Recommendations] Found ${_recommendations.length} recommendations');
    } catch (e) {
      debugPrint('Error fetching artist recommendations: $e');
      _recommendations = [];
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
      // Take last 8 songs from history
      final lastEight = recentHistory.take(8).toList();

      final artists = <String>{};

      for (final entry in lastEight) {
        final artist = entry['artist'] as String?;

        if (artist != null && artist != 'Unknown' && artist.isNotEmpty) {
          artists.add(artist);
        }
      }

      final List<Map<String, dynamic>> personalizedResults = [];

      for (final artist in artists.take(3)) {
        try {
          final results = await _ytdl.search('$artist music', limit: 3, musicOnly: true);
          personalizedResults.addAll(results);
        } catch (e) {
          debugPrint('Error searching for $artist: $e');
        }
      }

      if (artists.length >= 2) {
        final mixQuery = '${artists.take(3).join(' ')} music mix';
        try {
          final results = await _ytdl.search(mixQuery, limit: 5, musicOnly: true);
          personalizedResults.addAll(results);
        } catch (e) {
          debugPrint('Error searching mix: $e');
        }
      }

      final seen = <String>{};
      _recommendations = personalizedResults
          .where((v) => seen.add(v['id'] ?? ''))
          .take(15)
          .toList();

      debugPrint(
          '[Recommendations] Generated ${_recommendations.length} personalized from ${lastEight.length} history tracks');
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
      final searchQuery = track.genre != null && track.genre!.isNotEmpty
          ? '${track.artist} ${track.genre} music'
          : '${track.artist} ${track.title}';

      final results = await _ytdl.search(searchQuery, limit: 15, musicOnly: true);
      _recommendations = results;

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
    _lastArtist = null;
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

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
