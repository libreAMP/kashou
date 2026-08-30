import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'po_token_webview.dart';

class PoTokenSession {
  final String visitorData;
  final String poToken;
  final String? gvsPoToken;
  PoTokenSession(this.visitorData, this.poToken, {this.gvsPoToken});
}

class PoTokenService {
  static final PoTokenService instance = PoTokenService._();
  PoTokenService._();

  PoTokenWebView? _webView;
  String? _visitorData;
  String? _poToken;
  bool _broken = false;

  Future<PoTokenSession?> getSession({String? videoId}) async {
    if (_broken) return null;
    try {
      _visitorData ??= await _fetchVisitorData();

      if (_webView == null || _webView!.isExpired) {
        _webView?.close();
        _webView = PoTokenWebView();
        await _webView!.init().timeout(const Duration(seconds: 10));
        _poToken = null;
      }
      _poToken ??= await _webView!.generatePoToken(_visitorData!);

      String? gvsPoToken;
      if (videoId != null) {
        try {
          gvsPoToken = await _webView!.generatePoToken(videoId);
        } catch (e) {
          debugPrint('[potoken] gvs token unavailable: $e');
        }
      }

      return PoTokenSession(_visitorData!, _poToken!, gvsPoToken: gvsPoToken);
    } catch (e) {
      debugPrint('[potoken] unavailable, falling back: $e');
      _webView?.close();
      _webView = null;
      _poToken = null;
      _broken = true;
      return null;
    }
  }

  Future<String> _fetchVisitorData() async {
    final r = await http.post(
      Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240726.00.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'videoId': 'dQw4w9WgXcQ',
      }),
    ).timeout(const Duration(seconds: 5));
    final vd = (jsonDecode(r.body)['responseContext']?['visitorData']) as String?;
    if (vd == null || vd.isEmpty) {
      throw PoTokenException('could not obtain visitorData');
    }
    return vd;
  }

  void dispose() {
    _webView?.close();
    _webView = null;
  }
}
