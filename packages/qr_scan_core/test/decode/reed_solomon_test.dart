@Tags(['unit'])
library;

import 'dart:math';

import 'package:qr_scan_core/src/decode/reed_solomon.dart';
import 'package:test/test.dart';

const isoData = [
  0x10,
  0x20,
  0x0C,
  0x56,
  0x61,
  0x80,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
];
const isoEc = [0xA5, 0x24, 0xD4, 0xC1, 0xED, 0x36, 0xC7, 0x87, 0x2C, 0x55];

List<int> damage(List<int> cw, int errors, Random rnd) {
  final out = List<int>.of(cw);
  final positions = (List<int>.generate(
    cw.length,
    (i) => i,
  )..shuffle(rnd)).take(errors);
  for (final p in positions) {
    out[p] ^= 1 + rnd.nextInt(255);
  }
  return out;
}

void main() {
  final codeword = [...isoData, ...isoEc];

  test('ISO 18004 §7.5.2: 0 errors: syndromes are zero, nothing corrected', () {
    expect(ReedSolomon.syndromes(codeword, 10), everyElement(0));
    expect(ReedSolomon.correct(List.of(codeword), 10), 0);
  });

  test('ISO 18004 §7.5.2: 1 error at every position is corrected', () {
    for (var p = 0; p < codeword.length; p++) {
      for (final e in [1, 0x80, 0xFF]) {
        final r = List<int>.of(codeword);
        r[p] ^= e;
        expect(ReedSolomon.correct(r, 10), 1, reason: 'pos $p');
        expect(r, codeword);
      }
    }
  });

  test('ISO 18004 §7.5.2: exactly t errors are corrected exactly (t = 5)', () {
    final rnd = Random(1);
    for (var k = 0; k < 2000; k++) {
      final r = damage(codeword, 5, rnd);
      expect(ReedSolomon.correct(r, 10), 5);
      expect(r, codeword);
    }
  });

  test('ISO 18004 §7.5.2: t+1 errors give failure or a different valid codeword, never the input', () {
    final rnd = Random(2);
    var failures = 0;
    for (var k = 0; k < 2000; k++) {
      final r = damage(codeword, 6, rnd);
      final before = List<int>.of(r);
      final n = ReedSolomon.correct(r, 10);
      if (n == null) {
        failures++;
        expect(r, before, reason: 'uncorrectable block must be left unchanged');
      } else {
        expect(r, isNot(codeword));
        expect(ReedSolomon.syndromes(r, 10), everyElement(0));
        expect(n, lessThanOrEqualTo(5));
      }
    }
    expect(failures, greaterThan(1900), reason: 'miscorrection must be rare');
  });
}
