import '../common/bit_matrix.dart';
import '../common/version.dart';
import 'function_patterns.dart';

abstract final class DataMask {
  static bool isMasked(int pattern, int i, int j) {
    switch (pattern) {
      case 0:
        return (i + j) % 2 == 0;
      case 1:
        return i % 2 == 0;
      case 2:
        return j % 3 == 0;
      case 3:
        return (i + j) % 3 == 0;
      case 4:
        return (i ~/ 2 + j ~/ 3) % 2 == 0;
      case 5:
        return (i * j) % 2 + (i * j) % 3 == 0;
      case 6:
        return ((i * j) % 2 + (i * j) % 3) % 2 == 0;
      case 7:
        return ((i + j) % 2 + (i * j) % 3) % 2 == 0;
      default:
        throw RangeError.range(pattern, 0, 7, 'pattern');
    }
  }

  static BitMatrix unmask(BitMatrix symbol, Version version, int pattern) {
    final function = FunctionPatterns.forVersion(version);
    final out = symbol.copy();
    final n = symbol.height;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!function.get(x, y) && isMasked(pattern, y, x)) out.flip(x, y);
      }
    }
    return out;
  }
}
