@Tags(['unit'])
library;

import 'package:qr_scan_core/src/common/version.dart';
import 'package:qr_scan_core/src/decode/bitstream.dart';
import 'package:test/test.dart';

import '../support/bit_writer.dart';

final v1 = Version.byNumber(1);

String? textOf(BitWriter w, {Version? version, int capacity = 19}) =>
    BitstreamParser.parse(
      w.toBytes(capacity: capacity),
      version ?? v1,
    ).message?.text;

void main() {
  test('ISO 18004 §7.4.3: numeric mode, Annex I example "01234567"', () {
    final w = BitWriter()
      ..bits('0001 0000001000 0000001100 0101011001 1000011 0000');
    expect(textOf(w, capacity: 16), '01234567');
  });

  test('ISO 18004 §7.4.4: alphanumeric mode, "AC-42"', () {
    final w = BitWriter()
      ..bits('0010 000000101 00111001110 11100111001 000010 0000');
    expect(textOf(w), 'AC-42');
  });

  test('ISO 18004 §7.4.5: byte mode, UTF-8 Cyrillic and emoji', () {
    final w = BitWriter()
      ..write(4, 4)
      ..write(8, 8);
    for (final b in [0xD0, 0x9F, 0xD1, 0x80, 0xF0, 0x9F, 0x98, 0x80]) {
      w.write(b, 8);
    }
    w.write(0, 4);
    expect(textOf(w), 'Пр😀');
  });

  test('ISO 18004 §7.4.2: ECI 3 is ISO-8859-1, ECI 26 is UTF-8', () {
    for (final (eci, text) in [(3, 'Ã©'), (26, 'é')]) {
      final w = BitWriter()
        ..write(7, 4)
        ..write(eci, 8)
        ..write(4, 4)
        ..write(2, 8)
        ..write(0xC3, 8)
        ..write(0xA9, 8)
        ..write(0, 4);
      expect(textOf(w), text, reason: 'ECI $eci');
    }
  });

  test(
    'ISO 18004 Table 3: count lengths at version boundaries 9/10, 26/27',
    () {
      for (final (v, nBits, aBits, bBits) in [
        (9, 10, 9, 8),
        (10, 12, 11, 16),
        (26, 12, 11, 16),
        (27, 14, 13, 16),
      ]) {
        final w = BitWriter()
          ..write(1, 4)
          ..write(1, nBits)
          ..write(7, 4)
          ..write(2, 4)
          ..write(1, aBits)
          ..write(10, 6)
          ..write(4, 4)
          ..write(1, bBits)
          ..write(0x7A, 8)
          ..write(0, 4);
        expect(
          textOf(w, version: Version.byNumber(v), capacity: 40),
          '7Az',
          reason: 'v$v',
        );
      }
    },
  );
}
