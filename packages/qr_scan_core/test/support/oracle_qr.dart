library;

import 'package:qr/qr.dart';

enum OracleEc { l, m, q, h }

QrErrorCorrectLevel _level(OracleEc ec) => switch (ec) {
  OracleEc.l => QrErrorCorrectLevel.low,
  OracleEc.m => QrErrorCorrectLevel.medium,
  OracleEc.q => QrErrorCorrectLevel.quartile,
  OracleEc.h => QrErrorCorrectLevel.high,
};

class OracleSymbol {
  OracleSymbol(this.rows, this.version, this.mask, this.ec);

  final List<List<bool>> rows;

  final int version;

  final int mask;

  final OracleEc ec;

  int get size => rows.length;
}

OracleSymbol oracleEncodePayload(
  QrPayload payload, {
  OracleEc ec = OracleEc.m,
  int? mask,
  int minVersion = 1,
}) {
  final code = QrCode(
    payload: payload,
    errorCorrectLevel: _level(ec),
    minTypeNumber: minVersion,
  );
  final image = mask == null
      ? QrImage(code)
      : QrImage.withMaskPattern(code, mask);
  final n = image.moduleCount;
  final rows = [
    for (var y = 0; y < n; y++)
      [for (var x = 0; x < n; x++) image.isDark(y, x)],
  ];
  return OracleSymbol(rows, image.typeNumber, image.maskPattern, ec);
}

OracleSymbol oracleEncode(
  String text, {
  OracleEc ec = OracleEc.m,
  int? mask,
  int minVersion = 1,
}) => oracleEncodePayload(
  QrPayload.fromString(text),
  ec: ec,
  mask: mask,
  minVersion: minVersion,
);
