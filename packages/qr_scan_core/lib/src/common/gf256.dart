import 'dart:math' as math;
import 'dart:typed_data';

abstract final class GF256 {
  static const int primitive = 0x11D;

  static const int size = 256;

  static final Uint8List _exp = _buildExp();
  static final Uint8List _log = _buildLog();

  static Uint8List _buildExp() {
    final t = Uint8List(512);
    var x = 1;
    for (var i = 0; i < 255; i++) {
      t[i] = x;
      x <<= 1;
      if (x >= 256) x ^= primitive;
    }
    for (var i = 255; i < 512; i++) {
      t[i] = t[i - 255];
    }
    return t;
  }

  static Uint8List _buildLog() {
    final t = Uint8List(256);
    for (var i = 0; i < 255; i++) {
      t[_exp[i]] = i;
    }
    return t;
  }

  static void _checkElement(int a) {
    if (a < 0 || a > 255) throw RangeError.range(a, 0, 255, 'element');
  }

  static int add(int a, int b) {
    _checkElement(a);
    _checkElement(b);
    return a ^ b;
  }

  static int mul(int a, int b) {
    _checkElement(a);
    _checkElement(b);
    if (a == 0 || b == 0) return 0;
    return _exp[_log[a] + _log[b]];
  }

  static int div(int a, int b) {
    _checkElement(a);
    _checkElement(b);
    if (b == 0) throw ArgumentError('division by zero in GF(256)');
    if (a == 0) return 0;
    return _exp[_log[a] + 255 - _log[b]];
  }

  static int inv(int a) => div(1, a);

  static int expAlpha(int e) => _exp[e % 255];
}

class GfPoly {
  GfPoly(List<int> lowToHigh) : coefficients = _trim(lowToHigh);

  factory GfPoly.fromHighToLow(List<int> highToLow) {
    return GfPoly(highToLow.reversed.toList());
  }

  static final GfPoly zero = GfPoly(const []);

  final List<int> coefficients;

  static List<int> _trim(List<int> c) {
    var n = c.length;
    while (n > 0 && c[n - 1] == 0) {
      n--;
    }
    for (var i = 0; i < n; i++) {
      GF256._checkElement(c[i]);
    }
    return List.unmodifiable(c.sublist(0, n));
  }

  int get degree => coefficients.length - 1;

  bool get isZero => coefficients.isEmpty;

  int evaluateAt(int x) {
    var r = 0;
    for (var i = coefficients.length - 1; i >= 0; i--) {
      r = GF256.mul(r, x) ^ coefficients[i];
    }
    return r;
  }

  GfPoly operator *(GfPoly other) {
    if (isZero || other.isZero) return zero;
    final r = List<int>.filled(degree + other.degree + 1, 0);
    for (var i = 0; i < coefficients.length; i++) {
      final a = coefficients[i];
      if (a == 0) continue;
      for (var j = 0; j < other.coefficients.length; j++) {
        r[i + j] ^= GF256.mul(a, other.coefficients[j]);
      }
    }
    return GfPoly(r);
  }

  GfPoly truncate(int n) {
    return GfPoly(coefficients.sublist(0, math.min(n, coefficients.length)));
  }

  GfPoly derivative() {
    final out = <int>[];
    for (var i = 1; i < coefficients.length; i++) {
      out.add(i.isOdd ? coefficients[i] : 0);
    }
    return GfPoly(out);
  }

  @override
  bool operator ==(Object other) {
    if (other is! GfPoly || other.coefficients.length != coefficients.length) {
      return false;
    }
    for (var i = 0; i < coefficients.length; i++) {
      if (coefficients[i] != other.coefficients[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(coefficients);

  @override
  String toString() => 'GfPoly($coefficients)';
}
