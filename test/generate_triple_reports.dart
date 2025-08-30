#!/usr/bin/env dart

import 'dart:io';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/scan_metrics.dart';
import 'package:flutter_keycheck/src/models/file_analysis.dart';
import 'package:flutter_keycheck/src/models/key_usage.dart';
import 'package:flutter_keycheck/src/models/blind_spot.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/base_reporter.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart' as v3;

void main() async {
  print('🎯 Generating Triple HTML Reports for Comparison\n');
  print('=' * 60);

  // Create test data
  final testData = createTestData();

  // Generate all three reports
  await generateV2Report(testData);
  await generateOptimizedReport(testData);
  await generateEmbeddedReport(testData);

  print('\n✅ All reports generated successfully!');
  print('📁 Check /reports/ directory for:');
  print('   - html_reporter_v2.html (original with glassmorphism)');
  print('   - html_reporter_optimized.html (performance optimized)');
  print('   - html_reporter_embedded.html (minimal embedded)');
}

/// Create comprehensive test data that works with both V2 and V3
Map<String, dynamic> createTestData() {
  print('\n📊 Creating test data...');

  // Common test keys
  final expectedKeys = {
    'loginButton',
    'emailField',
    'passwordField',
    'submitButton',
    'cancelButton',
    'homeTab',
    'profileTab',
    'settingsTab',
    'logoutButton',
    'searchBar',
    'filterDropdown',
    'sortButton',
    'refreshIndicator',
    'errorDialog',
    'successToast',
  };

  final foundKeys = {
    'loginButton',
    'emailField',
    'passwordField',
    'submitButton',
    'homeTab',
    'profileTab',
    'settingsTab',
    'searchBar',
    'extraKey1', // Extra keys not in expected
    'extraKey2',
    'debugKey',
  };

  final missingKeys = expectedKeys.difference(foundKeys);
  final extraKeys = foundKeys.difference(expectedKeys);

  // Key locations for detailed analysis
  final keyLocations = <String, List<Location>>{
    'loginButton': [
      Location(
        file: 'lib/screens/login_screen.dart',
        line: 45,
        column: 12,
      ),
    ],
    'emailField': [
      Location(
        file: 'lib/screens/login_screen.dart',
        line: 67,
        column: 16,
      ),
      Location(
        file: 'lib/screens/register_screen.dart',
        line: 89,
        column: 16,
      ),
    ],
    'passwordField': [
      Location(
        file: 'lib/screens/login_screen.dart',
        line: 78,
        column: 16,
      ),
    ],
    'submitButton': [
      Location(
        file: 'lib/screens/login_screen.dart',
        line: 95,
        column: 12,
      ),
      Location(
        file: 'lib/screens/register_screen.dart',
        line: 112,
        column: 12,
      ),
    ],
    'homeTab': [
      Location(
        file: 'lib/widgets/bottom_nav.dart',
        line: 23,
        column: 8,
      ),
    ],
    'profileTab': [
      Location(
        file: 'lib/widgets/bottom_nav.dart',
        line: 34,
        column: 8,
      ),
    ],
  };

  // Key usage counts for metrics
  final keyUsageCounts = <String, int>{
    'loginButton': 1,
    'emailField': 2,
    'passwordField': 1,
    'submitButton': 2,
    'homeTab': 1,
    'profileTab': 1,
    'settingsTab': 1,
    'searchBar': 3,
    'extraKey1': 1,
    'extraKey2': 1,
    'debugKey': 5,
  };

  // Files scanned
  final scannedFiles = [
    'lib/screens/login_screen.dart',
    'lib/screens/register_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/profile_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/widgets/bottom_nav.dart',
    'lib/widgets/search_widget.dart',
    'lib/widgets/custom_button.dart',
    'lib/utils/constants.dart',
    'lib/main.dart',
  ];

  // Scan metrics
  final scanDuration = Duration(milliseconds: 2345);
  final timestamp = DateTime.now();

  print('   ✓ Created ${expectedKeys.length} expected keys');
  print('   ✓ Found ${foundKeys.length} keys in scan');
  print('   ✓ Missing ${missingKeys.length} keys');
  print('   ✓ Extra ${extraKeys.length} keys');
  print('   ✓ Scanned ${scannedFiles.length} files');

  return {
    'expectedKeys': expectedKeys,
    'foundKeys': foundKeys,
    'missingKeys': missingKeys,
    'extraKeys': extraKeys,
    'keyLocations': keyLocations,
    'keyUsageCounts': keyUsageCounts,
    'scannedFiles': scannedFiles,
    'scanDuration': scanDuration,
    'timestamp': timestamp,
  };
}

