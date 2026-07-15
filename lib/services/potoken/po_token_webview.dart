import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'js_util.dart';

class PoTokenException implements Exception {
  final String message;
  PoTokenException(this.message);
  @override
  String toString() => 'PoTokenException: $message';
}

// ported from newpipe's potoken webview
class PoTokenWebView {
  static const _requestKey = 'O43z0dpjhgX20SCx4KAo';
  static const _apiKey = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  final Completer<void> _ready = Completer<void>();
  final Map<String, Completer<String>> _pending = {};
  DateTime? _expiresAt;
  var _requestCounter = 0;
  bool _closed = false;

  bool get isExpired =>
      _expiresAt == null || DateTime.now().isAfter(_expiresAt!);

  Future<void> init() async {
    final html = await rootBundle.loadString('assets/potoken/po_token.html');
    // kick off the flow as soon as the page's own script has loaded
    final data = html.replaceFirst('</script>',
        "\nwindow.flutter_inappwebview.callHandler('downloadAndRunBotguard');</script>");

    _headless = HeadlessInAppWebView(
      initialSettings:
          InAppWebViewSettings(userAgent: _userAgent, javaScriptEnabled: true),
      initialData: InAppWebViewInitialData(
          data: data, baseUrl: WebUri('https://www.youtube.com')),
      onWebViewCreated: (c) {
        _controller = c;
        c.addJavaScriptHandler(
            handlerName: 'downloadAndRunBotguard',
            callback: (_) => _downloadAndRunBotguard());
        c.addJavaScriptHandler(
            handlerName: 'onRunBotguardResult',
            callback: (a) => _onRunBotguardResult(a.first as String));
        c.addJavaScriptHandler(
            handlerName: 'onJsError',
            callback: (a) => _failInit(PoTokenException('js: ${a.first}')));
        c.addJavaScriptHandler(
            handlerName: 'onObtainPoTokenResult',
            callback: (a) => _resolveToken(a[0] as String, a[1] as String));
        c.addJavaScriptHandler(
            handlerName: 'onObtainPoTokenError',
            callback: (a) => _rejectToken(a[0] as String, a[1] as String));
      },
    );

    await _headless!.run();
    await _ready.future.timeout(const Duration(seconds: 45), onTimeout: () {
      close();
      throw PoTokenException('potoken init timed out');
    });
  }

  Future<void> _downloadAndRunBotguard() async {
    final body = await _jnn('Create', '[ "$_requestKey" ]');
    final challenge = parseChallengeData(body);
    await _controller?.evaluateJavascript(source: '''
      try {
        var data = $challenge;
        runBotGuard(data).then(function(r) {
          window.webPoSignalOutput = r.webPoSignalOutput;
          window.flutter_inappwebview.callHandler('onRunBotguardResult', r.botguardResponse);
        }).catch(function(e){ window.flutter_inappwebview.callHandler('onJsError', ''+e); });
      } catch(e) { window.flutter_inappwebview.callHandler('onJsError', ''+e); }
    ''');
  }

  Future<void> _onRunBotguardResult(String botguardResponse) async {
    final body = await _jnn('GenerateIT', '[ "$_requestKey", "$botguardResponse" ]');
    final (integrityToken, ttl) = parseIntegrityTokenData(body);
    // refresh 10 min before youtube expires it
    _expiresAt = DateTime.now()
        .add(Duration(seconds: ttl))
        .subtract(const Duration(minutes: 10));
    await _controller?.evaluateJavascript(
        source: 'window.integrityToken = $integrityToken;');
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<String> generatePoToken(String identifier) async {
    if (_closed) throw PoTokenException('potoken webview closed');
    // key per call so concurrent mints for the same id don't clobber each other
    final key = '$identifier#${_requestCounter++}';
    final completer = Completer<String>();
    _pending[key] = completer;
    await _controller?.evaluateJavascript(source: '''
      (function(){
        try {
          var id = ${stringToU8(identifier)};
          var u8 = obtainPoToken(window.webPoSignalOutput, window.integrityToken, id);
          window.flutter_inappwebview.callHandler('onObtainPoTokenResult', "$key", Array.from(u8).join(","));
        } catch(e) { window.flutter_inappwebview.callHandler('onObtainPoTokenError', "$key", ''+e); }
      })();
    ''');
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _pending.remove(key);
      throw PoTokenException('potoken generation timed out');
    });
  }

  void _resolveToken(String key, String u8) {
    final c = _pending.remove(key);
    if (c == null) return;
    try {
      c.complete(u8ToBase64(u8));
    } catch (e) {
      c.completeError(PoTokenException('$e'));
    }
  }

  void _rejectToken(String key, String error) {
    _pending.remove(key)?.completeError(PoTokenException(error));
  }

  void _failInit(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
    close();
  }

  Future<String> _jnn(String endpoint, String data) async {
    final r = await http.post(
      Uri.parse('https://www.youtube.com/api/jnn/v1/$endpoint'),
      headers: const {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json+protobuf',
        'x-goog-api-key': _apiKey,
        'x-user-agent': 'grpc-web-javascript/0.1',
      },
      body: data,
    );
    if (r.statusCode != 200 || r.body.isEmpty) {
      throw PoTokenException('$endpoint failed (${r.statusCode})');
    }
    return r.body;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _headless?.dispose();
    _headless = null;
    _controller = null;
  }
}
