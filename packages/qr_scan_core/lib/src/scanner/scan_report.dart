import '../common/results.dart';

class ScanReport {
  ScanReport(List<QrCode> codes, List<ScanFailure> failures)
    : codes = List.unmodifiable(codes),
      failures = List.unmodifiable(failures);

  final List<QrCode> codes;

  final List<ScanFailure> failures;

  bool get isSuccess => codes.isNotEmpty;

  @override
  String toString() => 'ScanReport(codes: $codes, failures: $failures)';
}
