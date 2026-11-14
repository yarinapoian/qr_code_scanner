library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:qr_scan_core/src/common/bit_matrix.dart';
import 'package:qr_scan_core/src/common/geometry.dart';
import 'package:qr_scan_core/src/image/luminance_image.dart';

class Homography {
  Homography(this.m);

  final List<double> m;

  factory Homography.unitSquareTo(List<Point> p) {
    final dx1 = p[1].x - p[2].x, dx2 = p[3].x - p[2].x;
    final dy1 = p[1].y - p[2].y, dy2 = p[3].y - p[2].y;
    final sx = p[0].x - p[1].x + p[2].x - p[3].x;
    final sy = p[0].y - p[1].y + p[2].y - p[3].y;
    double g = 0, h = 0;
    if (sx.abs() > 1e-12 || sy.abs() > 1e-12) {
      final den = dx1 * dy2 - dx2 * dy1;
      g = (sx * dy2 - dx2 * sy) / den;
      h = (dx1 * sy - sx * dy1) / den;
    }
    final a = p[1].x - p[0].x + g * p[1].x;
    final b = p[3].x - p[0].x + h * p[3].x;
    final c = p[0].x;
    final d = p[1].y - p[0].y + g * p[1].y;
    final e = p[3].y - p[0].y + h * p[3].y;
    final f = p[0].y;
    return Homography([a, b, c, d, e, f, g, h, 1]);
  }

  Point apply(double x, double y) {
    final w = m[6] * x + m[7] * y + m[8];
    return Point(
      (m[0] * x + m[1] * y + m[2]) / w,
      (m[3] * x + m[4] * y + m[5]) / w,
    );
  }

  Homography inverse() {
    final [a, b, c, d, e, f, g, h, i] = m;
    final adj = [
      e * i - f * h,
      c * h - b * i,
      b * f - c * e,
      f * g - d * i,
      a * i - c * g,
      c * d - a * f,
      d * h - e * g,
      b * g - a * h,
      a * e - b * d,
    ];
    return Homography(adj);
  }
}

class Placement {
  Placement(this.symbol, this.corners, {this.quietZone = 4});

  final BitMatrix symbol;

  final Quad corners;

  final int quietZone;
}

class PhotoOptions {
  const PhotoOptions({
    this.dark = 30,
    this.light = 220,
    this.background = 200,
    this.noiseSigma = 0,
    this.blurRadius = 0,
    this.shadow = 0,
    this.gradient = 0,
    this.supersample = 3,
    this.seed = 0,
    this.clutter = 0,
  });

  final int dark;

  final int light;

  final int background;

  final double noiseSigma;

  final int blurRadius;

  final double shadow;

  final double gradient;

  final int supersample;

  final int seed;

  final int clutter;
}

class SyntheticPhoto {
  SyntheticPhoto(this.image, this.placements);

  final LuminanceImage image;
  final List<Placement> placements;

  Quad get corners => placements.first.corners;
}

SyntheticPhoto renderScene(
  int width,
  int height,
  List<Placement> placements, {
  PhotoOptions options = const PhotoOptions(),
}) {
  final rnd = math.Random(options.seed);
  final px = Float64List(width * height)
    ..fillRange(0, width * height, options.background.toDouble());
  for (var k = 0; k < options.clutter; k++) {
    final w = 3 + rnd.nextInt(width ~/ 8 + 1);
    final h = 3 + rnd.nextInt(height ~/ 8 + 1);
    final x0 = rnd.nextInt(width);
    final y0 = rnd.nextInt(height);
    final v = 20.0 + rnd.nextInt(120);
    for (var y = y0; y < math.min(height, y0 + h); y++) {
      for (var x = x0; x < math.min(width, x0 + w); x++) {
        px[y * width + x] = v;
      }
    }
  }
  for (final p in placements) {
    _draw(px, width, height, p, options);
  }
  _light(px, width, height, options);
  if (options.blurRadius > 0) {
    _boxBlur(px, width, height, options.blurRadius);
    _boxBlur(px, width, height, options.blurRadius);
  }
  final out = Uint8List(width * height);
  for (var i = 0; i < out.length; i++) {
    var v = px[i];
    if (options.noiseSigma > 0) v += _gauss(rnd) * options.noiseSigma;
    out[i] = v.round().clamp(0, 255);
  }
  return SyntheticPhoto(LuminanceImage(width, height, out), placements);
}

