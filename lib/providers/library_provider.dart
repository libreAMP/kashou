import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../services/music_scanner_service.dart';

class LibraryProvider extends ChangeNotifier {
  List<Track> _allTracks = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Playlist> _playlists = [];

  bool _isScanning = false;
  double _scanProgress = 0.0;

  // Getters
  List<Track> get allTracks => _allTracks;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Playlist> get playlists => _playlists;
  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;

  LibraryProvider() {
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
  }

  Future<void> scanLibrary() async {
    _isScanning = true;
    _scanProgress = 0.0;
    notifyListeners();

    try {
      final scanner = MusicScannerService();

      await for (final progress in scanner.scanMusic()) {
        _scanProgress = progress.progress;
        notifyListeners();
      }

      _allTracks = await scanner.getAllTracks();
      _albums = await scanner.getAlbums();
      _artists = await scanner.getArtists();

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning library: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      tracks: [],
      createdAt: DateTime.now(),
    );

    _playlists.add(playlist);
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].tracks.add(track);
      notifyListeners();
    }
  }

  Future<void> removeFromPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].tracks.remove(track);
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  List<Track> searchTracks(String query) {
    if (query.isEmpty) return _allTracks;

    final lowerQuery = query.toLowerCase();
    return _allTracks.where((track) {
      return track.title.toLowerCase().contains(lowerQuery) ||
          track.artist.toLowerCase().contains(lowerQuery) ||
          track.album.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<Album> searchAlbums(String query) {
    if (query.isEmpty) return _albums;

    final lowerQuery = query.toLowerCase();
    return _albums.where((album) {
      return album.name.toLowerCase().contains(lowerQuery) ||
          album.artist.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<Artist> searchArtists(String query) {
    if (query.isEmpty) return _artists;

    final lowerQuery = query.toLowerCase();
    return _artists.where((artist) {
      return artist.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
