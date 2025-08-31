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
    // Don't double-encode the scanResult - use toMap() instead of toJson()
    final data = scanResult.toMap();
    // Add top-level properties
    data['timestamp'] = timestamp.toIso8601String();
    data['project_path'] = projectPath;
    
    // Remove the nested structure - return the flat scan result data
    return jsonEncode(data);
  }

  factory ScanSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    
    // Handle the old wrapped format if present
    if (data.containsKey('scanResult')) {
      // Old format with nested scanResult
      return ScanSnapshot(
        timestamp: DateTime.parse(data['timestamp'] as String),
        projectPath: data['projectPath'] as String? ?? data['project_path'] as String? ?? '',
        scanResult: data['scanResult'] is String 
            ? ScanResult.fromJson(data['scanResult'] as String)
            : ScanResult.fromMap(data['scanResult'] as Map<String, dynamic>),
      );
    } else {
      // New format - data is the scan result directly with added fields
      final timestamp = data['timestamp'] as String? ?? DateTime.now().toIso8601String();
      final projectPath = data['project_path'] as String? ?? data['projectPath'] as String? ?? '';
      
      // Create a copy without the added fields for the scan result
      final scanResultData = Map<String, dynamic>.from(data);
      scanResultData.remove('project_path');
      scanResultData.remove('projectPath');
      // Keep timestamp as it's part of scan result too
      
      return ScanSnapshot(
        timestamp: DateTime.parse(timestamp),
        projectPath: projectPath,
        scanResult: ScanResult.fromMap(scanResultData),
      );
    }
  }
}
