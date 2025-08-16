// Re-export reporter v3
export 'reporter_v3.dart';

// Legacy compatibility
class Reporter {
  static ReporterV3 create(String format) {
    return ReporterV3();
  }
}
