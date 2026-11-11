import '../common/bit_matrix.dart';
import 'format_info.dart' show bchRemainder, bitCount;

abstract final class VersionInfoCodec {
  static const int generator = 0x1F25;

  static const int maxBitErrors = 3;

  static final List<int> validCodewords = _buildValidCodewords();

  static List<int> _buildValidCodewords() {
    final out = <int>[];
    for (var v = 7; v <= 40; v++) {
      out.add(encode(v));
    }
    return List.unmodifiable(out);
  }

  static int encode(int version) {
    RangeError.checkValueInInterval(version, 7, 40, 'version');
    return (version << 12) | bchRemainder(version << 12, generator, 12);
  }

  static int? decode(List<int> readings) {
    var best = -1;
    var bestDistance = 19;
    for (final r in readings) {
      for (var i = 0; i < validCodewords.length; i++) {
        final d = bitCount(r ^ validCodewords[i]);
        if (d < bestDistance) {
          bestDistance = d;
          best = i + 7;
        }
      }
    }
    if (bestDistance > maxBitErrors) return null;
    return best;
  }

  static List<int> read(BitMatrix m) {
    final n = m.height;
    var bl = 0;
    var tr = 0;
    for (var i = 17; i >= 0; i--) {
      final a = n - 11 + i % 3;
      final b = i ~/ 3;
      bl = (bl << 1) | (m.get(b, a) ? 1 : 0);
      tr = (tr << 1) | (m.get(a, b) ? 1 : 0);
    }
    return [bl, tr];
  }
}
