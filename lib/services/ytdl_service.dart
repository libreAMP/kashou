import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:collection/collection.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:innertube_dart/innertube_dart.dart' as innertube;

import '../models/youtube_streaming_data.dart';
import 'potoken/po_token_service.dart';
import 'youtube/youtube_service.dart';

/// A playable audio url plus whatever metadata the source reported with it.
class ResolvedAudioStream {
  const ResolvedAudioStream({
    required this.url,
    this.loudnessDb,
    this.title,
  });

  final String url;
  final double? loudnessDb;
  final String? title;
}

class YtdlWrapperService {
  static final YoutubeExplode _client = YoutubeExplode();
  static final Map<String, _CachedResult<List<Map<String, dynamic>>>>
      _searchCache = HashMap();
  static final Map<String, _CachedResult<YouTubeStreamingData>> _streamCache =
      HashMap();

  static const Duration _defaultStreamCacheTtl = Duration(minutes: 10);

  const YtdlWrapperService();

  /// Resolve the audio url to actually play for [watchUrl].
  ///
  /// The returned url is verified to serve bytes before it is handed back, so
  /// callers never pass a dead one to the player. See [isStreamUrlUsable] for
  /// why that has to be checked rather than assumed.
  ///
  /// Only InnerTube reports loudness, so streams resolved through
  /// youtube_explode carry no replay-gain correction.
  static Future<ResolvedAudioStream?> resolveAudioStream(
    String watchUrl, {
    bool forceRefresh = false,
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // every retry has to bypass the cache: it holds the manifest that just
      // came back dead, and re-reading it would hand back the same 403 url
      final stream = await _resolveOnce(watchUrl,
          forceRefresh: forceRefresh || attempt > 1);
      if (stream == null) return null;
      if (await isStreamUrlUsable(stream.url)) return stream;
      debugPrint('[Ytdl] dead stream url on attempt $attempt, re-resolving');
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return null;
  }

  static Future<ResolvedAudioStream?> _resolveOnce(
    String watchUrl, {
    required bool forceRefresh,
  }) async {
    // Desktop has no PoToken (see po_token_service.dart). Where one can be
    // minted, InnerTube stays first: it is the path that mints it.
    if (PoTokenService.supported) {
      final inner = await _resolveInnerTubeAudio(watchUrl,
          forceRefresh: forceRefresh);
      if (inner != null) return inner;
    }
    return _resolveExplodeAudio(watchUrl, forceRefresh: forceRefresh);
  }

  /// Whether [url] will actually serve bytes right now.
  ///
  /// YouTube grants roughly one usable fetch per resolved manifest, so a freshly
  /// minted url sometimes arrives already throttled and then *every* request to
  /// it 403s — regardless of user agent, range or headers, which is why this
  /// is not something the app's own headers can influence. The failure is also
  /// invisible to just_audio: mpv simply fails to open the file, no error
  /// reaches Dart, and the load hangs until the caller's timeout. Two bytes are
  /// enough to tell, and asking costs far less than a hung load.
  static Future<bool> isStreamUrlUsable(
    String url, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      // an m3u8 is a text manifest, not a byte range
      if (!url.contains('.m3u8')) req.headers['Range'] = 'bytes=0-1';
      final res = await client.send(req).timeout(timeout);
      final ok = res.statusCode == 200 || res.statusCode == 206;
      // a 206 that carries no bytes would hang mpv just as badly as a 403, so
      // confirm the body actually starts; the rest is never read
      if (ok) await res.stream.first.timeout(timeout);
      debugPrint('[Ytdl] probe ${res.statusCode} '
          '${ok ? 'usable' : 'REJECTED'} ${_shorten(url)}');
      return ok;
    } catch (e) {
      debugPrint('[Ytdl] probe failed ($e) ${_shorten(url)}');
      return false;
    } finally {
      client.close();
    }
  }

  static String _shorten(String url) =>
      url.length <= 96 ? url : '${url.substring(0, 96)}...';

