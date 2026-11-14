import 'dart:typed_data';

class LuminanceImage {
  LuminanceImage(this.width, this.height, this.bytes) {
    if (width < 0 || height < 0) {
      throw ArgumentError('negative size ${width}x$height');
    }
    if (bytes.length != width * height) {
      throw ArgumentError(
        'bytes.length is ${bytes.length}, expected ${width * height} '
        '(${width}x$height)',
      );
    }
  }

  factory LuminanceImage.fromYPlane(
    int width,
    int height,
    Uint8List plane, {
    int? rowStride,
  }) {
    final stride = rowStride ?? width;
    if (stride < width) throw ArgumentError('rowStride $stride < width $width');
    if (height > 0 && plane.length < stride * (height - 1) + width) {
      throw ArgumentError('plane too short for ${width}x$height @ $stride');
    }
    if (stride == width && plane.length == width * height) {
      return LuminanceImage(width, height, plane);
    }
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      out.setRange(y * width, (y + 1) * width, plane, y * stride);
    }
    return LuminanceImage(width, height, out);
  }

  factory LuminanceImage.fromRgba(int width, int height, Uint8List rgba) {
    if (width < 0 || height < 0) {
      throw ArgumentError('negative size ${width}x$height');
    }
    if (rgba.length != width * height * 4) {
      throw ArgumentError(
        'rgba.length ${rgba.length} != ${width * height * 4}',
      );
    }

    final out = Uint8List(width * height);
    for (var i = 0; i < out.length; i++) {
      final r = rgba[i * 4];
      final g = rgba[i * 4 + 1];
      final b = rgba[i * 4 + 2];
      final a = rgba[i * 4 + 3];
      final y = (299 * r + 587 * g + 114 * b + 500) ~/ 1000;
      out[i] = (y * a + 255 * (255 - a) + 127) ~/ 255;
    }
    return LuminanceImage(width, height, out);
  }

  final int width;

  final int height;

  final Uint8List bytes;

  int get(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      throw RangeError('($x, $y) outside ${width}x$height');
    }
    return bytes[y * width + x];
  }

  LuminanceImage inverted() {
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      out[i] = 255 - bytes[i];
    }
    return LuminanceImage(width, height, out);
  }

  LuminanceImage mirrored() {
    final out = Uint8List(bytes.length);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        out[row + x] = bytes[row + width - 1 - x];
      }
    }
    return LuminanceImage(width, height, out);
  }

  LuminanceImage downscaled(int factor) {
    if (factor < 1) throw ArgumentError('factor must be ≥ 1');
    if (factor == 1) return this;

    final w = width ~/ factor;
    final h = height ~/ factor;
    final out = Uint8List(w * h);
    final area = factor * factor;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0;
        for (var dy = 0; dy < factor; dy++) {
          final row = (y * factor + dy) * width + x * factor;
          for (var dx = 0; dx < factor; dx++) {
            sum += bytes[row + dx];
          }
        }
        out[y * w + x] = (sum + area ~/ 2) ~/ area;
      }
    }
    return LuminanceImage(w, h, out);
  }

  List<int> histogram() {
    final h = List<int>.filled(256, 0);
    for (final v in bytes) {
      h[v]++;
    }
    return h;
  }
}
