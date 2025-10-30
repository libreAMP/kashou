import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalMediaServer {
  LocalMediaServer._();

  static final LocalMediaServer instance = LocalMediaServer._();

  HttpServer? _server;
  String? _hostAddress;

  Future<String?> ensureStarted() async {
    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
      _server!.listen(_handleRequest);
    }

    _hostAddress ??= await _resolveHostAddress();

    if (_hostAddress == null) {
      await stop();
      return null;
    }

    return _buildBaseUrl();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _hostAddress = null;
  }

  String? buildStreamUrl(String filePath) {
    final baseUrl = _buildBaseUrl();
    if (baseUrl == null) return null;

    final encodedPath = base64UrlEncode(utf8.encode(filePath));
    return '$baseUrl/stream?path=$encodedPath';
  }

  Future<String?> _resolveHostAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (!_isPrivateAddress(value)) {
          continue;
        }
        return value;
      }
    }

    return null;
  }

  bool _isPrivateAddress(String address) {
    return address.startsWith('10.') ||
        address.startsWith('192.168.') ||
        address.startsWith('172.16.') ||
        address.startsWith('172.17.') ||
        address.startsWith('172.18.') ||
        address.startsWith('172.19.') ||
        address.startsWith('172.20.') ||
        address.startsWith('172.21.') ||
        address.startsWith('172.22.') ||
        address.startsWith('172.23.') ||
        address.startsWith('172.24.') ||
        address.startsWith('172.25.') ||
        address.startsWith('172.26.') ||
        address.startsWith('172.27.') ||
        address.startsWith('172.28.') ||
        address.startsWith('172.29.') ||
        address.startsWith('172.30.') ||
        address.startsWith('172.31.');
  }

  String? _buildBaseUrl() {
    if (_server == null || _hostAddress == null) return null;
    return 'http://$_hostAddress:${_server!.port}';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'GET') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }

      if (request.uri.path == '/stream') {
        await _serveAudio(request);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (error) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}

      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveAudio(HttpRequest request) async {
    final encodedPath = request.uri.queryParameters['path'];
    if (encodedPath == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    String decodedPath;
    try {
      decodedPath = utf8.decode(base64Url.decode(encodedPath));
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final file = File(decodedPath);
    final exists = await file.exists();
    if (!exists) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fileLength = await file.length();
    final mimeType = _inferMimeType(file.path);
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*');

    if (mimeType != null) {
      request.response.headers.contentType = ContentType.parse(mimeType);
    } else {
      request.response.headers.contentType = ContentType.binary;
    }

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final isHeadRequest = request.method == 'HEAD';

    Future<void> sendFullContent() async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, fileLength.toString());
      if (isHeadRequest) {
        await request.response.close();
        return;
      }

      try {
        await file.openRead().pipe(request.response);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
        } catch (_) {}

        try {
          await request.response.close();
        } catch (_) {}
      }
    }

    if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) {
      await sendFullContent();
      return;
    }

    // Only handle a single byte range.
    final rangeValue = rangeHeader.substring(6).trim();
    if (rangeValue.contains(',')) {
      request.response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    int? start;
    int? end;

    final parts = rangeValue.split('-');
    if (parts.length != 2) {
      request.response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    final startPart = parts[0].trim();
    final endPart = parts[1].trim();

    if (startPart.isEmpty && endPart.isEmpty) {
      await sendFullContent();
      return;
    }

    if (startPart.isNotEmpty) {
      start = int.tryParse(startPart);
    }

    if (endPart.isNotEmpty) {
      end = int.tryParse(endPart);
    }

    if (start == null) {
      // Suffix range: bytes=-<length>
      final suffixLength = end;
      if (suffixLength == null || suffixLength <= 0) {
        request.response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
        await request.response.close();
        return;
      }
      start = fileLength - suffixLength;
      if (start < 0) {
        start = 0;
      }
      end = fileLength - 1;
    } else {
      if (end == null || end >= fileLength) {
        end = fileLength - 1;
      }
    }

    if (start < 0 || start >= fileLength || end! < start) {
      request.response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    final chunkLength = end - start + 1;

    request.response
      ..statusCode = HttpStatus.partialContent
      ..headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$fileLength')
      ..headers.set(HttpHeaders.contentLengthHeader, chunkLength.toString());

    if (isHeadRequest) {
      await request.response.close();
      return;
    }

    try {
      await file.openRead(start, end + 1).pipe(request.response);
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}

      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  String? _inferMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/mp4';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';

    return null;
  }
}
