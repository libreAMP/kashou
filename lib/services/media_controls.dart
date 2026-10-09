import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import 'mpris_service.dart';

// mirrors playback into the desktop shells so their media keys reach back
class MediaControls {
  static final MediaControls instance = MediaControls._();
  MediaControls._();

  AudioProvider? _audio;
  MprisObject? _mpris;
  FlutterMediaSession? _session;
  String? _trackKey;
  String? _stateKey;

  void attach(AudioProvider audio) {
    if (!Platform.isLinux && !Platform.isWindows) return;
    if (_audio != null) return;
    _audio = audio;
    audio.addListener(_sync);
    if (Platform.isLinux) _startMpris(audio);
    if (Platform.isWindows) _startWindows(audio);
    _sync();
  }

  void _sync() {
    final audio = _audio;
    if (audio == null) return;
    _mpris?.push();
    if (Platform.isWindows) _pushWindows(audio);
  }

  Future<void> _startMpris(AudioProvider audio) async {
    final object = await startMpris(audio, _artUri);
    if (object == null) return;
    _mpris = object;
    await object.push();
  }

  Future<void> _startWindows(AudioProvider audio) async {
    try {
      final session = FlutterMediaSession();
      // unpackaged builds need a shortcut before smtc knows the app name
      await session.setWindowsAppUserModelId(
          'com.libreamp.kashou', displayName: 'Kashou');
      await session.activate();
      session.setActionHandler(
        onPlay: () {
          if (!audio.isPlaying) audio.togglePlayPause();
        },
        onPause: () {
          if (audio.isPlaying) audio.togglePlayPause();
        },
        onSkipToNext: audio.skipNext,
        onSkipToPrevious: audio.skipPrevious,
        onStop: audio.stop,
        onSeekTo: audio.seek,
      );
      _session = session;
      _pushWindows(audio);
    } catch (e) {
      debugPrint('media session failed: $e');
    }
  }

  void _pushWindows(AudioProvider audio) {
    if (_session == null) return;
    final track = audio.currentTrack;
    if (track?.id != _trackKey) {
      _trackKey = track?.id;
      _updateMetadata(track);
    }
    final status = track == null
        ? PlaybackStatus.idle
        : audio.isPlaying
            ? PlaybackStatus.playing
            : PlaybackStatus.paused;
    final key = '$status|${audio.position.inSeconds}';
    if (key == _stateKey) return;
    _stateKey = key;
    FlutterMediaSessionPlatform.instance.updatePlaybackState(PlaybackState(
      status: status,
      position: audio.position,
      repeatMode: switch (audio.repeatMode) {
        RepeatMode.off => MediaRepeatMode.none,
        RepeatMode.all => MediaRepeatMode.all,
        RepeatMode.one => MediaRepeatMode.one,
      },
      shuffleModeEnabled: audio.shuffleMode != ShuffleMode.off,
    ));
  }

  Future<void> _updateMetadata(Track? track) async {
    if (track == null) {
      await FlutterMediaSessionPlatform.instance
          .updateMetadata(const MediaMetadata());
      return;
    }
    final art = await _artUri(track);
    await FlutterMediaSessionPlatform.instance.updateMetadata(MediaMetadata(
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      artworkUri: art == null
          ? null
          : art.scheme == 'file'
              ? art.toFilePath()
              : art.toString(),
    ));
  }

  static Future<Uri?> _artUri(Track track) async {
    final source = track.sourceUrl;
    if (source != null) {
      final videoId = Uri.tryParse(source)?.queryParameters['v'];
      if (videoId != null) {
        return Uri.parse('https://i.ytimg.com/vi/$videoId/mqdefault.jpg');
      }
    }
    final art = track.albumArt;
    if (art == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shell_art_${track.id.hashCode}.jpg');
      await file.writeAsBytes(art, flush: true);
      return file.uri;
    } catch (e) {
      debugPrint('album art export failed: $e');
      return null;
    }
  }
}
