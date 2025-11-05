import 'dart:typed_data';

import 'track.dart';

class StreamHistoryEntry {
  const StreamHistoryEntry({
    required this.track,
    required this.timestamp,
    required this.isYouTube,
  });

  final Track track;
  final DateTime timestamp;
  final bool isYouTube;

  Map<String, dynamic> toPersistedMap() {
    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'path': track.path,
      'sourceUrl': track.sourceUrl ?? track.path,
      'duration': track.duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'isYouTube': isYouTube,
      'albumArt': track.albumArt?.toList(),
    };
  }

  static StreamHistoryEntry fromPersistedMap(Map<String, dynamic> map) {
    Uint8List? art;
    final artData = map['albumArt'];
    if (artData is List) {
      art = Uint8List.fromList(artData.cast<int>());
    }

    final track = Track(
      id: (map['id'] as String?) ?? map['path'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown title',
      artist: map['artist'] as String? ?? 'Unknown artist',
      album: map['album'] as String? ?? 'Unknown album',
      path: map['path'] as String? ?? '',
      duration: Duration(milliseconds: map['duration'] as int? ?? 0),
      albumArt: art,
      sourceUrl: map['sourceUrl'] as String?,
    );

    return StreamHistoryEntry(
      track: track,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      isYouTube: map['isYouTube'] as bool? ?? false,
    );
  }
}
