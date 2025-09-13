#!/usr/bin/env dart

/// 🧪 TESTER AGENT - Benchmark Comparison Tool
/// 
/// Analyzes performance trends and quality metrics over time
/// Provides before/after comparisons for code display improvements

import 'dart:io';
import 'dart:convert';
import 'dart:math';

class BenchmarkComparisonTool {
  static const String benchmarksDir = 'test/qa_benchmarks';
  static const String reportsDir = 'test/qa_reports';
  static const String comparisonDir = 'test/benchmark_comparisons';
  
  final Map<String, dynamic> comparisonConfig = {
    'performanceThresholds': {
      'regressionThreshold': 20, // 20% performance regression threshold
      'improvementThreshold': 10, // 10% improvement threshold
      'memoryThreshold': 15, // 15% memory increase threshold
    },
    'comparisonMetrics': [
      'avg_duration_ms',
      'max_duration_ms',
      'memory_used_kb',
      'quality_issues_count',
    ],
  };

  Future<void> generateComparison({
    String? baselineFile,
    String? currentFile,
    String? outputFile,
  }) async {
    print('🧪 Generating Benchmark Comparison Report');
    print('═' * 50);
    
    try {
      await Directory(comparisonDir).create(recursive: true);
      
      final baseline = await _loadBenchmarkData(baselineFile ?? _findLatestBaseline());
      final current = await _loadBenchmarkData(currentFile ?? _findLatestCurrent());
      
      final comparison = await _generateComparison(baseline, current);
      await _saveComparison(comparison, outputFile ?? 'benchmark_comparison.json');
      await _generateComparisonReport(comparison);
      
      print('\n✅ Benchmark comparison completed successfully');
    } catch (e) {
      print('\n❌ Benchmark comparison failed: $e');
      exit(1);
    }
  }

