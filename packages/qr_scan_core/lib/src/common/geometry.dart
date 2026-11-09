import 'dart:math' as math;

class Point {
  const Point(this.x, this.y);

  final double x;

  final double y;

  double distanceTo(Point o) {
    final dx = x - o.x;
    final dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Point operator +(Point o) => Point(x + o.x, y + o.y);

  Point operator -(Point o) => Point(x - o.x, y - o.y);

  Point operator *(double k) => Point(x * k, y * k);

  double cross(Point o) => x * o.y - y * o.x;

  double dot(Point o) => x * o.x + y * o.y;

  double get length => math.sqrt(x * x + y * y);

  @override
  bool operator ==(Object other) {
    return other is Point && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

class Quad {
  const Quad(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);

  final Point topLeft;

  final Point topRight;

  final Point bottomRight;

  final Point bottomLeft;

  List<Point> get points => [topLeft, topRight, bottomRight, bottomLeft];

  Point get center {
    final x = (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4;
    final y = (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4;
    return Point(x, y);
  }

  bool contains(Point p) {
    final pts = points;
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final c = (b - a).cross(p - a);
      if (c == 0) continue;
      final s = c > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'Quad($topLeft, $topRight, $bottomRight, $bottomLeft)';
}