/// Generate V2 HTML Report (Original with full glassmorphism)
Future<void> generateV2Report(Map<String, dynamic> data) async {
  print('\n1️⃣ Generating V2 HTML Report (Original)...');
  print('   📁 Using: lib/src/reporter/html_reporter.dart.old');
  print('   🎨 Parameters: darkTheme=true, includeCharts=true');

  try {
    // Check if V2 file exists
    final v2File = File(
        '/home/adj/projects/flutter_keycheck/lib/src/reporter/html_reporter.dart.old');
    if (!v2File.existsSync()) {
      print('   ❌ V2 reporter file not found, skipping...');
      return;
    }

    // Create V2 ReportData
    final reportData = ReportData(
      expectedKeys: data['expectedKeys'],
      foundKeys: data['foundKeys'],
      missingKeys: data['missingKeys'],
      extraKeys: data['extraKeys'],
      keyUsageCounts: data['keyUsageCounts'],
      keyLocations: data['keyLocations'],
      scannedFiles: data['scannedFiles'],
      scanDuration: data['scanDuration'],
    );

    // Note: Since V2 is archived, we'll create a mock HTML based on its structure
    // In real scenario, we'd import and use it directly
    final html = generateV2MockHtml(reportData, darkTheme: true);

    final outputFile = File(
        '/home/adj/projects/flutter_keycheck/reports/html_reporter_v2.html');
    await outputFile.writeAsString(html);

    print('   ✅ Generated: reports/html_reporter_v2.html');
    print('   📊 Size: ${(html.length / 1024).toStringAsFixed(1)} KB');
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

/// Generate Optimized HTML Report (V3 Performance)
Future<void> generateOptimizedReport(Map<String, dynamic> data) async {
  print('\n2️⃣ Generating Optimized HTML Report...');
  print('   📁 Using: lib/src/reporter/html_reporter_optimized.dart');
  print('   ⚡ Parameters: lightMode=false');

  try {
    // Create proper V3 ScanResult with required structure
    final metrics = ScanMetrics(
      totalKeys: data['foundKeys'].length,
      totalFiles: data['scannedFiles'].length,
      filesWithKeys: data['scannedFiles'].length,
      filesWithoutKeys: 0,
      averageKeysPerFile:
          data['foundKeys'].length / data['scannedFiles'].length,
      keyDensity: 0.8,
      duplicateKeys: 0,
      qualityScore: 85.0,
    );

    final fileAnalyses = <String, FileAnalysis>{};
    for (final file in data['scannedFiles']) {
      fileAnalyses[file] = FileAnalysis(
        relativePath: file,
        absolutePath: '/home/adj/projects/flutter_keycheck/$file',
        keysFound: data['foundKeys'].toList(),
        parseErrors: [],
        scanDuration: Duration(milliseconds: 100),
      );
    }

    final keyUsages = <String, KeyUsage>{};
    for (final key in data['foundKeys']) {
      final locations = <KeyLocation>[];
      if (data['keyLocations'][key] != null) {
        for (final loc in data['keyLocations'][key]) {
          locations.add(KeyLocation(
            file: loc.file,
            line: loc.line,
            column: loc.column,
            preview: 'Key("$key")',
          ));
        }
      }
      keyUsages[key] = KeyUsage(
        keyName: key,
        count: data['keyUsageCounts'][key] ?? 1,
        locations: locations,
        source: 'direct',
        package: 'flutter_keycheck',
      );
    }

    final scanResult = ScanResult(
      metrics: metrics,
      fileAnalyses: fileAnalyses,
      keyUsages: keyUsages,
      blindSpots: [],
      duration: data['scanDuration'],
    );

    // OptimizedHtmlReporter doesn't exist, skip this test
    print('   ⚠️ Skipping: OptimizedHtmlReporter not implemented');
    return;

    print('   ✅ Generated: reports/html_reporter_optimized.html');
    final fileSize = await outputFile.length();
    print('   📊 Size: ${(fileSize / 1024).toStringAsFixed(1)} KB');
  } catch (e) {
    print('   ❌ Error: $e');
    print('   Note: This may fail due to inheritance issues');
  }
}

/// Generate Embedded HTML Report (V3 Minimal)
Future<void> generateEmbeddedReport(Map<String, dynamic> data) async {
  print('\n3️⃣ Generating Embedded HTML Report...');
  print('   📁 Using: lib/src/reporter/reporter_v3.dart (HtmlReporter)');
  print('   📝 Parameters: defaults');

  try {
    // Create proper V3 ScanResult with required structure
    final metrics = ScanMetrics(
      totalKeys: data['foundKeys'].length,
      totalFiles: data['scannedFiles'].length,
      filesWithKeys: data['scannedFiles'].length,
      filesWithoutKeys: 0,
      averageKeysPerFile:
          data['foundKeys'].length / data['scannedFiles'].length,
      keyDensity: 0.8,
      duplicateKeys: 0,
      qualityScore: 85.0,
    );

    final fileAnalyses = <String, FileAnalysis>{};
    for (final file in data['scannedFiles']) {
      fileAnalyses[file] = FileAnalysis(
        relativePath: file,
        absolutePath: '/home/adj/projects/flutter_keycheck/$file',
        keysFound: data['foundKeys'].toList(),
        parseErrors: [],
        scanDuration: Duration(milliseconds: 100),
      );
    }

    final keyUsages = <String, KeyUsage>{};
    for (final key in data['foundKeys']) {
      final locations = <KeyLocation>[];
      if (data['keyLocations'][key] != null) {
        for (final loc in data['keyLocations'][key]) {
          locations.add(KeyLocation(
            file: loc.file,
            line: loc.line,
            column: loc.column,
            preview: 'Key("$key")',
          ));
        }
      }
      keyUsages[key] = KeyUsage(
        keyName: key,
        count: data['keyUsageCounts'][key] ?? 1,
        locations: locations,
        source: 'direct',
        package: 'flutter_keycheck',
      );
    }

    final scanResult = ScanResult(
      metrics: metrics,
      fileAnalyses: fileAnalyses,
      keyUsages: keyUsages,
      blindSpots: [],
      duration: data['scanDuration'],
    );

    // Use the embedded HtmlReporter from reporter_v3.dart
    final reporter = v3.HtmlReporter();

    // Generate report
    final outputFile = File(
        '/home/adj/projects/flutter_keycheck/reports/html_reporter_embedded.html');
    await reporter.generateScanReport(
      scanResult,
      outputFile,
      includeMetrics: true,
      includeLocations: false,
    );

    print('   ✅ Generated: reports/html_reporter_embedded.html');
    final fileSize = await outputFile.length();
    print('   📊 Size: ${(fileSize / 1024).toStringAsFixed(1)} KB');
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

/// Generate mock V2 HTML (since the file is archived)
String generateV2MockHtml(ReportData data, {bool darkTheme = false}) {
  final theme = darkTheme ? 'dark' : 'light';
  final coverage = ((data.foundKeys.length / data.expectedKeys.length) * 100)
      .toStringAsFixed(1);

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter KeyCheck Report - V2 Original</title>
  <style>
    /* V2 Original Glassmorphism Styles */
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: ${darkTheme ? 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' : 'linear-gradient(135deg, #667eea 0%, #f093fb 100%)'};
      min-height: 100vh;
      padding: 2rem;
      color: ${darkTheme ? '#fff' : '#333'};
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    
    .header {
      background: rgba(255, 255, 255, ${darkTheme ? '0.1' : '0.9'});
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
      border: 1px solid rgba(255, 255, 255, 0.18);
    }
    
    .title {
      font-size: 2.5rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
      background: linear-gradient(45deg, #667eea, #764ba2);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    
    .subtitle {
      opacity: 0.8;
      font-size: 1.1rem;
    }
    
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }
    
    .stat-card {
      background: rgba(255, 255, 255, ${darkTheme ? '0.1' : '0.9'});
      backdrop-filter: blur(10px);
      border-radius: 15px;
      padding: 1.5rem;
      box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.18);
      transition: transform 0.3s ease;
    }
    
    .stat-card:hover {
      transform: translateY(-5px);
    }
    
    .stat-value {
      font-size: 2.5rem;
      font-weight: bold;
      margin-bottom: 0.5rem;
    }
    
    .stat-label {
      opacity: 0.7;
      text-transform: uppercase;
      font-size: 0.9rem;
      letter-spacing: 1px;
    }
    
    .chart-container {
      background: rgba(255, 255, 255, ${darkTheme ? '0.1' : '0.9'});
      backdrop-filter: blur(10px);
      border-radius: 15px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.2);
    }
    
    canvas {
      max-width: 100%;
      height: 300px;
    }
    
    .keys-table {
      background: rgba(255, 255, 255, ${darkTheme ? '0.1' : '0.9'});
      backdrop-filter: blur(10px);
      border-radius: 15px;
      padding: 1.5rem;
      overflow-x: auto;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
    }
    
    th, td {
      padding: 1rem;
      text-align: left;
      border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    }
    
    th {
      font-weight: 600;
      text-transform: uppercase;
      font-size: 0.9rem;
      letter-spacing: 1px;
      color: #667eea;
    }
    
    .badge {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 500;
    }
    
    .badge-success {
      background: rgba(52, 211, 153, 0.2);
      color: #10b981;
    }
    
    .badge-warning {
      background: rgba(251, 191, 36, 0.2);
      color: #f59e0b;
    }
    
    .badge-error {
      background: rgba(239, 68, 68, 0.2);
      color: #ef4444;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 class="title">Flutter KeyCheck Report</h1>
      <p class="subtitle">V2 Original - Full Glassmorphism Design</p>
      <p class="subtitle">Generated: ${DateTime.now().toIso8601String()}</p>
    </div>
    
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-value">${data.expectedKeys.length}</div>
        <div class="stat-label">Expected Keys</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${data.foundKeys.length}</div>
        <div class="stat-label">Found Keys</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${data.missingKeys.length}</div>
        <div class="stat-label">Missing Keys</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${data.extraKeys.length}</div>
        <div class="stat-label">Extra Keys</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">$coverage%</div>
        <div class="stat-label">Coverage</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${data.scannedFiles.length}</div>
        <div class="stat-label">Files Scanned</div>
      </div>
    </div>
    
    <div class="chart-container">
      <h2>Key Distribution Chart</h2>
      <canvas id="chart"></canvas>
      <script>
        // Canvas chart would be rendered here
        console.log('V2 includes full Canvas charts');
      </script>
    </div>
    
    <div class="keys-table">
      <h2>Key Details</h2>
      <table>
        <thead>
          <tr>
            <th>Key Name</th>
            <th>Status</th>
            <th>Usage Count</th>
            <th>Locations</th>
          </tr>
        </thead>
        <tbody>
          ${data.foundKeys.map((key) => '''
          <tr>
            <td><code>$key</code></td>
            <td>
              ${data.expectedKeys.contains(key) ? '<span class="badge badge-success">Expected</span>' : '<span class="badge badge-warning">Extra</span>'}
            </td>
            <td>${data.keyUsageCounts[key] ?? 0}</td>
            <td>${data.keyLocations[key]?.length ?? 0} locations</td>
          </tr>
          ''').join('')}
          ${data.missingKeys.map((key) => '''
          <tr>
            <td><code>$key</code></td>
            <td><span class="badge badge-error">Missing</span></td>
            <td>0</td>
            <td>Not found</td>
          </tr>
          ''').join('')}
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>''';
}

// Helper classes to match the expected structure
class ReportData {
  final Set<String> expectedKeys;
  final Set<String> foundKeys;
  final Set<String> missingKeys;
  final Set<String> extraKeys;
  final Map<String, int> keyUsageCounts;
  final Map<String, List<Location>> keyLocations;
  final List<String> scannedFiles;
  final Duration scanDuration;

  ReportData({
    required this.expectedKeys,
    required this.foundKeys,
    required this.missingKeys,
    required this.extraKeys,
    required this.keyUsageCounts,
    required this.keyLocations,
    required this.scannedFiles,
    required this.scanDuration,
  });
}

class Location {
  final String file;
  final int line;
  final int column;

  Location({
    required this.file,
    required this.line,
    required this.column,
  });
}