  Future<Map<String, dynamic>> _loadBenchmarkData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Benchmark file not found: $filePath');
    }
    
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  String _findLatestBaseline() {
    final dir = Directory(benchmarksDir);
    if (!dir.existsSync()) return '';
    
    final files = dir
        .listSync()
        .where((file) => file.path.contains('baseline') && file.path.endsWith('.json'))
        .map((file) => file.path)
        .toList()
      ..sort();
    
    return files.isNotEmpty ? files.last : '';
  }

  String _findLatestCurrent() {
    final dir = Directory(reportsDir);
    if (!dir.existsSync()) return '';
    
    final files = dir
        .listSync()
        .where((file) => file.path.contains('quality_assurance') && file.path.endsWith('.json'))
        .map((file) => file.path)
        .toList()
      ..sort();
    
    return files.isNotEmpty ? files.last : '';
  }

  Future<Map<String, dynamic>> _generateComparison(
    Map<String, dynamic> baseline,
    Map<String, dynamic> current,
  ) async {
    final comparison = <String, dynamic>{
      'comparison_metadata': {
        'generated_at': DateTime.now().toIso8601String(),
        'baseline_timestamp': baseline['generated_at'] ?? 'unknown',
        'current_timestamp': current['generated_at'] ?? 'unknown',
      },
      'performance_comparison': {},
      'quality_comparison': {},
      'detailed_metrics': {},
      'recommendations': <String>[],
      'status': 'unknown',
    };

    // Performance metrics comparison
    final perfComparison = await _comparePerformanceMetrics(
      baseline['performance_metrics'] as List? ?? [],
      current['performance_metrics'] as List? ?? [],
    );
    comparison['performance_comparison'] = perfComparison;

    // Quality metrics comparison
    final qualityComparison = await _compareQualityMetrics(
      baseline['summary'] as Map<String, dynamic>? ?? {},
      current['summary'] as Map<String, dynamic>? ?? {},
    );
    comparison['quality_comparison'] = qualityComparison;

    // Generate recommendations
    final recommendations = _generateRecommendations(perfComparison, qualityComparison);
    comparison['recommendations'] = recommendations;

    // Determine overall status
    comparison['status'] = _determineOverallStatus(perfComparison, qualityComparison);

    return comparison;
  }

  Future<Map<String, dynamic>> _comparePerformanceMetrics(
    List<dynamic> baselineMetrics,
    List<dynamic> currentMetrics,
  ) async {
    final comparison = <String, dynamic>{
      'duration_analysis': {},
      'memory_analysis': {},
      'trend_analysis': {},
      'regression_alerts': <String>[],
    };

    if (baselineMetrics.isEmpty || currentMetrics.isEmpty) {
      comparison['error'] = 'Insufficient data for performance comparison';
      return comparison;
    }

    // Calculate average metrics
    final baselineAvgDuration = _calculateAverage(baselineMetrics, 'duration_ms');
    final currentAvgDuration = _calculateAverage(currentMetrics, 'duration_ms');
    final baselineAvgMemory = _calculateAverage(baselineMetrics, 'memory_used_kb');
    final currentAvgMemory = _calculateAverage(currentMetrics, 'memory_used_kb');

    // Duration analysis
    final durationChange = ((currentAvgDuration - baselineAvgDuration) / baselineAvgDuration) * 100;
    comparison['duration_analysis'] = {
      'baseline_avg_ms': baselineAvgDuration.toStringAsFixed(2),
      'current_avg_ms': currentAvgDuration.toStringAsFixed(2),
      'change_percent': durationChange.toStringAsFixed(1),
      'change_direction': durationChange > 0 ? 'slower' : 'faster',
      'is_regression': durationChange > comparisonConfig['performanceThresholds']['regressionThreshold'],
      'is_improvement': durationChange < -comparisonConfig['performanceThresholds']['improvementThreshold'],
    };

    // Memory analysis
    final memoryChange = ((currentAvgMemory - baselineAvgMemory) / baselineAvgMemory) * 100;
    comparison['memory_analysis'] = {
      'baseline_avg_kb': baselineAvgMemory.toStringAsFixed(2),
      'current_avg_kb': currentAvgMemory.toStringAsFixed(2),
      'change_percent': memoryChange.toStringAsFixed(1),
      'change_direction': memoryChange > 0 ? 'increased' : 'decreased',
      'is_regression': memoryChange > comparisonConfig['performanceThresholds']['memoryThreshold'],
    };

    // Regression alerts
    final alerts = <String>[];
    if (durationChange > comparisonConfig['performanceThresholds']['regressionThreshold']) {
      alerts.add('Performance regression detected: ${durationChange.toStringAsFixed(1)}% slower execution');
    }
    if (memoryChange > comparisonConfig['performanceThresholds']['memoryThreshold']) {
      alerts.add('Memory usage regression detected: ${memoryChange.toStringAsFixed(1)}% increase');
    }
    comparison['regression_alerts'] = alerts;

    // Trend analysis
    comparison['trend_analysis'] = {
      'performance_trend': durationChange < -10 ? 'improving' : durationChange > 10 ? 'degrading' : 'stable',
      'memory_trend': memoryChange < -5 ? 'improving' : memoryChange > 5 ? 'degrading' : 'stable',
    };

    return comparison;
  }

  Future<Map<String, dynamic>> _compareQualityMetrics(
    Map<String, dynamic> baselineSummary,
    Map<String, dynamic> currentSummary,
  ) async {
    final comparison = <String, dynamic>{
      'quality_score_comparison': {},
      'issue_analysis': {},
      'test_coverage_analysis': {},
      'quality_alerts': <String>[],
    };

    final baselineIssues = baselineSummary['quality_issues'] ?? 0;
    final currentIssues = currentSummary['quality_issues'] ?? 0;
    final baselineTests = baselineSummary['total_tests'] ?? 0;
    final currentTests = currentSummary['total_tests'] ?? 0;

    // Quality score comparison
    final qualityScoreChange = currentIssues - baselineIssues;
    comparison['quality_score_comparison'] = {
      'baseline_issues': baselineIssues,
      'current_issues': currentIssues,
      'change': qualityScoreChange,
      'change_direction': qualityScoreChange > 0 ? 'worse' : qualityScoreChange < 0 ? 'better' : 'same',
      'is_regression': qualityScoreChange > 0,
      'is_improvement': qualityScoreChange < 0,
    };

    // Test coverage analysis
    final testCoverageChange = currentTests - baselineTests;
    comparison['test_coverage_analysis'] = {
      'baseline_tests': baselineTests,
      'current_tests': currentTests,
      'change': testCoverageChange,
      'coverage_trend': testCoverageChange > 0 ? 'expanding' : testCoverageChange < 0 ? 'reducing' : 'stable',
    };

    // Quality alerts
    final alerts = <String>[];
    if (qualityScoreChange > 0) {
      alerts.add('Quality regression: ${qualityScoreChange} new issues detected');
    }
    if (testCoverageChange < 0) {
      alerts.add('Test coverage reduced: ${testCoverageChange} fewer tests');
    }
    comparison['quality_alerts'] = alerts;

    return comparison;
  }

  double _calculateAverage(List<dynamic> metrics, String field) {
    if (metrics.isEmpty) return 0.0;
    
    final values = metrics
        .where((m) => m[field] != null)
        .map((m) => (m[field] as num).toDouble())
        .toList();
    
    if (values.isEmpty) return 0.0;
    
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<String> _generateRecommendations(
    Map<String, dynamic> perfComparison,
    Map<String, dynamic> qualityComparison,
  ) {
    final recommendations = <String>[];

    // Performance recommendations
    final durationAnalysis = perfComparison['duration_analysis'] as Map<String, dynamic>? ?? {};
    final memoryAnalysis = perfComparison['memory_analysis'] as Map<String, dynamic>? ?? {};

    if (durationAnalysis['is_regression'] == true) {
      recommendations.add('🚨 Performance regression detected. Consider profiling and optimizing regex patterns in syntax highlighting.');
    } else if (durationAnalysis['is_improvement'] == true) {
      recommendations.add('✅ Performance improvement detected. Document the changes for future reference.');
    }

    if (memoryAnalysis['is_regression'] == true) {
      recommendations.add('🚨 Memory usage increased significantly. Review object creation and caching strategies.');
    }

    // Quality recommendations
    final qualityScore = qualityComparison['quality_score_comparison'] as Map<String, dynamic>? ?? {};

    if (qualityScore['is_regression'] == true) {
      recommendations.add('❌ Quality regression detected. Review recent changes and fix HTML tag contamination issues.');
    } else if (qualityScore['is_improvement'] == true) {
      recommendations.add('✅ Quality improvement detected. Code display cleanliness has improved.');
    }

    // General recommendations
    if (recommendations.isEmpty) {
      recommendations.add('📊 Performance and quality metrics are stable. Continue monitoring for trends.');
    }

    return recommendations;
  }

  String _determineOverallStatus(
    Map<String, dynamic> perfComparison,
    Map<String, dynamic> qualityComparison,
  ) {
    final regressionAlerts = perfComparison['regression_alerts'] as List? ?? [];
    final qualityAlerts = qualityComparison['quality_alerts'] as List? ?? [];

    if (regressionAlerts.isNotEmpty || qualityAlerts.isNotEmpty) {
      return 'regression_detected';
    }

    final durationAnalysis = perfComparison['duration_analysis'] as Map<String, dynamic>? ?? {};
    final qualityScore = qualityComparison['quality_score_comparison'] as Map<String, dynamic>? ?? {};

    if (durationAnalysis['is_improvement'] == true || qualityScore['is_improvement'] == true) {
      return 'improvement_detected';
    }

    return 'stable';
  }

  Future<void> _saveComparison(Map<String, dynamic> comparison, String filename) async {
    final file = File('$comparisonDir/$filename');
    final jsonContent = JsonEncoder.withIndent('  ').convert(comparison);
    await file.writeAsString(jsonContent);
    
    print('   💾 Comparison data saved to: ${file.path}');
  }

  Future<void> _generateComparisonReport(Map<String, dynamic> comparison) async {
    final htmlReport = _generateHtmlReport(comparison);
    final markdownReport = _generateMarkdownReport(comparison);
    
    await File('$comparisonDir/benchmark_comparison.html').writeAsString(htmlReport);
    await File('$comparisonDir/benchmark_comparison.md').writeAsString(markdownReport);
    
    print('   📊 HTML report: $comparisonDir/benchmark_comparison.html');
    print('   📝 Markdown report: $comparisonDir/benchmark_comparison.md');
  }

  String _generateHtmlReport(Map<String, dynamic> comparison) {
    final status = comparison['status'] as String;
    final statusColor = status == 'regression_detected' ? '#dc3545' : 
                       status == 'improvement_detected' ? '#28a745' : '#007bff';
    final statusIcon = status == 'regression_detected' ? '🚨' : 
                      status == 'improvement_detected' ? '✅' : '📊';

    final perfComp = comparison['performance_comparison'] as Map<String, dynamic>;
    final qualityComp = comparison['quality_comparison'] as Map<String, dynamic>;
    final recommendations = comparison['recommendations'] as List;

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🧪 Benchmark Comparison Report</title>
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
    .status-badge {
      display: inline-block;
      padding: 10px 20px;
      border-radius: 20px;
      background: ${statusColor};
      color: white;
      font-weight: bold;
      margin: 10px 0;
    }
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      padding: 30px;
    }
    .metric-card {
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      padding: 20px;
      background: white;
    }
    .metric-title {
      font-size: 1.2rem;
      font-weight: bold;
      margin-bottom: 15px;
      color: #333;
    }
    .metric-value {
      display: flex;
      justify-content: space-between;
      margin: 8px 0;
      padding: 8px;
      background: #f8f9fa;
      border-radius: 4px;
    }
    .improvement { color: #28a745; }
    .regression { color: #dc3545; }
    .stable { color: #007bff; }
    .recommendations {
      background: #f8f9fa;
      padding: 30px;
      border-top: 1px solid #e0e0e0;
    }
    .recommendation {
      background: white;
      border-left: 4px solid #007bff;
      padding: 15px;
      margin: 10px 0;
      border-radius: 0 4px 4px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🧪 Benchmark Comparison Report</h1>
      <div class="status-badge">$statusIcon ${status.replaceAll('_', ' ').toUpperCase()}</div>
      <p>Generated: ${comparison['comparison_metadata']['generated_at']}</p>
    </div>
    
    <div class="metrics-grid">
      <div class="metric-card">
        <div class="metric-title">⚡ Performance Analysis</div>
        ${_generatePerformanceMetricsHtml(perfComp)}
      </div>
      
      <div class="metric-card">
        <div class="metric-title">🔍 Quality Analysis</div>
        ${_generateQualityMetricsHtml(qualityComp)}
      </div>
    </div>
    
    <div class="recommendations">
      <h2>💡 Recommendations</h2>
      ${recommendations.map((rec) => '<div class="recommendation">$rec</div>').join('\n')}
    </div>
  </div>
</body>
</html>''';
  }

  String _generatePerformanceMetricsHtml(Map<String, dynamic> perfComp) {
    final duration = perfComp['duration_analysis'] as Map<String, dynamic>? ?? {};
    final memory = perfComp['memory_analysis'] as Map<String, dynamic>? ?? {};
    
    return '''
<div class="metric-value">
  <span>Average Duration:</span>
  <span class="${duration['change_direction'] == 'slower' ? 'regression' : 'improvement'}">
    ${duration['current_avg_ms']}ms (${duration['change_percent']}%)
  </span>
</div>
<div class="metric-value">
  <span>Memory Usage:</span>
  <span class="${memory['change_direction'] == 'increased' ? 'regression' : 'improvement'}">
    ${memory['current_avg_kb']}KB (${memory['change_percent']}%)
  </span>
</div>''';
  }

  String _generateQualityMetricsHtml(Map<String, dynamic> qualityComp) {
    final quality = qualityComp['quality_score_comparison'] as Map<String, dynamic>? ?? {};
    final coverage = qualityComp['test_coverage_analysis'] as Map<String, dynamic>? ?? {};
    
    return '''
<div class="metric-value">
  <span>Quality Issues:</span>
  <span class="${quality['change_direction'] == 'worse' ? 'regression' : 'improvement'}">
    ${quality['current_issues']} (${quality['change'] >= 0 ? '+' : ''}${quality['change']})
  </span>
</div>
<div class="metric-value">
  <span>Test Coverage:</span>
  <span class="${coverage['coverage_trend'] == 'expanding' ? 'improvement' : 'stable'}">
    ${coverage['current_tests']} tests (${coverage['change'] >= 0 ? '+' : ''}${coverage['change']})
  </span>
</div>''';
  }

  String _generateMarkdownReport(Map<String, dynamic> comparison) {
    final buffer = StringBuffer();
    
    buffer.writeln('# 🧪 Benchmark Comparison Report\n');
    buffer.writeln('**Generated:** ${comparison['comparison_metadata']['generated_at']}\n');
    buffer.writeln('**Status:** ${comparison['status'].toString().replaceAll('_', ' ').toUpperCase()}\n');
    
    buffer.writeln('## Performance Comparison\n');
    final perfComp = comparison['performance_comparison'] as Map<String, dynamic>;
    final duration = perfComp['duration_analysis'] as Map<String, dynamic>? ?? {};
    final memory = perfComp['memory_analysis'] as Map<String, dynamic>? ?? {};
    
    buffer.writeln('| Metric | Baseline | Current | Change |');
    buffer.writeln('|--------|----------|---------|--------|');
    buffer.writeln('| Average Duration | ${duration['baseline_avg_ms']}ms | ${duration['current_avg_ms']}ms | ${duration['change_percent']}% |');
    buffer.writeln('| Memory Usage | ${memory['baseline_avg_kb']}KB | ${memory['current_avg_kb']}KB | ${memory['change_percent']}% |');
    buffer.writeln();
    
    buffer.writeln('## Quality Comparison\n');
    final qualityComp = comparison['quality_comparison'] as Map<String, dynamic>;
    final quality = qualityComp['quality_score_comparison'] as Map<String, dynamic>? ?? {};
    
    buffer.writeln('| Metric | Baseline | Current | Change |');
    buffer.writeln('|--------|----------|---------|--------|');
    buffer.writeln('| Quality Issues | ${quality['baseline_issues']} | ${quality['current_issues']} | ${quality['change'] >= 0 ? '+' : ''}${quality['change']} |');
    buffer.writeln();
    
    buffer.writeln('## Recommendations\n');
    final recommendations = comparison['recommendations'] as List;
    for (final rec in recommendations) {
      buffer.writeln('- $rec');
    }
    
    return buffer.toString();
  }
}

Future<void> main(List<String> args) async {
  final tool = BenchmarkComparisonTool();
  
  String? baseline, current, output;
  
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--baseline':
        if (i + 1 < args.length) baseline = args[++i];
        break;
      case '--current':
        if (i + 1 < args.length) current = args[++i];
        break;
      case '--output':
        if (i + 1 < args.length) output = args[++i];
        break;
      case '--help':
        print('''
🧪 Benchmark Comparison Tool

Usage: dart benchmark_comparison_tool.dart [options]

Options:
  --baseline <file>  Path to baseline benchmark file
  --current <file>   Path to current benchmark file
  --output <file>    Output filename for comparison
  --help            Show this help message

Example:
  dart benchmark_comparison_tool.dart --baseline baseline.json --current current.json
''');
        return;
    }
  }
  
  await tool.generateComparison(
    baselineFile: baseline,
    currentFile: current,
    outputFile: output,
  );
}