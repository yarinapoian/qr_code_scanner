enum EcLevel {
  L(0x01),
  M(0x00),
  Q(0x03),
  H(0x02);

  const EcLevel(this.formatBits);

  final int formatBits;

  static EcLevel fromFormatBits(int bits) {
    switch (bits & 3) {
      case 0x01:
        return L;
      case 0x00:
        return M;
      case 0x03:
        return Q;
      default:
        return H;
    }
  }
}
