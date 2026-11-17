@Tags(['property'])
library;

import 'package:kiri_check/kiri_check.dart';
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:test/test.dart';

import '../support/oracle_qr.dart';
import '../support/symbols.dart';
import '../support/synthetic_photo.dart';
import '../support/text_gen.dart';

const seed = 20261116;

Arbitrary<(String, int, int, Pose, PhotoOptions)> mvpPhoto() => combine5(
  anyText(maxLength: 40),
  integer(min: 1, max: 25),
  integer(min: 0, max: 3),
  combine4(
    float(min: 3.5, max: 7),
    float(min: 0, max: 360),
    float(min: -22, max: 22),
    float(min: -18, max: 18),
  ).map(
    (t) => Pose(
      moduleSize: t.$1,
      rotationDeg: t.$2,
      tiltXDeg: t.$3,
      tiltYDeg: t.$4,
    ),
  ),
  combine4(
    float(min: 0, max: 10),
    integer(min: 0, max: 1),
    float(min: 0, max: 0.5),
    integer(min: 0, max: 1 << 30),
  ).map(
    (t) => PhotoOptions(
      noiseSigma: t.$1,
      blurRadius: t.$2,
      gradient: t.$3,
      seed: t.$4,
    ),
  ),
);

void main() {
  property(
    'text → QR → synthetic photo within MVP → scanner returns the same text',
    () {
      forAll(
        mvpPhoto(),
        (t) {
          final (text, v, ec, pose, options) = t;
          final s = oracleEncode(text, ec: OracleEc.values[ec], minVersion: v);
          final p = renderCode(matrixOf(s), pose: pose, options: options);
          final r = QrScanner().scan(p.image);
          expect(
            r.codes,
            hasLength(1),
            reason: 'v${s.version} $pose ${r.failures}',
          );
          expect(r.codes.single.text, text);
        },
        seed: seed,
        maxExamples: 60,
      );
    },
  );

  property(
    'rotation by 90°, inversion and mirroring do not change the result',
    () {
      forAll(
        combine3(
          anyText(maxLength: 30),
          integer(min: 1, max: 15),
          float(min: 0, max: 360),
        ),
        (t) {
          final (text, v, rot) = t;
          final p = renderCode(
            matrixOf(oracleEncode(text, minVersion: v)),
            pose: Pose(moduleSize: 4, rotationDeg: rot, tiltXDeg: 10),
          );
          final base = QrScanner().scan(p.image).codes.single.text;
          expect(base, text);
          for (final variant in [
            rotatePhoto90(p),
            invertPhoto(p),
            mirrorPhoto(p),
            invertPhoto(mirrorPhoto(p)),
          ]) {
            expect(QrScanner().scan(variant.image).codes.single.text, base);
          }
        },
        seed: seed + 1,
        maxExamples: 25,
      );
    },
  );

  property('K non-overlapping codes on one photo give exactly K results', () {
    forAll(
      combine3(
        integer(min: 1, max: 4),
        integer(min: 1, max: 6),
        float(min: 0, max: 90),
      ),
      (t) {
        final (k, v, rot) = t;
        final placements = <Placement>[];
        for (var i = 0; i < k; i++) {
          final m = matrixOf(oracleEncode('K$i of $k', minVersion: v + i));
          placements.add(
            Placement(
              m,
              poseCorners(
                m.width,
                Pose(moduleSize: 3.5, rotationDeg: rot + 40.0 * i),
                120.0 + (i % 2) * 240,
                120.0 + (i ~/ 2) * 240,
              ),
            ),
          );
        }
        final r = QrScanner().scan(renderScene(480, 480, placements).image);
        expect(r.codes.map((c) => c.text).toSet(), {
          for (var i = 0; i < k; i++) 'K$i of $k',
        });
        expect(r.codes, hasLength(k));
      },
      seed: seed + 2,
      maxExamples: 20,
    );
  });
}
