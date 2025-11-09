import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YtdlWrapperService {
  static final YoutubeExplode _client = YoutubeExplode();
  static final Map<String, _CachedResult<List<Map<String, dynamic>>>> _searchCache = HashMap();
  static final Map<String, _CachedResult<Map<String, dynamic>>> _detailsCache = HashMap();

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

  Future<Map<String, dynamic>?> fetchAudioDetails(String videoUrl) async {
    final key = videoUrl.trim();

    try {
      final videoId = VideoId.parseVideoId(videoUrl);
      if (videoId == null) {
        print('Invalid YouTube URL: $videoUrl');
        return null;
      }

      final video = await _client.videos.get(VideoId(videoId));
      final manifest = await _client.videos.streamsClient.getManifest(
        video.id,
        ytClients: [
          YoutubeApiClient.safari,
          YoutubeApiClient.android,
        ],
      );
      print('[youtube_explode] manifest fetched for ${video.url} -> audioOnly=${manifest.audioOnly.length} hls=${manifest.hls.length}');

      final hlsAudioStream = manifest.hls
          .whereType<HlsAudioStreamInfo>()
          .sorted((a, b) => a.bitrate.compareTo(b.bitrate))
          .lastOrNull;
      final hlsMuxedStream = manifest.hls
          .whereType<HlsMuxedStreamInfo>()
          .sorted((a, b) => a.bitrate.compareTo(b.bitrate))
          .lastOrNull;
      final progressiveAudioStream = manifest.audioOnly.sortByBitrate().reversed.firstOrNull;

      final selectedStream = hlsAudioStream ?? hlsMuxedStream ?? progressiveAudioStream;
      if (selectedStream == null) {
        print('No audio stream found for $videoUrl');
        return null;
      }

      final isHls = selectedStream is HlsAudioStreamInfo || selectedStream is HlsMuxedStreamInfo;
      final downloadUrl = selectedStream.url.toString();
      final selectedAudioCodec = selectedStream is AudioStreamInfo ? selectedStream.audioCodec : '';

      if (selectedStream is HlsAudioStreamInfo) {
        print('[youtube_explode] selected HLS audio stream tag=${selectedStream.tag} bitrate=${selectedStream.bitrate.kiloBitsPerSecond.toStringAsFixed(2)}kbps codec=${selectedStream.codec.mimeType}');
      } else if (selectedStream is HlsMuxedStreamInfo) {
        print('[youtube_explode] selected HLS muxed stream tag=${selectedStream.tag} bitrate=${selectedStream.bitrate.kiloBitsPerSecond.toStringAsFixed(2)}kbps codec=${selectedStream.codec.mimeType}');
      } else {
        print('[youtube_explode] selected progressive audio stream tag=${selectedStream.tag} bitrate=${selectedStream.bitrate.kiloBitsPerSecond.toStringAsFixed(2)}kbps codec=${selectedStream.codec.mimeType}');
      }
      print('[youtube_explode] download URL: $downloadUrl');

      final fallbackUrl = !isHls ? null : progressiveAudioStream?.url.toString();
      final fallbackAudioCodec = progressiveAudioStream?.audioCodec;
      if (fallbackUrl != null) {
        print('[youtube_explode] progressive fallback URL: $fallbackUrl');
      }

      final result = <String, dynamic>{
        'id': video.id.value,
        'title': video.title,
        'channel': video.author,
        'channel_url': 'https://www.youtube.com/channel/${video.channelId.value}',
        'thumbnail': video.thumbnails.highResUrl,
        'duration': video.duration?.inSeconds,
        'views': video.engagement.viewCount,
        'upload_date': video.uploadDate?.millisecondsSinceEpoch != null
            ? video.uploadDate!.millisecondsSinceEpoch ~/ 1000
            : null,
        'tags': video.keywords.toList(growable: false),
        'categories': video.keywords.isEmpty ? null : video.keywords.toList(growable: false),
        'description': video.description,
        'audio': {
          'download_url': downloadUrl,
          'ext': isHls ? 'm3u8' : selectedStream.container.toString(),
          'abr': selectedStream.bitrate.kiloBitsPerSecond,
          'asr': selectedAudioCodec.toLowerCase().contains('opus') ? 48000 : null,
          'filesize': selectedStream.size.totalBytes,
          'codec': selectedStream.codec.toString(),
          'format_id': selectedStream.tag,
          'protocol': isHls ? 'm3u8' : 'https',
          'mime_type': selectedStream.codec.mimeType,
          if (fallbackUrl != null) ...{
            'fallback_download_url': fallbackUrl,
            if (fallbackAudioCodec != null) 'fallback_codec': fallbackAudioCodec,
          },
        },
        'source_url': videoUrl,
      };

      return result;
    } catch (e) {
      print('youtube_explode fetch error: $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    _client.close();
    return Future.value();
  }
}

class _CachedResult<T> {
  _CachedResult(this.value) : timestamp = DateTime.now();

  final T value;
  final DateTime timestamp;

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 5;
}
