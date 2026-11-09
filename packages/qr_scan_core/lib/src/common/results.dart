import 'dart:typed_data';

import 'ec_level.dart';
import 'geometry.dart';

sealed class ScanFailure {
  const ScanFailure();

  int get stage;

  String get name;

  @override
  String toString() => name;
}

final class NotFound extends ScanFailure {
  const NotFound();

  @override
  int get stage => 0;

  @override
  String get name => 'NotFound';

  @override
  bool operator ==(Object other) => other is NotFound;

  @override
  int get hashCode => 0;
}

final class GeometryRejected extends ScanFailure {
  const GeometryRejected(this.reason);

  final String reason;

  @override
  int get stage => 1;

  @override
  String get name => 'GeometryRejected';

  @override
  String toString() => 'GeometryRejected($reason)';

  @override
  bool operator ==(Object other) {
    return other is GeometryRejected && other.reason == reason;
  }

  @override
  int get hashCode => reason.hashCode;
}

final class FormatInfoUnreadable extends ScanFailure {
  const FormatInfoUnreadable();

  @override
  int get stage => 2;

  @override
  String get name => 'FormatInfoUnreadable';

  @override
  bool operator ==(Object other) => other is FormatInfoUnreadable;

  @override
  int get hashCode => 2;
}

final class VersionMismatch extends ScanFailure {
  const VersionMismatch({
    required this.fromVersionInfo,
    required this.fromSize,
  });

  final int fromVersionInfo;

  final int fromSize;

  @override
  int get stage => 3;

  @override
  String get name => 'VersionMismatch';

  @override
  String toString() {
    return 'VersionMismatch(versionInfo: $fromVersionInfo, size: $fromSize)';
  }

  @override
  bool operator ==(Object other) {
    return other is VersionMismatch &&
        other.fromVersionInfo == fromVersionInfo &&
        other.fromSize == fromSize;
  }

  @override
  int get hashCode => Object.hash(fromVersionInfo, fromSize);
}

final class TooManyErrors extends ScanFailure {
  const TooManyErrors({this.blockIndex = -1});

  final int blockIndex;

  @override
  int get stage => 4;

  @override
  String get name => 'TooManyErrors';

  @override
  String toString() => 'TooManyErrors(block: $blockIndex)';

  @override
  bool operator ==(Object other) {
    return other is TooManyErrors && other.blockIndex == blockIndex;
  }

  @override
  int get hashCode => blockIndex;
}

final class MalformedData extends ScanFailure {
  const MalformedData(this.reason);

  final String reason;

  @override
  int get stage => 5;

  @override
  String get name => 'MalformedData';

  @override
  String toString() => 'MalformedData($reason)';

  @override
  bool operator ==(Object other) {
    return other is MalformedData && other.reason == reason;
  }

  @override
  int get hashCode => reason.hashCode;
}

final class UnsupportedMode extends ScanFailure {
  const UnsupportedMode(this.feature);

  final String feature;

  @override
  int get stage => 6;

  @override
  String get name => 'UnsupportedMode';

  @override
  String toString() => 'UnsupportedMode($feature)';

  @override
  bool operator ==(Object other) {
    return other is UnsupportedMode && other.feature == feature;
  }

  @override
  int get hashCode => feature.hashCode;
}

class QrCode {
  QrCode({
    required this.text,
    required this.bytes,
    required this.version,
    required this.ecLevel,
    required this.mask,
    required this.correctedErrors,
    this.mirrored = false,
    this.corners,
  });

  final String text;

  final Uint8List bytes;

  final int version;

  final EcLevel ecLevel;

  final int mask;

  final int correctedErrors;

  final bool mirrored;

  final Quad? corners;

  QrCode withCorners(Quad corners) {
    return QrCode(
      text: text,
      bytes: bytes,
      version: version,
      ecLevel: ecLevel,
      mask: mask,
      correctedErrors: correctedErrors,
      mirrored: mirrored,
      corners: corners,
    );
  }

  @override
  String toString() {
    return 'QrCode(v$version-${ecLevel.name}, mask $mask, '
        'corrected $correctedErrors${mirrored ? ', mirrored' : ''}: "$text")';
  }
}

sealed class DecodeResult {
  const DecodeResult();
}

final class DecodeSuccess extends DecodeResult {
  const DecodeSuccess(this.code);

  final QrCode code;
}

final class DecodeFailure extends DecodeResult {
  const DecodeFailure(this.failure);

  final ScanFailure failure;
}

ScanFailure moreInformative(ScanFailure a, ScanFailure b) {
  return b.stage > a.stage ? b : a;
}
