class ScanOptions {
  const ScanOptions({
    this.tryInverted = true,
    this.tryMirrored = true,
    this.maxCodes = 4,
    this.downscaleAbove = 2048,
    this.maxTripletsPerPass = 24,
  }) : assert(maxCodes >= 1);

  final bool tryInverted;

  final bool tryMirrored;

  final int maxCodes;

  final int downscaleAbove;

  final int maxTripletsPerPass;
}
