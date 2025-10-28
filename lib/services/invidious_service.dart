import 'dart:convert';
import 'package:http/http.dart' as http;

class InvidiousService {
  final String baseUrl;

  InvidiousService(this.baseUrl);

  Future<List<Map<String, dynamic>>> getTrending() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/trending'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/search?q=$query&type=video'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVideoDetails(String videoId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/videos/$videoId'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? getAudioStreamUrl(Map<String, dynamic> videoDetails) {
    final adaptiveFormats = videoDetails['adaptiveFormats'] as List?;
    if (adaptiveFormats != null) {
      // Find audio-only format
      for (final format in adaptiveFormats) {
        if (format['type'] == 'audio/webm' || format['type'] == 'audio/mp4') {
          return format['url'];
        }
      }
    }
    return null;
  }
}
