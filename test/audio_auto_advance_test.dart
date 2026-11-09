import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kashou/models/track.dart';
import 'package:kashou/providers/audio_provider.dart';

class FakeAudioPlayer implements AudioPlayer {
  final positionEvents = StreamController<Duration>.broadcast();
  final bufferedEvents = StreamController<Duration>.broadcast();
  final durationEvents = StreamController<Duration?>.broadcast();
  final stateEvents = StreamController<PlayerState>.broadcast();

  bool _playing = false;
  double _volume = 1.0;
  Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;

  int playCalls = 0;
  int loadCalls = 0;

  @override
  Stream<Duration> get positionStream => positionEvents.stream;

  @override
  Stream<Duration> get bufferedPositionStream => bufferedEvents.stream;

  @override
  Stream<Duration?> get durationStream => durationEvents.stream;

  @override
  Stream<PlayerState> get playerStateStream => stateEvents.stream;

  @override
  bool get playing => _playing;

  @override
  double get volume => _volume;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    int? initialIndex,
    bool preload = true,
    Duration? initialPosition,
  }) async {
    loadCalls++;
    _position = Duration.zero;
    positionEvents.add(_position);
    return null;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
    stateEvents.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    _playing = false;
    stateEvents.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    _playing = false;
    stateEvents.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    _position = position ?? Duration.zero;
    positionEvents.add(_position);
  }

  @override
  Future<void> dispose() async {
    await positionEvents.close();
    await bufferedEvents.close();
    await durationEvents.close();
    await stateEvents.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Track track(String id, String path) => Track(
      id: id,
      title: id,
      artist: '',
      album: '',
      path: path,
      duration: const Duration(seconds: 10),
    );

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new stream advances when completed is late', () async {
    final player = FakeAudioPlayer();
    final provider = AudioProvider(player: player);
    final a = track('a', 'https://example.com/a.m4a');
    final b = track('b', 'https://example.com/b.m4a');

    await provider.playTrack(a, playlist: [a, b]);
    expect(provider.currentTrack?.id, 'a');
    expect(player.playCalls, 1);

    // fresh stream reaches the end without a completed event
    player.positionEvents.add(const Duration(seconds: 10));
    await settle();

    expect(provider.currentTrack?.id, 'b');
    expect(player.playCalls, 2);
  });

  test('played stream advances on completed', () async {
    final player = FakeAudioPlayer();
    final provider = AudioProvider(player: player);
    final a = track('a', 'https://example.com/a.m4a');
    final b = track('b', 'https://example.com/b.m4a');

    await provider.playTrack(a, playlist: [a, b]);
    expect(provider.currentTrack?.id, 'a');

    player.stateEvents.add(PlayerState(true, ProcessingState.completed));
    await settle();

    expect(provider.currentTrack?.id, 'b');
    expect(player.playCalls, 2);
  });

  test('position at end does not double advance', () async {
    final player = FakeAudioPlayer();
    final provider = AudioProvider(player: player);
    final a = track('a', 'https://example.com/a.m4a');
    final b = track('b', 'https://example.com/b.m4a');

    await provider.playTrack(a, playlist: [a, b]);
    player.positionEvents.add(const Duration(seconds: 10));
    player.positionEvents.add(const Duration(seconds: 10));
    await settle();

    expect(provider.currentTrack?.id, 'b');
    expect(player.playCalls, 2);
  });
}
