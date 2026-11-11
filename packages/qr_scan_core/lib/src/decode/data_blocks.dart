import 'dart:typed_data';

import '../common/ec_level.dart';
import '../common/version.dart';

class DataBlock {
  DataBlock(this.dataCount, this.codewords);

  final int dataCount;

  final Uint8List codewords;

  int get ecCount => codewords.length - dataCount;
}

abstract final class DataBlocks {
  static List<DataBlock> deinterleave(
    List<int> raw,
    Version version,
    EcLevel level,
  ) {
    final ec = version.ecBlocksFor(level);
    if (raw.length != ec.totalCodewords) {
      throw ArgumentError(
        'expected ${ec.totalCodewords} codewords, got ${raw.length}',
      );
    }

    final blocks = <DataBlock>[];
    for (final g in ec.groups) {
      for (var i = 0; i < g.count; i++) {
        final size = g.dataCodewords + ec.ecCodewordsPerBlock;
        blocks.add(DataBlock(g.dataCodewords, Uint8List(size)));
      }
    }

    final longData = blocks.last.dataCount;
    var k = 0;
    for (var i = 0; i < longData; i++) {
      for (final b in blocks) {
        if (i < b.dataCount) b.codewords[i] = raw[k++];
      }
    }
    for (var i = 0; i < ec.ecCodewordsPerBlock; i++) {
      for (final b in blocks) {
        b.codewords[b.dataCount + i] = raw[k++];
      }
    }
    return blocks;
  }
}
