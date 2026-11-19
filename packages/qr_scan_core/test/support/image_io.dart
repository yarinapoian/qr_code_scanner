library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:qr_scan_core/qr_scan_core.dart';

LuminanceImage? loadLuminance(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) return null;
  final rgba = decoded.convert(numChannels: 4, format: img.Format.uint8);
  return LuminanceImage.fromRgba(
    rgba.width,
    rgba.height,
    rgba.getBytes(order: img.ChannelOrder.rgba),
  );
}

void writePgm(String path, LuminanceImage image) {
  final header = ascii.encode('P5\n${image.width} ${image.height}\n255\n');
  File(path).writeAsBytesSync(Uint8List.fromList([...header, ...image.bytes]));
}

bool _has(String tool) => Process.runSync('which', [tool]).exitCode == 0;

final bool hasZxing = _has('ZXingReader');

final bool hasZbar = _has('zbarimg');

List<List<int>> zxingRead(String path) {
  final r = Process.runSync('ZXingReader', [
    '-formats',
    'QRCode',
    '-json',
    path,
  ], stdoutEncoding: utf8);
  final out = <List<int>>[];
  for (final line in (r.stdout as String).split('\n')) {
    final l = line.trim();
    if (!l.startsWith('{')) continue;
    final j = jsonDecode(l) as Map<String, Object?>;
    if (j['Error'] != null) continue;
    final hex = (j['Bytes'] as String?) ?? '';
    out.add([
      for (final h in hex.split(' ').where((s) => s.isNotEmpty))
        int.parse(h, radix: 16),
    ]);
  }
  return out;
}

List<List<int>> zbarRead(String path) {
  final r = Process.runSync('zbarimg', [
    '-q',
    '--raw',
    '-Sdisable',
    '-Sqrcode.enable',
    '--nodbus',
    path,
  ], stdoutEncoding: null);
  final bytes = r.stdout as List<int>;
  if (bytes.isEmpty) return const [];
  final out = <List<int>>[];
  var cur = <int>[];
  for (final b in bytes) {
    if (b == 10) {
      out.add(cur);
      cur = [];
    } else {
      cur.add(b);
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}
