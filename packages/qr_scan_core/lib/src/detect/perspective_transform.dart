import '../common/geometry.dart';

class PerspectiveTransform {
  const PerspectiveTransform(
    this.a,
    this.b,
    this.c,
    this.d,
    this.e,
    this.f,
    this.g,
    this.h,
  );

  final double a, b, c, d, e, f, g, h;

  static PerspectiveTransform? fromPoints(List<Point> from, List<Point> to) {
    if (from.length != 4 || to.length != 4) {
      throw ArgumentError('need exactly 4 point pairs');
    }

    final m = List.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final x = from[i].x;
      final y = from[i].y;
      final u = to[i].x;
      final v = to[i].y;
      m[2 * i].setAll(0, [x, y, 1, 0, 0, 0, -x * u, -y * u, u]);
      m[2 * i + 1].setAll(0, [0, 0, 0, x, y, 1, -x * v, -y * v, v]);
    }

    final s = solve(m);
    if (s == null) return null;
    final t = PerspectiveTransform(
      s[0],
      s[1],
      s[2],
      s[3],
      s[4],
      s[5],
      s[6],
      s[7],
    );

    var sign = 0;
    for (final p in from) {
      final w = t.g * p.x + t.h * p.y + 1;
      if (w.abs() < 1e-9) return null;
      final sw = w > 0 ? 1 : -1;
      if (sign != 0 && sw != sign) return null;
      sign = sw;
    }
    return t;
  }

  static List<double>? solve(List<List<double>> m) {
    final n = m.length;
    var scale = 0.0;
    for (final row in m) {
      for (var j = 0; j < n; j++) {
        if (row[j].abs() > scale) scale = row[j].abs();
      }
    }
    if (scale == 0) return null;

    final eps = 1e-12 * scale;
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() <= eps) return null;

      if (pivot != col) {
        final t = m[pivot];
        m[pivot] = m[col];
        m[col] = t;
      }

      for (var r = col + 1; r < n; r++) {
        final factor = m[r][col] / m[col][col];
        if (factor == 0) continue;
        for (var k = col; k <= n; k++) {
          m[r][k] -= factor * m[col][k];
        }
      }
    }

    final x = List<double>.filled(n, 0);
    for (var r = n - 1; r >= 0; r--) {
      var s = m[r][n];
      for (var k = r + 1; k < n; k++) {
        s -= m[r][k] * x[k];
      }
      x[r] = s / m[r][r];
    }

    return x.every((v) => v.isFinite) ? x : null;
  }

  Point apply(double x, double y) {
    final w = g * x + h * y + 1;
    return Point((a * x + b * y + c) / w, (d * x + e * y + f) / w);
  }

  Point applyPoint(Point p) => apply(p.x, p.y);
}
