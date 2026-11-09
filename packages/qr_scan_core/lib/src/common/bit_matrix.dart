class BitMatrix {
  factory BitMatrix(int width, int height) {
    if (width < 0 || height < 0) {
      throw ArgumentError('negative size $width x $height');
    }

    final cells = List<bool>.filled(width * height, false);
    return BitMatrix._raw(width, height, cells);
  }

  factory BitMatrix.square(int size) => BitMatrix(size, size);

  factory BitMatrix.fromRows(List<List<bool>> rows) {
    final height = rows.length;
    final width = height == 0 ? 0 : rows[0].length;
    final m = BitMatrix(width, height);
    for (var y = 0; y < height; y++) {
      final row = rows[y];
      if (row.length != width) {
        throw ArgumentError('row $y has length ${row.length}, expected $width');
      }
      for (var x = 0; x < width; x++) {
        if (row[x]) m.set(x, y);
      }
    }
    return m;
  }

  factory BitMatrix.parse(String picture, {String dark = '#'}) {
    final lines = <String>[];
    var width = 0;
    for (final raw in picture.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      lines.add(line);
      if (line.length > width) width = line.length;
    }

    final m = BitMatrix(width, lines.length);
    for (var y = 0; y < lines.length; y++) {
      for (var x = 0; x < lines[y].length; x++) {
        if (lines[y][x] == dark) m.set(x, y);
      }
    }
    return m;
  }

  BitMatrix._raw(this.width, this.height, this._cells);

  final int width;

  final int height;

  final List<bool> _cells;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  bool get(int x, int y) => _cells[_index(x, y)];

  void set(int x, int y) {
    _cells[_index(x, y)] = true;
  }

  void flip(int x, int y) {
    final i = _index(x, y);
    _cells[i] = !_cells[i];
  }

  void setRegion(int left, int top, int w, int h) {
    if (left < 0 || top < 0 || w < 0 || h < 0) {
      throw ArgumentError('negative region $left,$top ${w}x$h');
    }
    if (left + w > width || top + h > height) {
      throw ArgumentError('region $left,$top ${w}x$h exceeds ${width}x$height');
    }
    for (var y = top; y < top + h; y++) {
      for (var x = left; x < left + w; x++) {
        set(x, y);
      }
    }
  }

  int get popCount {
    var n = 0;
    for (final cell in _cells) {
      if (cell) n++;
    }
    return n;
  }

  BitMatrix copy() {
    final cells = List<bool>.of(_cells, growable: false);
    return BitMatrix._raw(width, height, cells);
  }

  BitMatrix transposed() {
    final m = BitMatrix(height, width);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (get(x, y)) m.set(y, x);
      }
    }
    return m;
  }

  int _index(int x, int y) {
    _check(x, y);
    return y * width + x;
  }

  void _check(int x, int y) {
    if (!contains(x, y)) {
      throw RangeError('($x, $y) outside ${width}x$height');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! BitMatrix || other.width != width || other.height != height) {
      return false;
    }
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(_cells));

  @override
  String toString() {
    final sb = StringBuffer();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        sb.write(get(x, y) ? '#' : '.');
      }
      sb.write('\n');
    }
    return sb.toString();
  }
}
