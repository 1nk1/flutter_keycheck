#!/usr/bin/env dart

/// 🧪 TESTER AGENT - Quality Assurance Test Runner
/// 
/// Comprehensive test execution script for code display validation
/// 
/// Features:
/// - Automated test suite execution
/// - Performance benchmarking
/// - Quality issue detection and reporting
/// - Visual baseline generation
/// - Cross-platform compatibility testing

import 'dart:io';
import 'dart:convert';
import 'dart:async';

class QualityAssuranceRunner {
  static const String baseDir = '.';
  static const String reportsDir = 'test/qa_reports';
  static const String benchmarksDir = 'test/qa_benchmarks';
  
  final Map<String, dynamic> runnerConfig = {
    'testFiles': [
      'test/code_display_quality_assurance_test.dart',
      'test/code_display_test.dart',
      'test/code_display_validation_test.dart',
      'test/html_security_test.dart',
      'test/visual_modal_test.dart',
    ],
    'performanceThresholds': {
      'maxAvgDurationMs': 20,
      'maxMemoryIncreaseMB': 50,
      'maxQualityIssues': 0,
    },
    'outputFormats': ['json', 'html', 'markdown'],
  };

  Future<void> run() async {
    print('🧪 Starting Quality Assurance Test Suite');
    print('═' * 60);
    
    try {
      await _setupEnvironment();
      final results = await _executeTests();
      await _generateReports(results);
      await _validateResults(results);
      
      print('\n✅ Quality Assurance Tests Completed Successfully');
    } catch (e) {
      print('\n❌ Quality Assurance Tests Failed: $e');
      exit(1);
    }
  }

  Future<void> _setupEnvironment() async {
    print('📋 Setting up test environment...');
    
    // Create directories
    await Directory(reportsDir).create(recursive: true);
    await Directory(benchmarksDir).create(recursive: true);
    await Directory('$reportsDir/baselines').create(recursive: true);
    await Directory('$reportsDir/screenshots').create(recursive: true);
    
    // Clean previous reports
    await _cleanPreviousReports();
    
    print('   ✓ Environment setup complete');
  }

  Future<void> _cleanPreviousReports() async {
    final reportTypes = ['*.html', '*.json', '*.md'];
    for (final pattern in reportTypes) {
      final files = Directory(reportsDir)
          .listSync()
          .where((file) => file.path.endsWith(pattern.substring(1)))
          .toList();
      for (final file in files) {
        await file.delete();
      }
    }
  }

  Future<Map<String, dynamic>> _executeTests() async {
    print('🧪 Executing test suites...');
    
    final results = <String, dynamic>{
      'startTime': DateTime.now().toIso8601String(),
      'testSuites': <Map<String, dynamic>>[],
      'summary': {
        'totalTests': 0,
        'passedTests': 0,
        'failedTests': 0,
        'totalDuration': 0,
      },
    };

    for (final testFile in runnerConfig['testFiles']) {
      print('   📝 Running: $testFile');
      
      final suiteResult = await _runTestSuite(testFile);
      results['testSuites'].add(suiteResult);
      
      final summary = results['summary'] as Map<String, dynamic>;
      summary['totalTests'] += suiteResult['testCount'] ?? 0;
      summary['passedTests'] += suiteResult['passedCount'] ?? 0;
      summary['failedTests'] += suiteResult['failedCount'] ?? 0;
      summary['totalDuration'] += suiteResult['duration'] ?? 0;
      
      print('      ✓ ${suiteResult['testCount']} tests (${suiteResult['duration']}ms)');
    }

    results['endTime'] = DateTime.now().toIso8601String();
    return results;
  }

  Future<Map<String, dynamic>> _runTestSuite(String testFile) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final process = await Process.run(
        'dart', 
        ['test', testFile, '--reporter=json'],
        workingDirectory: baseDir,
      );
      
      stopwatch.stop();
      
      final output = process.stdout as String;
      final testResults = _parseTestOutput(output);
      
