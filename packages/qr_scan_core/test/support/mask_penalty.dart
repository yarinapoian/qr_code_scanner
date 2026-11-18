library;

int maskPenalty(List<List<bool>> m) {
  final n = m.length;
  var score = 0;
  for (var line = 0; line < n; line++) {
    for (final horizontal in [true, false]) {
      var run = 1;
      for (var i = 1; i <= n; i++) {
        final same =
            i < n &&
            (horizontal
                ? m[line][i] == m[line][i - 1]
                : m[i][line] == m[i - 1][line]);
        if (same) {
          run++;
        } else {
          if (run >= 5) score += 3 + run - 5;
          run = 1;
        }
      }
    }
  }
  for (var y = 0; y < n - 1; y++) {
    for (var x = 0; x < n - 1; x++) {
      final c = m[y][x];
      if (m[y][x + 1] == c && m[y + 1][x] == c && m[y + 1][x + 1] == c) {
        score += 3;
      }
    }
  }
  const a = [
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
    false,
    false,
    false,
  ];
  const b = [
    false,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
  ];
  bool match(List<bool> p, int y, int x, bool horizontal) {
    for (var i = 0; i < 11; i++) {
      final v = horizontal ? m[y][x + i] : m[y + i][x];
      if (v != p[i]) return false;
    }
    return true;
  }

  for (var y = 0; y < n; y++) {
    for (var x = 0; x + 11 <= n; x++) {
      if (match(a, y, x, true) || match(b, y, x, true)) score += 40;
    }
  }
  for (var x = 0; x < n; x++) {
    for (var y = 0; y + 11 <= n; y++) {
      if (match(a, y, x, false) || match(b, y, x, false)) score += 40;
    }
  }
  var dark = 0;
  for (final row in m) {
    dark += row.where((v) => v).length;
  }
  final percent = dark * 100 / (n * n);
  score += ((percent - 50).abs() ~/ 5) * 10;
  return score;
}
