class BitSource {
  BitSource(this.bytes);

  final List<int> bytes;
  int _position = 0;

  int get available => bytes.length * 8 - _position;

  int read(int n) {
    if (n < 0 || n > 32) throw RangeError.range(n, 0, 32, 'n');
    if (n > available) {
      throw RangeError('need $n bits, only $available available');
    }
    var v = 0;
    for (var i = 0; i < n; i++) {
      final byte = bytes[_position >> 3];
      final bit = (byte >> (7 - (_position & 7))) & 1;
      v = (v << 1) | bit;
      _position++;
    }
    return v;
  }
}
