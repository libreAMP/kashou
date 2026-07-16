import 'package:flutter/material.dart';

import '../models/track.dart';
import '../widgets/track_list_item.dart';

// see all target for the local sections
class TrackListPage extends StatelessWidget {
  final String title;
  final List<Track> tracks;

  const TrackListPage({super.key, required this.title, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: tracks.isEmpty
          ? Center(
              child: Text('Nothing here yet',
                  style: Theme.of(context).textTheme.bodyMedium))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
              itemCount: tracks.length,
              itemBuilder: (_, i) => TrackListItem(track: tracks[i]),
            ),
    );
  }
}
