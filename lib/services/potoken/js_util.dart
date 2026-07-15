import 'dart:convert';

// newpipe's botguard challenge helpers, ported to dart

String parseChallengeData(String raw) {
  final scrambled = jsonDecode(raw) as List;

  final List challengeData;
  if (scrambled.length > 1 && scrambled[1] is String) {
    challengeData = jsonDecode(_descramble(scrambled[1] as String)) as List;
  } else {
    challengeData = scrambled[0] as List;
  }

  final safeScript = challengeData[1] is List
      ? (challengeData[1] as List).firstWhere((e) => e is String, orElse: () => null)
      : null;
  final trustedUrl = challengeData[2] is List
      ? (challengeData[2] as List).firstWhere((e) => e is String, orElse: () => null)
      : null;

  return jsonEncode({
    'messageId': challengeData[0],
    'interpreterJavascript': {
      'privateDoNotAccessOrElseSafeScriptWrappedValue': safeScript,
      'privateDoNotAccessOrElseTrustedResourceUrlWrappedValue': trustedUrl,
    },
    'interpreterHash': challengeData[3],
    'program': challengeData[4],
    'globalName': challengeData[5],
    'clientExperimentsStateBlob': challengeData[7],
  });
}

(String, int) parseIntegrityTokenData(String raw) {
  final data = jsonDecode(raw) as List;
  return (_base64ToU8(data[0] as String), (data[1] as num).toInt());
}

String stringToU8(String identifier) => _newUint8Array(utf8.encode(identifier));

// the minter hands the token back as comma-separated byte ints
String u8ToBase64(String poToken) {
  final bytes = poToken.split(',').map((s) => int.parse(s) & 0xFF).toList();
  return base64.encode(bytes).replaceAll('+', '-').replaceAll('/', '_');
}

// youtube scrambles by base64 then subtracting 97 from each byte, so undo it
String _descramble(String scrambled) {
  final bytes = _base64ToBytes(scrambled).map((b) => (b + 97) & 0xFF).toList();
  return utf8.decode(bytes, allowMalformed: true);
}

String _base64ToU8(String b64) => _newUint8Array(_base64ToBytes(b64));

String _newUint8Array(List<int> bytes) =>
    'new Uint8Array([${bytes.map((b) => b & 0xFF).join(',')}])';

// youtube's base64 variant swaps + / = for - _ .
List<int> _base64ToBytes(String b64) {
  final normalized =
      b64.replaceAll('-', '+').replaceAll('_', '/').replaceAll('.', '=');
  return base64.decode(base64.normalize(normalized));
}
