import 'dart:math' as math;

import '../common/bit_matrix.dart';
import '../common/geometry.dart';
import '../common/results.dart';
import '../common/version.dart';
import 'alignment_grid.dart';
import 'alignment_pattern.dart';
import 'finder_edges.dart';
import 'finder_selection.dart';
import 'grid_sampler.dart';
import 'perspective_transform.dart';
import 'timing_pattern.dart';

class DetectedSymbol {
  const DetectedSymbol({
    required this.modules,
    required this.corners,
    required this.triplet,
    required this.piecewise,
  });

  final BitMatrix modules;

  final Quad corners;

  final FinderTriplet triplet;

  final bool piecewise;

  int get dimension => modules.width;
}

class Detection {
  const Detection(this.candidates, [this.failure]);

  final List<DetectedSymbol> candidates;

  final ScanFailure? failure;
}

class _Mapping {
  const _Mapping(this.map, this.transform, {this.piecewise = false});

  _Mapping.global(PerspectiveTransform t) : this(GridSampler.global(t), t);

  final ModuleMapper map;
  final PerspectiveTransform transform;
  final bool piecewise;
}

class Detector {
  Detector(this.image);

  final BitMatrix image;

  static const List<double> alignmentAllowances = [4, 8, 16];

  Detection detect(FinderTriplet triplet, {int? dimension}) {
    final moduleSize = estimateModuleSize(triplet);
    if (!moduleSize.isFinite || moduleSize < 1) {
      return const Detection([], GeometryRejected('module size below 1 px'));
    }

    final sizes = dimension != null
        ? [dimension]
        : candidateDimensions(triplet, moduleSize);
    if (sizes.isEmpty) {
      return const Detection([], GeometryRejected('no valid symbol size'));
    }

    final out = <DetectedSymbol>[];
    ScanFailure failure = const GeometryRejected('degenerate geometry');
    for (final size in sizes) {
      final version = Version.forSize(size);
      if (version == null) continue;

      final symbols = _sample(triplet, version, moduleSize);
      if (symbols.isEmpty) {
        failure = const GeometryRejected('symbol extends beyond the image');
      }
      out.addAll(symbols);
    }
    return Detection(out, out.isEmpty ? failure : null);
  }

  List<DetectedSymbol> _sample(
    FinderTriplet t,
    Version version,
    double moduleSize,
  ) {
    final affine = globalTransform(t, null, version.size);
    if (affine == null) return const [];

    final List<_Mapping> mappings;
    if (version.hasVersionInfo) {
      mappings = _alignmentGridMappings(t, version, moduleSize);
    } else if (version.alignmentCenters.isNotEmpty) {
      mappings = _oneAlignmentMappings(t, version, moduleSize, affine);
    } else {
      mappings = _noAlignmentMappings(t, version, moduleSize, affine);
    }

    final out = <DetectedSymbol>[];
    for (final m in mappings) {
      final modules = GridSampler.sample(image, version.size, m.map);
      if (modules == null) continue;
      out.add(
        DetectedSymbol(
          modules: modules,
          corners: _corners(m.transform, version.size),
          triplet: t,
          piecewise: m.piecewise,
        ),
      );
    }
    return out;
  }

  List<_Mapping> _alignmentGridMappings(
    FinderTriplet t,
    Version version,
    double moduleSize,
  ) {
    final finder = AlignmentPatternFinder(image, moduleSize);
    final grid = AlignmentGrid.discover(
      finder,
      version,
      t,
      FinderEdgeEstimator(image),
      moduleSize,
    );
    final last = grid.size - 1;
    final bottomRight =
        grid.found(last, last) ??
        _searchBottomRight(finder, grid.point(last, last));

    final global = globalTransform(t, bottomRight, version.size);
    if (global == null) return const [];

    final out = <_Mapping>[];
    final piecewise = GridSampler.piecewise(grid.lines, grid.points);
    if (piecewise != null) {
      out.add(_Mapping(piecewise, global, piecewise: true));
    }
    out.add(_Mapping.global(global));
    return out;
  }

