import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kashou/models/track.dart';
import 'package:kashou/services/download_manager.dart';
import 'package:kashou/services/download_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DownloadStore safely handles empty, malformed, or mixed art ids', () async {
    SharedPreferences.setMockInitialValues({
      'dl_art': jsonEncode({'/path/to/song.m4a': 'vid123', 'invalid_val': 123}),
    });

    final artMap = await DownloadStore.loadArtIds();
    expect(artMap['/path/to/song.m4a'], 'vid123');
    expect(artMap['invalid_val'], '123');

    await DownloadStore.rememberArt('/path/to/another.m4a', 'vid456');
    final updated = await DownloadStore.loadArtIds();
    expect(updated['/path/to/another.m4a'], 'vid456');
  });

  test('DownloadJob serializes and deserializes cleanly', () {
    final track = Track(
      id: 'song1',
      title: 'prince of egypt',
      artist: 'MOFE',
      album: 'Single',
      path: '/path/song.m4a',
      duration: const Duration(seconds: 180),
      sourceUrl: 'https://youtube.com/watch?v=vid123',
    );
    final job = DownloadJob(track: track, progress: 1.0, status: 'done');
    final json = job.toJson();
    final restored = DownloadJob.fromJson(json);

    expect(restored.track.title, 'prince of egypt');
    expect(restored.track.artist, 'MOFE');
    expect(restored.status, 'done');
    expect(restored.progress, 1.0);
  });
}
