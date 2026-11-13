library;

import 'dart:math';

import 'package:qr_scan_core/src/common/bit_matrix.dart';
import 'package:qr_scan_core/src/common/ec_level.dart';
import 'package:qr_scan_core/src/common/version.dart';
import 'package:qr_scan_core/src/decode/codeword_placement.dart';

import 'oracle_qr.dart';

EcLevel ecOf(OracleEc ec) => EcLevel.values[ec.index];

BitMatrix matrixOf(OracleSymbol s) => BitMatrix.fromRows(s.rows);

int interleavedIndex(Version v, EcLevel level, int b, int i) {
  final ec = v.ecBlocksFor(level);
  final sizes = [
    for (final g in ec.groups)
      for (var j = 0; j < g.count; j++) g.dataCodewords,
  ];
  final blocks = sizes.length;
  final shortData = sizes.first;
  final dataTotal = sizes.fold(0, (a, s) => a + s);
  if (i < sizes[b]) {
    if (i < shortData) return i * blocks + b;
    final longBefore = sizes.sublist(0, b).where((s) => s > shortData).length;
    return shortData * blocks + longBefore;
  }
  return dataTotal + (i - sizes[b]) * blocks + b;
}

void corruptCodeword(BitMatrix symbol, Version v, int index, int pattern) {
  assert(pattern > 0 && pattern < 256);
  var bit = 0;
  for (final p in CodewordPlacement.order(v)) {
    final x = p.x;
    final y = p.y;
    final cw = bit ~/ 8;
    if (cw == index && (pattern >> (7 - bit % 8)) & 1 == 1) symbol.flip(x, y);
    bit++;
    if (cw > index) break;
  }
}

void corruptEveryBlock(
  BitMatrix symbol,
  Version v,
  EcLevel level,
  int perBlock,
  Random rnd,
) {
  final ec = v.ecBlocksFor(level);
  var b = 0;
  for (final g in ec.groups) {
    for (var j = 0; j < g.count; j++, b++) {
      final len = g.dataCodewords + ec.ecCodewordsPerBlock;
      final picks = (List<int>.generate(
        len,
        (i) => i,
      )..shuffle(rnd)).take(perBlock);
      for (final i in picks) {
        corruptCodeword(
          symbol,
          v,
          interleavedIndex(v, level, b, i),
          1 + rnd.nextInt(255),
        );
      }
    }
  }
}