void _draw(Float64List px, int width, int height, Placement p, PhotoOptions o) {
  final n = p.symbol.width;
  final q = p.quietZone;
  final c = p.corners;
  final toImage = Homography.unitSquareTo(c.points);
  final toModule = toImage.inverse();
  final outer = [
    for (final (u, v) in [(-q, -q), (n + q, -q), (n + q, n + q), (-q, n + q)])
      toImage.apply(u / n, v / n),
  ];
  final minX = math.max(0, outer.map((e) => e.x).reduce(math.min).floor());
  final maxX = math.min(
    width - 1,
    outer.map((e) => e.x).reduce(math.max).ceil(),
  );
  final minY = math.max(0, outer.map((e) => e.y).reduce(math.min).floor());
  final maxY = math.min(
    height - 1,
    outer.map((e) => e.y).reduce(math.max).ceil(),
  );
  final ss = o.supersample;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      var sum = 0.0;
      var inside = 0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final m = toModule.apply(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss);
          final u = m.x * n;
          final v = m.y * n;
          if (u < -q || v < -q || u >= n + q || v >= n + q) continue;
          inside++;
          final mu = u.floor();
          final mv = v.floor();
          final isDark =
              mu >= 0 && mv >= 0 && mu < n && mv < n && p.symbol.get(mu, mv);
          sum += isDark ? o.dark : o.light;
        }
      }
      if (inside == 0) continue;
      final i = y * width + x;
      final total = ss * ss;
      px[i] = (sum + px[i] * (total - inside)) / total;
    }
  }
}

void _light(Float64List px, int width, int height, PhotoOptions o) {
  if (o.shadow == 0 && o.gradient == 0) return;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var f = 1.0 - o.gradient * x / width;
      if (o.shadow > 0 && x >= width ~/ 2) f *= 1 - o.shadow;
      px[y * width + x] *= f;
    }
  }
}

void _boxBlur(Float64List px, int width, int height, int r) {
  final tmp = Float64List(px.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var s = 0.0;
      var n = 0;
      for (var k = -r; k <= r; k++) {
        final xx = x + k;
        if (xx < 0 || xx >= width) continue;
        s += px[y * width + xx];
        n++;
      }
      tmp[y * width + x] = s / n;
    }
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var s = 0.0;
      var n = 0;
      for (var k = -r; k <= r; k++) {
        final yy = y + k;
        if (yy < 0 || yy >= height) continue;
        s += tmp[yy * width + x];
        n++;
      }
      px[y * width + x] = s / n;
    }
  }
}

