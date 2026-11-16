import '../common/bit_matrix.dart';
import '../common/geometry.dart';
import 'finder_selection.dart';
import 'perspective_transform.dart';

class Correspondences {
  Correspondences(this.module, this.pixel);

  final List<Point> module;

  final List<Point> pixel;

  void add(Point m, Point p) {
    module.add(m);
    pixel.add(p);
  }
}

class FinderEdgeEstimator {
  const FinderEdgeEstimator(this.image);

  final BitMatrix image;

  static const double step = 0.25;

  PerspectiveTransform? estimate(FinderTriplet t, int dim, double moduleSize) {
    final seeds = correspondences(t, dim, moduleSize);
    if (seeds.module.length < 8) return null;

    final first = leastSquares(seeds.module, seeds.pixel);
    if (first == null) return null;

    final refined = refineWithTiming(first, dim, seeds.module, seeds.pixel);
    return refined ?? first;
  }

  PerspectiveTransform? refineWithTiming(
    PerspectiveTransform estimate,
    int dim,
    List<Point> from,
    List<Point> to,
  ) {
    final n = dim.toDouble();
    final f = List<Point>.of(from);
    final g = List<Point>.of(to);
    var added = 0;
    for (final horizontal in [true, false]) {
      final boundaries = _timingBoundaries(estimate, n, horizontal);
      if (boundaries == null) continue;

      for (var i = 0; i < boundaries.length; i++) {
        final along = 7.0 + i;
        if (horizontal) {
          f.add(Point(along, 6.5));
        } else {
          f.add(Point(6.5, along));
        }
        g.add(boundaries[i]);
      }
      added += boundaries.length;
    }
    if (added == 0) return null;
    return leastSquares(f, g);
  }

  List<Point>? _timingBoundaries(
    PerspectiveTransform t,
    double n,
    bool horizontal,
  ) {
    final a = horizontal ? t.apply(5, 6.5) : t.apply(6.5, 5);
    final b = horizontal ? t.apply(n - 5, 6.5) : t.apply(6.5, n - 5);
    final len = a.distanceTo(b);
    if (!len.isFinite || len < 1) return null;

    final steps = (len / step).ceil();
    final out = <Point>[];
    bool? last;
    Point? lastPoint;
    for (var s = 0; s <= steps; s++) {
      final p = Point(
        a.x + (b.x - a.x) * s / steps,
        a.y + (b.y - a.y) * s / steps,
      );
      final x = p.x.floor();
      final y = p.y.floor();
      if (!image.contains(x, y)) return null;
      final dark = image.get(x, y);
      if (last != null && dark != last) {
        out.add(Point((p.x + lastPoint!.x) / 2, (p.y + lastPoint.y) / 2));
      }
      last = dark;
      lastPoint = p;
    }
    return out.length == n - 13 ? out : null;
  }

  Correspondences correspondences(FinderTriplet t, int dim, double moduleSize) {
    final n = dim.toDouble();
    final tl = t.topLeft.point;
    final tr = t.topRight.point;
    final bl = t.bottomLeft.point;
    final out = Correspondences([], []);
    out.add(const Point(3.5, 3.5), tl);
    out.add(Point(n - 3.5, 3.5), tr);
    out.add(Point(3.5, n - 3.5), bl);

    final maxLength = 5.0 * moduleSize * 1.6;
    void edge(Point centre, Point towards, bool forward, Point module) {
      final p = edgePoint(centre, towards, forward, maxLength);
      if (p != null) out.add(module, p);
    }

    edge(tl, tr, true, const Point(7, 3.5));
    edge(tl, tr, false, const Point(0, 3.5));
    edge(tl, bl, true, const Point(3.5, 7));
    edge(tl, bl, false, const Point(3.5, 0));
    edge(tr, tl, true, Point(n - 7, 3.5));
    edge(tr, tl, false, Point(n, 3.5));
    edge(tr, bl, true, Point(n - 7, 7));
    edge(tr, bl, false, Point(n, 0));
    edge(bl, tl, true, Point(3.5, n - 7));
    edge(bl, tl, false, Point(3.5, n));
    edge(bl, tr, true, Point(7, n - 7));
    edge(bl, tr, false, Point(0, n));
    return out;
  }

