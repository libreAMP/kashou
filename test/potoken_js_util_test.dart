import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kashou/services/potoken/js_util.dart';

void main() {
  test('stringToU8 encodes bytes as a uint8array literal', () {
    expect(stringToU8('abc'), 'new Uint8Array([97,98,99])');
  });

  test('u8ToBase64 round-trips through youtube base64', () {
    // "abc" as comma bytes -> base64 "YWJj"
    expect(u8ToBase64('97,98,99'), 'YWJj');
  });

  test('parseChallengeData reads an unscrambled challenge array', () {
    final raw = jsonEncode([
      ['msg-1', null, null, 'hash-1', 'program-1', 'globalX', null, 'blob-1'],
    ]);
    final out = jsonDecode(parseChallengeData(raw)) as Map;
    expect(out['messageId'], 'msg-1');
    expect(out['program'], 'program-1');
    expect(out['globalName'], 'globalX');
    expect(out['clientExperimentsStateBlob'], 'blob-1');
  });

  test('parseIntegrityTokenData returns a token literal and ttl', () {
    final raw = jsonEncode(['YWJj', 3600]);
    final (token, ttl) = parseIntegrityTokenData(raw);
    expect(token, 'new Uint8Array([97,98,99])');
    expect(ttl, 3600);
  });
}
