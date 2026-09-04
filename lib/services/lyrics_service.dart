import 'dart:convert';

import 'package:http/http.dart' as http;

class LyricLine {
  LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class LyricsResult {
  LyricsResult({this.lines = const [], this.plain = ''});

  final List<LyricLine> lines;
  final String plain;

  bool get isEmpty => lines.isEmpty && plain.trim().isEmpty;
}

class LyricsService {
  static const _ua = {'User-Agent': 'kashou/1.0'};
  static final RegExp _lrcTime = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');

  static Future<LyricsResult> fetch(String title, String artist) async {
    Map<String, dynamic>? json;
    try {
      var resp = await http.get(
        Uri.https('lrclib.net', '/api/get', {
          'artist_name': artist,
          'track_name': title,
        }),
        headers: _ua,
      );
      if (resp.statusCode == 200) {
        json = jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        final search = await http.get(
          Uri.https('lrclib.net', '/api/search', {'q': '$title $artist'}),
          headers: _ua,
        );
        if (search.statusCode == 200) {
          final list = jsonDecode(search.body) as List;
          if (list.isNotEmpty) {
            json = list.first as Map<String, dynamic>;
          }
        }
      }
    } catch (_) {
      return LyricsResult();
    }
    if (json == null) return LyricsResult();
    final synced = json['syncedLyrics'] as String?;
    final plain = json['plainLyrics'] as String? ?? '';
    return LyricsResult(
      lines: synced != null ? _parseLrc(synced) : const [],
      plain: plain,
    );
  }

  static List<LyricLine> _parseLrc(String lrc) {
    final out = <LyricLine>[];
    for (final line in lrc.split('\n')) {
      final m = _lrcTime.firstMatch(line);
      if (m == null) continue;
      final min = int.tryParse(m.group(1)!) ?? 0;
      final sec = int.tryParse(m.group(2)!) ?? 0;
      final frac = m.group(3);
      final ms = frac == null ? 0 : int.tryParse(frac.padRight(3, '0')) ?? 0;
      final text = line.substring(m.end).trim();
      if (text.isEmpty) continue;
      out.add(LyricLine(
        Duration(minutes: min, seconds: sec, milliseconds: ms),
        text,
      ));
    }
    return out;
  }
}
