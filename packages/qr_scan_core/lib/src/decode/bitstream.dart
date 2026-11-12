import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../common/results.dart';
import '../common/version.dart';
import 'bit_source.dart';

abstract final class Mode {
  static const int terminator = 0x0;

  static const int numeric = 0x1;

  static const int alphanumeric = 0x2;

  static const int structuredAppend = 0x3;

  static const int byte = 0x4;

  static const int fnc1First = 0x5;

  static const int eci = 0x7;

  static const int kanji = 0x8;

  static const int fnc1Second = 0x9;

  static int countBits(int mode, int group) {
    switch (mode) {
      case numeric:
        return const [10, 12, 14][group];
      case alphanumeric:
        return const [9, 11, 13][group];
      case byte:
        return const [8, 16, 16][group];
      case kanji:
        return const [8, 10, 12][group];
      default:
        throw ArgumentError('mode $mode has no character count');
    }
  }
}

const String alphanumericTable =
    r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

enum Charset { latin1, utf8 }

class Message {
  Message(this.text, this.bytes);

  final String text;

  final Uint8List bytes;
}

class ParseResult {
  const ParseResult.success(Message this.message) : failure = null;

  const ParseResult.failure(ScanFailure this.failure) : message = null;

  final Message? message;

  final ScanFailure? failure;
}

abstract final class BitstreamParser {
  static ParseResult parse(List<int> data, Version version) {
    final src = BitSource(data);
    final group = version.countGroup;
    final text = StringBuffer();
    final bytes = BytesBuilder(copy: false);
    Charset? eciCharset;
    var sawTerminator = false;

    ParseResult fail(ScanFailure f) => ParseResult.failure(f);

    while (src.available >= 4) {
      final mode = src.read(4);
      switch (mode) {
        case Mode.terminator:
          sawTerminator = true;
        case Mode.numeric:
          final r = _numeric(src, Mode.countBits(mode, group));
          if (r == null) {
            return fail(const MalformedData('bad numeric segment'));
          }
          text.write(r);
          bytes.add(ascii.encode(r));
        case Mode.alphanumeric:
          final r = _alphanumeric(src, Mode.countBits(mode, group));
          if (r == null) {
            return fail(const MalformedData('bad alphanumeric segment'));
          }
          text.write(r);
          bytes.add(ascii.encode(r));
        case Mode.byte:
          final raw = _bytes(src, Mode.countBits(mode, group));
          if (raw == null) return fail(const MalformedData('bad byte segment'));
          final s = decodeBytes(raw, eciCharset);
          if (s == null) {
            return fail(const MalformedData('byte segment is not valid UTF-8'));
          }
          text.write(s);
          bytes.add(raw);
        case Mode.eci:
          final value = _eciDesignator(src);
          if (value == null) {
            return fail(const MalformedData('bad ECI designator'));
          }
          final cs = charsetForEci(value);
          if (cs == null) return fail(UnsupportedMode('ECI $value'));
          eciCharset = cs;
        case Mode.kanji:
          return fail(const UnsupportedMode('Kanji'));
        case Mode.fnc1First:
        case Mode.fnc1Second:
          return fail(const UnsupportedMode('FNC1'));
        case Mode.structuredAppend:
          return fail(const UnsupportedMode('Structured Append'));
        default:
          return fail(MalformedData('unknown mode indicator $mode'));
      }
      if (sawTerminator) break;
    }

    final padding = _checkPadding(src);
    if (padding != null) return fail(padding);
    return ParseResult.success(Message(text.toString(), bytes.toBytes()));
  }

  static String? _numeric(BitSource src, int countBits) {
    if (src.available < countBits) return null;
    var count = src.read(countBits);
    final sb = StringBuffer();
    while (count > 0) {
      final digits = math.min(3, count);
      final bits = const [0, 4, 7, 10][digits];
      if (src.available < bits) return null;
      final v = src.read(bits);
      if (v >= const [1, 10, 100, 1000][digits]) return null;
      sb.write(v.toString().padLeft(digits, '0'));
      count -= digits;
    }
    return sb.toString();
  }

  static String? _alphanumeric(BitSource src, int countBits) {
    if (src.available < countBits) return null;
    var count = src.read(countBits);
    final sb = StringBuffer();
    while (count > 1) {
      if (src.available < 11) return null;
      final v = src.read(11);
      if (v >= 45 * 45) return null;
      sb.write(alphanumericTable[v ~/ 45]);
      sb.write(alphanumericTable[v % 45]);
      count -= 2;
    }

    if (count == 1) {
      if (src.available < 6) return null;
      final v = src.read(6);
      if (v >= 45) return null;
      sb.write(alphanumericTable[v]);
    }
    return sb.toString();
  }

  static Uint8List? _bytes(BitSource src, int countBits) {
    if (src.available < countBits) return null;
    final count = src.read(countBits);
    if (src.available < count * 8) return null;
    final out = Uint8List(count);
    for (var i = 0; i < count; i++) {
      out[i] = src.read(8);
    }
    return out;
  }

  static int? _eciDesignator(BitSource src) {
    if (src.available < 8) return null;
    final first = src.read(8);
    if (first & 0x80 == 0) return first;
    if (first & 0xC0 == 0x80) {
      if (src.available < 8) return null;
      return ((first & 0x3F) << 8) | src.read(8);
    }
    if (first & 0xE0 == 0xC0) {
      if (src.available < 16) return null;
      return ((first & 0x1F) << 16) | src.read(16);
    }
    return null;
  }

  static Charset? charsetForEci(int value) {
    if (value == 1 || value == 3) return Charset.latin1;
    if (value == 26) return Charset.utf8;
    return null;
  }

  static String? decodeBytes(List<int> raw, Charset? charset) {
    switch (charset) {
      case Charset.latin1:
        return latin1.decode(raw);
      case Charset.utf8:
        return _strictUtf8(raw);
      case null:
        return _strictUtf8(raw) ?? latin1.decode(raw);
    }
  }

  static String? _strictUtf8(List<int> raw) {
    try {
      return const Utf8Decoder().convert(raw);
    } on FormatException {
      return null;
    }
  }

  static ScanFailure? _checkPadding(BitSource src) {
    final toBoundary = src.available % 8;
    if (toBoundary > 0 && src.read(toBoundary) != 0) {
      return const MalformedData('non-zero bits after terminator');
    }
    return null;
  }
}
