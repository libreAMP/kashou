import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final String? coverImage;

  Playlist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    this.coverImage,
  });

  int get trackCount => tracks.length;

  Duration get totalDuration {
    return tracks.fold(Duration.zero, (total, track) => total + track.duration);
  }

  // art bytes are too big for prefs
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'tracks': [
          for (final t in tracks)
            (t.toMap()..remove('albumArt')),
        ],
      };

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
        tracks: [
          for (final t in (map['tracks'] as List? ?? const []))
            Track.fromMap(Map<String, dynamic>.from(t as Map)),
        ],
      );
}
