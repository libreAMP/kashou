import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/audio_service.dart' as audio_svc;
import '../services/ytdl_service.dart';
import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/custom_equalizer.dart';
import '../models/stream_history_entry.dart';

enum RepeatMode { off, all, one }

enum ShuffleMode { off, songs, categories }

class AudioProvider extends ChangeNotifier {
  AudioPlayer? _audioPlayer;
  audio_svc.AudioPlayerHandler? _audioHandler;
  SettingsProvider? _settingsProvider;
  ConcatenatingAudioSource? _playlist;

  final List<StreamSubscription> _playerSubs = [];
  // re-subscribed on each gapless setup
  StreamSubscription<int?>? _gaplessIndexSub;

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
  bool _pendingShouldUseExistingSource = false;

  bool _isPlaying = false;
  bool _pausedByInterruption = false;
  int _lastPositionSecond = -1;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoadingTrack = false;

  RepeatMode _repeatMode = RepeatMode.off;
  ShuffleMode _shuffleMode = ShuffleMode.off;

  static const int _maxRecentTracks = 20;
  static const int _maxStreamHistory = 50;
  List<String> _recentTrackIds = [];
  List<Map<String, dynamic>> _streamHistory = [];
  static const String _streamHistoryKey = 'stream_history_v1';

  List<double> _equalizerBands = [];
  bool _equalizerEnabled = false;

  double _bassBoost = 0.0;
  double _trebleBoost = 0.0;
  double _reverbLevel = 0.0;
  double _tempoControl = 1.0;
  double _masterVolume = 1.0;

