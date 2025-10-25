import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../services/audio_service.dart' as audio_svc;
import '../providers/settings_provider.dart';

enum RepeatMode { off, all, one }

enum ShuffleMode { off, songs, categories }

class AudioProvider extends ChangeNotifier {
  AudioPlayer? _audioPlayer;
  audio_svc.AudioPlayerHandler? _audioHandler;
  SettingsProvider? _settingsProvider;
  ConcatenatingAudioSource? _playlist;
  
  AudioPlayer get audioPlayer {
    if (_audioPlayer == null) {
      _initializeAudioService();
    }
    return _audioPlayer!;
  }

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = 0;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  RepeatMode _repeatMode = RepeatMode.off;
  ShuffleMode _shuffleMode = ShuffleMode.off;

  // Equalizer
  List<double> _equalizerBands = List.filled(10, 0.0);
  bool _equalizerEnabled = false;

  // Audio effects
  double _bassBoost = 0.0;
  double _trebleBoost = 0.0;
  double _reverbLevel = 0.0;
  double _tempoControl = 1.0;

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  RepeatMode get repeatMode => _repeatMode;
  ShuffleMode get shuffleMode => _shuffleMode;
  List<double> get equalizerBands => _equalizerBands;
  bool get equalizerEnabled => _equalizerEnabled;
  double get bassBoost => _bassBoost;
  double get trebleBoost => _trebleBoost;
  double get reverbLevel => _reverbLevel;
  double get tempoControl => _tempoControl;

  AudioProvider({SettingsProvider? settingsProvider}) {
    _settingsProvider = settingsProvider;
    _initializeAudioService();
  }
  
  void updateSettings(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  Future<void> _initializeAudioService() async {
    if (_audioPlayer != null) return;
    
    await audio_svc.AudioPlayerService.initialize();
    
    // Get the audio handler
    final handler = audio_svc.AudioPlayerService.audioHandler;
    if (handler is audio_svc.AudioPlayerHandler) {
      _audioHandler = handler;
      _audioPlayer = handler.player;
      
      // Set up skip callbacks
      handler.onSkipNext = skipNext;
      handler.onSkipPrevious = skipPrevious;
      
      _initializePlayer();
    } else {
      // Fallback to regular player
      _audioPlayer = AudioPlayer();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;

      if (state.processingState == ProcessingState.completed) {
        _handleTrackComplete();
      }

      notifyListeners();
    });
  }

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    _currentTrack = track;

    if (playlist != null) {
      _queue = playlist;
      _currentIndex = playlist.indexOf(track);
    } else {
      _queue = [track];
      _currentIndex = 0;
    }

    try {
      if (_audioHandler != null) {
        await _audioHandler!.setTrackMediaItem(track);
      }
      
      final enableGapless = _settingsProvider?.enableGapless ?? false;
      final enableCrossfade = _settingsProvider?.enableCrossfade ?? false;
      final crossfadeDuration = _settingsProvider?.crossfadeDuration ?? 3.0;
      final enableReplayGain = _settingsProvider?.enableReplayGain ?? false;
      
      if (enableGapless && _queue.length > 1) {
        await _setupGaplessPlayback();
      } else {
        double volume = 1.0;
        if (enableReplayGain) {
          // TODO read the actual gain tag, flat cut for now
          volume = 0.8;
        }
        
        await audioPlayer.setVolume(volume);
        
        if (enableCrossfade && _isPlaying) {
          await _crossfadeToTrack(track, crossfadeDuration);
        } else {
          await audioPlayer.setFilePath(track.path);
          await audioPlayer.play();
        }
      }
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }
  
  Future<void> _setupGaplessPlayback() async {
    _playlist = ConcatenatingAudioSource(
      children: _queue.map((track) {
        return AudioSource.file(track.path);
      }).toList(),
    );
    
    await audioPlayer.setAudioSource(_playlist!, initialIndex: _currentIndex);
    await audioPlayer.play();
    
    audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        _currentTrack = _queue[index];
        if (_audioHandler != null) {
          _audioHandler!.setTrackMediaItem(_queue[index]);
        }
        notifyListeners();
      }
    });
  }
  
  Future<void> _crossfadeToTrack(Track track, double duration) async {
    // fade out then in on the one player, real overlap needs two players
    final currentVolume = audioPlayer.volume;
    
    for (int i = 10; i >= 0; i--) {
      await audioPlayer.setVolume(currentVolume * (i / 10));
      await Future.delayed(Duration(milliseconds: (duration * 100).toInt()));
    }
    
    await audioPlayer.setFilePath(track.path);
    await audioPlayer.play();
    
    for (int i = 0; i <= 10; i++) {
      await audioPlayer.setVolume(currentVolume * (i / 10));
      await Future.delayed(Duration(milliseconds: (duration * 100).toInt()));
    }
  }
  
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;

    int nextIndex = _currentIndex + 1;

    if (nextIndex >= _queue.length) {
      if (_repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        await audioPlayer.stop();
        _isPlaying = false;
        notifyListeners();
        return;
      }
    }

    _currentIndex = nextIndex;
    await playTrack(_queue[_currentIndex], playlist: _queue);
  }

  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;

    if (prevIndex < 0) {
      if (_repeatMode == RepeatMode.all) {
        prevIndex = _queue.length - 1;
      } else {
        await audioPlayer.seek(Duration.zero);
        return;
      }
    }

    _currentIndex = prevIndex;
    await playTrack(_queue[_currentIndex], playlist: _queue);
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void setShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    if (mode == ShuffleMode.songs && _queue.isNotEmpty) {
      final currentTrack = _queue[_currentIndex];
      _queue.shuffle();
      _currentIndex = _queue.indexOf(currentTrack);
    }
    notifyListeners();
  }

  void _handleTrackComplete() {
    if (_repeatMode == RepeatMode.one) {
      audioPlayer.seek(Duration.zero);
      audioPlayer.play();
    } else {
      skipNext();
    }
  }

  // Equalizer controls
  void setEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      notifyListeners();
    }
  }

  void setEqualizerEnabled(bool enabled) {
    _equalizerEnabled = enabled;
    notifyListeners();
  }

  void resetEqualizer() {
    _equalizerBands = List.filled(10, 0.0);
    notifyListeners();
  }

  // Audio effects
  void setBassBoost(double value) {
    _bassBoost = value;
    notifyListeners();
  }

  void setTrebleBoost(double value) {
    _trebleBoost = value;
    notifyListeners();
  }

  void setReverbLevel(double value) {
    // TODO hook up a native reverb effect, stored only for now
    _reverbLevel = value;
    notifyListeners();
  }

  void setTempoControl(double value) {
    _tempoControl = value;
    audioPlayer.setSpeed(value);
    notifyListeners();
  }

  @override
  void dispose() {
    // Don't dispose the audio player if it's managed by AudioHandler
    if (_audioHandler == null && _audioPlayer != null) {
      _audioPlayer!.dispose();
    }
    super.dispose();
  }
}
