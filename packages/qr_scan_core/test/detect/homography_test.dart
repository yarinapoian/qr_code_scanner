@Tags(['unit'])
library;

import 'dart:math';

import 'package:qr_scan_core/src/common/geometry.dart';
import 'package:qr_scan_core/src/detect/perspective_transform.dart';
import 'package:test/test.dart';

import '../support/synthetic_photo.dart';

void main() {
  test('homography from the 8×8 system matches the closed-form one on random quads', () {
    final rnd = Random(5);
    for (var k = 0; k < 200; k++) {
      Point r(double cx, double cy) => Point(
        cx + rnd.nextDouble() * 40 - 20,
        cy + rnd.nextDouble() * 40 - 20,
      );
      final quad = [r(0, 0), r(200, 0), r(200, 200), r(0, 200)];
      final ours = PerspectiveTransform.fromPoints(const [
        Point(0, 0),
        Point(1, 0),
        Point(1, 1),
        Point(0, 1),
      ], quad)!;
      final oracle = Homography.unitSquareTo(quad);
      for (final (u, v) in [(0, 0), (1, 1), (0.5, 0.5), (0.1, 0.9)]) {
        expect(
          ours
              .apply(u.toDouble(), v.toDouble())
              .distanceTo(oracle.apply(u.toDouble(), v.toDouble())),
          lessThan(1e-6),
        );
      }
    }
  });
}
