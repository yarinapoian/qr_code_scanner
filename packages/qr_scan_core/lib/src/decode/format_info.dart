import '../common/bit_matrix.dart';
import '../common/ec_level.dart';
import 'codeword_placement.dart';

class FormatInfo {
  const FormatInfo(this.ecLevel, this.mask, {this.bitErrors = 0});

  final EcLevel ecLevel;

  final int mask;

  final int bitErrors;

  int get dataBits => (ecLevel.formatBits << 3) | mask;

  @override
  bool operator ==(Object other) {
    return other is FormatInfo &&
        other.ecLevel == ecLevel &&
        other.mask == mask;
  }

  @override
  int get hashCode => Object.hash(ecLevel, mask);

  @override
  String toString() => 'FormatInfo(${ecLevel.name}, mask $mask)';
}

abstract final class FormatInfoCodec {
  static const int generator = 0x537;

  static const int xorMask = 0x5412;

  static const int maxBitErrors = 3;

  static final List<int> validCodewords = _buildValidCodewords();

  static List<int> _buildValidCodewords() {
    final out = <int>[];
    for (var d = 0; d < 32; d++) {
      out.add(encode(d));
    }
    return List.unmodifiable(out);
  }

  static int encode(int data5) {
    if (data5 < 0 || data5 > 31) throw RangeError.range(data5, 0, 31, 'data5');
    return ((data5 << 10) | bchRemainder(data5 << 10, generator, 10)) ^ xorMask;
  }

  static FormatInfo? decode(List<int> readings) {
    var best = -1;
    var bestDistance = 16;

    for (final r in readings) {
      for (var d = 0; d < 32; d++) {
        final dist = bitCount(r ^ validCodewords[d]);
        if (dist < bestDistance) {
          bestDistance = dist;
          best = d;
        }
      }
    }

    if (best < 0 || bestDistance > maxBitErrors) return null;
    return FormatInfo(
      EcLevel.fromFormatBits(best >> 3),
      best & 7,
      bitErrors: bestDistance,
    );
  }

  static List<ModulePosition> copy1Positions() {
    final out = <ModulePosition>[];
    for (var x = 0; x <= 5; x++) {
      out.add(ModulePosition(x, 8));
    }
    out.add(const ModulePosition(7, 8));
    out.add(const ModulePosition(8, 8));
    out.add(const ModulePosition(8, 7));
    for (var y = 5; y >= 0; y--) {
      out.add(ModulePosition(8, y));
    }
    return out;
  }

  static List<ModulePosition> copy2Positions(int n) {
    final out = <ModulePosition>[];
    for (var y = n - 1; y >= n - 7; y--) {
      out.add(ModulePosition(8, y));
    }
    for (var x = n - 8; x < n; x++) {
      out.add(ModulePosition(x, 8));
    }
    return out;
  }

  static List<int> read(BitMatrix m) {
    return [
      _readBits(m, copy1Positions()),
      _readBits(m, copy2Positions(m.height)),
    ];
  }

  static int _readBits(BitMatrix m, List<ModulePosition> positions) {
    var value = 0;
    for (final p in positions) {
      value = (value << 1) | (m.get(p.x, p.y) ? 1 : 0);
    }
    return value;
  }
}

int bchRemainder(int value, int generator, int degree) {
  var v = value;
  for (var bit = v.bitLength - 1; bit >= degree; bit--) {
    if ((v >> bit) & 1 == 1) v ^= generator << (bit - degree);
  }
  return v;
}

int bitCount(int v) {
  var n = 0;
  var x = v;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}
