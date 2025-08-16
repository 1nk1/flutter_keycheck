#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

void main() {
  print('Checking scan coverage metrics...');

  final file = File('reports/scan-coverage.json');
  if (!file.existsSync()) {
    print('ERROR: reports/scan-coverage.json not found');
    exit(1);
  }

  final content = file.readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;

  // Check required fields
  final metrics = json['metrics'] as Map<String, dynamic>?;
  if (metrics == null) {
    print('ERROR: metrics field missing');
    exit(1);
  }

  final requiredFields = [
    'files_total',
    'files_scanned',
    'parse_success_rate',
    'widgets_total',
    'widgets_with_keys',
    'handlers_total',
    'handlers_linked'
  ];

  for (final field in requiredFields) {
    if (!metrics.containsKey(field)) {
      print('ERROR: Missing required field: $field');
      exit(1);
    }
  }

  // Check thresholds
  final parseRate = metrics['parse_success_rate'] as num;
  if (parseRate < 0.8) {
    print('WARNING: Parse success rate below 0.8: $parseRate');
  }

  final widgetsTotal = metrics['widgets_total'] as int;
  final widgetsWithKeys = metrics['widgets_with_keys'] as int;
  if (widgetsTotal > 0) {
    final keyRate = (widgetsWithKeys / widgetsTotal * 100).toStringAsFixed(1);
    print('Widget key coverage: $keyRate% ($widgetsWithKeys/$widgetsTotal)');
  }

  print('✅ All required metrics present');
  print('Files: ${metrics['files_scanned']}/${metrics['files_total']}');
  print('Parse rate: $parseRate');
  print('Widgets: $widgetsWithKeys/$widgetsTotal');
  print('Handlers: ${metrics['handlers_linked']}/${metrics['handlers_total']}');
}
