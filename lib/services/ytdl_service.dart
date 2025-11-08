import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
class YtdlWrapperService {
  static const MethodChannel _channel = MethodChannel('com.libreamp.kashou/ytmusic');
  static bool get _supportsNativeBridge => Platform.isAndroid;

  const YtdlWrapperService();

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
  }) async {
    if (!_supportsNativeBridge) {
      throw UnsupportedError('Native yt-dlp bridge is only available on Android');
    }

    try {
      final response = await _channel.invokeMethod<String>('search', {
        'query': query,
        'limit': limit,
      });

      if (response == null || response.isEmpty) return [];
      final decoded = json.decode(response);

      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] != null) {
          print('Search error: ${decoded['error']}');
          return [];
        }
        final results = decoded['results'];
        if (results is List) {
          return results
              .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
    } catch (e) {
      print('Native search error: $e');
    }

    return [];
  }

  Future<Map<String, dynamic>?> fetchAudioDetails(String videoUrl) async {
    if (!_supportsNativeBridge) {
      throw UnsupportedError('Native yt-dlp bridge is only available on Android');
    }

    try {
      print('Fetching audio details from native yt-dlp for: $videoUrl');
      final response = await _channel.invokeMethod<String>('fetchAudioDetails', {
        'url': videoUrl,
      });

      if (response == null || response.isEmpty) {
        print('Native yt-dlp returned empty response');
        return null;
      }
      
      final decoded = json.decode(response);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          print('yt-dlp error: ${decoded['error']}');
          return null;
        }
        print('Native yt-dlp returned: ${decoded.keys}');
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      print('Native yt-dlp error: $e');
    }

    return null;
  }
}
