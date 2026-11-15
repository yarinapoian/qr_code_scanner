import '../common/bit_matrix.dart';
import '../common/geometry.dart';

class FinderPattern {
  const FinderPattern(this.x, this.y, this.moduleSize, [this.count = 1]);

  final double x;

  final double y;

  final double moduleSize;

  final int count;

  Point get point => Point(x, y);

  bool aboutEquals(double size, double px, double py) {
    if ((py - y).abs() > size || (px - x).abs() > size) return false;
    final diff = (size - moduleSize).abs();
    return diff <= 1.0 || diff <= moduleSize;
  }

  FinderPattern combine(double px, double py, double size) {
    final n = count + 1;
    return FinderPattern(
      (count * x + px) / n,
      (count * y + py) / n,
      (count * moduleSize + size) / n,
      n,
    );
  }

  @override
  String toString() {
    return 'Finder(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
        'm=${moduleSize.toStringAsFixed(2)}, n=$count)';
  }
}

class FinderPatternFinder {
  FinderPatternFinder(this.image);

  final BitMatrix image;

  final List<FinderPattern> _candidates = [];

  static const double maxVarianceRatio = 0.5;

  List<FinderPattern> find() {
    _candidates.clear();
    final h = image.height;
    final w = image.width;
    if (w < 7 || h < 7) return const [];

    final rowStep = ((3 * h) ~/ (4 * 177)).clamp(1, 3);
    for (var y = rowStep - 1; y < h; y += rowStep) {
      _scanRow(y);
    }

    return List<FinderPattern>.of(_candidates)..sort(_byConfidence);
  }

  static int _byConfidence(FinderPattern a, FinderPattern b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final byY = a.y.compareTo(b.y);
    return byY != 0 ? byY : a.x.compareTo(b.x);
  }

  void _scanRow(int y) {
    final w = image.width;
    final runs = List<int>.filled(5, 0);
    var state = 0;

    for (var x = 0; x < w; x++) {
      final dark = image.get(x, y);
      final inDarkRun = state.isEven;

      if (dark) {
        if (!inDarkRun) state++;
        runs[state]++;
      } else if (inDarkRun && state == 4) {
        if (foundPatternCross(runs)) _handlePossibleCenter(runs, y, x);
        _shiftByTwoRuns(runs);
        state = 3;
      } else if (inDarkRun) {
        state++;
        runs[state]++;
      } else {
        runs[state]++;
      }
    }

    if (foundPatternCross(runs)) _handlePossibleCenter(runs, y, w);
  }

  static void _shiftByTwoRuns(List<int> runs) {
    runs[0] = runs[2];
    runs[1] = runs[3];
    runs[2] = runs[4];
    runs[3] = 1;
    runs[4] = 0;
  }

  static bool foundPatternCross(
    List<int> c, {
    double ratio = maxVarianceRatio,
  }) {
    if (c.any((r) => r == 0)) return false;
    final total = _sum(c);
    if (total < 7) return false;

    final module = total / 7.0;
    final tol = module * ratio;
    final direct =
        (module - c[0]).abs() < tol &&
        (module - c[1]).abs() < tol &&
        (3 * module - c[2]).abs() < 3 * tol &&
        (module - c[3]).abs() < tol &&
        (module - c[4]).abs() < tol;
    return direct || biasInvariantCross(c, module, ratio);
  }

  static bool biasInvariantCross(List<int> c, double module, double ratio) {
    final tol = module * ratio;
    return (c[0] + c[1] - 2 * module).abs() < tol &&
        (c[1] + c[2] - 4 * module).abs() < 2 * tol &&
        (c[2] + c[3] - 4 * module).abs() < 2 * tol &&
        (c[3] + c[4] - 2 * module).abs() < tol &&
        c[2] > c[0] &&
        c[2] > c[4] &&
        c[2] > 1.4 * c[1] &&
        c[2] > 1.4 * c[3];
  }

  static int _sum(List<int> c) {
    var total = 0;
    for (final v in c) {
      total += v;
    }
    return total;
  }