  Point? edgePoint(
    Point centre,
    Point towards,
    bool forward,
    double maxLength,
  ) {
    final len = (towards - centre).length;
    if (len == 0) return null;
    final sign = forward ? 1 : -1;
    final d = (towards - centre) * (sign / len);

    var state = 0;
    Point? lastDark;
    for (var s = 0.0; s <= maxLength; s += step) {
      final p = centre + d * s;
      final x = p.x.floor();
      final y = p.y.floor();
      if (!image.contains(x, y)) return null;
      final dark = image.get(x, y);
      switch (state) {
        case 0:
          if (!dark) state = 1;
        case 1:
          if (dark) state = 2;
        case 2:
          if (dark) {
            lastDark = p;
          } else {
            final end = lastDark ?? p;
            return Point((end.x + p.x) / 2, (end.y + p.y) / 2);
          }
      }
    }
    return null;
  }

  static PerspectiveTransform? robustLeastSquares(
    List<Point> from,
    List<Point> to, {
    List<double>? weights,
    required double maxResidual,
  }) {
    final first = leastSquares(from, to, weights: weights);
    if (first == null) return null;
    final keepFrom = <Point>[];
    final keepTo = <Point>[];
    final keepW = <double>[];
    for (var i = 0; i < from.length; i++) {
      if (first.applyPoint(from[i]).distanceTo(to[i]) <= maxResidual) {
        keepFrom.add(from[i]);
        keepTo.add(to[i]);
        if (weights == null) {
          keepW.add(1);
        } else {
          keepW.add(weights[i]);
        }
      }
    }
    if (keepFrom.length == from.length || keepFrom.length < 6) return first;
    return leastSquares(keepFrom, keepTo, weights: keepW) ?? first;
  }

  static PerspectiveTransform? leastSquares(
    List<Point> from,
    List<Point> to, {
    List<double>? weights,
  }) {
    final fromNorm = _Normalisation.of(from);
    final toNorm = _Normalisation.of(to);
    final fm = fromNorm.centre;
    final fs = fromNorm.scale;
    final tm = toNorm.centre;
    final ts = toNorm.scale;

    final ata = List.generate(8, (_) => List<double>.filled(9, 0));
    void addRow(List<double> row, double rhs, double w) {
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
          ata[i][j] += w * row[i] * row[j];
        }
        ata[i][8] += w * row[i] * rhs;
      }
    }

    for (var k = 0; k < from.length; k++) {
      final x = (from[k].x - fm.x) * fs;
      final y = (from[k].y - fm.y) * fs;
      final u = (to[k].x - tm.x) * ts;
      final v = (to[k].y - tm.y) * ts;
      var w = 1.0;
      if (weights != null) w = weights[k];
      addRow([x, y, 1, 0, 0, 0, -x * u, -y * u], u, w);
      addRow([0, 0, 0, x, y, 1, -x * v, -y * v], v, w);
    }

    final h = PerspectiveTransform.solve(ata);
    if (h == null) return null;

    final hn = [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0];
    final tf = [fs, 0.0, -fs * fm.x, 0.0, fs, -fs * fm.y, 0.0, 0.0, 1.0];
    final ttInv = [1 / ts, 0.0, tm.x, 0.0, 1 / ts, tm.y, 0.0, 0.0, 1.0];
    final m = _mul(ttInv, _mul(hn, tf));
    if (m[8].abs() < 1e-12) return null;
    final k = 1 / m[8];
    return PerspectiveTransform(
      m[0] * k,
      m[1] * k,
      m[2] * k,
      m[3] * k,
      m[4] * k,
      m[5] * k,
      m[6] * k,
      m[7] * k,
    );
  }

  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(9, 0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        out[r * 3 + c] =
            a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
      }
    }
    return out;
  }
}

class _Normalisation {
  _Normalisation(this.centre, this.scale);

  factory _Normalisation.of(List<Point> pts) {
    var cx = 0.0;
    var cy = 0.0;
    for (final p in pts) {
      cx += p.x;
      cy += p.y;
    }
    final centre = Point(cx / pts.length, cy / pts.length);

    var spread = 0.0;
    for (final p in pts) {
      spread += (p - centre).length;
    }
    spread /= pts.length;
    return _Normalisation(centre, spread == 0 ? 1 : 1 / spread);
  }

  final Point centre;
  final double scale;
}
