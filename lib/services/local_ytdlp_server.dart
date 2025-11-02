import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class LocalYtdlpServer {
  static HttpServer? _server;
  static Process? _ytdlpProcess;
  static const int _port = 8080;

  static Future<void> start() async {
    if (_server != null) return;

    try {
      // Start local HTTP server
      _server = await HttpServer.bind('localhost', _port);
      print('Local yt-dlp server started on http://localhost:$_port');

      await for (HttpRequest request in _server!) {
        try {
          await _handleRequest(request);
        } catch (e) {
          print('Request error: $e');
          request.response
            ..statusCode = 500
            ..write(json.encode({'error': e.toString()}))
            ..close();
        }
      }
    } catch (e) {
      print('Failed to start local server: $e');
    }
  }

  static Future<void> stop() async {
    _server?.close();
    _server = null;
    _ytdlpProcess?.kill();
    _ytdlpProcess = null;
    print('Local yt-dlp server stopped');
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    try {
      if (request.uri.path == '/search' && request.method == 'GET') {
        await _handleSearch(request, response);
      } else if (request.uri.path == '/download' && request.method == 'GET') {
        await _handleDownload(request, response);
      } else if (request.uri.path == '/' && request.method == 'GET') {
        // Check if yt-dlp is available
        try {
          final result = await Process.run('yt-dlp', ['--version']);
          if (result.exitCode == 0) {
            response
              ..write(json.encode({
                'status': 'ok',
                'message': 'Local yt-dlp server running',
                'version': result.stdout.toString().trim()
              }))
              ..close();
          } else {
            response
              ..write(json.encode({
                'status': 'error',
                'message': 'yt-dlp not available',
                'error': result.stderr.toString()
              }))
              ..close();
          }
        } catch (e) {
          response
            ..statusCode = 500
            ..write(json.encode({
              'status': 'error',
              'message': 'yt-dlp check failed',
              'error': e.toString()
            }))
            ..close();
        }
      } else {
        response
          ..statusCode = 404
          ..write(json.encode({'error': 'Not found'}))
          ..close();
      }
    } catch (e) {
      response
        ..statusCode = 500
        ..write(json.encode({'error': e.toString()}))
        ..close();
    }
  }

  static Future<void> _handleSearch(HttpRequest request, HttpResponse response) async {
    final query = request.uri.queryParameters['q'];
    final limit = request.uri.queryParameters['limit'] ?? '10';

    if (query == null || query.isEmpty) {
      response
        ..statusCode = 400
        ..write(json.encode({'error': 'Missing query parameter'}))
        ..close();
      return;
    }

    try {
      // Run yt-dlp search command
      final args = [
        'ytsearch$limit:$query',
        '--print',
        '%(id)s|||%(title)s|||%(channel)s|||%(duration)s|||%(view_count)s|||%(thumbnail)s|||%(webpage_url)s',
        '--flat-playlist',
        '--no-warnings',
        '--quiet'
      ];

      final result = await Process.run('yt-dlp', args);

      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final lines = result.stdout.toString().trim().split('\n');
        final results = <Map<String, dynamic>>[];

        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          final parts = line.split('|||');
          if (parts.length >= 7) {
            results.add({
              'id': parts[0],
              'title': parts[1],
              'channel': parts[2],
              'duration': int.tryParse(parts[3]) ?? 0,
              'views': int.tryParse(parts[4]) ?? 0,
              'thumbnail': parts[5],
              'url': parts[6],
            });
          }
        }

        response
          ..write(json.encode({'results': results}))
          ..close();
      } else {
        response
          ..statusCode = 500
          ..write(json.encode({'error': 'yt-dlp search failed: ${result.stderr}'}))
          ..close();
      }
    } catch (e) {
      response
        ..statusCode = 500
        ..write(json.encode({'error': e.toString()}))
        ..close();
    }
  }

  static Future<void> _handleDownload(HttpRequest request, HttpResponse response) async {
    final url = request.uri.queryParameters['url'];

    if (url == null || url.isEmpty) {
      response
        ..statusCode = 400
        ..write(json.encode({'error': 'Missing url parameter'}))
        ..close();
      return;
    }

    try {
      final infoArgs = [
        '--print',
        '%(id)s|||%(title)s|||%(channel)s|||%(duration)s|||%(view_count)s|||%(thumbnail)s|||%(formats)s',
        '--no-warnings',
        '--quiet',
        url
      ];

      final infoResult = await Process.run('yt-dlp', infoArgs);

      if (infoResult.exitCode != 0) {
        response
          ..statusCode = 500
          ..write(json.encode({'error': 'Failed to get video info'}))
          ..close();
        return;
      }

      final lines = infoResult.stdout.toString().trim().split('\n');
      if (lines.isEmpty) {
        response
          ..statusCode = 404
          ..write(json.encode({'error': 'No video info found'}))
          ..close();
        return;
      }

      final parts = lines[0].split('|||');
      if (parts.length < 7) {
        response
          ..statusCode = 500
          ..write(json.encode({'error': 'Invalid video info format'}))
          ..close();
        return;
      }

      final audioArgs = [
        '-f', 'bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio',
        '--get-url',
        '--no-warnings',
        '--quiet',
        url
      ];

      final audioResult = await Process.run('yt-dlp', audioArgs);

      final audioUrl = audioResult.exitCode == 0 ? audioResult.stdout.toString().trim() : null;

      final result = {
        'id': parts[0],
        'title': parts[1],
        'channel': parts[2],
        'duration': int.tryParse(parts[3]) ?? 0,
        'views': int.tryParse(parts[4]) ?? 0,
        'thumbnail': parts[5],
        'audio_url': audioUrl,
        'download_url': audioUrl,
      };

      response
        ..write(json.encode(result))
        ..close();
    } catch (e) {
      response
        ..statusCode = 500
        ..write(json.encode({'error': e.toString()}))
        ..close();
    }
  }

  static bool get isRunning => _server != null;
  static String get serverUrl => 'http://localhost:$_port';
}