  static double _centerFromEnd(List<int> c, int end) {
    return end - c[4] - c[3] - c[2] / 2.0;
  }

  void _handlePossibleCenter(List<int> runs, int y, int endX) {
    final total = _sum(runs);
    var cx = _centerFromEnd(runs, endX);

    final cy = crossCheckVertical(cx.floor(), y, runs[2], total);
    if (cy.isNaN) return;
    cx = crossCheckHorizontal(cx.floor(), cy.floor(), runs[2], total);
    if (cx.isNaN) return;
    if (!crossCheckDiagonal(cx.floor(), cy.floor())) return;

    final size = total / 7.0;
    for (var i = 0; i < _candidates.length; i++) {
      if (_candidates[i].aboutEquals(size, cx, cy)) {
        _candidates[i] = _candidates[i].combine(cx, cy, size);
        return;
      }
    }
    _candidates.add(FinderPattern(cx, cy, size));
  }

  double crossCheckVertical(
    int cx,
    int startY,
    int maxCount,
    int originalTotal,
  ) {
    if (cx < 0 || cx >= image.width) return double.nan;
    return _crossCheck(
      startY,
      image.height,
      (y) => image.get(cx, y),
      maxCount,
      originalTotal,
    );
  }

  double crossCheckHorizontal(
    int startX,
    int cy,
    int maxCount,
    int originalTotal,
  ) {
    if (cy < 0 || cy >= image.height) return double.nan;
    return _crossCheck(
      startX,
      image.width,
      (x) => image.get(x, cy),
      maxCount,
      originalTotal,
    );
  }

  double _crossCheck(
    int start,
    int length,
    bool Function(int i) isDark,
    int maxCount,
    int originalTotal,
  ) {
    final c = List<int>.filled(5, 0);

    var i = start;
    while (i >= 0 && isDark(i)) {
      c[2]++;
      i--;
    }
    if (i < 0) return double.nan;
    while (i >= 0 && !isDark(i) && c[1] <= maxCount) {
      c[1]++;
      i--;
    }
    if (i < 0 || c[1] > maxCount) return double.nan;
    while (i >= 0 && isDark(i) && c[0] <= maxCount) {
      c[0]++;
      i--;
    }
    if (c[0] > maxCount) return double.nan;

    i = start + 1;
    while (i < length && isDark(i)) {
      c[2]++;
      i++;
    }
    if (i == length) return double.nan;
    while (i < length && !isDark(i) && c[3] < maxCount) {
      c[3]++;
      i++;
    }
    if (i == length || c[3] >= maxCount) return double.nan;
    while (i < length && isDark(i) && c[4] < maxCount) {
      c[4]++;
      i++;
    }
    if (c[4] >= maxCount) return double.nan;

    final total = _sum(c);
    if (5 * (total - originalTotal).abs() >= 2 * originalTotal) {
      return double.nan;
    }
    return foundPatternCross(c) ? _centerFromEnd(c, i) : double.nan;
  }

  bool crossCheckDiagonal(int cx, int cy) {
    if (!image.contains(cx, cy)) return false;

    var step = 0;
    int run(int direction, bool dark) {
      var n = 0;
      while (true) {
        final x = cx + direction * step;
        final y = cy + direction * step;
        if (!image.contains(x, y) || image.get(x, y) != dark) return n;
        n++;
        step++;
      }
    }

    final centreUp = run(-1, true);
    if (centreUp == 0) return false;
    final lightUp = run(-1, false);
    if (lightUp == 0) return false;
    final outerUp = run(-1, true);
    if (outerUp == 0) return false;

    step = 1;
    final centreDown = run(1, true);
    final lightDown = run(1, false);
    if (lightDown == 0) return false;
    final outerDown = run(1, true);
    if (outerDown == 0) return false;

    return foundPatternCross([
      outerUp,
      lightUp,
      centreUp + centreDown,
      lightDown,
      outerDown,
    ], ratio: 0.75);
  }
}
