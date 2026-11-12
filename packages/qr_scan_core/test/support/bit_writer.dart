class BitWriter {
  final List<int> _bits = [];

  int get length => _bits.length;

  void write(int value, int n) {
    for (var i = n - 1; i >= 0; i--) {
      _bits.add((value >> i) & 1);
    }
  }

  void bits(String s) {
    for (final c in s.split('')) {
      if (c == '0' || c == '1') _bits.add(c == '1' ? 1 : 0);
    }
  }

  List<int> toBytes({int? capacity, bool pad = true}) {
    final bits = List<int>.of(_bits);
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    final out = <int>[
      for (var i = 0; i < bits.length; i += 8)
        bits.sublist(i, i + 8).fold(0, (a, b) => (a << 1) | b),
    ];
    if (capacity != null) {
      var k = 0;
      while (out.length < capacity) {
        out.add(pad ? (k.isEven ? 0xEC : 0x11) : 0);
        k++;
      }
    }
    return out;
  }
}
