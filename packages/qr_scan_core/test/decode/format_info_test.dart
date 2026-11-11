@Tags(['unit'])
library;

import 'package:qr_scan_core/src/decode/format_info.dart';
import 'package:test/test.dart';

const isoFormatTable = [
  0x5412,
  0x5125,
  0x5E7C,
  0x5B4B,
  0x45F9,
  0x40CE,
  0x4F97,
  0x4AA0,
  0x77C4,
  0x72F3,
  0x7DAA,
  0x789D,
  0x662F,
  0x6318,
  0x6C41,
  0x6976,
  0x1689,
  0x13BE,
  0x1CE7,
  0x19D0,
  0x0762,
  0x0255,
  0x0D0C,
  0x083B,
  0x355F,
  0x3068,
  0x3F31,
  0x3A06,
  0x24B4,
  0x2183,
  0x2EDA,
  0x2BED,
];

Iterable<int> errorPatterns(int k) sync* {
  for (var e = 0; e < 1 << 15; e++) {
    if (bitCount(e) <= k) yield e;
  }
}

void main() {
  test('ISO 18004 §7.9: every value decodes under every ≤3-bit error (32 × 576 cases)', () {
    final patterns = errorPatterns(3).toList();
    expect(patterns, hasLength(1 + 15 + 105 + 455));
    for (var d = 0; d < 32; d++) {
      for (final e in patterns) {
        final r = FormatInfoCodec.decode([isoFormatTable[d] ^ e]);
        expect(r, isNotNull, reason: 'data $d error $e');
        expect(r!.dataBits, d);
        expect(r.bitErrors, bitCount(e));
      }
    }
  });
}
