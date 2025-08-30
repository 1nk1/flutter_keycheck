import 'dart:convert';
import 'scan_result.dart';

/// Snapshot of scan results for baseline/diff operations
class ScanSnapshot {
  final DateTime timestamp;
  final String projectPath;
  final ScanResult scanResult;

  ScanSnapshot({
    required this.timestamp,
    required this.projectPath,
    required this.scanResult,
  });

  String toJson() {
    return jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'projectPath': projectPath,
      'scanResult': scanResult.toJson(),
    });
  }

  factory ScanSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return ScanSnapshot(
      timestamp: DateTime.parse(data['timestamp'] as String),
      projectPath: data['projectPath'] as String,
      scanResult: ScanResult.fromJson(jsonEncode(data['scanResult'])),
    );
  }
}
