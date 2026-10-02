import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/track.dart';
import '../utils/platform.dart';
import 'local_media_server.dart';

class CastService extends ChangeNotifier {
  CastService._();
  static final CastService instance = CastService._();

  GoogleCastSession? _session;
  StreamSubscription? _sessionSub;
  StreamSubscription? _mediaStatusSub;
  StreamSubscription? _positionSub;

  Duration _castPosition = Duration.zero;
  final Duration _castDuration = Duration.zero;
  bool _isCastPlaying = false;

  GoogleCastSession? get session => _session;
  bool get isCasting => _session != null;
  bool get isCastPlaying => _isCastPlaying;
  Duration get castPosition => _castPosition;
  Duration get castDuration => _castDuration;

  void initialize() {
    if (!isMobile) return;

    _sessionSub = GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
      _session = session;
      if (session == null) {
        _isCastPlaying = false;
        _mediaStatusSub?.cancel();
        _positionSub?.cancel();
        LocalMediaServer.instance.stop();
      } else {
        _attachMediaListeners();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _mediaStatusSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  void _attachMediaListeners() {
    _mediaStatusSub?.cancel();
    _mediaStatusSub = GoogleCastRemoteMediaClient.instance.mediaStatusStream.listen((status) {
      final isPlaying = status?.playerState == CastMediaPlayerState.playing ||
          status?.playerState == CastMediaPlayerState.buffering;
      if (_isCastPlaying != isPlaying) {
        _isCastPlaying = isPlaying;
        notifyListeners();
      }
    });

    _positionSub?.cancel();
    _positionSub = GoogleCastRemoteMediaClient.instance.playerPositionStream.listen((pos) {
      _castPosition = pos;
      notifyListeners();
    });
  }

  Future<void> togglePlayPause() async {
    if (!isCasting) return;
    try {
      if (_isCastPlaying) {
        await GoogleCastRemoteMediaClient.instance.pause();
        _isCastPlaying = false;
      } else {
        await GoogleCastRemoteMediaClient.instance.play();
        _isCastPlaying = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> play() async {
    if (!isCasting) return;
    try {
      await GoogleCastRemoteMediaClient.instance.play();
      _isCastPlaying = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pause() async {
    if (!isCasting) return;
    try {
      await GoogleCastRemoteMediaClient.instance.pause();
      _isCastPlaying = false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> seek(Duration position) async {
    if (!isCasting) return;
    try {
      await GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: position),
      );
      _castPosition = position;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> loadTrack(Track track, {Duration startPosition = Duration.zero}) async {
    if (!isCasting) return false;
    try {
      String streamUrl;
      final isRemote = track.path.startsWith('http://') || track.path.startsWith('https://');

      if (isRemote) {
        streamUrl = track.path;
      } else {
        final server = LocalMediaServer.instance;
        final baseUrl = await server.ensureStarted();
        final serverUrl = baseUrl != null ? server.buildStreamUrl(track.path) : null;
        if (serverUrl == null) return false;
        streamUrl = serverUrl;
      }

      final contentType = _inferTrackMimeType(track.path) ?? 'audio/mpeg';
      final metadata = GoogleCastGenericMediaMetadata(
        title: track.title,
        subtitle: track.artist,
        images: track.albumArt != null
            ? [
                GoogleCastImage(
                  url: Uri.parse(
                    'data:image/jpeg;base64,${base64Encode(track.albumArt!)}',
                  ),
                ),
              ]
            : [],
      );

      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformationIOS(
          contentId: streamUrl,
          streamType: CastMediaStreamType.buffered,
          contentUrl: Uri.parse(streamUrl),
          contentType: contentType,
          metadata: metadata,
        ),
        autoPlay: true,
        playPosition: startPosition,
        playbackRate: 1.0,
      );

      _isCastPlaying = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> endSession() async {
    if (!isCasting) return;
    try {
      await GoogleCastRemoteMediaClient.instance.stop();
      await GoogleCastSessionManager.instance.endSession();
    } catch (_) {}
    _session = null;
    _isCastPlaying = false;
    LocalMediaServer.instance.stop();
    notifyListeners();
  }

  String? _inferTrackMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/mp4';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return null;
  }
}
