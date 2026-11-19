@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:test/test.dart';

class Fixture {
  Fixture(Map<String, Object?> j)
    : source = j['source']! as String,
      label = j['label']! as String,
      version = j['version']! as int,
      ec = j['ec']! as String,
      mask = j['mask'] as int?,
      expect = (j['expect']! as Map).cast<String, Object?>(),
      matrix = _unpack(j['size']! as int, (j['rows']! as List).cast<String>());

  final String source;
  final String label;
  final int version;
  final String ec;
  final int? mask;
  final Map<String, Object?> expect;
  final BitMatrix matrix;

  static BitMatrix _unpack(int n, List<String> rows) {
    final m = BitMatrix.square(n);
    for (var y = 0; y < n; y++) {
      final bits = BigInt.parse(
        rows[y],
        radix: 16,
      ).toRadixString(2).padLeft(rows[y].length * 4, '0');
      for (var x = 0; x < n; x++) {
        if (bits[x] == '1') m.set(x, y);
      }
    }
    return m;
  }

  @override
  String toString() => '$source "$label" v$version-$ec';
}

List<Fixture> loadFixtures() {
  final raw = jsonDecode(
    File('test/fixtures/oracle_symbols.json').readAsStringSync(),
  ) as List;
  return [for (final j in raw) Fixture((j as Map).cast<String, Object?>())];
}

void checkResult(Fixture f, DecodeResult r) {
  if (f.expect.containsKey('text')) {
    expect(
      r,
      isA<DecodeSuccess>(),
      reason: '$f → ${r is DecodeFailure ? r.failure : ''}',
    );
    final code = (r as DecodeSuccess).code;
    expect(code.text, f.expect['text'], reason: '$f');
    expect(code.version, f.version, reason: '$f');
    expect(code.ecLevel.name, f.ec, reason: '$f');
    if (f.mask != null) expect(code.mask, f.mask, reason: '$f');
  } else {
    expect(r, isA<DecodeFailure>(), reason: '$f');
    final failure = (r as DecodeFailure).failure;
    expect(failure.name, f.expect['failure'], reason: '$f');
    expect(
      failure.toString(),
      contains(f.expect['detail']! as String),
      reason: '$f',
    );
  }
}

void main() {
  final fixtures = loadFixtures();

  test('matrix decoder reads every segno / qrencode symbol as the encoder intended', () {
    expect(fixtures.map((f) => f.source).toSet(), {'segno', 'qrencode'});
    for (final f in fixtures) {
      checkResult(f, QrMatrixDecoder.decode(f.matrix));
    }
  });
}