  bool _isRemotePath(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  bool _isHlsStream(String path) =>
      path.contains('.m3u8') || path.contains('playlist.m3u8');

  Track? get currentTrack => _pendingTrack ?? _currentTrack;
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

  void addTracksToQueue(List<Track> tracks) {
    if (tracks.isEmpty) return;

    for (final track in tracks) {
      final exists = _queue.any((t) => t.id == track.id);
      if (!exists) {
        _queue.add(track);
      }
    }

    debugPrint(
        '[Audio] Added ${tracks.length} tracks to queue. Queue size: ${_queue.length}');
    notifyListeners();
  }

  void clearQueueAfterCurrent() {
    if (_queue.isEmpty || _currentIndex < 0) return;

    final current = _queue[_currentIndex];
    _queue = [current];
    _currentIndex = 0;
    debugPrint('[Audio] Cleared queue after current track');
    notifyListeners();
  }

  double get bassBoost => _bassBoost;
  double get trebleBoost => _trebleBoost;
  double get reverbLevel => _reverbLevel;
  double get tempoControl => _tempoControl;
  double get masterVolume => _masterVolume;
  List<Map<String, dynamic>> get streamHistory =>
      List.unmodifiable(_streamHistory);
  List<StreamHistoryEntry> get streamHistoryEntries => _streamHistory
      .map(StreamHistoryEntry.fromPersistedMap)
      .toList(growable: false);
  List<StreamHistoryEntry> get youtubeStreamHistoryEntries =>
      streamHistoryEntries
          .where((entry) => entry.isYouTube)
          .toList(growable: false);

  AudioProvider({SettingsProvider? settingsProvider}) {
    _settingsProvider = settingsProvider;
    _initializeAudioService();
    _loadRecentTracks();
    _loadStreamHistory();
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
    _pendingShouldUseExistingSource = false;
  }

  void _restorePendingSnapshot() {
    if (_queueBeforePending != null) {
      _queue = List<Track>.from(_queueBeforePending!);
      if (_queue.isNotEmpty) {
        final restoredIndex =
            (_indexBeforePending ?? 0).clamp(0, _queue.length - 1);
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
    _pendingShouldUseExistingSource = false;
    if (_currentTrack == null) {
      _currentTrack = _lastCommittedTrack;
    }
    notifyListeners();
  }

  Future<void> prepareTrackLoad(Track track, {List<Track>? playlist}) async {
    final wasPlaying = preparePendingTrack(track, playlist: playlist);

    if (_pendingShouldUseExistingSource) {
      return;
    }

    if (wasPlaying || audioPlayer.playing) {
      try {
        await audioPlayer.pause();
      } catch (_) {}
    }

    try {
      await audioPlayer.stop();
    } catch (_) {}

    _position = Duration.zero;
    _bufferedPosition = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _isLoadingTrack = true;
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

  Future<void> _loadStreamHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_streamHistoryKey);
    if (stored != null) {
      final data = jsonDecode(stored) as List<dynamic>;
      _streamHistory =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveRecentTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_tracks', _recentTrackIds);
  }

  Future<void> _saveStreamHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streamHistoryKey, jsonEncode(_streamHistory));
  }

  Future<void> clearStreamHistory() async {
    _streamHistory.clear();
    await _saveStreamHistory();
    notifyListeners();
  }

  Future<void> removeFromStreamHistory(String sourceUrl) async {
    _streamHistory.removeWhere((item) => item['sourceUrl'] == sourceUrl);
    await _saveStreamHistory();
    notifyListeners();
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

  void _addToStreamHistory(Track track) {
    final sourceUrl = track.sourceUrl ?? track.path;
    if (sourceUrl.isEmpty || !_isRemotePath(sourceUrl)) return;

    final entry = StreamHistoryEntry(
      track: track,
      timestamp: DateTime.now(),
      isYouTube: sourceUrl.contains('youtu'),
    );

    _streamHistory.removeWhere((item) => item['sourceUrl'] == sourceUrl);
    _streamHistory.insert(0, entry.toPersistedMap());
    if (_streamHistory.length > _maxStreamHistory) {
      _streamHistory = _streamHistory.sublist(0, _maxStreamHistory);
    }
    _saveStreamHistory();
    notifyListeners();
  }

  List<Track> getRecentlyPlayedTracks(LibraryProvider library) {
    final tracks = <Track>[];
    for (final id in _recentTrackIds) {
      final track = library.allTracks.firstWhere((track) => track.id == id,
          orElse: () => Track(
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
    _configureAudioSession();

    _playerSubs.add(audioPlayer.positionStream.listen((position) {
      _position = position;
      if (_isLoadingTrack &&
          _pendingTrack != null &&
          position > Duration.zero) {
        _isLoadingTrack = false;
        _pendingTrack = null;
        notifyListeners();
        return;
      }
      // ui only shows whole seconds
      if (position.inSeconds != _lastPositionSecond) {
        _lastPositionSecond = position.inSeconds;
        notifyListeners();
      }
    }));

    _playerSubs.add(audioPlayer.bufferedPositionStream.listen((buffered) {
      _bufferedPosition = buffered;
      notifyListeners();
    }));

    _playerSubs.add(audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    }));

    _playerSubs.add(audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;

      if (state.playing && _isLoadingTrack) {
        _isLoadingTrack = false;
      }

      if (state.processingState == ProcessingState.completed) {
        _handleTrackComplete();
      }

      notifyListeners();
    }));

    _playerSubs.add(audioPlayer.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null) {
        CustomEqualizer.init(sessionId);
        _loadEqualizerBands();
      }
    }));

    _masterVolume = audioPlayer.volume;
    _playerSubs.add(audioPlayer.volumeStream.listen((volume) {
      _masterVolume = volume;
      notifyListeners();
    }));
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Listen for interruptions (calls, other apps, Android Auto disconnect, etc.)
      session.interruptionEventStream.listen((event) {
        debugPrint(
            '[AudioSession] Interruption event: ${event.type}, begin=${event.begin}');
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // only resume what the interruption paused, not a user pause
              _pausedByInterruption = audioPlayer.playing;
              audioPlayer.pause();
              break;
          }
        } else {
          if (event.type != AudioInterruptionType.duck &&
              _pausedByInterruption &&
              !_isLoadingTrack &&
              !audioPlayer.playing) {
            audioPlayer.play();
          }
          _pausedByInterruption = false;
        }
      });

      // Listen for "becoming noisy" events (headphones unplugged, BT disconnect)
      session.becomingNoisyEventStream.listen((_) {
        debugPrint(
            '[AudioSession] Becoming noisy - pausing (headphones/BT disconnected)');
        audioPlayer.pause();
      });

      debugPrint('[AudioProvider] Audio session configured successfully');
    } catch (e) {
      debugPrint('[AudioProvider] Failed to configure audio session: $e');
    }
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
    _pendingShouldUseExistingSource = shouldUseExisting;

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

  bool _isWatchUrl(String path) =>
      path.contains('youtube.com/watch') || path.contains('youtu.be/');

  // saved stream urls go stale after a few hours, liked songs hit this
  bool _isStaleStreamUrl(String path) {
    if (!path.contains('googlevideo')) return false;
    final expire = Uri.tryParse(path)?.queryParameters['expire'];
    final seconds = int.tryParse(expire ?? '');
    if (seconds == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > seconds - 60;
  }

  // radio queue entries only carry a watch url
  Future<Track?> _resolveWatchTrack(Track track) async {
    final watchUrl = _isWatchUrl(track.path) ? track.path : track.sourceUrl;
    if (watchUrl == null || !_isWatchUrl(watchUrl)) return null;
    try {
      final data =
          await const YtdlWrapperService().fetchStreamingData(watchUrl);
      if (data == null || !data.playable) return null;
      final format = data.bestStream ?? data.fallbackStream;
      if (format == null) return null;

      // only fill in what the track is missing, never overwrite known metadata
      final noArtist = track.artist.isEmpty || track.artist == 'Unknown';
      final channel =
          data.channelName.replaceAll(RegExp(r'\s*-\s*Topic$'), '').trim();

      Uint8List? art = track.albumArt;
      art ??= await const YtdlWrapperService()
          .fetchVideoArt(data.videoId, preferred: data.thumbnailUrl);

      return track.copyWith(
        path: format.url,
        title: track.title == 'Unknown' && data.title.isNotEmpty
            ? data.title
            : track.title,
        artist: noArtist && channel.isNotEmpty ? channel : track.artist,
        duration:
            track.duration == Duration.zero ? data.duration : track.duration,
        albumArt: art,
      );
    } catch (e) {
      debugPrint('[Audio] watch url resolve failed: $e');
      return null;
    }
  }

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    if (_isRemotePath(track.path) &&
        (_isWatchUrl(track.path) || _isStaleStreamUrl(track.path))) {
      final pendingAlready =
          _pendingTrack != null && _pendingTrack!.id == track.id;
      if (!pendingAlready) {
        preparePendingTrack(track, playlist: playlist);
      }
      try {
        await audioPlayer.pause();
      } catch (_) {}
      try {
        await audioPlayer.stop();
      } catch (_) {}
      _isLoadingTrack = true;
      notifyListeners();

      final resolved = await _resolveWatchTrack(track);
      if (resolved == null) {
        cancelPendingTrack();
        return;
      }
      track = resolved;
      final qi = _queue.indexWhere((t) => t.id == track.id);
      if (qi != -1) _queue[qi] = track;
    }

    final bool alreadyPending =
        _pendingTrack != null && _pendingTrack!.id == track.id;
    final bool wasPlaying = alreadyPending
        ? _isPlaying
        : preparePendingTrack(track, playlist: playlist);
    final bool shouldReuse = _pendingShouldUseExistingSource;

    if (!shouldReuse) {
      if (wasPlaying || audioPlayer.playing) {
        try {
          await audioPlayer.pause();
        } catch (_) {}
      }

      try {
        await audioPlayer.stop();
      } catch (_) {}

      _position = Duration.zero;
      _bufferedPosition = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _isLoadingTrack = true;
      notifyListeners();
    }

    if (alreadyPending) {
      if (playlist != null) {
        _queue = List<Track>.from(playlist);
        _currentIndex = _queue.indexWhere((t) => t.id == track.id);
        if (_currentIndex == -1) {
          _queue.insert(0, track);
          _currentIndex = 0;
        }
      } else if (_queue.isEmpty) {
        _queue = [track];
        _currentIndex = 0;
      } else {
        final index = _queue.indexWhere((t) => t.id == track.id);
        if (index != -1) {
          _queue[index] = track;
          _currentIndex = index;
        }
      }

      _pendingTrack = track;
      _currentTrack = track;
      notifyListeners();
    }

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
        _gaplessIndexSub?.cancel();
        _gaplessIndexSub = null;
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
      _pendingShouldUseExistingSource = false;
      final queueIndex = _queue.indexWhere((t) => t.id == track.id);
      if (queueIndex != -1) {
        _queue[queueIndex] = track;
        _currentIndex = queueIndex;
      }
      notifyListeners();
      // history writes cant be allowed to trip the rollback
      try {
        _addToRecentTracks(track.id);
        _addToStreamHistory(track);
      } catch (e) {
        debugPrint('[Audio] history bookkeeping failed: $e');
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      _isLoadingTrack = false;
      _pendingTrack = null;
      _pendingShouldUseExistingSource = false;
      if (audioPlayer.playing) {
        // the new audio made it out, rolling back would show the wrong song
        _currentTrack = track;
        _lastCommittedTrack = track;
      } else if (_lastCommittedTrack != null) {
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

    _gaplessIndexSub?.cancel();
    _gaplessIndexSub = audioPlayer.currentIndexStream.listen((index) {
      // stale events fire after leaving gapless
      if (_playlist == null) return;
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
    debugPrint('[Audio] Creating audio source for: ${track.title}');
    debugPrint('[Audio] Path: $path');
    if (_isRemotePath(path)) {
      final uri = Uri.parse(path);
      if (_isHlsStream(path)) {
        debugPrint('[Audio] Using HLS audio source');
        return HlsAudioSource(uri);
      }
      debugPrint('[Audio] Using URI audio source');
      return AudioSource.uri(uri);
    }
    debugPrint('[Audio] Using file audio source');
    return AudioSource.file(path);
  }

  Future<void> _loadTrackIntoPlayer(Track track) async {
    debugPrint('[Audio] Loading track into player: ${track.title}');
    final source = _createAudioSource(track);
    await audioPlayer.setAudioSource(source);
    debugPrint('[Audio] Audio source set successfully');
  }

  Future<void> togglePlayPause() async {
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      final completed = _position >= _duration && _duration > Duration.zero;
      if (completed) {
        await audioPlayer.seek(Duration.zero);
      }
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

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await playTrack(_queue[index], playlist: _queue);
  }

  void moveQueueItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    // keep the pointer on whatever is playing
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
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
      await CustomEqualizer.getCenterBandFreqs();
      _equalizerBands = List.filled(10, 0.0);
    } catch (e) {
      _equalizerBands = List.filled(10, 0.0);
    }
    notifyListeners();
  }

  Timer? _eqNotifyDebounce;

  void setEqualizerBand(int index, double value) {
    if (index < 0 || index >= _equalizerBands.length) return;
    _equalizerBands[index] = value;
    if (_equalizerEnabled) {
      final millibels = (value * 125).toInt();
      CustomEqualizer.setBandLevel(index, millibels).catchError((e) {
        debugPrint('Error setting equalizer band $index: $e');
      });
    }
    // dont notify per tick
    _eqNotifyDebounce?.cancel();
    _eqNotifyDebounce =
        Timer(const Duration(milliseconds: 150), notifyListeners);
  }

  void setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    try {
      await CustomEqualizer.enableEffects(enabled);
    } catch (e) {}
    notifyListeners();
  }

  void resetEqualizer() async {
    _equalizerBands = List.filled(_equalizerBands.length, 0.0);
    if (_equalizerEnabled) {
      for (int i = 0; i < _equalizerBands.length; i++) {
        try {
          await CustomEqualizer.setBandLevel(i, 0);
        } catch (e) {
          debugPrint('Error resetting equalizer band $i: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> applyEqualizerPreset(String presetName) async {
    if (!_equalizerEnabled) return;

    try {
      await CustomEqualizer.setPreset(presetName);
      final presetValues = await CustomEqualizer.getPresetBandLevels();
      if (presetValues.isNotEmpty) {
        _equalizerBands = presetValues.map((millibelValue) {
          return (millibelValue / 125.0).clamp(-12.0, 12.0);
        }).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error applying preset $presetName: $e');
    }
  }

  void setBassBoost(double value) async {
    _bassBoost = value;
    try {
      await CustomEqualizer.setBassBoost((value * 1000).toInt());
    } catch (e) {}
    notifyListeners();
  }

  void setTrebleBoost(double value) async {
    // no dedicated treble effect on android, virtualizer is the closest
    _trebleBoost = value;
    try {
      await CustomEqualizer.setVirtualizer((value * 1000).toInt());
    } catch (e) {}
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
    for (final sub in _playerSubs) {
      sub.cancel();
    }
    _playerSubs.clear();
    _eqNotifyDebounce?.cancel();
    _gaplessIndexSub?.cancel();
    if (_audioHandler == null && _audioPlayer != null) {
      _audioPlayer!.dispose();
    }
    super.dispose();
  }
}