      return {
        'testFile': testFile,
        'duration': stopwatch.elapsedMilliseconds,
        'exitCode': process.exitCode,
        'testCount': testResults['testCount'],
        'passedCount': testResults['passedCount'],
        'failedCount': testResults['failedCount'],
        'results': testResults['tests'],
        'stderr': process.stderr,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'testFile': testFile,
        'duration': stopwatch.elapsedMilliseconds,
        'exitCode': 1,
        'error': e.toString(),
        'testCount': 0,
        'passedCount': 0,
        'failedCount': 1,
      };
    }
  }

  Map<String, dynamic> _parseTestOutput(String output) {
    final lines = output.split('\n').where((line) => line.trim().isNotEmpty);
    final tests = <Map<String, dynamic>>[];
    int passedCount = 0, failedCount = 0;

    for (final line in lines) {
      try {
        final json = jsonDecode(line);
        if (json['type'] == 'testDone') {
          tests.add({
            'name': json['test']['name'],
            'result': json['result'],
            'hidden': json['hidden'] ?? false,
            'skipped': json['skipped'] ?? false,
            'time': json['time'] ?? 0,
          });
          
          if (json['result'] == 'success') {
            passedCount++;
          } else {
            failedCount++;
          }
        }
      } catch (e) {
        // Skip non-JSON lines
      }
    }

    return {
      'testCount': tests.length,
      'passedCount': passedCount,
      'failedCount': failedCount,
      'tests': tests,
    };
  }

  Future<void> _generateReports(Map<String, dynamic> results) async {
    print('📊 Generating reports...');
    
    for (final format in runnerConfig['outputFormats']) {
      switch (format) {
        case 'json':
          await _generateJsonReport(results);
          break;
        case 'html':
          await _generateHtmlReport(results);
          break;
        case 'markdown':
          await _generateMarkdownReport(results);
          break;
      }
    }
    
    print('   ✓ Reports generated');
  }

  Future<void> _generateJsonReport(Map<String, dynamic> results) async {
    final jsonReport = JsonEncoder.withIndent('  ').convert(results);
    await File('$reportsDir/quality_assurance_results.json').writeAsString(jsonReport);
  }

  Future<void> _generateHtmlReport(Map<String, dynamic> results) async {
    final summary = results['summary'] as Map<String, dynamic>;
    final totalTests = summary['totalTests'];
    final passedTests = summary['passedTests'];
    final failedTests = summary['failedTests'];
    final successRate = totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0';
    
    final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Quality Assurance Test Results</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 2.5rem;
    }
    .header .subtitle {
      margin: 10px 0 0 0;
      opacity: 0.9;
      font-size: 1.1rem;
    }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      padding: 30px;
      background: #f8f9fa;
    }
    .summary-card {
      background: white;
      border-radius: 8px;
      padding: 20px;
      text-align: center;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    .summary-card .number {
      font-size: 2.5rem;
      font-weight: bold;
      margin-bottom: 5px;
    }
    .summary-card .label {
      color: #666;
      font-size: 0.9rem;
    }
    .passed { color: #28a745; }
    .failed { color: #dc3545; }
    .total { color: #007bff; }
    .rate { color: #17a2b8; }
    .content {
      padding: 30px;
    }
    .test-suite {
      margin-bottom: 30px;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      overflow: hidden;
    }
    .test-suite-header {
      background: #f8f9fa;
      padding: 15px 20px;
      border-bottom: 1px solid #e0e0e0;
      font-weight: bold;
    }
    .test-suite-content {
      padding: 20px;
    }
    .test-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 0;
      border-bottom: 1px solid #f0f0f0;
    }
    .test-item:last-child {
      border-bottom: none;
    }
    .test-name {
      flex: 1;
    }
    .test-result {
      padding: 4px 12px;
      border-radius: 4px;
      font-size: 0.8rem;
      font-weight: bold;
    }
    .test-result.success {
      background: #d4edda;
      color: #155724;
    }
    .test-result.failure {
      background: #f8d7da;
      color: #721c24;
    }
    .footer {
      background: #f8f9fa;
      padding: 20px;
      text-align: center;
      color: #666;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🧪 Quality Assurance Test Results</h1>
      <div class="subtitle">Code Display Validation Test Suite</div>
    </div>
    
    <div class="summary">
      <div class="summary-card">
        <div class="number total">$totalTests</div>
        <div class="label">Total Tests</div>
      </div>
      <div class="summary-card">
        <div class="number passed">$passedTests</div>
        <div class="label">Passed</div>
      </div>
      <div class="summary-card">
        <div class="number failed">$failedTests</div>
        <div class="label">Failed</div>
      </div>
      <div class="summary-card">
        <div class="number rate">$successRate%</div>
        <div class="label">Success Rate</div>
      </div>
    </div>
    
    <div class="content">
      ${(results['testSuites'] as List).map((suite) => _generateTestSuiteHtml(suite)).join('\n')}
    </div>
    
    <div class="footer">
      Generated on ${DateTime.now().toString()} | Flutter KeyCheck Quality Assurance
    </div>
  </div>
</body>
</html>''';

    await File('$reportsDir/quality_assurance_results.html').writeAsString(htmlContent);
  }

  String _generateTestSuiteHtml(Map<String, dynamic> suite) {
    final testFile = suite['testFile'] ?? 'Unknown';
    final duration = suite['duration'] ?? 0;
    final testCount = suite['testCount'] ?? 0;
    final passedCount = suite['passedCount'] ?? 0;
    final failedCount = suite['failedCount'] ?? 0;
    
    final tests = (suite['results'] as List? ?? []).map((test) {
      final name = test['name'] ?? 'Unnamed test';
      final result = test['result'] ?? 'unknown';
      final time = test['time'] ?? 0;
      
      return '''
        <div class="test-item">
          <div class="test-name">$name</div>
          <div class="test-result $result">${result.toUpperCase()}</div>
        </div>''';
    }).join('\n');

    return '''
      <div class="test-suite">
        <div class="test-suite-header">
          $testFile - $testCount tests, ${duration}ms
          <span style="float: right;">
            <span class="passed">✓ $passedCount</span>
            <span class="failed">✗ $failedCount</span>
          </span>
        </div>
        <div class="test-suite-content">
          $tests
        </div>
      </div>''';
  }

  Future<void> _generateMarkdownReport(Map<String, dynamic> results) async {
    final summary = results['summary'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    
    buffer.writeln('# 🧪 Quality Assurance Test Results\n');
    buffer.writeln('**Code Display Validation Test Suite**\n');
    buffer.writeln('Generated on: ${DateTime.now()}\n');
    
    buffer.writeln('## Summary\n');
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Tests | ${summary['totalTests']} |');
    buffer.writeln('| Passed Tests | ${summary['passedTests']} |');
    buffer.writeln('| Failed Tests | ${summary['failedTests']} |');
    buffer.writeln('| Success Rate | ${summary['totalTests'] > 0 ? (summary['passedTests'] / summary['totalTests'] * 100).toStringAsFixed(1) : '0'}% |');
    buffer.writeln('| Total Duration | ${summary['totalDuration']}ms |');
    buffer.writeln();

    buffer.writeln('## Test Suites\n');
    for (final suite in results['testSuites'] as List) {
      buffer.writeln('### ${suite['testFile']}\n');
      buffer.writeln('- Tests: ${suite['testCount']}');
      buffer.writeln('- Duration: ${suite['duration']}ms');
      buffer.writeln('- Passed: ${suite['passedCount']}');
      buffer.writeln('- Failed: ${suite['failedCount']}\n');
      
      if (suite['results'] != null) {
        buffer.writeln('#### Test Details\n');
        for (final test in suite['results'] as List) {
          final status = test['result'] == 'success' ? '✅' : '❌';
          buffer.writeln('- $status ${test['name']}');
        }
        buffer.writeln();
      }
    }

    await File('$reportsDir/quality_assurance_results.md').writeAsString(buffer.toString());
  }

  Future<void> _validateResults(Map<String, dynamic> results) async {
    print('🔍 Validating results against quality thresholds...');
    
    final summary = results['summary'] as Map<String, dynamic>;
    final thresholds = runnerConfig['performanceThresholds'];
    final issues = <String>[];
    
    // Check failure threshold
    if (summary['failedTests'] > 0) {
      issues.add('❌ Found ${summary['failedTests']} failed tests');
    }
    
    // Check performance thresholds
    final avgDuration = summary['totalDuration'] / summary['totalTests'];
    if (avgDuration > thresholds['maxAvgDurationMs']) {
      issues.add('⚠️  Average test duration (${avgDuration}ms) exceeds threshold (${thresholds['maxAvgDurationMs']}ms)');
    }
    
    // Validate quality reports exist
    final qualityReportFile = File('$reportsDir/quality_assurance_report.json');
    if (await qualityReportFile.exists()) {
      final qualityReport = jsonDecode(await qualityReportFile.readAsString());
      final qualityIssues = qualityReport['quality_issues']?.length ?? 0;
      
      if (qualityIssues > thresholds['maxQualityIssues']) {
        issues.add('❌ Found $qualityIssues quality issues (max allowed: ${thresholds['maxQualityIssues']})');
      }
    }
    
    if (issues.isNotEmpty) {
      print('   Quality validation issues:');
      for (final issue in issues) {
        print('   $issue');
      }
      throw Exception('Quality validation failed with ${issues.length} issues');
    }
    
    print('   ✅ All quality thresholds met');
  }
}

Future<void> main(List<String> args) async {
  final runner = QualityAssuranceRunner();
  await runner.run();
}