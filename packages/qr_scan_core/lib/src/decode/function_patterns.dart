import '../common/bit_matrix.dart';
import '../common/version.dart';

abstract final class FunctionPatterns {
  static final Map<int, BitMatrix> _cache = {};

  static BitMatrix forVersion(Version version) {
    return _cache.putIfAbsent(version.number, () => _build(version));
  }

  static BitMatrix _build(Version version) {
    final n = version.size;
    final m = BitMatrix.square(n);

    m.setRegion(0, 0, 9, 9);
    m.setRegion(n - 8, 0, 8, 9);
    m.setRegion(0, n - 8, 9, 8);

    final c = version.alignmentCenters;
    final last = c.length - 1;
    for (var i = 0; i < c.length; i++) {
      for (var j = 0; j < c.length; j++) {
        final overlapsFinder =
            (i == 0 && j == 0) ||
            (i == 0 && j == last) ||
            (i == last && j == 0);
        if (!overlapsFinder) m.setRegion(c[j] - 2, c[i] - 2, 5, 5);
      }
    }

    m.setRegion(6, 9, 1, n - 17);
    m.setRegion(9, 6, n - 17, 1);

    if (version.hasVersionInfo) {
      m.setRegion(n - 11, 0, 3, 6);
      m.setRegion(0, n - 11, 6, 3);
    }
    return m;
  }

  static int dataModuleCount(Version version) {
    final n = version.size;
    return n * n - forVersion(version).popCount;
  }
}
