import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:http/http.dart' as http;

// youtube music browse endpoints
class YtMusicService {
  static const _base =
      'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';
  static const _clientVersion = '1.20260213.01.00';

  static final Map<String, _Cached> _cache = HashMap();
  static const _ttl = Duration(minutes: 15);

  const YtMusicService();

  Future<Map<String, dynamic>?> _browse(String browseId, {String? params}) async {
    try {
      final res = await http.post(
        Uri.parse(_base),
        headers: const {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0',
          'X-Goog-Api-Format-Version': '1',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': _clientVersion,
              // follow the device locale
              'hl': PlatformDispatcher.instance.locale.languageCode,
              if (PlatformDispatcher.instance.locale.countryCode != null)
                'gl': PlatformDispatcher.instance.locale.countryCode,
            }
          },
          'browseId': browseId,
          if (params != null) 'params': params,
        }),
      );
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getHomeShelves() async {
    final hit = _get('home');
    if (hit != null) return hit;

    final json = await _browse('FEmusic_home');
    if (json == null) return const [];

    final shelves = <Map<String, dynamic>>[];
    final raw = <dynamic>[];
    _collect(json, 'musicCarouselShelfRenderer', raw);
    for (final shelf in raw) {
      final title = _text(shelf['header']?['musicCarouselShelfBasicHeaderRenderer']
          ?['title']);
      final items = _playlistItems(shelf['contents']);
      if (items.isNotEmpty) {
        shelves.add({'title': title ?? 'For you', 'items': items});
      }
    }
    _put('home', shelves);
    return shelves;
  }

  Future<List<Map<String, dynamic>>> getMoodsAndGenres() async {
    final hit = _get('moods');
    if (hit != null) return hit;

    final json = await _browse('FEmusic_moods_and_genres');
    if (json == null) return const [];

    final sections = <Map<String, dynamic>>[];
    final grids = <dynamic>[];
    _collect(json, 'gridRenderer', grids);
    for (final grid in grids) {
      final section = _text(grid['header']?['gridHeaderRenderer']?['title']);
      final items = <Map<String, dynamic>>[];
      final btns = <dynamic>[];
      _collect(grid, 'musicNavigationButtonRenderer', btns);
      for (final b in btns) {
        final title = _text(b['buttonText']);
        final params = b['clickCommand']?['browseEndpoint']?['params'];
        if (title != null && params is String) {
          items.add({'title': title, 'params': params});
        }
      }
      if (items.isNotEmpty) {
        sections.add({'section': section ?? '', 'items': items});
      }
    }
    _put('moods', sections);
    return sections;
  }

  Future<List<Map<String, dynamic>>> getMoodCategory(String params) async {
    final key = 'cat_$params';
    final hit = _get(key);
    if (hit != null) return hit;

    final json =
        await _browse('FEmusic_moods_and_genres_category', params: params);
    if (json == null) return const [];

    final shelves = <Map<String, dynamic>>[];
    final raw = <dynamic>[];
    _collect(json, 'musicCarouselShelfRenderer', raw);
    for (final shelf in raw) {
      final title = _text(shelf['header']?['musicCarouselShelfBasicHeaderRenderer']
          ?['title']);
      final items = _playlistItems(shelf['contents']);
      if (items.isNotEmpty) {
        shelves.add({'title': title ?? '', 'items': items});
      }
    }
    // some categories lay playlists out in a grid instead of a carousel
    if (shelves.isEmpty) {
      final grids = <dynamic>[];
      _collect(json, 'gridRenderer', grids);
      for (final grid in grids) {
        final items = _playlistItems(grid['items']);
        if (items.isNotEmpty) {
          shelves.add({'title': _text(grid['header']?['gridHeaderRenderer']?['title']) ?? '', 'items': items});
        }
      }
    }
    _put(key, shelves);
    return shelves;
  }

  // community playlists filter
  Future<List<Map<String, dynamic>>> searchPlaylists(String query,
      {int limit = 12}) async {
    final key = 'spl_${query.trim().toLowerCase()}';
    final hit = _get(key);
    if (hit != null) return hit;

    try {
      final res = await http.post(
        Uri.parse(
            'https://music.youtube.com/youtubei/v1/search?prettyPrint=false'),
        headers: const {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': _clientVersion,
              'hl': PlatformDispatcher.instance.locale.languageCode,
              if (PlatformDispatcher.instance.locale.countryCode != null)
                'gl': PlatformDispatcher.instance.locale.countryCode,
            }
          },
          'query': query,
          'params': 'EgeKAQQoAEABagoQAxAEEAoQCRAF',
        }),
      );
      if (res.statusCode != 200) return const [];

      final rows = <dynamic>[];
      _collect(jsonDecode(res.body), 'musicResponsiveListItemRenderer', rows);

      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final browseId = r['navigationEndpoint']?['browseEndpoint']?['browseId'];
        if (browseId is! String || !browseId.startsWith('VL')) continue;
        final cols = r['flexColumns'] as List?;
        final title = cols != null && cols.isNotEmpty
            ? _text(cols[0]['musicResponsiveListItemFlexColumnRenderer']
                ?['text'])
            : null;
        if (title == null) continue;
        final subtitle = cols != null && cols.length > 1
            ? _text(cols[1]['musicResponsiveListItemFlexColumnRenderer']
                ?['text'])
            : null;
        out.add({
          'playlistId': browseId,
          'title': title,
          'subtitle': subtitle ?? '',
          'thumbnail': _lastThumb(r['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails']),
        });
        if (out.length >= limit) break;
      }
      _put(key, out);
      return out;
    } catch (_) {
      return const [];
    }
  }

  // songs inside a playlist
  Future<List<Map<String, dynamic>>> getPlaylistSongs(String playlistId,
      {int limit = 100}) async {
    final id = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
    final key = 'pl_$id';
    final hit = _get(key);
    if (hit != null) return hit;

    final json = await _browse('VL$id');
    if (json == null) return const [];

    final rows = <dynamic>[];
    _collect(json, 'musicResponsiveListItemRenderer', rows);

    final songs = <Map<String, dynamic>>[];
    for (final r in rows) {
      final videoId = _videoId(r);
      if (videoId == null) continue;
      final cols = r['flexColumns'] as List?;
      final title = cols != null && cols.isNotEmpty
          ? _text(cols[0]['musicResponsiveListItemFlexColumnRenderer']?['text'])
          : null;
      if (title == null) continue;
      final artist = cols != null && cols.length > 1
          ? _text(cols[1]['musicResponsiveListItemFlexColumnRenderer']?['text'])
          : null;
      final thumb = _lastThumb(r['thumbnail']?['musicThumbnailRenderer']
          ?['thumbnail']?['thumbnails']);
      songs.add({
        'id': videoId,
        'title': title,
        'url': 'https://www.youtube.com/watch?v=$videoId',
        'channel': artist ?? '',
        'thumbnail': thumb,
        'duration': _duration(r),
      });
      if (songs.length >= limit) break;
    }
    _put(key, songs);
    return songs;
  }

  List<Map<String, dynamic>> _playlistItems(dynamic contents) {
    final out = <Map<String, dynamic>>[];
    if (contents is! List) return out;
    for (final c in contents) {
      final r = c['musicTwoRowItemRenderer'];
      if (r == null) continue;
      final nav = r['navigationEndpoint']?['browseEndpoint'];
      final browseId = nav?['browseId'] as String?;
      if (browseId == null || !browseId.startsWith('VL')) continue;
      out.add({
        'playlistId': browseId,
        'title': _text(r['title']) ?? '',
        'subtitle': _text(r['subtitle']) ?? '',
        'thumbnail': _lastThumb(r['thumbnailRenderer']?['musicThumbnailRenderer']
            ?['thumbnail']?['thumbnails']),
      });
    }
    return out;
  }

  String? _videoId(Map r) {
    final fromData = r['playlistItemData']?['videoId'];
    if (fromData is String) return fromData;
    final ov = <dynamic>[];
    _collect(r['overlay'], 'watchEndpoint', ov);
    if (ov.isNotEmpty) return ov.first['videoId'] as String?;
    return null;
  }

  int? _duration(Map r) {
    final fixed = r['fixedColumns'] as List?;
    if (fixed == null || fixed.isEmpty) return null;
    final t = _text(fixed.last['musicResponsiveListItemFixedColumnRenderer']
        ?['text']);
    return _clock(t);
  }

  String? _text(dynamic node) {
    if (node == null) return null;
    final runs = node['runs'];
    if (runs is List && runs.isNotEmpty) {
      return runs.map((e) => e['text'] ?? '').join();
    }
    return node['simpleText'] as String?;
  }

  String? _lastThumb(dynamic thumbs) {
    if (thumbs is List && thumbs.isNotEmpty) {
      return thumbs.last['url'] as String?;
    }
    return null;
  }

  int? _clock(String? c) {
    if (c == null) return null;
    final parts = c.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    var total = 0;
    for (final p in parts) {
      final n = int.tryParse(p.trim());
      if (n == null) return null;
      total = total * 60 + n;
    }
    return total;
  }

  static void _collect(dynamic node, String key, List out) {
    if (node is Map) {
      final v = node[key];
      if (v != null) out.add(v);
      for (final e in node.values) {
        _collect(e, key, out);
      }
    } else if (node is List) {
      for (final e in node) {
        _collect(e, key, out);
      }
    }
  }

  List<Map<String, dynamic>>? _get(String key) {
    final c = _cache[key];
    if (c != null && DateTime.now().difference(c.at) < _ttl) return c.value;
    return null;
  }

  void _put(String key, List<Map<String, dynamic>> value) {
    _cache[key] = _Cached(value);
  }
}

class _Cached {
  final List<Map<String, dynamic>> value;
  final DateTime at;
  _Cached(this.value) : at = DateTime.now();
}
