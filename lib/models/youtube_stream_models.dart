import 'package:innertube_dart/innertube_dart.dart';

class YoutubeStreamInfo {
  final String videoId;
  final String title;
  final int duration;
  final List<AudioStream> audioStreams;
  final List<VideoStream> videoStreams;
  final bool hasMultipleLanguages;
  final List<String> availableLanguages;
  final String? thumbnailUrl;
  final String? author;
  final int? viewCount;
  final double? loudnessDb;

  YoutubeStreamInfo({
    required this.videoId,
    required this.title,
    required this.duration,
    required this.audioStreams,
    required this.videoStreams,
    required this.hasMultipleLanguages,
    required this.availableLanguages,
    this.thumbnailUrl,
    this.author,
    this.viewCount,
    this.loudnessDb,
  });

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

class CachedStreamData {
  final YoutubeStreamInfo streamInfo;
  final DateTime fetchTime;
  final DateTime expirationTime;

  CachedStreamData({
    required this.streamInfo,
    required this.fetchTime,
    required this.expirationTime,
  });

  bool get isExpired => DateTime.now().isAfter(expirationTime);

  Duration get timeUntilExpiration {
    final diff = expirationTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
