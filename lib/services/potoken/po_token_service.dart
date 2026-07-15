import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'po_token_webview.dart';

class PoTokenSession {
  final String visitorData;
  final String poToken;
  PoTokenSession(this.visitorData, this.poToken);
}

class PoTokenService {
  static final PoTokenService instance = PoTokenService._();
  PoTokenService._();

  PoTokenWebView? _webView;
  String? _visitorData;
  String? _poToken;
  Future<PoTokenSession?>? _inFlight;

  Future<PoTokenSession?> getSession() {
    // collapse concurrent callers onto one generation
    return _inFlight ??= _getSession().whenComplete(() => _inFlight = null);
  }

  Future<PoTokenSession?> _getSession() async {
    try {
      _visitorData ??= await _fetchVisitorData();

      if (_webView == null || _webView!.isExpired) {
        _webView?.close();
        _webView = PoTokenWebView();
        await _webView!.init();
        _poToken = null;
      }
      _poToken ??= await _webView!.generatePoToken(_visitorData!);

      debugPrint('[potoken] session ready (${_poToken!.length} chars)');
      return PoTokenSession(_visitorData!, _poToken!);
    } catch (e) {
      debugPrint('[potoken] unavailable, falling back: $e');
      _webView?.close();
      _webView = null;
      _poToken = null;
      return null;
    }
  }

  // any web player response carries responseContext.visitorData, grab one from a throwaway call
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
    );
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
