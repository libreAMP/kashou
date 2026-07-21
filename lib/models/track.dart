import 'dart:typed_data';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final Uint8List? albumArt;
  final int? trackNumber;
  final int? year;
  final String? genre;
  final int? bitrate;
  final int? sampleRate;
  final String? codec;
  final String? sourceUrl;
  final String? artistId;
  final double? loudnessDb;
  final String? views;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    this.albumArt,
    this.trackNumber,
    this.year,
    this.genre,
    this.bitrate,
    this.sampleRate,
    this.codec,
    this.sourceUrl,
    this.artistId,
    this.loudnessDb,
    this.views,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    Duration? duration,
    Uint8List? albumArt,
    int? trackNumber,
    int? year,
    String? genre,
    int? bitrate,
    int? sampleRate,
    String? codec,
    String? sourceUrl,
    String? artistId,
    double? loudnessDb,
    String? views,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      albumArt: albumArt ?? this.albumArt,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      codec: codec ?? this.codec,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      artistId: artistId ?? this.artistId,
      loudnessDb: loudnessDb ?? this.loudnessDb,
      views: views ?? this.views,
    );
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      path: map['path'] as String,
      duration: Duration(milliseconds: map['duration'] as int),
      albumArt: map['albumArt'] != null ? Uint8List.fromList((map['albumArt'] as List).cast<int>()) : null,
      trackNumber: map['trackNumber'] as int?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
      bitrate: map['bitrate'] as int?,
      sampleRate: map['sampleRate'] as int?,
      codec: map['codec'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      artistId: map['artistId'] as String?,
      loudnessDb: (map['loudnessDb'] as num?)?.toDouble(),
      views: map['views'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'path': path,
      'duration': duration.inMilliseconds,
      'albumArt': albumArt?.toList(),
      'trackNumber': trackNumber,
      'year': year,
      'genre': genre,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'codec': codec,
      'sourceUrl': sourceUrl,
      'artistId': artistId,
      'loudnessDb': loudnessDb,
      'views': views,
    };
  }
}
