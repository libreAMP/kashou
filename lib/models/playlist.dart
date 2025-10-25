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
}