  List<_Mapping> _oneAlignmentMappings(
    FinderTriplet t,
    Version version,
    double moduleSize,
    PerspectiveTransform affine,
  ) {
    final dim = version.size;
    final finder = AlignmentPatternFinder(image, moduleSize);
    final bottomRight = _searchBottomRight(
      finder,
      affine.apply(dim - 6.5, dim - 6.5),
    );

    final out = <_Mapping>[];
    if (bottomRight != null) {
      final withAlignment = globalTransform(t, bottomRight, dim);
      if (withAlignment != null) out.add(_Mapping.global(withAlignment));
    }
    out.add(_Mapping.global(affine));
    if (bottomRight == null) {
      final edges = FinderEdgeEstimator(image).estimate(t, dim, moduleSize);
      if (edges != null) out.add(_Mapping.global(edges));
    }
    return out;
  }

  List<_Mapping> _noAlignmentMappings(
    FinderTriplet t,
    Version version,
    double moduleSize,
    PerspectiveTransform affine,
  ) {
    final out = <_Mapping>[];
    final estimator = FinderEdgeEstimator(image);
    final edges = estimator.estimate(t, version.size, moduleSize);
    if (edges != null) out.add(_Mapping.global(edges));
    out.add(_Mapping.global(affine));
    return out;
  }

  static Quad _corners(PerspectiveTransform t, int dim) {
    final d = dim.toDouble();
    return Quad(t.apply(0, 0), t.apply(d, 0), t.apply(d, d), t.apply(0, d));
  }

  Point? _searchBottomRight(AlignmentPatternFinder finder, Point estimate) {
    for (final allowance in alignmentAllowances) {
      final p = finder.find(estimate.x, estimate.y, allowance);
      if (p != null) return p;
    }
    return null;
  }

  static PerspectiveTransform? globalTransform(
    FinderTriplet t,
    Point? alignment,
    int dim,
  ) {
    final tl = t.topLeft.point;
    final tr = t.topRight.point;
    final bl = t.bottomLeft.point;
    final far = dim - 3.5;

    Point brModule = Point(far, far);
    Point brImage = tr - tl + bl;
    if (alignment != null) {
      brModule = Point(dim - 6.5, dim - 6.5);
      brImage = alignment;
    }

    return PerspectiveTransform.fromPoints(
      [const Point(3.5, 3.5), Point(far, 3.5), brModule, Point(3.5, far)],
      [tl, tr, brImage, bl],
    );
  }

  double estimateModuleSize(FinderTriplet t) {
    final a = _moduleSizeAlong(t.topLeft.point, t.topRight.point);
    final b = _moduleSizeAlong(t.topLeft.point, t.bottomLeft.point);
    if (a.isNaN && b.isNaN) return t.moduleSize;
    if (a.isNaN) return b;
    if (b.isNaN) return a;
    return (a + b) / 2;
  }

  double _moduleSizeAlong(Point from, Point to) {
    final atFrom = _finderWidth(from, to);
    final atTo = _finderWidth(to, from);
    if (atFrom.isNaN) return atTo / 7;
    if (atTo.isNaN) return atFrom / 7;
    return (atFrom + atTo) / 14;
  }

  double _finderWidth(Point centre, Point to) {
    final fromX = centre.x.floor();
    final fromY = centre.y.floor();
    final toX = to.x.floor();
    final toY = to.y.floor();
    final forward = _darkLightDarkLength(fromX, fromY, toX, toY);

    var scale = 1.0;
    var backX = fromX - (toX - fromX);
    if (backX < 0) {
      scale = fromX / (fromX - backX);
      backX = 0;
    } else if (backX >= image.width) {
      scale = (image.width - 1 - fromX) / (backX - fromX);
      backX = image.width - 1;
    }

    var backY = (fromY - (toY - fromY) * scale).floor();
    scale = 1.0;
    if (backY < 0) {
      scale = fromY / (fromY - backY);
      backY = 0;
    } else if (backY >= image.height) {
      scale = (image.height - 1 - fromY) / (backY - fromY);
      backY = image.height - 1;
    }
    backX = (fromX + (backX - fromX) * scale).floor();

    final backward = _darkLightDarkLength(fromX, fromY, backX, backY);
    return forward + backward - 1;
  }

