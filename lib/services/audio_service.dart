import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

// the buffer size setting maps to player buffer durations, set at construction
AudioLoadConfiguration _loadConfigFor(int bufferSize) {
  final seconds = switch (bufferSize) {
    1024 => 20,
    4096 => 120,
    _ => 50,
  };
  return AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(seconds: seconds),
      maxBufferDuration: Duration(seconds: seconds * 2),
    ),
    darwinLoadControl: DarwinLoadControl(
      preferredForwardBufferDuration: Duration(seconds: seconds),
    ),
  );
}

class AudioPlayerService {
  static AudioPlayer? _audioPlayer;
  static AudioHandler? _audioHandler;
  static bool _isInitializing = false;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    final prefs = await SharedPreferences.getInstance();
    final bufferSize = prefs.getInt('buffer_size') ?? 2048;
    _audioPlayer = AudioPlayer(audioLoadConfiguration: _loadConfigFor(bufferSize));

    try {
      _audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(bufferSize),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.libreamp.kashou.audio',
          androidNotificationChannelName: 'Kashou Audio Service',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'drawable/ic_stat_kashou',
        ),
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio service: $e');
    } finally {
      _isInitializing = false;
    }
  }

  static AudioPlayer get audioPlayer {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
    }
    return _audioPlayer!;
  }

  static AudioHandler? get audioHandler => _audioHandler;
}

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AndroidLoudnessEnhancer loudness = AndroidLoudnessEnhancer();
  late final AudioPlayer _player;
  Function()? onSkipNext;
  Function()? onSkipPrevious;

  AudioPlayerHandler(int bufferSize) {
    loudness.setEnabled(true);
    _player = AudioPlayer(
      audioLoadConfiguration: _loadConfigFor(bufferSize),
      audioPipeline: AudioPipeline(androidAudioEffects: [loudness]),
    );
    _player.playbackEventStream.map(_transformEvent).listen(playbackState.add);
  }

  AudioPlayer get player => _player;

  void updateDuration(Duration duration) {
    final current = mediaItem.value;
    if (current != null) {
      mediaItem.add(current.copyWith(duration: duration));
    }
  }

  Future<void> setTrackMediaItem(Track track) async {
    Uri? artUri;
    if (track.albumArt != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final artFile =
            File('${tempDir.path}/album_art_${track.id.hashCode}.jpg');
        await artFile.writeAsBytes(track.albumArt!);
        artUri = Uri.file(artFile.path);
      } catch (e) {
        print('Error saving album art to file: $e');
      }
    }

    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: artUri,
      ),
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: queue.value.isNotEmpty ? 0 : null,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipNext != null) {
      onSkipNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipPrevious != null) {
      onSkipPrevious!();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Handle queue item skip
  }
}
