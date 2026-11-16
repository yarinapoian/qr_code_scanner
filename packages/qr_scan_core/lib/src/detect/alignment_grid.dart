import '../common/geometry.dart';
import '../common/version.dart';
import 'alignment_pattern.dart';
import 'finder_edges.dart';
import 'finder_selection.dart';

class _Anchor {
  const _Anchor(this.module, this.pixel, this.weight);

  final Point module;
  final Point pixel;
  final double weight;
}

class AlignmentGrid {
  AlignmentGrid._(this.lines, this.points, this._found);

  final List<double> lines;

  final List<List<Point>> points;

  final List<List<bool>> _found;

  static const double allowance = 6;

  static const double maxShift = 4.5;

  int get size => lines.length;

  Point point(int i, int j) => points[i][j];

  Point? found(int i, int j) => _found[i][j] ? points[i][j] : null;

  static AlignmentGrid discover(
    AlignmentPatternFinder finder,
    Version version,
    FinderTriplet t,
    FinderEdgeEstimator edges,
    double moduleSize,
  ) {
    final lines = <double>[];
    for (final c in version.alignmentCenters) {
      lines.add(c + 0.5);
    }
    final k = lines.length;

    final seeds = edges.correspondences(t, version.size, moduleSize);
    final anchors = <_Anchor>[];
    for (var i = 0; i < seeds.module.length; i++) {
      final weight = i < 3 ? 1.0 : 0.3;
      anchors.add(_Anchor(seeds.module[i], seeds.pixel[i], weight));
    }

    final tl = t.topLeft.point;
    final points = List.generate(k, (_) => List<Point>.filled(k, tl));
    final found = List.generate(k, (_) => List<bool>.filled(k, false));

    final order = _outwardOrder(k);
    for (var pass = 0; pass < 2; pass++) {
      for (final cell in order) {
        final i = cell[0];
        final j = cell[1];
        if (found[i][j]) continue;

        final module = Point(lines[j], lines[i]);
        final predicted = _predict(anchors, module, moduleSize);
        points[i][j] = predicted;
        if (_isFinderCorner(i, j, k)) continue;

        final hit = finder.find(predicted.x, predicted.y, allowance);
        if (hit != null && hit.distanceTo(predicted) <= maxShift * moduleSize) {
          points[i][j] = hit;
          found[i][j] = true;
          anchors.add(_Anchor(module, hit, 1.0));
        }
      }
    }
    return AlignmentGrid._(lines, points, found);
  }

  static List<List<int>> _outwardOrder(int k) {
    final order = <List<int>>[];
    for (var i = 0; i < k; i++) {
      for (var j = 0; j < k; j++) {
        order.add([i, j]);
      }
    }
    order.sort((a, b) {
      final byDistance = (a[0] + a[1]).compareTo(b[0] + b[1]);
      if (byDistance != 0) return byDistance;
      return a[0].compareTo(b[0]);
    });
    return order;
  }

  static bool _isFinderCorner(int i, int j, int k) {
    return (i == 0 && j == 0) ||
        (i == 0 && j == k - 1) ||
        (i == k - 1 && j == 0);
  }

  static Point _predict(
    List<_Anchor> anchors,
    Point module,
    double moduleSize,
  ) {
    if (anchors.length >= 5) {
      final from = <Point>[];
      final to = <Point>[];
      final weights = <double>[];
      for (final a in anchors) {
        final distance = a.module.distanceTo(module) / 40;
        from.add(a.module);
        to.add(a.pixel);
        weights.add(a.weight / (1 + distance * distance));
      }

      final h = FinderEdgeEstimator.robustLeastSquares(
        from,
        to,
        weights: weights,
        maxResidual: 1.5 * moduleSize,
      );
      if (h != null) {
        final r = h.apply(module.x, module.y);
        if (r.x.isFinite && r.y.isFinite) return r;
      }
    }
    return _affine(anchors[0], anchors[1], anchors[2], module);
  }

  static Point _affine(_Anchor a, _Anchor b, _Anchor c, Point m) {
    final u = b.module - a.module;
    final v = c.module - a.module;
    final w = m - a.module;
    final det = u.cross(v);
    final s = w.cross(v) / det;
    final t = u.cross(w) / det;
    return a.pixel + (b.pixel - a.pixel) * s + (c.pixel - a.pixel) * t;
  }
}
