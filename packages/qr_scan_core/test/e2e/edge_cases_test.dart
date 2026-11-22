@Tags(['e2e'])
library;

import 'dart:typed_data';

import 'package:qr/qr.dart' show InputTooLongException;
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:test/test.dart';

import '../support/mask_penalty.dart';
import '../support/oracle_qr.dart';
import '../support/symbols.dart';
import '../support/synthetic_photo.dart';

String atCapacity(String unit, int version, OracleEc ec) {
  var lo = 0;
  var hi = 8000;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    try {
      final s = oracleEncode(unit * mid, ec: ec, minVersion: version);
      if (s.version == version) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    } on InputTooLongException {
      hi = mid - 1;
    }
  }
  return unit * lo;
}

String scanText(SyntheticPhoto p) =>
    QrScanner().scan(p.image).codes.single.text;

void main() {
  group('design doc §5 edge cases', () {
    test(
      'data exactly at the capacity of the version (numeric, alnum, byte)',
      () {
        for (final (unit, v, ec) in [
          ('7', 1, OracleEc.l),
          ('A', 2, OracleEc.h),
          ('b', 5, OracleEc.q),
          ('9', 10, OracleEc.m),
        ]) {
          final text = atCapacity(unit, v, ec);
          expect(text, isNotEmpty);
          final s = oracleEncode(text, ec: ec, minVersion: v);
          expect(s.version, v);
          final r = QrMatrixDecoder.decode(matrixOf(s));
          expect((r as DecodeSuccess).code.text, text);
          expect(
            scanText(
              renderCode(
                matrixOf(s),
                pose: const Pose(moduleSize: 4, rotationDeg: 15),
              ),
            ),
            text,
          );
        }
      },
    );

    test('version 40 at capacity from a photo', () {
      final text = atCapacity('Q', 40, OracleEc.h);
      final s = oracleEncode(text, ec: OracleEc.h, minVersion: 40);
      expect(
        scanText(
          renderCode(
            matrixOf(s),
            pose: const Pose(moduleSize: 4, rotationDeg: 8),
          ),
        ),
        text,
      );
    }, tags: ['slow']);

    test('empty data', () {
      final s = oracleEncode('', minVersion: 1);
      expect(
        (QrMatrixDecoder.decode(matrixOf(s)) as DecodeSuccess).code.text,
        '',
      );
      expect(scanText(renderCode(matrixOf(s))), '');
    });

    test('mixed digits/letters, Cyrillic, emoji', () {
      for (final text in [
        'ABC123xyz',
        'Оплата: 125,50 грн',
        'Привіт 👋🏽 world 🌍',
        '0042FF',
        'ÄÖÜ ß € ✓',
      ]) {
        expect(
          scanText(
            renderCode(
              matrixOf(oracleEncode(text, minVersion: 3)),
              pose: const Pose(moduleSize: 4, rotationDeg: 33),
            ),
          ),
          text,
        );
      }
    });

    test('worst-penalty mask (ISO 18004 §7.8.3) still reads', () {
      for (final v in [2, 6, 10]) {
        final scored = [
          for (var mask = 0; mask < 8; mask++)
            (
              mask,
              maskPenalty(
                oracleEncode('WORST MASK $v', minVersion: v, mask: mask).rows,
              ),
            ),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        final worst = scored.first.$1;
        final s = oracleEncode('WORST MASK $v', minVersion: v, mask: worst);
        expect(
          scanText(
            renderCode(
              matrixOf(s),
              pose: const Pose(moduleSize: 4, rotationDeg: 12),
            ),
          ),
          'WORST MASK $v',
        );
      }
    });

    test(
      'code cut by the frame edge: failure or correct text, never wrong',
      () {
        final s = oracleEncode('CROPPED', ec: OracleEc.h, minVersion: 4);
        final p = renderCode(
          matrixOf(s),
          pose: const Pose(moduleSize: 4, rotationDeg: 30),
        );
        final w = p.image.width;
        final h = p.image.height;
        for (final keep in [0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]) {
          final cw = (w * keep).round();
          final out = Uint8List(cw * h);
          for (var y = 0; y < h; y++) {
            out.setRange(y * cw, (y + 1) * cw, p.image.bytes, y * w);
          }
          final r = QrScanner().scan(LuminanceImage(cw, h, out));
          for (final c in r.codes) {
            expect(c.text, 'CROPPED', reason: 'keep $keep');
          }
          if (r.codes.isEmpty) expect(r.failures, isNotEmpty);
        }
      },
    );

    test('fake finder patterns and clutter in the background', () {
      final code = matrixOf(oracleEncode('REAL ONE', minVersion: 3));
      final fake = BitMatrix.parse('''
#######
#.....#
#.###.#
#.###.#
#.###.#
#.....#
#######
''');
      final placements = [
        Placement(
          code,
          poseCorners(
            code.width,
            const Pose(moduleSize: 4, rotationDeg: 10),
            200,
            200,
          ),
        ),
        for (final (x, y) in [
          (50.0, 50.0),
          (360.0, 60.0),
          (60.0, 350.0),
          (370.0, 360.0),
          (300.0, 40.0),
        ])
          Placement(
            fake,
            poseCorners(7, const Pose(moduleSize: 4), x, y),
            quietZone: 1,
          ),
      ];
      final p = renderScene(
        420,
        420,
        placements,
        options: const PhotoOptions(clutter: 25, seed: 9),
      );
      final r = QrScanner().scan(p.image);
      expect(r.codes.map((c) => c.text), ['REAL ONE']);
    });

    test('inverted (light-on-dark) code', () {
      final p = invertPhoto(
        renderCode(matrixOf(oracleEncode('INVERTED', minVersion: 2))),
      );
      expect(scanText(p), 'INVERTED');
    });

    test('mirrored code', () {
      final p = mirrorPhoto(
        renderCode(
          matrixOf(oracleEncode('MIRRORED', minVersion: 5)),
          pose: const Pose(moduleSize: 4, rotationDeg: 20),
        ),
      );
      final c = QrScanner().scan(p.image).codes.single;
      expect(c.text, 'MIRRORED');
      expect(c.mirrored, isTrue);
    });

    test('several codes on one photo', () {
      final placements = [
        for (var i = 0; i < 4; i++)
          Placement(
            matrixOf(oracleEncode('CODE-$i', minVersion: 2 + i)),
            poseCorners(
              25 + 4 * i,
              Pose(moduleSize: 4, rotationDeg: i * 25.0),
              130.0 + (i % 2) * 260,
              130.0 + (i ~/ 2) * 260,
            ),
          ),
      ];
      final r = QrScanner().scan(renderScene(520, 520, placements).image);
      expect(r.codes.map((c) => c.text).toSet(), {
        'CODE-0',
        'CODE-1',
        'CODE-2',
        'CODE-3',
      });
    });

    test('ISO 18004 §7.9: one damaged format-info copy still reads', () {
      final m = matrixOf(oracleEncode('ONE COPY', minVersion: 2));
      for (var x = 0; x <= 5; x++) {
        m.flip(x, 8);
      }
      m.flip(8, 2);
      expect(scanText(renderCode(m)), 'ONE COPY');
    });

    test('ISO 18004 §7.9: the other format-info copy damaged still reads', () {
      final m = matrixOf(oracleEncode('OTHER COPY', minVersion: 2));
      final n = m.height;
      for (var y = n - 1; y >= n - 6; y--) {
        m.flip(8, y);
      }
      expect(scanText(renderCode(m)), 'OTHER COPY');
    });

    test(
      'worst-penalty mask (ISO 18004 §7.8.3) at version 1 and version 40',
      () {
        for (final v in [1, 40]) {
          final scored = [
            for (var mask = 0; mask < 8; mask++)
              (
                mask,
                maskPenalty(
                  oracleEncode('WORST MASK $v', minVersion: v, mask: mask).rows,
                ),
              ),
          ]..sort((a, b) => b.$2.compareTo(a.$2));
          final worst = scored.first.$1;
          final s = oracleEncode('WORST MASK $v', minVersion: v, mask: worst);
          expect(
            scanText(
              renderCode(
                matrixOf(s),
                pose: const Pose(moduleSize: 4, rotationDeg: 12),
              ),
            ),
            'WORST MASK $v',
          );
        }
      },
    );

    test('version 40 at capacity decodes from the matrix', () {
      final text = atCapacity('Q', 40, OracleEc.h);
      final s = oracleEncode(text, ec: OracleEc.h, minVersion: 40);
      expect(s.version, 40);
      final r = QrMatrixDecoder.decode(matrixOf(s));
      expect((r as DecodeSuccess).code.text, text);
    });

    test(
      'code cropped from the bottom edge: failure or correct text, never wrong',
      () {
        final s = oracleEncode('CROPPED V', ec: OracleEc.h, minVersion: 4);
        final p = renderCode(
          matrixOf(s),
          pose: const Pose(moduleSize: 4, rotationDeg: 30),
        );
        final w = p.image.width;
        final h = p.image.height;
        for (final keep in [0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]) {
          final ch = (h * keep).round();
          final out = Uint8List(w * ch);
          out.setRange(0, w * ch, p.image.bytes);
          final r = QrScanner().scan(LuminanceImage(w, ch, out));
          for (final c in r.codes) {
            expect(c.text, 'CROPPED V', reason: 'keep $keep');
          }
          if (r.codes.isEmpty) expect(r.failures, isNotEmpty);
        }
      },
    );

    test(
      'fake finder patterns in the background with a mirrored real code',
      () {
        final code = matrixOf(oracleEncode('MIRROR + CLUTTER', minVersion: 3));
        final fake = BitMatrix.parse('''
#######
#.....#
#.###.#
#.###.#
#.###.#
#.....#
#######
''');
        final placements = [
          Placement(
            code,
            poseCorners(
              code.width,
              const Pose(moduleSize: 4, rotationDeg: 10),
              200,
              200,
            ),
          ),
          for (final (x, y) in [
            (50.0, 50.0),
            (360.0, 60.0),
            (60.0, 350.0),
            (370.0, 360.0),
            (300.0, 40.0),
          ])
            Placement(
              fake,
              poseCorners(7, const Pose(moduleSize: 4), x, y),
              quietZone: 1,
            ),
        ];
        final p = mirrorPhoto(
          renderScene(
            420,
            420,
            placements,
            options: const PhotoOptions(clutter: 25, seed: 11),
          ),
        );
        final r = QrScanner().scan(p.image);
        final c = r.codes.single;
        expect(c.text, 'MIRROR + CLUTTER');
        expect(c.mirrored, isTrue);
      },
    );
  });
}