  double _darkLightDarkLength(int fromX, int fromY, int toX, int toY) {
    final steep = (toY - fromY).abs() > (toX - fromX).abs();
    var fx = fromX;
    var fy = fromY;
    var tx = toX;
    var ty = toY;
    if (steep) {
      fx = fromY;
      fy = fromX;
      tx = toY;
      ty = toX;
    }

    final dx = (tx - fx).abs();
    final dy = (ty - fy).abs();
    final xStep = fx < tx ? 1 : -1;
    final yStep = fy < ty ? 1 : -1;
    var error = -dx ~/ 2;
    var y = fy;
    var state = 0;

    for (var x = fx; x != tx + xStep; x += xStep) {
      final px = steep ? y : x;
      final py = steep ? x : y;
      if (!image.contains(px, py)) break;

      final expectDark = state != 1;
      if (image.get(px, py) != expectDark) {
        if (state == 2) return _distance(x, y, fx, fy);
        state++;
      }

      error += dy;
      if (error > 0) {
        if (y == ty) break;
        y += yStep;
        error -= dx;
      }
    }
    if (state == 2) return _distance(tx + xStep, ty, fx, fy);
    return double.nan;
  }

  static double _distance(int ax, int ay, int bx, int by) {
    final dx = (ax - bx).toDouble();
    final dy = (ay - by).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  static List<int> estimateDimensions(FinderTriplet t, double moduleSize) {
    final across = t.topLeft.point.distanceTo(t.topRight.point) / moduleSize;
    final down = t.topLeft.point.distanceTo(t.bottomLeft.point) / moduleSize;
    final raw = (across + down) / 2 + 7;
    if (raw < 21 - 4 || raw > 177 + 4) return const [];

    final version = (raw - 17) / 4;
    final below = 17 + 4 * version.floor().clamp(1, 40);
    final above = 17 + 4 * version.ceil().clamp(1, 40);
    if (below == above) return [below];

    final dBelow = (raw - below).abs();
    final dAbove = (raw - above).abs();
    final nearer = dBelow <= dAbove ? below : above;
    final farther = dBelow <= dAbove ? above : below;
    if ((dBelow - dAbove).abs() < 2) return [nearer, farther];
    return [nearer];
  }

  List<int> candidateDimensions(FinderTriplet t, double moduleSize) {
    final estimated = estimateDimensions(t, moduleSize);
    final row = _timingRow(t, moduleSize);
    final column = _timingColumn(t, moduleSize);

    final out = <int>[];
    void add(int? d) {
      if (d == null || out.contains(d)) return;
      if (estimated.isNotEmpty && (d - estimated.first).abs() > 16) return;
      out.add(d);
    }

    if (row != null && row == column) add(row);
    add(row);
    add(column);
    estimated.forEach(add);
    return out;
  }

  int? _timingRow(FinderTriplet t, double moduleSize) {
    final reader = TimingPatternReader(image);
    return reader.read(
      t.topLeft.point,
      t.topRight.point,
      t.bottomLeft.point,
      moduleSize,
    );
  }

  int? _timingColumn(FinderTriplet t, double moduleSize) {
    final reader = TimingPatternReader(image);
    return reader.read(
      t.topLeft.point,
      t.bottomLeft.point,
      t.topRight.point,
      moduleSize,
    );
  }

  bool hasTimingPatterns(FinderTriplet t) {
    final moduleSize = estimateModuleSize(t);
    if (!moduleSize.isFinite || moduleSize < 1) return false;
    return _timingRow(t, moduleSize) != null &&
        _timingColumn(t, moduleSize) != null;
  }

  List<FinderTriplet> rankTriplets(List<FinderTriplet> triplets) {
    final withTiming = <FinderTriplet>[];
    final without = <FinderTriplet>[];
    for (final t in triplets) {
      if (hasTimingPatterns(t)) {
        withTiming.add(t);
      } else {
        without.add(t);
      }
    }
    return withTiming + without;
  }
}
