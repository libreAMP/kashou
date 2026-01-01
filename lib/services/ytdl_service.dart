import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/youtube_streaming_data.dart';

class YtdlWrapperService {
  static final YoutubeExplode _client = YoutubeExplode();
  static final Map<String, _CachedResult<List<Map<String, dynamic>>>> _searchCache = HashMap();
  static final Map<String, _CachedResult<YouTubeStreamingData>> _streamCache = HashMap();

  static const Duration _defaultStreamCacheTtl = Duration(minutes: 10);

  const YtdlWrapperService();

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
  }) async {
    final key = '${query.trim().toLowerCase()}_$limit';
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final searchResults = await _client.search.search(query);
      final videos = searchResults.take(limit).toList();

      print('[youtube_explode] search "$query" (limit=$limit) -> ${videos.length} results');

      final items = videos.map<Map<String, dynamic>>((video) {
        final duration = video.duration;
        final uploadDate = video.uploadDate;
        print('[youtube_explode] • ${video.title} (${video.id.value}) by ${video.author}');
        return <String, dynamic>{
          'id': video.id.value,
          'title': video.title,
          'url': video.url,
          'channel': video.author,
          'duration': duration?.inSeconds,
          'views': video.engagement.viewCount,
          'upload_date': uploadDate != null ? uploadDate.millisecondsSinceEpoch ~/ 1000 : null,
          'thumbnail': video.thumbnails.highResUrl,
        };
      }).toList(growable: false);

      _searchCache[key] = _CachedResult(items);
      return items;
    } catch (e) {
      print('youtube_explode search error: $e');
      return [];
    }
  }

  Future<YouTubeStreamingData?> fetchStreamingData(
    String videoUrl, {
    bool forceRefresh = false,
  }) async {
    final trimmedUrl = videoUrl.trim();
    final parsedVideoId = VideoId.parseVideoId(trimmedUrl);

    if (parsedVideoId == null) {
      print('Invalid YouTube URL: $videoUrl');
      return null;
    }

    final cacheKey = parsedVideoId;
    final cached = forceRefresh ? null : _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final videoId = VideoId(parsedVideoId);
      final video = await _client.videos.get(videoId);
      final manifest = await _client.videos.streamsClient.getManifest(
        video.id,
        ytClients: [
          YoutubeApiClient.safari,
          YoutubeApiClient.android,
        ],
      );

      final hlsAudioStreams = manifest.hls
          .whereType<HlsAudioStreamInfo>()
          .sorted((a, b) => b.bitrate.compareTo(a.bitrate))
          .toList(growable: false);
      final hlsMuxedStreams = manifest.hls
          .whereType<HlsMuxedStreamInfo>()
          .sorted((a, b) => b.bitrate.compareTo(a.bitrate))
          .toList(growable: false);
      final progressiveStreams = manifest.audioOnly
          .sortByBitrate()
          .reversed
          .toList(growable: false);

      if (hlsAudioStreams.isEmpty && hlsMuxedStreams.isEmpty && progressiveStreams.isEmpty) {
        print('No audio streams available for $videoUrl');
        return null;
      }

      final primaryFormats = <YouTubeStreamFormat>[
        ...hlsAudioStreams.map(_mapToStreamFormat),
        ...hlsMuxedStreams.map(_mapToStreamFormat),
      ];
      final fallbackFormats = <YouTubeStreamFormat>[
        ...progressiveStreams.map(_mapToStreamFormat),
      ];

      final streamingData = YouTubeStreamingData(
        videoId: video.id.value,
        sourceUrl: trimmedUrl,
        title: video.title,
        channelName: video.author,
        channelUrl: 'https://www.youtube.com/channel/${video.channelId.value}',
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration,
        viewCount: video.engagement.viewCount,
        uploadDate: video.uploadDate,
        tags: video.keywords.toList(growable: false),
        description: video.description,
        primaryStreams: primaryFormats,
        fallbackStreams: fallbackFormats,
        fetchedAt: DateTime.now(),
        cacheTtl: _defaultStreamCacheTtl,
      );

      _streamCache[cacheKey] = _CachedResult(streamingData, ttl: streamingData.cacheTtl);

      return streamingData;
    } catch (e) {
      print('youtube_explode streaming fetch error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAudioDetails(
    String videoUrl, {
    bool forceRefresh = false,
  }) async {
    final streamingData = await fetchStreamingData(videoUrl, forceRefresh: forceRefresh);
    if (streamingData == null) {
      return null;
    }
    return _legacyMapFromStreamingData(streamingData);
  }

  static YouTubeStreamFormat _mapToStreamFormat(StreamInfo stream) {
    final bitrate = stream.bitrate.bitsPerSecond;
    final mimeType = stream.codec.mimeType;
    final codecLabel = stream.codec.toString();
    final container = stream.container?.name ?? stream.codec.mimeType;
    final itag = stream.tag.toString();
    final url = stream.url.toString();

    YouTubeStreamType type;
    if (stream is HlsAudioStreamInfo) {
      type = YouTubeStreamType.hlsAudio;
    } else if (stream is HlsMuxedStreamInfo) {
      type = YouTubeStreamType.hlsMuxed;
    } else {
      type = YouTubeStreamType.progressive;
    }

    final contentLength = stream is AudioOnlyStreamInfo ? stream.size.totalBytes : null;
    final approxLifetime = type == YouTubeStreamType.progressive ? null : const Duration(minutes: 5);

    return YouTubeStreamFormat(
      itag: itag,
      url: url,
      bitrate: bitrate,
      mimeType: mimeType,
      codecLabel: codecLabel,
      container: container,
      type: type,
      audioSampleRate: null,
      approxLifetime: approxLifetime,
      contentLength: contentLength,
    );
  }

  Map<String, dynamic> _legacyMapFromStreamingData(YouTubeStreamingData data) {
    final bestStream = data.bestStream ?? data.fallbackStream;
    if (bestStream == null) {
      return {};
    }

    final fallbackStream = data.fallbackStream;

    return <String, dynamic>{
      'id': data.videoId,
      'title': data.title,
      'channel': data.channelName,
      'channel_url': data.channelUrl,
      'thumbnail': data.thumbnailUrl,
      'duration': data.duration?.inSeconds,
      'views': data.viewCount,
      'upload_date': data.uploadDate?.millisecondsSinceEpoch != null
          ? data.uploadDate!.millisecondsSinceEpoch ~/ 1000
          : null,
      'tags': data.tags,
      'description': data.description,
      'audio': {
        'download_url': bestStream.url,
        'ext': bestStream.isHls ? 'm3u8' : bestStream.container,
        'abr': bestStream.bitrateKbps.toDouble(),
        'asr': bestStream.audioSampleRate,
        'filesize': bestStream.contentLength,
        'codec': bestStream.codecLabel,
        'format_id': bestStream.itag,
        'protocol': bestStream.isHls ? 'm3u8' : 'https',
        'mime_type': bestStream.mimeType,
        if (fallbackStream != null) ...{
          'fallback_download_url': fallbackStream.url,
          'fallback_codec': fallbackStream.codecLabel,
        },
      },
      'source_url': data.sourceUrl,
    };
  }

  static Future<void> dispose() async {
    _client.close();
    return Future.value();
  }
}

class _CachedResult<T> {
  _CachedResult(
    this.value, {
    Duration? ttl,
  })  : timestamp = DateTime.now(),
        ttl = ttl ?? const Duration(minutes: 5);

  final T value;
  final DateTime timestamp;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}