  static Future<ResolvedAudioStream?> _resolveInnerTubeAudio(
    String watchUrl, {
    required bool forceRefresh,
  }) async {
    final videoId = VideoId.parseVideoId(watchUrl.trim());
    if (videoId == null) return null;

    var info = await YoutubeService.instance
        .fetchStreams(videoId, forceRefresh: forceRefresh);
    if ((info == null || info.audioStreams.isEmpty) && !forceRefresh) {
      // a cold client often needs a second, uncached attempt
      await Future.delayed(const Duration(milliseconds: 800));
      info = await YoutubeService.instance
          .fetchStreams(videoId, forceRefresh: true);
    }
    if (info == null || info.audioStreams.isEmpty) return null;

    final mp4 = info.audioStreams
        .where((s) => s.mimeType.contains('mp4'))
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    final stream = mp4.isNotEmpty ? mp4.first : info.audioStreams.first;

    return ResolvedAudioStream(
      url: stream.url,
      loudnessDb: info.loudnessDb,
      title: info.title,
    );
  }

  static Future<ResolvedAudioStream?> _resolveExplodeAudio(
    String watchUrl, {
    required bool forceRefresh,
  }) async {
    try {
      final data = await const YtdlWrapperService().fetchStreamingData(
        watchUrl,
        useInnerTube: false,
        forceRefresh: forceRefresh,
      );
      final stream = data?.bestStream ?? data?.fallbackStream;
      if (stream == null) return null;
      return ResolvedAudioStream(url: stream.url, title: data?.title);
    } catch (_) {
      return null;
    }
  }

  /// Direct youtube_explode resolve (no InnerTube, no PoToken). Returns the
  /// stream URL or null.
  static Future<String?> fetchFallbackAudioUrl(String videoUrl,
      {bool forceRefresh = false}) async {
    final resolved =
        await _resolveExplodeAudio(videoUrl, forceRefresh: forceRefresh);
    return resolved?.url;
  }

  // filter out stuff too short or too long to really be a song
  static const _minMusicSeconds = 45;
  static const _maxMusicSeconds = 15 * 60;

