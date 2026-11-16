import 'dart:math' as math;

import '../common/bit_matrix.dart';
import '../common/geometry.dart';

class AlignmentPatternFinder {
  AlignmentPatternFinder(this.image, this.moduleSize);

  final BitMatrix image;

  final double moduleSize;

  final List<_Candidate> _candidates = [];

  Point? find(double estX, double estY, double allowanceModules) {
    _candidates.clear();
    final allowance = (allowanceModules * moduleSize).floor();
    final left = math.max(0, estX.floor() - allowance);
    final right = math.min(image.width - 1, estX.floor() + allowance);
    if (right - left < moduleSize * 3) return null;
    final top = math.max(0, estY.floor() - allowance);
    final bottom = math.min(image.height - 1, estY.floor() + allowance);
    if (bottom - top < moduleSize * 3) return null;

    final height = bottom - top;
    final middle = top + height ~/ 2;
    for (var g = 0; g < height; g++) {
      final y = _rowFromMiddle(middle, g);
      if (y < 0 || y >= image.height) continue;
      final found = _scanRow(y, left, right);
      if (found != null) return found;
    }

    if (_candidates.isEmpty) return null;
    return _candidates.first.point;
  }

  static int _rowFromMiddle(int middle, int g) {
    final offset = (g + 1) ~/ 2;
    return g.isEven ? middle + offset : middle - offset;
  }

  Point? _scanRow(int y, int left, int right) {
    final runs = List<int>.filled(3, 0);
    var x = left;
    while (x <= right && !image.get(x, y)) {
      x++;
    }

    var state = 0;
    for (; x <= right; x++) {
      final dark = image.get(x, y);
      if (dark && state == 1) {
        runs[1]++;
      } else if (dark && state == 2) {
        if (_crossOk(runs)) {
          final found = _handle(runs, y, x);
          if (found != null) return found;
        }
        runs[0] = runs[2];
        runs[1] = 1;
        runs[2] = 0;
        state = 1;
      } else if (dark) {
        state++;
        runs[state]++;
      } else {
        if (state == 1) state++;
        runs[state]++;
      }
    }

    if (_crossOk(runs)) return _handle(runs, y, right + 1);
    return null;
  }

  bool _crossOk(List<int> c) {
    var lo = c[0];
    var hi = c[0];
    for (var i = 0; i < 3; i++) {
      if (c[i] < 0.4 * moduleSize || c[i] > 1.9 * moduleSize) return false;
      if (c[i] < lo) lo = c[i];
      if (c[i] > hi) hi = c[i];
    }
    return hi <= 2.2 * lo;
  }

  Point? _handle(List<int> counts, int y, int end) {
    final total = counts[0] + counts[1] + counts[2];
    final cx = end - counts[2] - counts[1] / 2.0;
    final cy = _crossCheckVertical(y, cx.floor(), 2 * counts[1], total);
    if (cy.isNaN) return null;
    if (!verifyRings(cx, cy)) return null;

    final size = total / 3.0;
    for (var i = 0; i < _candidates.length; i++) {
      final c = _candidates[i];
      if ((cy - c.y).abs() <= size && (cx - c.x).abs() <= size) {
        final diff = (size - c.size).abs();
        if (diff <= 1.0 || diff <= c.size) {
          return Point((c.x + cx) / 2, (c.y + cy) / 2);
        }
      }
    }
    _candidates.add(_Candidate(cx, cy, size));
    return null;
  }

  double _crossCheckVertical(
    int startY,
    int cx,
    int maxCount,
    int originalTotal,
  ) {
    final h = image.height;
    if (cx < 0 || cx >= image.width) return double.nan;
    final c = List<int>.filled(3, 0);

    var i = startY;
    while (i >= 0 && image.get(cx, i) && c[1] <= maxCount) {
      c[1]++;
      i--;
    }
    if (i < 0 || c[1] > maxCount) return double.nan;
    while (i >= 0 && !image.get(cx, i) && c[0] <= maxCount) {
      c[0]++;
      i--;
    }
    if (c[0] > maxCount) return double.nan;

    i = startY + 1;
    while (i < h && image.get(cx, i) && c[1] <= maxCount) {
      c[1]++;
      i++;
    }
    if (i == h || c[1] > maxCount) return double.nan;
    while (i < h && !image.get(cx, i) && c[2] <= maxCount) {
      c[2]++;
      i++;
    }
    if (c[2] > maxCount) return double.nan;

    final total = c[0] + c[1] + c[2];
    if (5 * (total - originalTotal).abs() >= 2 * originalTotal) {
      return double.nan;
    }
    if (!_crossOk(c)) return double.nan;
    return i - c[2] - c[1] / 2.0;
  }

  bool verifyRings(double cx, double cy) {
    final x = cx.floor();
    final y = cy.floor();
    if (!image.contains(x, y) || !image.get(x, y)) return false;
    for (final d in _ringDirections) {
      if (!_ringOk(x, y, d[0], d[1])) return false;
    }
    return true;
  }

  bool _ringOk(int x, int y, int dx, int dy) {
    final limit = (3.5 * moduleSize).ceil() + 1;
    var i = 0;
    var cx = x;
    var cy = y;
    int runOf(bool dark) {
      var n = 0;
      while (i < limit && image.contains(cx, cy) && image.get(cx, cy) == dark) {
        n++;
        i++;
        cx += dx;
        cy += dy;
      }
      return n;
    }

    final centre = runOf(true);
    final light = runOf(false);
    final outer = runOf(true);
    final lo = 0.4 * moduleSize;
    final hi = 1.9 * moduleSize;
    return centre <= hi && light >= lo && light <= hi && outer >= lo;
  }
}

const List<List<int>> _ringDirections = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
  [1, 1],
  [-1, -1],
  [1, -1],
  [-1, 1],
];

class _Candidate {
  _Candidate(this.x, this.y, this.size);
  final double x;
  final double y;
  final double size;

  Point get point => Point(x, y);
}
