import '../common/bit_matrix.dart';
import '../common/geometry.dart';

class TimingPatternReader {
  const TimingPatternReader(this.image);

  final BitMatrix image;

  static const List<double> offsets = [3.0, 2.75, 3.25, 2.5, 3.5];

  int? read(Point from, Point to, Point side, double moduleSize) {
    final along = to - from;
    final length = along.length;
    if (length < 10 * moduleSize) return null;

    final u = along * (1 / length);
    final toSide = side - from;
    final perp = toSide - u * toSide.dot(u);
    if (perp.length == 0) return null;
    final normal = perp * (1 / perp.length);

    final votes = <int, int>{};
    for (final offset in offsets) {
      final shift = normal * (offset * moduleSize);
      final d = _count(from + shift, to + shift, moduleSize);
      if (d != null) votes[d] = (votes[d] ?? 0) + 1;
    }
    if (votes.isEmpty) return null;

    int? best;
    var bestVotes = 0;
    for (final entry in votes.entries) {
      final better =
          entry.value > bestVotes ||
          (entry.value == bestVotes && entry.key < best!);
      if (better) {
        best = entry.key;
        bestVotes = entry.value;
      }
    }
    return best;
  }

  int? _count(Point a, Point b, double moduleSize) {
    final steps = (a.distanceTo(b) * 2).ceil();
    if (steps < 4) return null;

    final runs = <int>[];
    final colours = <bool>[];
    _collectRuns(a, b, steps, runs, colours);
    _mergeShortRuns(runs, colours, (0.3 * moduleSize * 2).ceil());
    if (runs.length < 5 || !colours.first || !colours.last) return null;

    final inner = runs.sublist(1, runs.length - 1);
    final sorted = List.of(inner);
    sorted.sort();
    final median = sorted[sorted.length ~/ 2];
    for (final r in inner) {
      if (r < 0.4 * median || r > 2.2 * median) return null;
    }

    final darkInner = (inner.length - 1) ~/ 2;
    final dim = 2 * darkInner + 15;
    if (dim < 21 || dim > 177) return null;
    return dim;
  }

  void _collectRuns(
    Point a,
    Point b,
    int steps,
    List<int> runs,
    List<bool> colours,
  ) {
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final x = (a.x + (b.x - a.x) * t).floor();
      final y = (a.y + (b.y - a.y) * t).floor();
      final dark = image.contains(x, y) && image.get(x, y);
      if (colours.isNotEmpty && colours.last == dark) {
        runs[runs.length - 1]++;
      } else {
        colours.add(dark);
        runs.add(1);
      }
    }
  }

  static void _mergeShortRuns(List<int> runs, List<bool> colours, int minRun) {
    var merged = true;
    while (merged && runs.length > 2) {
      merged = false;
      for (var i = 1; i < runs.length - 1; i++) {
        if (runs[i] < minRun) {
          runs[i - 1] += runs[i] + runs[i + 1];
          runs.removeRange(i, i + 2);
          colours.removeRange(i, i + 2);
          merged = true;
          break;
        }
      }
    }
  }
}
