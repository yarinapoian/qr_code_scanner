import 'dart:typed_data';

import '../common/bit_matrix.dart';
import '../common/version.dart';
import 'function_patterns.dart';

class ModulePosition {
  const ModulePosition(this.x, this.y);

  final int x;

  final int y;
}

abstract final class CodewordPlacement {
  static List<ModulePosition> order(Version version) {
    final out = <ModulePosition>[];
    final function = FunctionPatterns.forVersion(version);
    final n = version.size;
    var upward = true;
    for (var right = n - 1; right > 0; right -= 2) {
      if (right == 6) right--;
      for (var k = 0; k < n; k++) {
        final y = upward ? n - 1 - k : k;
        for (var c = 0; c < 2; c++) {
          final x = right - c;
          if (!function.get(x, y)) out.add(ModulePosition(x, y));
        }
      }
      upward = !upward;
    }
    return out;
  }

  static Uint8List read(BitMatrix symbol, Version version) {
    final out = Uint8List(version.totalCodewords);
    var bits = 0;
    var current = 0;
    var index = 0;
    for (final p in order(version)) {
      current = (current << 1) | (symbol.get(p.x, p.y) ? 1 : 0);
      if (++bits == 8) {
        if (index < out.length) out[index] = current;
        index++;
        bits = 0;
        current = 0;
      }
    }
    return out;
  }
}
