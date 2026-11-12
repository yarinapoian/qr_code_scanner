import '../common/gf256.dart';

class Lfsr {
  const Lfsr(this.locator, this.length);

  final GfPoly locator;

  final int length;
}

abstract final class ReedSolomon {
  static int? correct(List<int> codeword, int ecCount) {
    final n = codeword.length;
    if (ecCount <= 0 || ecCount >= n || n > 255) {
      throw ArgumentError('invalid block: n=$n, ec=$ecCount');
    }
    final s = syndromes(codeword, ecCount);
    if (s.every((v) => v == 0)) return 0;

    final lfsr = berlekampMassey(s);
    final lambda = lfsr.locator;
    final errors = lambda.degree;
    if (errors != lfsr.length || errors < 1 || errors > ecCount ~/ 2) {
      return null;
    }

    final positions = chienSearch(lambda, n);
    if (positions.length != errors) return null;

    final values = forney(s, lambda, positions, n);
    if (values == null) return null;

    final fixed = List<int>.of(codeword);
    for (var k = 0; k < positions.length; k++) {
      fixed[positions[k]] ^= values[k];
    }
    if (syndromes(fixed, ecCount).any((v) => v != 0)) return null;
    codeword.setAll(0, fixed);
    return errors;
  }

  static List<int> syndromes(List<int> codeword, int ecCount) {
    final poly = GfPoly.fromHighToLow(codeword);
    final out = <int>[];
    for (var i = 0; i < ecCount; i++) {
      out.add(poly.evaluateAt(GF256.expAlpha(i)));
    }
    return out;
  }

  static Lfsr berlekampMassey(List<int> s) {
    final c = <int>[1];
    var b = <int>[1];
    var l = 0;
    var m = 1;
    var bCoef = 1;

    for (var k = 0; k < s.length; k++) {
      var d = s[k];
      for (var i = 1; i <= l && i < c.length; i++) {
        d ^= GF256.mul(c[i], s[k - i]);
      }
      if (d == 0) {
        m++;
        continue;
      }

      final coef = GF256.div(d, bCoef);
      final t = List<int>.of(c);
      final needed = b.length + m;
      while (c.length < needed) {
        c.add(0);
      }
      for (var i = 0; i < b.length; i++) {
        c[i + m] ^= GF256.mul(coef, b[i]);
      }

      if (2 * l <= k) {
        l = k + 1 - l;
        b = t;
        bCoef = d;
        m = 1;
      } else {
        m++;
      }
    }

    return Lfsr(GfPoly(c), l);
  }

  static List<int> chienSearch(GfPoly lambda, int n) {
    final out = <int>[];
    for (var p = 0; p < n; p++) {
      if (lambda.evaluateAt(GF256.expAlpha(-(n - 1 - p))) == 0) out.add(p);
    }
    return out;
  }

  static List<int>? forney(
    List<int> s,
    GfPoly lambda,
    List<int> positions,
    int n,
  ) {
    final omega = (GfPoly(s) * lambda).truncate(s.length);
    final dLambda = lambda.derivative();
    final out = <int>[];
    for (final p in positions) {
      final x = GF256.expAlpha(n - 1 - p);
      final xInv = GF256.inv(x);
      final denom = dLambda.evaluateAt(xInv);
      if (denom == 0) return null;
      final e = GF256.mul(x, GF256.div(omega.evaluateAt(xInv), denom));
      if (e == 0) return null;
      out.add(e);
    }
    return out;
  }
}
