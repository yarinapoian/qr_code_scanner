@Tags(['unit'])
library;

import 'package:qr_scan_core/src/common/gf256.dart';
import 'package:test/test.dart';

int peasantMul(int a, int b) {
  var r = 0;
  while (b > 0) {
    if (b & 1 != 0) r ^= a;
    a <<= 1;
    if (a & 0x100 != 0) a ^= 0x11D;
    b >>= 1;
  }
  return r;
}

void main() {
  test('ISO 18004 §7.5.2: GF(256) mul, add and div over all 256×256 pairs', () {
    for (var a = 0; a < 256; a++) {
      for (var b = 0; b < 256; b++) {
        expect(GF256.mul(a, b), peasantMul(a, b), reason: '$a*$b');
        expect(GF256.add(a, b), a ^ b);
        if (b != 0) expect(GF256.mul(GF256.div(a, b), b), a, reason: '$a/$b');
      }
    }
  });
}
