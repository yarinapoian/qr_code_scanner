@Tags(['e2e', 'slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:qr_scan_core/qr_scan_core.dart';
import 'package:test/test.dart';

import '../support/image_io.dart';

const root = 'test/fixtures/corpus';
const baselinePath = 'test/fixtures/corpus_baseline.json';

class Outcome {
  int images = 0, read = 0, notRead = 0, charset = 0;
  final wrong = <String>[];
  Map<String, int> toJson() => {'images': images, 'read': read};
}

void main() {
  final dir = Directory(root);
  final sets = dir.existsSync()
      ? (dir
            .listSync(recursive: true)
            .whereType<File>()
            .where(_isImage)
            .map((f) => p.relative(f.parent.path, from: root))
            .toSet()
            .toList()
          ..sort())
      : <String>[];

  test(
    'real-photo corpus: 0 wrong, read rate not below baseline',
    () {
      final baseline = File(baselinePath).existsSync()
          ? (jsonDecode(File(baselinePath).readAsStringSync()) as Map)
                .cast<String, Object?>()
          : <String, Object?>{};
      final results = <String, Outcome>{};
      for (final set in sets) {
        final o = results[set] = Outcome();
        final files =
            Directory(p.join(root, set))
                .listSync()
                .whereType<File>()
                .where(_isImage)
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in files) {
          final txt = File(p.setExtension(f.path, '.txt'));
          if (!txt.existsSync()) continue;
          final expected = txt.readAsStringSync();
          final image = loadLuminance(f.path);
          if (image == null) continue;
          o.images++;
          final codes = QrScanner().scan(image).codes;
          if (codes.isEmpty) {
            o.notRead++;
          } else if (codes.any((c) => c.text == expected)) {
            o.read++;
          } else if (hasZxing && _sameBytesAsZxing(codes.first.bytes, f.path)) {
            o.charset++;
          } else {
            o.wrong.add(
              '${f.path}: got "${codes.first.text}", expected "$expected"',
            );
          }
        }
      }
      final report = StringBuffer('corpus:\n');
      for (final e in results.entries) {
        final o = e.value;
        final before = (baseline[e.key] as Map?)?['read'];
        report.writeln(
          '  ${e.key.padRight(18)} ${o.read}/${o.images} read, ${o.charset} charset-only, ${o.notRead} not read, ${o.wrong.length} wrong (baseline $before)',
        );
      }
      // ignore: avoid_print
      print(report);
      for (final o in results.values) {
        expect(o.wrong, isEmpty);
      }
      if (Platform.environment['UPDATE_BASELINE'] == '1') {
        File(baselinePath).writeAsStringSync(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({for (final e in results.entries) e.key: e.value.toJson()}),
        );
        return;
      }
      for (final e in results.entries) {
        final before = (baseline[e.key] as Map?)?['read'] as int?;
        if (before != null) {
          expect(
            e.value.read,
            greaterThanOrEqualTo(before),
            reason: 'regression in ${e.key}',
          );
        }
      }
    },
    skip: sets.isEmpty ? 'no corpus: run tool/fetch_corpus.sh' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

bool _isImage(File f) => const {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
}.contains(p.extension(f.path).toLowerCase());

bool _sameBytesAsZxing(List<int> ours, String path) =>
    zxingRead(path).any((z) => const ListEquality<int>().equals(z, ours));
