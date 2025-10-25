import 'dart:typed_data';
import 'track.dart';

class Album {
  final String id;
  final String name;
  final String artist;
  final List<Track> tracks;
  final Uint8List? albumArt;
  final int? year;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.tracks,
    this.albumArt,
    this.year,
  });

  int get trackCount => tracks.length;

  Duration get totalDuration {
    return tracks.fold(Duration.zero, (total, track) => total + track.duration);
  }
}
