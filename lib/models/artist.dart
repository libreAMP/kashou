import 'track.dart';
import 'album.dart';

class Artist {
  final String id;
  final String name;
  final List<Album> albums;
  final List<Track> tracks;
  final String? artistImage;

  Artist({
    required this.id,
    required this.name,
    required this.albums,
    required this.tracks,
    this.artistImage,
  });

  int get albumCount => albums.length;
  int get trackCount => tracks.length;
}
