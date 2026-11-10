@Tags(['unit'])
library;

import 'package:qr_scan_core/src/common/version.dart';
import 'package:qr_scan_core/src/decode/function_patterns.dart';
import 'package:test/test.dart';

int isoRemainderBits(int v) {
  if (v == 1) return 0;
  if (v <= 6) return 7;
  if (v <= 13) return 0;
  if (v <= 20) return 3;
  if (v <= 27) return 4;
  if (v <= 34) return 3;
  return 0;
}

void main() {
  test('ISO 18004 Table 1: data modules = 8 × codewords + remainder bits, all 40 versions', () {
    for (final v in Version.all) {
      expect(
        FunctionPatterns.dataModuleCount(v),
        v.totalCodewords * 8 + isoRemainderBits(v.number),
        reason: '$v',
      );
    }
  });
}
