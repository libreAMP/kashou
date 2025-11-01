import 'dart:convert';

import 'package:http/http.dart' as http;

class YtdlWrapperService {
  final String baseUrl;

  const YtdlWrapperService(this.baseUrl);

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
    );
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 10,
  }) async {
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
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> fetchAudioDetails(String videoUrl) async {
    try {
      final response = await http.get(
        _buildUri('/download', {
          'url': videoUrl,
        }),
        headers: const {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> healthcheck() async {
    try {
      final response = await http.get(_buildUri('/'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
