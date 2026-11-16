import '../common/bit_matrix.dart';
import '../common/geometry.dart';
import 'perspective_transform.dart';

typedef ModuleMapper = Point Function(double mx, double my);

abstract final class GridSampler {
  static const double edgeTolerance = 2;

  static const double maxOutsideShare = 0.2;

  static BitMatrix? sample(BitMatrix image, int dimension, ModuleMapper map) {
    final out = BitMatrix.square(dimension);
    var outside = 0;
    final w = image.width;
    final h = image.height;

    for (var y = 0; y < dimension; y++) {
      for (var x = 0; x < dimension; x++) {
        final p = map(x + 0.5, y + 0.5);
        if (!p.x.isFinite || !p.y.isFinite) return null;

        var px = p.x.floor();
        var py = p.y.floor();
        if (px < 0 || py < 0 || px >= w || py >= h) {
          if (p.x >= -edgeTolerance &&
              p.y >= -edgeTolerance &&
              p.x < w + edgeTolerance &&
              p.y < h + edgeTolerance) {
            px = px.clamp(0, w - 1);
            py = py.clamp(0, h - 1);
          } else {
            outside++;
            continue;
          }
        }

        if (image.get(px, py)) out.set(x, y);
      }
    }

    if (outside > dimension * dimension * maxOutsideShare) return null;
    return out;
  }

  static ModuleMapper global(PerspectiveTransform t) => t.apply;

  static ModuleMapper? piecewise(List<double> lines, List<List<Point>> points) {
    final k = lines.length;
    if (k < 2) return null;
    final cells = <List<PerspectiveTransform>>[];
    for (var i = 0; i < k - 1; i++) {
      final row = <PerspectiveTransform>[];
      for (var j = 0; j < k - 1; j++) {
        final t = PerspectiveTransform.fromPoints(
          [
            Point(lines[j], lines[i]),
            Point(lines[j + 1], lines[i]),
            Point(lines[j + 1], lines[i + 1]),
            Point(lines[j], lines[i + 1]),
          ],
          [
            points[i][j],
            points[i][j + 1],
            points[i + 1][j + 1],
            points[i + 1][j],
          ],
        );
        if (t == null) return null;
        row.add(t);
      }
      cells.add(row);
    }
    int cellOf(double v) {
      var c = 0;
      while (c < k - 2 && v >= lines[c + 1]) {
        c++;
      }
      return c;
    }

    return (mx, my) => cells[cellOf(my)][cellOf(mx)].apply(mx, my);
  }
}
