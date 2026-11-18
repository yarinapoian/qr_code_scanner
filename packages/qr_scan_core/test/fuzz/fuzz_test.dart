@Tags(['fuzz'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:kiri_check/kiri_check.dart';
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:qr_scan_core/src/common/version.dart';
import 'package:qr_scan_core/src/decode/bitstream.dart';
import 'package:test/test.dart';

const maxScan = Duration(seconds: 3);

ScanReport timedScan(LuminanceImage img) {
  final sw = Stopwatch()..start();
  final r = QrScanner().scan(img);
  expect(sw.elapsed, lessThan(maxScan), reason: '${img.width}x${img.height}');
  return r;
}

Uint8List noise(Random r, int n) =>
    Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));

void main() {
  test('degenerate sizes: 0×0, 1×1, 1×N, N×1, 7×7, 39×41, 40×40', () {
    final rnd = Random(1);
    for (final (w, h) in [
      (0, 0),
      (1, 1),
      (0, 50),
      (50, 0),
      (1, 500),
      (500, 1),
      (2, 2),
      (7, 7),
      (39, 41),
      (40, 40),
      (41, 39),
      (3, 2000),
    ]) {
      final r = timedScan(LuminanceImage(w, h, noise(rnd, w * h)));
      expect(r.codes, isEmpty);
      expect(r.failures, isNotEmpty);
    }
  });

  property(
    'random images of any size and content: only ScanFailure values',
    () {
      forAll(
        combine4(
          integer(min: 0, max: 260),
          integer(min: 0, max: 260),
          integer(min: 0, max: 4),
          integer(),
        ),
        (t) {
          final (w, h, kind, s) = t;
          final rnd = Random(s);
          final bytes = Uint8List(w * h);
          for (var i = 0; i < bytes.length; i++) {
            final x = w == 0 ? 0 : i % w;
            final y = w == 0 ? 0 : i ~/ w;
            bytes[i] = switch (kind) {
              0 => rnd.nextInt(256),
              1 => ((x ~/ 3 + y ~/ 3).isEven ? 20 : 230),
              2 => ((x ~/ (1 + s % 7)) % 5 == 0 ? 10 : 240),
              3 => ((x * 31 + y * 17) ^ s) % 256,
              _ => (rnd.nextInt(8) == 0 ? 0 : 255),
            };
          }
          final r = timedScan(LuminanceImage(w, h, bytes));
          expect(r.failures.isNotEmpty || r.codes.isNotEmpty, isTrue);
        },
        seed: 31337,
        maxExamples: 150,
      );
    },
  );

  test('random matrices of every size 0..181 → DecodeFailure, never throw', () {
    final rnd = Random(3);
    for (var n = 0; n <= 181; n++) {
      final m = BitMatrix.square(n);
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          if (rnd.nextBool()) m.set(x, y);
        }
      }
      expect(QrMatrixDecoder.decode(m), isA<DecodeFailure>(), reason: '$n');
    }
    expect(QrMatrixDecoder.decode(BitMatrix(21, 25)), isA<DecodeFailure>());
  });

  test(
    'random data codewords into the bitstream parser → value, never throw',
    () {
      final rnd = Random(4);
      for (var k = 0; k < 3000; k++) {
        final v = Version.byNumber(1 + rnd.nextInt(40));
        final len = rnd.nextInt(v.ecBlocksFor(EcLevel.L).dataCodewords + 1);
        final r = BitstreamParser.parse(noise(rnd, len), v);
        expect(r.message != null || r.failure != null, isTrue);
      }
    },
  );
}
