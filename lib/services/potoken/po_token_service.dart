import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  // BotGuard PoToken needs a JS engine. On Android/iOS that's the free
  // system WebView (see po_token_webview.dart, same as Metrolist/NewPipe).
  // On desktop there is no system WebView: flutter_inappwebview has no
  // stable Linux backend (only beta WPE WebKit with system deps + crashes),
  // and an embedded QuickJS engine can't mint either — BotGuard fills
  // webPoSignalOutput from background tasks QuickJS never runs.
  // So skip PoToken on desktop entirely (zero bloat, zero 10s timeout) and
  // rely on the proven no-token path: token-less InnerTube clients
  // (VISIONOS/ANDROID_VR/...) + youtube_explode safari/android fallback in
  // ytdl_service.dart, which returns playable progressive audio for all
  // probed tracks including licensed ones.
  static bool get _potokenSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Whether this platform can mint a PoToken at all. Desktop cannot, so
  /// callers use this to pick a stream source that works without one.
  static bool get supported => _potokenSupported;

  Future<PoTokenSession?> getSession({String? videoId}) async {
    if (_broken || !_potokenSupported) return null;
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
