import 'package:flutter_keycheck/src/models/scan_result.dart';

/// Result of comparing two snapshots
class DiffResult {
  final Set<String> added;
  final Set<String> removed;
  final Map<String, String> renamed;
  final Set<String> unchanged;
  final ScanResult baseline;
  final ScanResult current;

  DiffResult({
    required this.added,
    required this.removed,
    required this.renamed,
    required this.unchanged,
    required this.baseline,
    required this.current,
  });

  bool get hasChanges =>
      added.isNotEmpty || removed.isNotEmpty || renamed.isNotEmpty;

  int get totalChanges => added.length + removed.length + renamed.length;

  double get driftPercentage {
    final totalKeys = baseline.keyUsages.length;
    if (totalKeys == 0) return 0.0;
    return (totalChanges / totalKeys * 100);
  }

  Map<String, dynamic> toMap() {
    return {
      'added': added.toList(),
      'removed': removed.toList(),
      'renamed': renamed,
      'unchanged': unchanged.toList(),
      'total_changes': totalChanges,
      'drift_percentage': driftPercentage,
      'has_changes': hasChanges,
    };
  }
}
