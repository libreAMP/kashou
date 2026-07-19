import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  List<Track> _favoriteTracks = [];

  bool _isScanning = false;
  double _scanProgress = 0.0;

  static const _libraryCacheKey = 'library_cache_v1';
  static const _favoriteTracksKey = 'favorite_tracks_v2';
  static const _playlistsKey = 'playlists_v1';

  // Getters
  List<Track> get allTracks => _allTracks;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Playlist> get playlists => _playlists;
  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  Set<String> get favoriteTrackIds => _favoriteTracks.map((t) => t.id).toSet();
  List<Track> get favoriteTracks => _favoriteTracks;

  LibraryProvider() {
    _loadLibrary();
    _loadFavorites();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_playlistsKey);
      if (stored == null) return;
      final data = jsonDecode(stored) as List<dynamic>;
      _playlists = [
        for (final p in data) Playlist.fromMap(Map<String, dynamic>.from(p)),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _playlistsKey, jsonEncode([for (final p in _playlists) p.toMap()]));
  }

  Future<void> _loadLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_libraryCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached) as List<dynamic>;
        _allTracks = data
            .map(
                (item) => Track.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        _rebuildCollections();
        _scanProgress = 1.0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached library: $e');
    }
  }

  void _rebuildCollections() {
    final Map<String, List<Track>> albumMap = {};
    final Map<String, List<Track>> artistMap = {};

    for (final track in _allTracks) {
      final albumKey = '${track.album}_${track.artist}';
      albumMap.putIfAbsent(albumKey, () => <Track>[]).add(track);
      artistMap.putIfAbsent(track.artist, () => <Track>[]).add(track);
    }

    _albums = albumMap.entries.map((entry) {
      final tracks = entry.value;
      return Album(
        id: entry.key,
        name: tracks.first.album,
        artist: tracks.first.artist,
        tracks: tracks,
        albumArt: tracks.first.albumArt,
        year: tracks.first.year,
      );
    }).toList();

    _artists = artistMap.entries.map((entry) {
      final tracks = entry.value;
      final artistAlbums = <Album>{};
      for (final track in tracks) {
        final albumTracks =
            tracks.where((t) => t.album == track.album).toList();
        artistAlbums.add(Album(
          id: track.album,
          name: track.album,
          artist: entry.key,
          tracks: albumTracks,
          albumArt: albumTracks.first.albumArt,
          year: albumTracks.first.year,
        ));
      }
      return Artist(
        id: entry.key,
        name: entry.key,
        albums: artistAlbums.toList(),
        tracks: tracks,
      );
    }).toList();
  }

  Future<void> _saveLibraryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload =
          jsonEncode(_allTracks.map((track) => track.toMap()).toList());
      await prefs.setString(_libraryCacheKey, payload);
    } catch (e) {
      debugPrint('Error saving library cache: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_favoriteTracksKey);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached) as List<dynamic>;
        _favoriteTracks = data
            .map(
                (item) => Track.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        debugPrint('Loaded ${_favoriteTracks.length} favorite tracks');
        notifyListeners();
      } else {
        debugPrint('No cached favorites found');
      }
    } catch (e) {
      debugPrint('Error loading favorite tracks: $e');
    }
  }

  bool isTrackFavorite(String trackId) =>
      _favoriteTracks.any((t) => t.id == trackId);

  Future<void> toggleFavorite(Track track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = _favoriteTracks.indexWhere((t) => t.id == track.id);

      if (index != -1) {
        _favoriteTracks.removeAt(index);
        debugPrint('Removed from favorites: ${track.title}');
      } else {
        _favoriteTracks.add(track);
        debugPrint('Added to favorites: ${track.title}');
      }

      // Save to storage
      final payload =
          jsonEncode(_favoriteTracks.map((t) => t.toMap()).toList());
      await prefs.setString(_favoriteTracksKey, payload);
      debugPrint('Saved ${_favoriteTracks.length} favorites to storage');
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> scanLibrary({bool force = false}) async {
    if (_isScanning) return;
    if (!force && _allTracks.isNotEmpty && _scanProgress == 1.0) {
      return;
    }
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
      if (_albums.isEmpty || _artists.isEmpty) {
        _rebuildCollections();
      }
      await _saveLibraryCache();
      _scanProgress = 1.0;
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
    await _savePlaylists();
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].tracks.add(track);
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeFromPlaylist(String playlistId, Track track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].tracks.remove(track);
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _savePlaylists();
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

  Future<void> updateTrackMetadata(Track updatedTrack) async {
    final index = _allTracks.indexWhere((track) => track.id == updatedTrack.id);
    if (index == -1) return;

    _allTracks[index] = updatedTrack;
    _rebuildCollections();
    await _saveLibraryCache();
    notifyListeners();
  }
}
