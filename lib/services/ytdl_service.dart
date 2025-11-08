import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class YtdlWrapperService {
  static const MethodChannel _channel = MethodChannel('com.libreamp.kashou/ytmusic');
  static bool get _supportsNativeBridge => Platform.isAndroid;

  final String? _customServerUrl;

  YtdlWrapperService([String? serverUrl])
      : _customServerUrl = (serverUrl != null && serverUrl.isNotEmpty) ? serverUrl : null;

  String get baseUrl => _customServerUrl ?? 'native';

  bool get _useNativeBridge => _supportsNativeBridge && _customServerUrl == null;

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final base = _customServerUrl!;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalizedBase$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
    );
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
  }) async {
    if (_useNativeBridge) {
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

    // Fallback to HTTP server if explicitly configured
    if (_customServerUrl == null) return [];

    try {
      final response = await http.get(
        _buildUri('/search', {
          'q': query,
          'limit': limit,
          'page': page,
        }),
        headers: const {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final results = decoded['results'];
          if (results is List) {
            return results
                .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
                .toList();
          }
        } else if (decoded is List) {
          return decoded
              .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      print('HTTP search error: $e');
    }

    return [];
  }

  Future<Map<String, dynamic>?> fetchAudioDetails(String videoUrl) async {
    if (_useNativeBridge) {
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

    if (_customServerUrl == null) return null;

    try {
      final response = await http.get(
        _buildUri('/download', {
          'url': videoUrl,
        }),
        headers: const {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      print('HTTP fetch error: $e');
    }

    return null;
  }
}
