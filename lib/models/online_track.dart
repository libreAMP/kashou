import 'dart:typed_data';

import 'track.dart';

class OnlineTrack extends Track {
  OnlineTrack({
    required super.id,
    required super.title,
    required super.artist,
    required super.album,
    required super.duration,
    required this.videoId,
    String? path,
    this.audioUrl,
    this.thumbnails,
    Uint8List? albumArt,
    super.genre,
  }) : super(
          path: path ?? 'youtube://$videoId',
          albumArt: albumArt,
        );

  final String videoId;
  final String? audioUrl;
  final List<dynamic>? thumbnails;

  OnlineTrack copyWith({
    String? audioUrl,
  }) {
    return OnlineTrack(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      videoId: videoId,
      path: path,
      audioUrl: audioUrl ?? this.audioUrl,
      thumbnails: thumbnails,
      albumArt: albumArt,
      genre: genre,
    );
  }
}
