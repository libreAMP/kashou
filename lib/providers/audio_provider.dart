import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/audio_service.dart' as audio_svc;
import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/custom_equalizer.dart';

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
  Track? _pendingTrack;
  Track? _lastCommittedTrack;
  List<Track>? _queueBeforePending;
  int? _indexBeforePending;
  List<Track> _queue = [];
  int _currentIndex = 0;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoadingTrack = false;

  RepeatMode _repeatMode = RepeatMode.off;
  ShuffleMode _shuffleMode = ShuffleMode.off;

  static const int _maxRecentTracks = 20;
  List<String> _recentTrackIds = [];

  List<double> _equalizerBands = [];
  bool _equalizerEnabled = false;

  double _bassBoost = 0.0;
  double _trebleBoost = 0.0;
  double _reverbLevel = 0.0;
  double _tempoControl = 1.0;
  double _masterVolume = 1.0;

  bool _isRemotePath(String path) => path.startsWith('http://') || path.startsWith('https://');

  bool _isHlsStream(String path) => path.contains('.m3u8') || path.contains('playlist.m3u8');

  Track? get currentTrack => _currentTrack ?? _pendingTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get bufferedPosition => _bufferedPosition;
  Duration get duration => _duration;
  bool get isLoadingTrack => _isLoadingTrack;
  RepeatMode get repeatMode => _repeatMode;
  ShuffleMode get shuffleMode => _shuffleMode;
  List<double> get equalizerBands => _equalizerBands;
  bool get equalizerEnabled => _equalizerEnabled;
  double get bassBoost => _bassBoost;
  double get trebleBoost => _trebleBoost;
  double get reverbLevel => _reverbLevel;
  double get tempoControl => _tempoControl;
  double get masterVolume => _masterVolume;

  AudioProvider({SettingsProvider? settingsProvider}) {
    _settingsProvider = settingsProvider;
    _initializeAudioService();
    _loadRecentTracks();
  }
  
  void updateSettings(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  void _storePendingSnapshot() {
    _queueBeforePending = List<Track>.from(_queue);
    _indexBeforePending = _queue.isNotEmpty ? _currentIndex : null;
    _lastCommittedTrack ??= _currentTrack;
  }

  void _clearPendingSnapshot() {
    _queueBeforePending = null;
    _indexBeforePending = null;
  }

  void _restorePendingSnapshot() {
    if (_queueBeforePending != null) {
      _queue = List<Track>.from(_queueBeforePending!);
      if (_queue.isNotEmpty) {
        final restoredIndex = (_indexBeforePending ?? 0).clamp(0, _queue.length - 1);
        _currentIndex = restoredIndex;
        _currentTrack = _queue[_currentIndex];
      } else {
        _currentIndex = 0;
        _currentTrack = null;
      }
    }
    _clearPendingSnapshot();
  }

  void cancelPendingTrack() {
    if (_pendingTrack == null) return;
    _isLoadingTrack = false;
    _restorePendingSnapshot();
    _pendingTrack = null;
    if (_currentTrack == null) {
      _currentTrack = _lastCommittedTrack;
    }
    notifyListeners();
  }

  void updateTrackMetadata(Track track) {
    bool updated = false;
    if (_currentTrack != null && _currentTrack!.id == track.id) {
      _currentTrack = track;
      updated = true;
    }
    if (_pendingTrack != null && _pendingTrack!.id == track.id) {
      _pendingTrack = track;
      updated = true;
    }
    final queueIndex = _queue.indexWhere((t) => t.id == track.id);
    if (queueIndex != -1) {
      _queue[queueIndex] = track;
      updated = true;
    }
    if (updated) {
      _lastCommittedTrack = track;
      notifyListeners();
    }
  }

  Future<void> _loadRecentTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRecent = prefs.getStringList('recent_tracks') ?? [];
    _recentTrackIds = storedRecent;
    notifyListeners();
  }

  Future<void> _saveRecentTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_tracks', _recentTrackIds);
  }

  void _addToRecentTracks(String trackId) {
    _recentTrackIds.remove(trackId);
    _recentTrackIds.insert(0, trackId);
    if (_recentTrackIds.length > _maxRecentTracks) {
      _recentTrackIds = _recentTrackIds.sublist(0, _maxRecentTracks);
    }
    _saveRecentTracks();
    notifyListeners();
  }

  List<Track> getRecentlyPlayedTracks(LibraryProvider library) {
    final tracks = <Track>[];
    for (final id in _recentTrackIds) {
      final track = library.allTracks.firstWhere((track) => track.id == id, orElse: () => Track(
        id: '',
        title: '',
        artist: '',
        album: '',
        path: '',
        duration: Duration.zero,
      ));
      if (track.id.isNotEmpty) {
        tracks.add(track);
      }
    }
    return tracks;
  }

  Future<void> _initializeAudioService() async {
    if (_audioPlayer != null) return;
    
    await audio_svc.AudioPlayerService.initialize();
    
    final handler = audio_svc.AudioPlayerService.audioHandler;
    if (handler is audio_svc.AudioPlayerHandler) {
      _audioHandler = handler;
      _audioPlayer = handler.player;
      
      handler.onSkipNext = skipNext;
      handler.onSkipPrevious = skipPrevious;
      
      _initializePlayer();
    } else {
      _audioPlayer = AudioPlayer();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    audioPlayer.positionStream.listen((position) {
      _position = position;
      if (_isLoadingTrack && _pendingTrack != null && position > Duration.zero) {
        _isLoadingTrack = false;
        _pendingTrack = null;
      }
      notifyListeners();
    });

    audioPlayer.bufferedPositionStream.listen((buffered) {
      _bufferedPosition = buffered;
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

    audioPlayer.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null) {
        CustomEqualizer.init(sessionId);
        _loadEqualizerBands();
      }
    });

    _masterVolume = audioPlayer.volume;
    audioPlayer.volumeStream.listen((volume) {
      _masterVolume = volume;
      notifyListeners();
    });
  }

  bool preparePendingTrack(Track track, {List<Track>? playlist}) {
    final isNewPending = _pendingTrack == null || _pendingTrack!.id != track.id;
    if (isNewPending) {
      _storePendingSnapshot();
    }

    if (playlist != null) {
      _queue = List<Track>.from(playlist);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else {
      _queue = [track];
      _currentIndex = 0;
    }

    final wasPlaying = _isPlaying;
    final shouldUseExisting = _shouldUseExistingSource(track, wasPlaying);

    _pendingTrack = track;
    _currentTrack = track;
    _isLoadingTrack = !shouldUseExisting;
    notifyListeners();

    if (shouldUseExisting) {
      _pendingTrack = null;
      _clearPendingSnapshot();
    }

    return wasPlaying;
  }

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    final wasPlaying = preparePendingTrack(track, playlist: playlist);

    try {
      if (_audioHandler != null) {
        await _audioHandler!.setTrackMediaItem(track);
      }
      
      final enableGapless = _settingsProvider?.enableGapless ?? false;
      final enableCrossfade = _settingsProvider?.enableCrossfade ?? false;
      final crossfadeDuration = _settingsProvider?.crossfadeDuration ?? 3.0;
      final enableReplayGain = _settingsProvider?.enableReplayGain ?? false;
      
      if (enableGapless && _queue.length > 1 && !_isRemotePath(track.path)) {
        await _setupGaplessPlayback();
      } else {
        _playlist = null;
        double volume = 1.0;
        if (enableReplayGain) {
          // TODO read the actual gain tag, flat cut for now
          volume = 0.8;
        }

        await audioPlayer.setVolume(volume);

        if (enableCrossfade && wasPlaying && !_isRemotePath(track.path)) {
          await _crossfadeToTrack(track, crossfadeDuration);
        } else {
          await _loadTrackIntoPlayer(track);
          await audioPlayer.play();
        }
      }
      
      _isPlaying = audioPlayer.playing;
      _currentTrack = track;
      _pendingTrack = null;
      _isLoadingTrack = false;
      _lastCommittedTrack = track;
      _clearPendingSnapshot();
      _addToRecentTracks(track.id);
      final queueIndex = _queue.indexWhere((t) => t.id == track.id);
      if (queueIndex != -1) {
        _queue[queueIndex] = track;
        _currentIndex = queueIndex;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing track: $e');
      _isLoadingTrack = false;
      _pendingTrack = null;
      if (_lastCommittedTrack != null) {
        _currentTrack = _lastCommittedTrack;
        _restorePendingSnapshot();
      }
      notifyListeners();
    }
  }
  
  Future<void> _setupGaplessPlayback() async {
    _playlist = ConcatenatingAudioSource(
      children: _queue.map((track) {
        return _createAudioSource(track);
      }).toList(),
    );
    
    await audioPlayer.setAudioSource(_playlist!, initialIndex: _currentIndex);
    await audioPlayer.play();
    
    audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        _currentTrack = _queue[index];
        _lastCommittedTrack = _currentTrack;
        _pendingTrack = null;
        _isLoadingTrack = false;
        _clearPendingSnapshot();
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
    
    await _loadTrackIntoPlayer(track);
    await audioPlayer.play();
    
    for (int i = 0; i <= 10; i++) {
      await audioPlayer.setVolume(currentVolume * (i / 10));
      await Future.delayed(Duration(milliseconds: (duration * 100).toInt()));
    }
  }
  
  bool _playlistIsMatchingQueue() {
    if (_playlist == null) return false;
    final children = _playlist!.children;
    if (children.length != _queue.length) return false;
    for (int i = 0; i < children.length; i++) {
      final source = children[i];
      final track = _queue[i];
      if (source is UriAudioSource) {
        if (source.uri.toString() != track.path) {
          return false;
        }
      } else if (_isRemotePath(track.path)) {
        return false;
      }
    }
    return true;
  }

  bool _shouldUseExistingSource(Track track, bool wasPlaying) {
    if (!_isRemotePath(track.path)) {
      return wasPlaying && _playlistIsMatchingQueue();
    }

    if (!wasPlaying) return false;

    if (_playlist != null && _playlistIsMatchingQueue()) {
      final currentSource = _playlist!.children[_currentIndex];
      if (currentSource is UriAudioSource) {
        return currentSource.uri.toString() == track.path;
      }
    }

    return false;
  }

  AudioSource _createAudioSource(Track track) {
    final path = track.path;
    if (_isRemotePath(path)) {
      final uri = Uri.parse(path);
      if (_isHlsStream(path)) {
        return HlsAudioSource(uri);
      }
      return AudioSource.uri(uri);
    }
    return AudioSource.file(path);
  }

  Future<void> _loadTrackIntoPlayer(Track track) async {
    final source = _createAudioSource(track);
    await audioPlayer.setAudioSource(source);
  }

  Future<void> togglePlayPause() async {
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
    _isPlaying = audioPlayer.playing;
    notifyListeners();
  }

  Future<void> stop() async {
    await audioPlayer.stop();
    _isPlaying = false;
    _currentTrack = null;
    _pendingTrack = null;
    _lastCommittedTrack = null;
    _clearPendingSnapshot();
    _position = Duration.zero;
    _duration = Duration.zero;
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
    try {
      final loopMode = switch (mode) {
        RepeatMode.off => LoopMode.off,
        RepeatMode.all => LoopMode.all,
        RepeatMode.one => LoopMode.one,
      };
      audioPlayer.setLoopMode(loopMode);
    } catch (e) {
      debugPrint('Failed to set repeat mode: $e');
    }
    notifyListeners();
  }

  void setShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    try {
      audioPlayer.setShuffleModeEnabled(mode != ShuffleMode.off);
      if (mode != ShuffleMode.off) {
        audioPlayer.shuffle();
      }
    } catch (e) {
      debugPrint('Failed to set shuffle mode: $e');
    }
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

  Future<void> _loadEqualizerBands() async {
    try {
      final freqs = await CustomEqualizer.getCenterBandFreqs();
      _equalizerBands = List.filled(10, 0.0);
    } catch (e) {
      _equalizerBands = List.filled(10, 0.0);
    }
    notifyListeners();
  }

  void setEqualizerBand(int index, double value) async {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      if (_equalizerEnabled) {
        try {
          await CustomEqualizer.setBandLevel(index, (value * 100).toInt());
        } catch (e) {
        }
      }
      notifyListeners();
    }
  }

  void setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    try {
      await CustomEqualizer.enableEffects(enabled);
    } catch (e) {
    }
    notifyListeners();
  }

  void resetEqualizer() async {
    _equalizerBands = List.filled(_equalizerBands.length, 0.0);
    if (_equalizerEnabled) {
      for (int i = 0; i < _equalizerBands.length; i++) {
        try {
          await CustomEqualizer.setBandLevel(i, 0);
        } catch (e) {
        }
      }
    }
    notifyListeners();
  }

  void setBassBoost(double value) async {
    _bassBoost = value;
    try {
      await CustomEqualizer.setBassBoost((value * 1000).toInt()); 
    } catch (e) {
    }
    notifyListeners();
  }

  void setTrebleBoost(double value) async {
    // no dedicated treble effect on android, virtualizer is the closest
    _trebleBoost = value;
    try {
      await CustomEqualizer.setVirtualizer((value * 1000).toInt());
    } catch (e) {
    }
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

  Future<void> setMasterVolume(double value) async {
    _masterVolume = value.clamp(0.0, 1.0);
    await audioPlayer.setVolume(_masterVolume);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_audioHandler == null && _audioPlayer != null) {
      _audioPlayer!.dispose();
    }
    super.dispose();
  }
}
