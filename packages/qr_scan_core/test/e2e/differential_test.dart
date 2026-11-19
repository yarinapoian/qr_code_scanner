@Tags(['oracle', 'differential', 'slow'])
library;

import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:test/test.dart';

import '../support/image_io.dart';
import '../support/oracle_qr.dart';
import '../support/symbols.dart';
import '../support/synthetic_photo.dart';
import '../support/text_gen.dart';

const eq = ListEquality<int>();

void main() {
  test(
    'agreement with ZXing and zbar on 120 synthetic photos',
    () {
      final dir = Directory.systemTemp.createTempSync('qr_diff_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final rnd = Random(4242);
      var ours = 0, zx = 0, zb = 0, agreeZx = 0, agreeZb = 0;
      final disagreements = <String>[];
      for (var k = 0; k < 120; k++) {
        final text = textFrom(
          textPools.values.elementAt(k % 4),
          List.generate(1 + rnd.nextInt(40), (_) => rnd.nextInt(1000)),
        );
        final s = oracleEncode(
          text,
          ec: OracleEc.values[rnd.nextInt(4)],
          minVersion: 1 + rnd.nextInt(20),
        );
        final hard = k % 3 == 0;
        final pose = Pose(
          moduleSize: hard
              ? 2.5 + rnd.nextDouble()
              : 3.5 + rnd.nextDouble() * 3,
          rotationDeg: rnd.nextDouble() * 360,
          tiltXDeg: (rnd.nextDouble() * 2 - 1) * (hard ? 35 : 20),
        );
        final options = PhotoOptions(
          noiseSigma: rnd.nextDouble() * (hard ? 20 : 8),
          blurRadius: hard ? 1 : 0,
          gradient: rnd.nextDouble() * 0.5,
          seed: k,
        );
        final p = renderCode(matrixOf(s), pose: pose, options: options);
        final path = '${dir.path}/$k.pgm';
        writePgm(path, p.image);

        final mine = QrScanner()
            .scan(p.image)
            .codes
            .map((c) => c.bytes.toList())
            .toList();
        final z = hasZxing ? zxingRead(path) : const <List<int>>[];
        final b = hasZbar ? zbarRead(path) : const <List<int>>[];
        final truth = s.rows.isEmpty
            ? <int>[]
            : QrMatrixDecoder.decode(matrixOf(s)) is DecodeSuccess
            ? (QrMatrixDecoder.decode(matrixOf(s)) as DecodeSuccess).code.bytes
                  .toList()
            : <int>[];
        if (mine.isNotEmpty) {
          ours++;
          expect(
            eq.equals(mine.single, truth),
            isTrue,
            reason: 'our read of #$k is wrong',
          );
        }
        if (z.isNotEmpty) zx++;
        if (b.isNotEmpty) zb++;
        if (mine.isNotEmpty && z.isNotEmpty) {
          eq.equals(mine.single, z.single)
              ? agreeZx++
              : disagreements.add('#$k ZXing');
        }
        if (mine.isNotEmpty && b.isNotEmpty) {
          eq.equals(mine.single, b.single)
              ? agreeZb++
              : disagreements.add('#$k zbar');
        }
      }
      // ignore: avoid_print
      print(
        'differential: ours $ours/120, ZXing $zx/120, zbar $zb/120, '
        'agree with ZXing $agreeZx, with zbar $agreeZb, disagreements $disagreements',
      );
      expect(disagreements, isEmpty);
    },
    skip: hasZxing || hasZbar ? false : 'ZXingReader / zbarimg not installed',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
