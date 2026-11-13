import 'dart:typed_data';

import '../common/bit_matrix.dart';
import '../common/results.dart';
import '../common/version.dart';
import 'bitstream.dart';
import 'codeword_placement.dart';
import 'data_blocks.dart';
import 'format_info.dart';
import 'mask.dart';
import 'reed_solomon.dart';
import 'version_info.dart';

abstract final class QrMatrixDecoder {
  static DecodeResult decode(BitMatrix matrix, {bool tryMirrored = true}) {
    final normal = _decodeOriented(matrix, mirrored: false);
    if (normal is DecodeSuccess || !tryMirrored) return normal;

    final mirrored = _decodeOriented(matrix.transposed(), mirrored: true);
    if (mirrored is DecodeSuccess) return mirrored;

    final a = (normal as DecodeFailure).failure;
    final b = (mirrored as DecodeFailure).failure;
    return DecodeFailure(moreInformative(a, b));
  }

  static DecodeResult _decodeOriented(BitMatrix m, {required bool mirrored}) {
    if (m.width != m.height) {
      return const DecodeFailure(GeometryRejected('matrix is not square'));
    }
    final sized = Version.forSize(m.width);
    if (sized == null) {
      return DecodeFailure(GeometryRejected('invalid symbol size ${m.width}'));
    }

    final format = FormatInfoCodec.decode(FormatInfoCodec.read(m));
    if (format == null) return const DecodeFailure(FormatInfoUnreadable());

    final version = sized;
    if (sized.hasVersionInfo) {
      final decoded = VersionInfoCodec.decode(VersionInfoCodec.read(m));
      if (decoded != null && decoded != sized.number) {
        return DecodeFailure(
          VersionMismatch(fromVersionInfo: decoded, fromSize: sized.number),
        );
      }
    }

    final unmasked = DataMask.unmask(m, version, format.mask);
    final raw = CodewordPlacement.read(unmasked, version);

    final blocks = DataBlocks.deinterleave(raw, version, format.ecLevel);
    var corrected = 0;
    final data = BytesBuilder(copy: false);
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final n = ReedSolomon.correct(b.codewords, b.ecCount);
      if (n == null) return DecodeFailure(TooManyErrors(blockIndex: i));
      corrected += n;
      data.add(Uint8List.sublistView(b.codewords, 0, b.dataCount));
    }

    final parsed = BitstreamParser.parse(data.toBytes(), version);
    final failure = parsed.failure;
    if (failure != null) return DecodeFailure(failure);
    final msg = parsed.message!;
    return DecodeSuccess(
      QrCode(
        text: msg.text,
        bytes: msg.bytes,
        version: version.number,
        ecLevel: format.ecLevel,
        mask: format.mask,
        correctedErrors: corrected,
        mirrored: mirrored,
      ),
    );
  }
}
