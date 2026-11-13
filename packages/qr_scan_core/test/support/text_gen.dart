library;

import 'package:kiri_check/kiri_check.dart';

const textPools = <String, String>{
  'numeric': '0123456789',
  'alphanumeric': r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:',
  'ascii': ' !"#&()*+,-./0123456789:;<=>?@ABCXYZ[]^_abcxyz{|}~',
  'unicode': 'aZ09 ПривітЁёЇїҐґ€£©ÿßçé漢字😀🎉',
};

String textFrom(String pool, List<int> picks) {
  final runes = pool.runes.toList();
  return String.fromCharCodes([for (final p in picks) runes[p % runes.length]]);
}

Arbitrary<String> anyText({int maxLength = 60}) => combine2(
  integer(min: 0, max: textPools.length - 1),
  list(integer(min: 0, max: 1000), maxLength: maxLength),
).map((t) => textFrom(textPools.values.elementAt(t.$1), t.$2));