  // maxres art 404s for plenty of videos, walk down to a size that exists
  Future<Uint8List?> fetchVideoArt(String videoId, {String? preferred}) async {
    final urls = {
      if (preferred != null && preferred.isNotEmpty) preferred,
      // hq has black bars, mq doesnt
      'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
    };
    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
    bool musicOnly = false,
  }) async {
    final key = '${query.trim().toLowerCase()}_${limit}_$musicOnly';
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final searchResults = await _client.search.search(query);
      var videos = searchResults.toList();
      if (musicOnly) {
        videos = videos.where((v) {
          final s = v.duration?.inSeconds;
          return s != null && s >= _minMusicSeconds && s <= _maxMusicSeconds;
        }).toList();
      }
      videos = videos.take(limit).toList();

      debugPrint(
          '[youtube_explode] search "$query" (limit=$limit, music=$musicOnly) -> ${videos.length} results');

      final items = videos.map<Map<String, dynamic>>((video) {
        final duration = video.duration;
        final uploadDate = video.uploadDate;
        return <String, dynamic>{
          'id': video.id.value,
          'title': video.title,
          'url': video.url,
          'channel': video.author,
          'duration': duration?.inSeconds,
          'views': video.engagement.viewCount,
          'upload_date': uploadDate != null
              ? uploadDate.millisecondsSinceEpoch ~/ 1000
              : null,
          'thumbnail': video.thumbnails.highResUrl,
        };
      }).toList(growable: false);

      _searchCache[key] = _CachedResult(items);
      return items;
    } catch (e) {
      debugPrint('youtube_explode search error: $e');
      return [];
    }
  }

  Future<YouTubeStreamingData?> fetchStreamingData(
    String videoUrl, {
    bool forceRefresh = false,
    bool useInnerTube = true,
  }) async {
    final trimmedUrl = videoUrl.trim();
    final parsedVideoId = VideoId.parseVideoId(trimmedUrl);

    if (parsedVideoId == null) {
      debugPrint('Invalid YouTube URL: $videoUrl');
      return null;
    }

    final cacheKey = parsedVideoId;
    final cached = forceRefresh ? null : _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    if (useInnerTube) {
      try {
        final streamInfo = await YoutubeService.instance
            .fetchStreams(parsedVideoId, forceRefresh: forceRefresh);

        if (streamInfo != null && streamInfo.audioStreams.isNotEmpty) {
          final streamingData = _convertInnerTubeToStreamingData(
              streamInfo, trimmedUrl, null);
          _streamCache[cacheKey] =
              _CachedResult(streamingData, ttl: _defaultStreamCacheTtl);
          return streamingData;
        }

        debugPrint('[innertube] No streams found, falling back to youtube_explode');
      } catch (e) {
        debugPrint('[innertube] Error: $e, falling back to youtube_explode');
      }
    }

    // Fallback to youtube_explode_dart
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
      final progressiveStreams =
          manifest.audioOnly.sortByBitrate().reversed.toList(growable: false);

      if (hlsAudioStreams.isEmpty &&
          hlsMuxedStreams.isEmpty &&
          progressiveStreams.isEmpty) {
        debugPrint('No audio streams available for $videoUrl');
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

      _streamCache[cacheKey] =
          _CachedResult(streamingData, ttl: streamingData.cacheTtl);

      return streamingData;
    } catch (e) {
      debugPrint('youtube_explode streaming fetch error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAudioDetails(
    String videoUrl, {
    bool forceRefresh = false,
  }) async {
    final streamingData =
        await fetchStreamingData(videoUrl, forceRefresh: forceRefresh);
    if (streamingData == null) {
      return null;
    }
    return _legacyMapFromStreamingData(streamingData);
  }

  static YouTubeStreamFormat _mapToStreamFormat(StreamInfo stream) {
    final bitrate = stream.bitrate.bitsPerSecond;
    final mimeType = stream.codec.mimeType;
    final codecLabel = stream.codec.toString();
    final container = stream.container.name;
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

    final contentLength =
        stream is AudioOnlyStreamInfo ? stream.size.totalBytes : null;
    final approxLifetime = type == YouTubeStreamType.progressive
        ? null
        : const Duration(minutes: 5);

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

  YouTubeStreamingData _convertInnerTubeToStreamingData(
    dynamic streamInfo,
    String sourceUrl,
    Video? videoMetadata,
  ) {
    final videoId = streamInfo.videoId as String? ?? '';
    final title = streamInfo.title as String? ?? '';
    final audioStreams = streamInfo.audioStreams as List<innertube.AudioStream>;

    final primaryFormats = audioStreams.map((stream) {
      debugPrint(
          '[innertube] Audio stream: ${stream.itag}, ${stream.bitrate}bps, ${stream.mimeType}');
      debugPrint(
          '[innertube] Audio URL: ${stream.url.substring(0, stream.url.length > 100 ? 100 : stream.url.length)}...');
      return YouTubeStreamFormat(
        url: stream.url,
        itag: stream.itag.toString(),
        bitrate: stream.bitrate,
        mimeType: stream.mimeType,
        codecLabel: stream.mimeType.split('/').last,
        container: stream.mimeType.split('/').last,
        type: YouTubeStreamType.progressive,
        audioSampleRate: stream.audioSampleRate,
        approxLifetime: const Duration(hours: 6),
        contentLength: stream.contentLength,
      );
    }).toList();

    final fallbackFormats = <YouTubeStreamFormat>[];

    String? thumbnailUrl;
    if (videoMetadata != null) {
      final videoId = videoMetadata.id.value;
      thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
    }

    return YouTubeStreamingData(
      videoId: videoId,
      sourceUrl: sourceUrl,
      title: videoMetadata?.title ?? title,
      loudnessDb: streamInfo.loudnessDb as double?,
      // empty, not 'Unknown', so callers keep the artist they already know
      channelName: videoMetadata?.author ?? '',
      channelUrl: videoMetadata != null
          ? 'https://www.youtube.com/channel/${videoMetadata.channelId.value}'
          : 'https://youtube.com',
      thumbnailUrl: thumbnailUrl ?? videoMetadata?.thumbnails.highResUrl,
      duration: videoMetadata?.duration,
      viewCount: videoMetadata?.engagement.viewCount,
      uploadDate: videoMetadata?.uploadDate,
      tags: videoMetadata?.keywords.toList(growable: false) ?? [],
      description: videoMetadata?.description,
      primaryStreams: primaryFormats,
      fallbackStreams: fallbackFormats,
      fetchedAt: DateTime.now(),
      cacheTtl: _defaultStreamCacheTtl,
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
