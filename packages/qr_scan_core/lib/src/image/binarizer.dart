import 'dart:typed_data';

import '../common/bit_matrix.dart';
import 'luminance_image.dart';

abstract interface class Binarizer {
  BitMatrix binarize(LuminanceImage image);
}

const int minBlackWhiteDifference = 24;

class OtsuBinarizer implements Binarizer {
  const OtsuBinarizer();

  @override
  BitMatrix binarize(LuminanceImage image) {
    final out = BitMatrix(image.width, image.height);
    final t = threshold(image.histogram());
    if (t == null) return out;

    final w = image.width;
    final bytes = image.bytes;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < w; x++) {
        if (bytes[y * w + x] <= t) out.set(x, y);
      }
    }
    return out;
  }

  static int? threshold(List<int> histogram) {
    var total = 0;
    var sumAll = 0.0;
    var lo = -1;
    var hi = -1;
    for (var i = 0; i < 256; i++) {
      final c = histogram[i];
      if (c == 0) continue;
      if (lo < 0) lo = i;
      hi = i;
      total += c;
      sumAll += i * c;
    }
    if (total == 0 || hi - lo < minBlackWhiteDifference) return null;

    var weightDark = 0;
    var sumDark = 0.0;
    var best = lo;
    var bestVariance = -1.0;
    for (var t = lo; t < hi; t++) {
      weightDark += histogram[t];
      if (weightDark == 0) continue;
      final weightLight = total - weightDark;
      if (weightLight == 0) break;

      sumDark += t * histogram[t];
      final meanDark = sumDark / weightDark;
      final meanLight = (sumAll - sumDark) / weightLight;
      final diff = meanDark - meanLight;
      final variance = weightDark.toDouble() * weightLight * diff * diff;
      if (variance > bestVariance) {
        bestVariance = variance;
        best = t;
      }
    }
    return best;
  }
}

class LocalBlockBinarizer implements Binarizer {
  const LocalBlockBinarizer();

  static const int blockSize = 8;

  static const int minimumDimension = blockSize * 5;

  @override
  BitMatrix binarize(LuminanceImage image) {
    final w = image.width;
    final h = image.height;
    if (w < minimumDimension || h < minimumDimension) {
      return const OtsuBinarizer().binarize(image);
    }

    final blocksX = (w + blockSize - 1) ~/ blockSize;
    final blocksY = (h + blockSize - 1) ~/ blockSize;
    final blackPoints = blockBlackPoints(image, blocksX, blocksY);

    final out = BitMatrix(w, h);
    for (var by = 0; by < blocksY; by++) {
      for (var bx = 0; bx < blocksX; bx++) {
        final threshold = _neighbourhoodMean(
          blackPoints,
          bx,
          by,
          blocksX,
          blocksY,
        );
        _thresholdBlock(image, _offset(bx, w), _offset(by, h), threshold, out);
      }
    }
    return out;
  }

  static int _neighbourhoodMean(
    Uint8List points,
    int bx,
    int by,
    int blocksX,
    int blocksY,
  ) {
    final cx = bx.clamp(2, blocksX - 3);
    final cy = by.clamp(2, blocksY - 3);
    var sum = 0;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        sum += points[(cy + dy) * blocksX + cx + dx];
      }
    }
    return sum ~/ 25;
  }

  static Uint8List blockBlackPoints(
    LuminanceImage image,
    int blocksX,
    int blocksY,
  ) {
    final points = Uint8List(blocksX * blocksY);
    for (var by = 0; by < blocksY; by++) {
      for (var bx = 0; bx < blocksX; bx++) {
        final stats = _BlockStats.of(image, bx, by);
        final min = stats.min;
        var point = stats.mean;

        if (stats.max - min <= minBlackWhiteDifference) {
          point = min ~/ 2;
          if (by > 0 && bx > 0) {
            final up = points[(by - 1) * blocksX + bx];
            final left = points[by * blocksX + bx - 1];
            final upLeft = points[(by - 1) * blocksX + bx - 1];
            final neighbours = (up + 2 * left + upLeft) ~/ 4;
            if (min < neighbours) point = neighbours;
          }
        }
        points[by * blocksX + bx] = point;
      }
    }
    return points;
  }

  static void _thresholdBlock(
    LuminanceImage image,
    int left,
    int top,
    int threshold,
    BitMatrix out,
  ) {
    final w = image.width;
    for (var y = top; y < top + blockSize; y++) {
      for (var x = left; x < left + blockSize; x++) {
        if (image.bytes[y * w + x] <= threshold) out.set(x, y);
      }
    }
  }

  static int _offset(int block, int size) {
    final o = block * blockSize;
    return o > size - blockSize ? size - blockSize : o;
  }
}

class _BlockStats {
  _BlockStats(this.min, this.max, this.mean);

  factory _BlockStats.of(LuminanceImage image, int bx, int by) {
    const size = LocalBlockBinarizer.blockSize;
    final w = image.width;
    final left = LocalBlockBinarizer._offset(bx, w);
    final top = LocalBlockBinarizer._offset(by, image.height);
    var sum = 0;
    var min = 255;
    var max = 0;
    for (var y = top; y < top + size; y++) {
      for (var x = left; x < left + size; x++) {
        final v = image.bytes[y * w + x];
        sum += v;
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }
    return _BlockStats(min, max, sum ~/ (size * size));
  }

  final int min;
  final int max;
  final int mean;
}
