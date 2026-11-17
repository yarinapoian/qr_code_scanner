import '../common/bit_matrix.dart';
import '../common/geometry.dart';
import '../common/results.dart';
import '../decode/matrix_decoder.dart';
import '../detect/detector.dart';
import '../detect/finder_pattern.dart';
import '../detect/finder_selection.dart';
import '../image/binarizer.dart';
import '../image/luminance_image.dart';
import 'scan_options.dart';
import 'scan_report.dart';

class QrScanner {
  QrScanner({this.options = const ScanOptions()});

  final ScanOptions options;

  static const List<Binarizer> _binarizers = [
    LocalBlockBinarizer(),
    OtsuBinarizer(),
  ];

  ScanReport scan(LuminanceImage image) {
    if (image.width == 0 || image.height == 0) {
      return ScanReport(const [], const [NotFound()]);
    }

    final factor = _downscaleFactor(image);
    final downscaledImage = image.downscaled(factor);
    final state = _ScanState(options.maxCodes);

    final done = _tryBinarizers(downscaledImage, state);
    if (!done && options.tryInverted) {
      _tryBinarizers(downscaledImage.inverted(), state);
    }
    return state.report(factor);
  }

  bool _tryBinarizers(LuminanceImage source, _ScanState state) {
    for (final binarizer in _binarizers) {
      if (state.full) return true;
      final found = _pass(binarizer.binarize(source), state);
      if (found && !state.hasOpenFailures) return true;
    }
    return state.full;
  }

  int _downscaleFactor(LuminanceImage image) {
    final longer = image.width > image.height ? image.width : image.height;
    return (longer / options.downscaleAbove).ceil();
  }

  bool _pass(BitMatrix binary, _ScanState state) {
    final finders = <FinderPattern>[];
    for (final f in FinderPatternFinder(binary).find()) {
      if (!state.insideKnownCode(f.point)) finders.add(f);
    }
    final detector = Detector(binary);
    final triplets = detector.rankTriplets(FinderSelector.triplets(finders));

    final used = <FinderPattern>{};
    var attempts = 0;
    var foundAny = false;
    for (final triplet in triplets) {
      if (state.full || attempts >= options.maxTripletsPerPass) break;
      if (triplet.patterns.any(used.contains)) continue;
      attempts++;

      final result = _decodeTriplet(detector, triplet);
      if (result is DecodeSuccess) {
        if (state.add(result.code)) foundAny = true;
        used.addAll(triplet.patterns);
      } else if (result is DecodeFailure) {
        state.fail(triplet, result.failure);
      }
    }
    return foundAny;
  }

  DecodeResult _decodeTriplet(Detector detector, FinderTriplet triplet) {
    final detection = detector.detect(triplet);
    var best = detection.failure ?? const NotFound();
    final queue = List.of(detection.candidates);
    final triedSizes = <int>{};

    while (queue.isNotEmpty) {
      final candidate = queue.removeAt(0);
      triedSizes.add(candidate.dimension);

      final result = QrMatrixDecoder.decode(
        candidate.modules,
        tryMirrored: options.tryMirrored,
      );
      if (result is DecodeSuccess) {
        final code = result.code;
        var corners = candidate.corners;
        if (code.mirrored) corners = _swapTopRightAndBottomLeft(corners);
        return DecodeSuccess(code.withCorners(corners));
      }

      final failure = (result as DecodeFailure).failure;
      best = moreInformative(best, failure);
      if (failure is VersionMismatch) {
        final size = 17 + 4 * failure.fromVersionInfo;
        if (triedSizes.add(size)) {
          queue.addAll(detector.detect(triplet, dimension: size).candidates);
        }
      }
    }
    return DecodeFailure(best);
  }

  static Quad _swapTopRightAndBottomLeft(Quad q) {
    return Quad(q.topLeft, q.bottomLeft, q.bottomRight, q.topRight);
  }
}

class _Failure {
  _Failure(this.region, this.failure);

  final Point region;
  final ScanFailure failure;
}

class _ScanState {
  _ScanState(this.maxCodes);

  final int maxCodes;
  final List<QrCode> codes = [];
  final List<_Failure> _failures = [];

  bool get full => codes.length >= maxCodes;

  bool get hasOpenFailures => _openFailures().isNotEmpty;

  bool insideKnownCode(Point p) => codes.any((c) => c.corners!.contains(p));

  bool add(QrCode code) {
    if (insideKnownCode(code.corners!.center)) return false;
    codes.add(code);
    return true;
  }

  void fail(FinderTriplet t, ScanFailure failure) {
    _failures.add(_Failure(_centroid(t), failure));
  }

  List<ScanFailure> _openFailures() {
    final open = <ScanFailure>[];
    for (final f in _failures) {
      if (!insideKnownCode(f.region)) open.add(f.failure);
    }
    return open;
  }

  ScanReport report(int factor) {
    final scaled = <QrCode>[];
    for (final c in codes) {
      scaled.add(c.withCorners(_scale(c.corners!, factor)));
    }

    final open = _openFailures();
    if (open.isEmpty) {
      if (scaled.isEmpty) return ScanReport(scaled, const [NotFound()]);
      return ScanReport(scaled, const []);
    }

    var best = open.first;
    for (final f in open) {
      best = moreInformative(best, f);
    }
    return ScanReport(scaled, [best]);
  }

  static Point _centroid(FinderTriplet t) {
    final x = (t.topLeft.x + t.topRight.x + t.bottomLeft.x) / 3;
    final y = (t.topLeft.y + t.topRight.y + t.bottomLeft.y) / 3;
    return Point(x, y);
  }

  static Quad _scale(Quad q, int f) {
    return Quad(
      q.topLeft * f.toDouble(),
      q.topRight * f.toDouble(),
      q.bottomRight * f.toDouble(),
      q.bottomLeft * f.toDouble(),
    );
  }
}
