@Tags(['unit'])
library;

import 'package:qr_scan_core/src/image/binarizer.dart';
import 'package:test/test.dart';

import '../support/oracle_qr.dart';
import '../support/symbols.dart';
import '../support/synthetic_photo.dart';

void main() {
  test(
    '50 % shadow over half the code: local 8×8 ≈ exact, global Otsu fails',
    () {
      final p = renderCode(
        matrixOf(oracleEncode('SHADOW', minVersion: 4)),
        pose: const Pose(moduleSize: 4),
        options: const PhotoOptions(shadow: 0.5),
      );
      final local = binarizationErrorRate(
        p,
        const LocalBlockBinarizer().binarize(p.image),
      );
      final global = binarizationErrorRate(
        p,
        const OtsuBinarizer().binarize(p.image),
      );
      expect(local, lessThan(0.01));
      expect(global, greaterThan(0.1));
    },
  );
}
