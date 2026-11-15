import 'dart:math' as math;

import 'finder_pattern.dart';

class FinderTriplet {
  const FinderTriplet(this.topLeft, this.topRight, this.bottomLeft, this.score);

  final FinderPattern topLeft;

  final FinderPattern topRight;

  final FinderPattern bottomLeft;

  final double score;

  List<FinderPattern> get patterns => [topLeft, topRight, bottomLeft];

  double get moduleSize {
    return (topLeft.moduleSize + topRight.moduleSize + bottomLeft.moduleSize) /
        3;
  }

  @override
  String toString() => 'Triplet(TL $topLeft, TR $topRight, BL $bottomLeft)';
}

abstract final class FinderSelector {
  static const double maxLegImbalance = 0.4;

  static const double maxCosine = 0.4;

  static const double maxModuleRatio = 1.8;

  static const double minSpan = 9;

  static const double maxSpan = 185;

  static List<FinderTriplet> triplets(
    List<FinderPattern> candidates, {
    int maxCandidates = 16,
    int maxTriplets = 32,
  }) {
    final c = candidates.take(maxCandidates).toList();
    final out = <FinderTriplet>[];
    for (var i = 0; i < c.length; i++) {
      for (var j = i + 1; j < c.length; j++) {
        for (var k = j + 1; k < c.length; k++) {
          final t = evaluate(c[i], c[j], c[k]);
          if (t != null) out.add(t);
        }
      }
    }
    out.sort((a, b) => a.score.compareTo(b.score));
    return out.take(maxTriplets).toList();
  }

  static FinderTriplet? evaluate(
    FinderPattern a,
    FinderPattern b,
    FinderPattern c,
  ) {
    final minSize = math.min(
      a.moduleSize,
      math.min(b.moduleSize, c.moduleSize),
    );
    final maxSize = math.max(
      a.moduleSize,
      math.max(b.moduleSize, c.moduleSize),
    );
    if (minSize <= 0 || maxSize / minSize > maxModuleRatio) return null;

    final ab = a.point.distanceTo(b.point);
    final bc = b.point.distanceTo(c.point);
    final ac = a.point.distanceTo(c.point);
    var tl = c;
    var p = a;
    var q = b;
    if (bc >= ab && bc >= ac) {
      tl = a;
      p = b;
      q = c;
    } else if (ac >= ab && ac >= bc) {
      tl = b;
      p = a;
      q = c;
    }

    final v1 = p.point - tl.point;
    final v2 = q.point - tl.point;
    final l1 = v1.length;
    final l2 = v2.length;
    if (l1 == 0 || l2 == 0) return null;
    final imbalance = (l1 - l2).abs() / math.max(l1, l2);
    if (imbalance > maxLegImbalance) return null;
    final cosine = v1.dot(v2) / (l1 * l2);
    if (cosine.abs() > maxCosine) return null;
    final meanSize = (a.moduleSize + b.moduleSize + c.moduleSize) / 3;
    final span = (l1 + l2) / 2 / meanSize;
    if (span < minSpan || span > maxSpan) return null;

    final clockwise = v1.cross(v2) > 0;
    final tr = clockwise ? p : q;
    final bl = clockwise ? q : p;
    final score = imbalance + cosine.abs() + (maxSize - minSize) / maxSize;
    return FinderTriplet(tl, tr, bl, score);
  }
}
