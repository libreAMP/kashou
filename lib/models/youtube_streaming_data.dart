import 'package:flutter/foundation.dart';

enum YouTubeStreamType {
  hlsAudio,
  hlsMuxed,
  progressive,
}

@immutable
class YouTubeStreamFormat {
  const YouTubeStreamFormat({
    required this.itag,
    required this.url,
    required this.bitrate,
    required this.mimeType,
    required this.codecLabel,
    required this.container,
    required this.type,
    this.audioSampleRate,
    this.approxLifetime,
    this.contentLength,
  });

  final String itag;
  final String url;
  final int bitrate;
  final String mimeType;
  final String codecLabel;
  final String container;
  final YouTubeStreamType type;
  final int? audioSampleRate;
  final Duration? approxLifetime;
  final int? contentLength;

  bool get isHls => type != YouTubeStreamType.progressive;

  int get bitrateKbps => (bitrate / 1000).round();
}

enum YouTubeStreamQualityTier { high, medium, low }

@immutable
class YouTubeStreamingData {
  const YouTubeStreamingData({
    required this.videoId,
    required this.sourceUrl,
    required this.title,
    required this.channelName,
    required this.channelUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    required this.uploadDate,
    required this.tags,
    required this.description,
    required this.primaryStreams,
    required this.fallbackStreams,
    required this.fetchedAt,
    required this.cacheTtl,
    this.loudnessDb,
  });

  final String videoId;
  final String sourceUrl;
  final String title;
  final String channelName;
  final String channelUrl;
  final double? loudnessDb;
  final String? thumbnailUrl;
  final Duration? duration;
  final int? viewCount;
  final DateTime? uploadDate;
  final List<String> tags;
  final String? description;
  final List<YouTubeStreamFormat> primaryStreams;
  final List<YouTubeStreamFormat> fallbackStreams;
  final DateTime fetchedAt;
  final Duration cacheTtl;

  bool get playable => primaryStreams.isNotEmpty || fallbackStreams.isNotEmpty;

  DateTime get cacheExpiry => fetchedAt.add(cacheTtl);

  bool get isCacheExpired => DateTime.now().isAfter(cacheExpiry);

  List<YouTubeStreamFormat> get _streamsByPreference {
    final combined = <YouTubeStreamFormat>[
      ...primaryStreams,
      ...fallbackStreams,
    ];
    combined.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return combined;
  }

  YouTubeStreamFormat? get bestStream {
    final ordered = _streamsByPreference;
    return ordered.isNotEmpty ? ordered.first : null;
  }

  YouTubeStreamFormat? get fallbackStream {
    return fallbackStreams.isNotEmpty ? fallbackStreams.first : null;
  }

  YouTubeStreamFormat? streamForQuality(YouTubeStreamQualityTier tier) {
    final ordered = _streamsByPreference;
    if (ordered.isEmpty) {
      return null;
    }
    switch (tier) {
      case YouTubeStreamQualityTier.high:
        return ordered.first;
      case YouTubeStreamQualityTier.low:
        return ordered.last;
      case YouTubeStreamQualityTier.medium:
        if (ordered.length <= 2) {
          return ordered.last;
        }
        return ordered[ordered.length ~/ 2];
    }
  }
}
