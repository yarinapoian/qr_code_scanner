@Tags(['unit'])
library;

import 'package:qr_scan_core/src/common/bit_matrix.dart';
import 'package:qr_scan_core/src/detect/finder_pattern.dart';
import 'package:test/test.dart';

import '../support/oracle_qr.dart';
import '../support/symbols.dart';

BitMatrix upscale(BitMatrix m, int s, {int q = 4}) {
  final n = m.width;
  final out = BitMatrix((n + 2 * q) * s, (n + 2 * q) * s);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (m.get(x, y)) out.setRegion((x + q) * s, (y + q) * s, s, s);
    }
  }
  return out;
}

void main() {
  test('ISO 18004 §6.3.3: finds the three finders of a symbol at the exact centres', () {
    for (final s in [1, 2, 3, 5]) {
      final m = matrixOf(oracleEncode('FINDER', minVersion: 3));
      final img = upscale(m, s);
      final found = FinderPatternFinder(img).find();
      expect(found, hasLength(3), reason: 'scale $s');
      final n = m.width;
      final expected = [
        (3.5, 3.5),
        (n - 3.5, 3.5),
        (3.5, n - 3.5),
      ].map((p) => ((p.$1 + 4) * s, (p.$2 + 4) * s));
      for (final (ex, ey) in expected) {
        expect(
          found.any(
            (f) =>
                (f.x - ex).abs() <= 0.5 * s + 0.5 &&
                (f.y - ey).abs() <= 0.5 * s + 0.5,
          ),
          isTrue,
          reason: 'scale $s expected ($ex, $ey) in $found',
        );
      }
      for (final f in found) {
        expect(f.moduleSize, closeTo(s.toDouble(), 0.5 * s + 0.3));
      }
    }
  });
}
