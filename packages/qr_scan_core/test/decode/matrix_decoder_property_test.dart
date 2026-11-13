@Tags(['property'])
library;

import 'dart:math';

import 'package:kiri_check/kiri_check.dart';
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:qr_scan_core/src/common/version.dart';
import 'package:test/test.dart';

import '../support/oracle_qr.dart';
import '../support/symbols.dart';
import '../support/text_gen.dart';

const seed = 20261115;

void main() {
  property('decode(encode(x)) == x for random text, every level and any of the 8 masks', () {
    forAll(
      combine4(
        anyText(),
        integer(min: 0, max: 3),
        integer(min: 0, max: 7),
        integer(min: 1, max: 40),
      ),
      (t) {
        final (text, ec, mask, minVersion) = t;
        final s = oracleEncode(
          text,
          ec: OracleEc.values[ec],
          mask: mask,
          minVersion: minVersion,
        );
        final r = QrMatrixDecoder.decode(matrixOf(s));
        expect(r, isA<DecodeSuccess>(), reason: 'v${s.version} "$text"');
        final code = (r as DecodeSuccess).code;
        expect(code.text, text);
        expect(code.version, s.version);
        expect(code.mask, mask);
        expect(code.ecLevel, ecOf(OracleEc.values[ec]));
      },
      seed: seed,
      maxExamples: 150,
    );
  });

  property('damage within t codewords per block is corrected exactly', () {
    forAll(
      combine4(
        integer(min: 1, max: 40),
        integer(min: 0, max: 3),
        integer(),
        anyText(maxLength: 20),
      ),
      (t) {
        final (v, ec, rndSeed, text) = t;
        final s = oracleEncode(
          text,
          ec: OracleEc.values[ec],
          minVersion: v,
          mask: rndSeed & 7,
        );
        final version = Version.byNumber(s.version);
        final level = ecOf(s.ec);
        final rnd = Random(rndSeed);
        final perBlock = rnd.nextInt(
          version.ecBlocksFor(level).correctablePerBlock + 1,
        );
        final m = matrixOf(s);
        corruptEveryBlock(m, version, level, perBlock, rnd);
        final r = QrMatrixDecoder.decode(m);
        expect(r, isA<DecodeSuccess>());
        final code = (r as DecodeSuccess).code;
        expect(code.text, text);
        expect(
          code.correctedErrors,
          perBlock * version.ecBlocksFor(level).blockCount,
        );
      },
      seed: seed + 1,
      maxExamples: 120,
    );
  });

  var miscorrections = 0;
  var trials = 0;
  property('damage beyond t: failure value (or rare miscorrection), never an exception', () {
    forAll(
      combine3(integer(min: 1, max: 40), integer(min: 0, max: 3), integer()),
      (t) {
        final (v, ec, rndSeed) = t;
        final s = oracleEncode(
          'beyond t',
          ec: OracleEc.values[ec],
          minVersion: v,
          mask: rndSeed & 7,
        );
        final version = Version.byNumber(s.version);
        final level = ecOf(s.ec);
        final rnd = Random(rndSeed);
        final extra = 1 + rnd.nextInt(3);
        final m = matrixOf(s);
        corruptEveryBlock(
          m,
          version,
          level,
          version.ecBlocksFor(level).correctablePerBlock + extra,
          rnd,
        );
        trials++;
        final r = QrMatrixDecoder.decode(m, tryMirrored: false);
        if (r is DecodeSuccess) miscorrections++;
      },
      seed: seed + 2,
      maxExamples: 120,
      tearDownAll: () {
        expect(miscorrections, lessThanOrEqualTo(trials ~/ 50));
      },
    );
  });
}