double _gauss(math.Random r) {
  final u1 = 1 - r.nextDouble();
  final u2 = r.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

class Pose {
  const Pose({
    this.moduleSize = 4,
    this.rotationDeg = 0,
    this.tiltXDeg = 0,
    this.tiltYDeg = 0,
    this.margin = 12,
  });

  final double moduleSize;

  final double rotationDeg;

  final double tiltXDeg;

  final double tiltYDeg;

  final int margin;
}

Quad poseCorners(int n, Pose pose, double cx, double cy) {
  final s = n * pose.moduleSize;
  final ax = pose.tiltXDeg * math.pi / 180;
  final ay = pose.tiltYDeg * math.pi / 180;
  final rz = pose.rotationDeg * math.pi / 180;
  final dist = 2.5 * s;
  Point project(double x, double y) {
    var y1 = y * math.cos(ax);
    var z1 = y * math.sin(ax);
    final x2 = x * math.cos(ay) + z1 * math.sin(ay);
    z1 = -x * math.sin(ay) + z1 * math.cos(ay);
    final k = dist / (dist + z1);
    final px = x2 * k;
    y1 *= k;
    return Point(
      cx + px * math.cos(rz) - y1 * math.sin(rz),
      cy + px * math.sin(rz) + y1 * math.cos(rz),
    );
  }

  final h = s / 2;
  return Quad(project(-h, -h), project(h, -h), project(h, h), project(-h, h));
}

SyntheticPhoto renderCode(
  BitMatrix symbol, {
  Pose pose = const Pose(),
  PhotoOptions options = const PhotoOptions(),
  int quietZone = 4,
}) {
  final n = symbol.width;
  final probe = poseCorners(n + 2 * quietZone, pose, 0, 0);
  final xs = probe.points.map((p) => p.x);
  final ys = probe.points.map((p) => p.y);
  final w =
      (xs.reduce(math.max) - xs.reduce(math.min)).ceil() + 2 * pose.margin;
  final h =
      (ys.reduce(math.max) - ys.reduce(math.min)).ceil() + 2 * pose.margin;
  final cx = pose.margin - xs.reduce(math.min);
  final cy = pose.margin - ys.reduce(math.min);
  final corners = poseCorners(n, pose, cx, cy);
  return renderScene(w, h, [
    Placement(symbol, corners, quietZone: quietZone),
  ], options: options);
}

SyntheticPhoto invertPhoto(SyntheticPhoto p) =>
    SyntheticPhoto(p.image.inverted(), p.placements);

SyntheticPhoto mirrorPhoto(SyntheticPhoto p) {
  final w = p.image.width.toDouble();
  Point f(Point q) => Point(w - q.x, q.y);
  return SyntheticPhoto(p.image.mirrored(), [
    for (final pl in p.placements)
      Placement(
        pl.symbol,
        Quad(
          f(pl.corners.topLeft),
          f(pl.corners.topRight),
          f(pl.corners.bottomRight),
          f(pl.corners.bottomLeft),
        ),
        quietZone: pl.quietZone,
      ),
  ]);
}

SyntheticPhoto rotatePhoto90(SyntheticPhoto p) {
  final src = p.image;
  final w = src.width;
  final h = src.height;
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out[x * h + (h - 1 - y)] = src.bytes[y * w + x];
    }
  }
  Point f(Point q) => Point(h - q.y, q.x);
  return SyntheticPhoto(LuminanceImage(h, w, out), [
    for (final pl in p.placements)
      Placement(
        pl.symbol,
        Quad(
          f(pl.corners.topLeft),
          f(pl.corners.topRight),
          f(pl.corners.bottomRight),
          f(pl.corners.bottomLeft),
        ),
        quietZone: pl.quietZone,
      ),
  ]);
}

double binarizationErrorRate(SyntheticPhoto photo, BitMatrix binary) {
  var errors = 0;
  var total = 0;
  for (final p in photo.placements) {
    final n = p.symbol.width;
    final toModule = Homography.unitSquareTo(p.corners.points).inverse();
    for (var y = 0; y < photo.image.height; y++) {
      for (var x = 0; x < photo.image.width; x++) {
        final m = toModule.apply(x + 0.5, y + 0.5);
        final u = m.x * n;
        final v = m.y * n;
        if (u < 0 || v < 0 || u >= n || v >= n) continue;
        final fu = u - u.floor();
        final fv = v - v.floor();
        if (fu < 0.25 || fu > 0.75 || fv < 0.25 || fv > 0.75) continue;
        total++;
        if (binary.get(x, y) != p.symbol.get(u.floor(), v.floor())) errors++;
      }
    }
  }
  return total == 0 ? 0 : errors / total;
}
