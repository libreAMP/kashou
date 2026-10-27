import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/album.dart';
import '../providers/audio_provider.dart';
import '../screens/album_detail_screen.dart';
import 'm3e_cover_card.dart';
import 'square_art.dart';

class AlbumCard extends StatelessWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen.album(album: album),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select<AudioProvider, ({bool current, bool playing})>(
      (audio) {
        final current = audio.currentTrack;
        final isCurrent = current != null &&
            album.tracks.any((track) => track.id == current.id);
        return (current: isCurrent, playing: isCurrent && audio.isPlaying);
      },
    );

    return M3ECoverCard(
      art: SquareArt(
        bytes: album.albumArt,
        radius: 0,
        fallbackIcon: Icons.album_rounded,
      ),
      title: album.name,
      subtitle: '${album.artist} · ${album.trackCount} songs',
      playing: state.playing,
      onTap: () => _open(context),
      onPlay: album.tracks.isEmpty
          ? null
          : () {
              final audio = Provider.of<AudioProvider>(context, listen: false);
              if (state.current) {
                audio.togglePlayPause();
              } else {
                audio.playTrack(album.tracks.first, playlist: album.tracks);
              }
            },
    );
  }
}
