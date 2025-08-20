#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

void main() {
  print('Validating scan-coverage.json against schema v1.0...');

  final file = File('reports/scan-coverage.json');
  if (!file.existsSync()) {
    print('ERROR: reports/scan-coverage.json not found');
    exit(1);
  }

  final content = file.readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;

  // Validate top-level required fields
  final requiredTop = ['version', 'timestamp', 'metrics', 'detectors'];
  for (final field in requiredTop) {
    if (!json.containsKey(field)) {
      print('ERROR: Missing top-level field: $field');
      exit(1);
    }
  }

  // Validate version format
  final version = json['version'] as String;
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    print('ERROR: Invalid version format: $version');
    exit(1);
  }

  // Validate timestamp
  final timestamp = json['timestamp'] as String;
  try {
    DateTime.parse(timestamp);
  } catch (e) {
    print('ERROR: Invalid ISO 8601 timestamp: $timestamp');
    exit(1);
  }

  // Validate metrics
  final metrics = json['metrics'] as Map<String, dynamic>;
  final requiredMetrics = [
    'files_total',
    'files_scanned',
    'parse_success_rate',
    'widgets_total',
    'widgets_with_keys',
    'handlers_total',
    'handlers_linked'
  ];

  for (final field in requiredMetrics) {
    if (!metrics.containsKey(field)) {
      print('ERROR: Missing metric field: $field');
      exit(1);
    }
  }

  // Validate detectors
  final detectors = json['detectors'] as List<dynamic>;
  for (var i = 0; i < detectors.length; i++) {
    final detector = detectors[i] as Map<String, dynamic>;
    final requiredDetector = ['name', 'hits', 'keys_found', 'effectiveness'];

    for (final field in requiredDetector) {
      if (!detector.containsKey(field)) {
        print('ERROR: Detector $i missing field: $field');
        exit(1);
      }
    }

    // Validate effectiveness range
    final effectiveness = detector['effectiveness'] as num;
    if (effectiveness < 0 || effectiveness > 100) {
      print(
          'ERROR: Detector ${detector['name']} effectiveness out of range: $effectiveness');
      exit(1);
    }
  }

  print('✅ Schema validation passed');
  print('Version: $version');
  print('Timestamp: $timestamp');
  print('Detectors: ${detectors.length}');
}
