import 'package:flutter/material.dart';
import 'dart:async';

import '../models/online_track.dart';
import '../services/online_music/ytmusic_api_service.dart';

class OnlineMusicProvider extends ChangeNotifier {
  OnlineMusicProvider({OnlineMusicService? service})
      : _service = service ?? YTMusicApiService();

  final OnlineMusicService _service;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  List<OnlineTrack> _searchResults = const [];
  Timer? _searchTimer;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OnlineTrack> get searchResults => _searchResults;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _service.initialize();
      _isInitialized = true;
      _error = null;
    } catch (e) {
      _error = 'Initialization failed: $e';
    }
    notifyListeners();
  }

  Future<void> search(String query, {int limit = 20}) async {
    _searchTimer?.cancel();

    if (query.isEmpty) {
      _searchResults = const [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await initialize();
        final results = await _service.searchTracks(query, limit: limit);
        _searchResults = results;
        _error = null;
      } catch (e) {
        _error = 'Search failed: $e';
        _searchResults = const [];
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<String> getStreamUrl(String videoId) async {
    try {
      await initialize();
      return await _service.getStreamUrl(videoId);
    } catch (e) {
      _error = 'Stream URL failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearResults() {
    _searchResults = const [];
    notifyListeners();
  }
}
