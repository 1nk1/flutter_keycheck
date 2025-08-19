#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;

/// Performance monitoring dashboard generator
/// 
/// This tool generates comprehensive performance dashboards from benchmark results,
/// providing visual insights into performance trends, regressions, and optimization opportunities.
/// 
/// Features:
/// - HTML dashboard with interactive charts
/// - Performance trend analysis
/// - Regression detection and alerts
/// - CI/CD integration metrics
/// - Memory usage profiling
/// - Comparative analysis across configurations
/// 
/// Usage:
///   dart run tools/performance_dashboard.dart [options]
///
/// Options:
///   --input <dir>          Input directory containing benchmark results
///   --output <dir>         Output directory for dashboard files
///   --baseline <file>      Baseline file for comparison
///   --format <format>      Output format: html, json, markdown (default: html)
///   --threshold <percent>  Regression threshold percentage (default: 20)
///   --days <number>        Number of days to include in trends (default: 30)
///   --help                 Show help information
Future<void> main(List<String> args) async {
  final options = parseArguments(args);
  
  if (options['help'] == true) {
    printUsage();
    return;
  }

  try {
    final generator = PerformanceDashboardGenerator(options);
    await generator.generateDashboard();
    
    print('✅ Performance dashboard generated successfully!');
    print('📄 Output: ${options['output']}');
    
  } catch (e, stackTrace) {
    print('❌ Error generating dashboard: $e');
    if (options['verbose'] == true) {
      print('Stack trace: $stackTrace');
    }
    exit(1);
  }
}

/// Print usage information
void printUsage() {
  print('''
📊 Flutter KeyCheck Performance Dashboard Generator

Usage: dart run tools/performance_dashboard.dart [options]

Options:
  --input <dir>          Input directory containing benchmark results (default: performance_results)
  --output <dir>         Output directory for dashboard files (default: dashboard)
  --baseline <file>      Baseline file for comparison analysis
  --format <format>      Output format: html, json, markdown (default: html)
  --threshold <percent>  Regression threshold percentage (default: 20)
  --days <number>        Number of days to include in trends (default: 30)
  --title <string>       Dashboard title (default: Flutter KeyCheck Performance Dashboard)
  --verbose              Enable verbose output
  --help                 Show this help message

Examples:
  # Generate HTML dashboard from default results
  dart run tools/performance_dashboard.dart

  # Generate dashboard with custom baseline
  dart run tools/performance_dashboard.dart --baseline baseline.json --threshold 15

  # Generate markdown report for CI
  dart run tools/performance_dashboard.dart --format markdown --output reports/

  # Generate comprehensive dashboard with 60-day trends
  dart run tools/performance_dashboard.dart --days 60 --verbose
''');
}

/// Parse command line arguments
Map<String, dynamic> parseArguments(List<String> args) {
  final options = <String, dynamic>{};
  
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      
      // Boolean flags
      if (['help', 'verbose'].contains(key)) {
        options[key] = true;
      } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        // Options with values
        options[key] = args[i + 1];
        i++; // Skip next argument as it's the value
      } else {
        options[key] = true; // Flag without value
      }
    }
  }
  
  // Set defaults
  options['input'] ??= 'performance_results';
  options['output'] ??= 'dashboard';
  options['format'] ??= 'html';
  options['threshold'] ??= '20';
  options['days'] ??= '30';
  options['title'] ??= 'Flutter KeyCheck Performance Dashboard';
  
  return options;
}

/// Performance dashboard generator
class PerformanceDashboardGenerator {
  final Map<String, dynamic> options;
  late final String inputDir;
  late final String outputDir;
  late final String format;
  late final double threshold;
  late final int days;
  late final String title;

  PerformanceDashboardGenerator(this.options) {
    inputDir = options['input'] as String;
    outputDir = options['output'] as String;
    format = options['format'] as String;
    threshold = double.parse(options['threshold'] as String);
    days = int.parse(options['days'] as String);
    title = options['title'] as String;
  }

  /// Generate comprehensive performance dashboard
  Future<void> generateDashboard() async {
    print('📊 Generating performance dashboard...');
    print('Input: $inputDir');
    print('Output: $outputDir');
    print('Format: $format');

    // Ensure output directory exists
    await Directory(outputDir).create(recursive: true);

    // Load and analyze performance data
    final analyzer = PerformanceDataAnalyzer(inputDir, days);
    final analysisResults = await analyzer.analyzePerformanceData();

    // Generate dashboard based on format
    switch (format.toLowerCase()) {
      case 'html':
        await _generateHtmlDashboard(analysisResults);
        break;
      case 'json':
        await _generateJsonDashboard(analysisResults);
        break;
      case 'markdown':
        await _generateMarkdownDashboard(analysisResults);
        break;
      default:
        throw ArgumentError('Unsupported format: $format');
    }

    // Generate supporting files
    await _generateSupportingFiles(analysisResults);
  }

  /// Generate HTML dashboard with interactive charts
  Future<void> _generateHtmlDashboard(PerformanceAnalysisResults results) async {
    print('📄 Generating HTML dashboard...');

    final htmlContent = _buildHtmlDashboard(results);
    final htmlFile = File(path.join(outputDir, 'index.html'));
    await htmlFile.writeAsString(htmlContent);

    // Generate CSS
    await _generateStylesheet();
    
    // Generate JavaScript for charts
    await _generateChartScripts(results);

    print('✅ HTML dashboard generated: ${htmlFile.path}');
  }

  /// Generate JSON dashboard data
  Future<void> _generateJsonDashboard(PerformanceAnalysisResults results) async {
    print('📄 Generating JSON dashboard...');

    final jsonData = {
      'metadata': {
        'generated_at': DateTime.now().toIso8601String(),
        'title': title,
        'period_days': days,
        'regression_threshold': threshold,
      },
      'summary': results.summary.toMap(),
      'trends': results.trends.map((t) => t.toMap()).toList(),
      'regressions': results.regressions.map((r) => r.toMap()).toList(),
      'benchmarks': results.benchmarks.map((b) => b.toMap()).toList(),
    };

    final jsonFile = File(path.join(outputDir, 'dashboard.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await jsonFile.writeAsString(encoder.convert(jsonData));

    print('✅ JSON dashboard generated: ${jsonFile.path}');
  }

  /// Generate Markdown dashboard report
  Future<void> _generateMarkdownDashboard(PerformanceAnalysisResults results) async {
    print('📄 Generating Markdown dashboard...');

    final markdownContent = _buildMarkdownDashboard(results);
    final markdownFile = File(path.join(outputDir, 'README.md'));
    await markdownFile.writeAsString(markdownContent);

    print('✅ Markdown dashboard generated: ${markdownFile.path}');
  }

  /// Build HTML dashboard content
  String _buildHtmlDashboard(PerformanceAnalysisResults results) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <link rel="stylesheet" href="dashboard.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/date-fns@2.29.3/index.min.js"></script>
</head>
<body>
    <div class="container">
        <header class="dashboard-header">
            <h1>$title</h1>
            <div class="header-info">
                <span class="info-item">Generated: ${DateTime.now().toLocal().toString().split('.')[0]}</span>
                <span class="info-item">Period: $days days</span>
                <span class="info-item">Threshold: ${threshold.toStringAsFixed(0)}%</span>
            </div>
        </header>

        <div class="summary-grid">
            <div class="summary-card">
                <h3>Performance Score</h3>
                <div class="metric-value ${_getScoreClass(results.summary.overallScore)}">${results.summary.overallScore.toStringAsFixed(1)}</div>
                <div class="metric-label">Overall Performance</div>
            </div>
            <div class="summary-card">
                <h3>Avg Scan Time</h3>
                <div class="metric-value">${results.summary.averageScanTime.toStringAsFixed(0)}ms</div>
                <div class="metric-label">Typical Project</div>
            </div>
            <div class="summary-card">
                <h3>Memory Usage</h3>
                <div class="metric-value">${results.summary.averageMemoryUsage.toStringAsFixed(0)}MB</div>
                <div class="metric-label">Peak Usage</div>
            </div>
            <div class="summary-card">
                <h3>Regressions</h3>
                <div class="metric-value ${results.regressions.isEmpty ? 'good' : 'warning'}">${results.regressions.length}</div>
                <div class="metric-label">Detected Issues</div>
            </div>
        </div>

        ${_buildRegressionAlertsSection(results.regressions)}

        <div class="charts-grid">
            <div class="chart-container">
                <h3>Performance Trends</h3>
                <canvas id="performanceTrendsChart"></canvas>
            </div>
            <div class="chart-container">
                <h3>Memory Usage Trends</h3>
                <canvas id="memoryTrendsChart"></canvas>
            </div>
            <div class="chart-container">
                <h3>Configuration Comparison</h3>
                <canvas id="configComparisonChart"></canvas>
            </div>
            <div class="chart-container">
                <h3>Throughput Analysis</h3>
                <canvas id="throughputChart"></canvas>
            </div>
        </div>

        <div class="detailed-analysis">
            <h2>Detailed Analysis</h2>
            ${_buildBenchmarkTable(results.benchmarks)}
        </div>

        <div class="recommendations">
            <h2>Performance Recommendations</h2>
            ${_buildRecommendations(results)}
        </div>

        <footer class="dashboard-footer">
            <p>Generated by Flutter KeyCheck Performance Monitoring Suite</p>
            <p>Data analysis period: ${results.trends.isNotEmpty ? results.trends.first.date : 'N/A'} to ${results.trends.isNotEmpty ? results.trends.last.date : 'N/A'}</p>
        </footer>
    </div>

    <script src="dashboard.js"></script>
</body>
</html>
''';
  }

  /// Build markdown dashboard content
  String _buildMarkdownDashboard(PerformanceAnalysisResults results) {
    final buffer = StringBuffer();

    buffer.writeln('# $title\n');
    buffer.writeln('*Generated: ${DateTime.now().toLocal().toString().split('.')[0]}*\n');

    // Summary section
    buffer.writeln('## Performance Summary\n');
    buffer.writeln('| Metric | Value | Status |');
    buffer.writeln('|--------|-------|--------|');
    buffer.writeln('| Overall Score | ${results.summary.overallScore.toStringAsFixed(1)}/100 | ${_getScoreText(results.summary.overallScore)} |');
    buffer.writeln('| Average Scan Time | ${results.summary.averageScanTime.toStringAsFixed(0)}ms | ${results.summary.averageScanTime < 1000 ? '✅ Good' : results.summary.averageScanTime < 3000 ? '⚠️ Warning' : '❌ Poor'} |');
    buffer.writeln('| Average Memory Usage | ${results.summary.averageMemoryUsage.toStringAsFixed(0)}MB | ${results.summary.averageMemoryUsage < 200 ? '✅ Good' : results.summary.averageMemoryUsage < 500 ? '⚠️ Warning' : '❌ Poor'} |');
    buffer.writeln('| Active Regressions | ${results.regressions.length} | ${results.regressions.isEmpty ? '✅ None' : '❌ Issues Found'} |\n');

    // Regressions section
    if (results.regressions.isNotEmpty) {
      buffer.writeln('## ⚠️ Performance Regressions\n');
      for (final regression in results.regressions) {
        buffer.writeln('- **${regression.metric}**: ${regression.degradation.toStringAsFixed(1)}% slower');
        buffer.writeln('  - Configuration: ${regression.configuration}');
        buffer.writeln('  - Baseline: ${regression.baselineValue.toStringAsFixed(1)}');
        buffer.writeln('  - Current: ${regression.currentValue.toStringAsFixed(1)}');
        buffer.writeln();
      }
    }

    // Trends section
    if (results.trends.isNotEmpty) {
      buffer.writeln('## Performance Trends\n');
      buffer.writeln('### Recent Performance Data\n');
      buffer.writeln('| Date | Scan Time (ms) | Memory (MB) | Files/sec |');
      buffer.writeln('|------|----------------|-------------|-----------|');
      
      final recentTrends = results.trends.take(10);
      for (final trend in recentTrends) {
        buffer.writeln('| ${trend.date} | ${trend.scanTime.toStringAsFixed(0)} | ${trend.memoryUsage.toStringAsFixed(0)} | ${trend.throughput.toStringAsFixed(1)} |');
      }
      buffer.writeln();
    }

    // Recommendations section
    buffer.writeln('## Recommendations\n');
    final recommendations = _generateRecommendations(results);
    for (final recommendation in recommendations) {
      buffer.writeln('- $recommendation');
    }
    buffer.writeln();

    // Configuration comparison
    buffer.writeln('## Configuration Performance\n');
    buffer.writeln('| Configuration | Avg Time (ms) | Avg Memory (MB) | Throughput (files/sec) |');
    buffer.writeln('|---------------|---------------|-----------------|------------------------|');
    
    final groupedBenchmarks = <String, List<BenchmarkData>>{};
    for (final benchmark in results.benchmarks) {
      groupedBenchmarks.putIfAbsent(benchmark.configuration, () => []).add(benchmark);
    }

    for (final entry in groupedBenchmarks.entries) {
      final config = entry.key;
      final benchmarks = entry.value;
      
      final avgTime = benchmarks.map((b) => b.scanTime).reduce((a, b) => a + b) / benchmarks.length;
      final avgMemory = benchmarks.map((b) => b.memoryUsage).reduce((a, b) => a + b) / benchmarks.length;
      final avgThroughput = benchmarks.map((b) => b.throughput).reduce((a, b) => a + b) / benchmarks.length;
      
      buffer.writeln('| $config | ${avgTime.toStringAsFixed(0)} | ${avgMemory.toStringAsFixed(0)} | ${avgThroughput.toStringAsFixed(1)} |');
    }

    buffer.writeln('\n---\n*Dashboard generated by Flutter KeyCheck Performance Monitoring Suite*');

    return buffer.toString();
  }

  /// Build regression alerts section
  String _buildRegressionAlertsSection(List<PerformanceRegression> regressions) {
    if (regressions.isEmpty) {
      return '''
        <div class="alert alert-success">
            <h3>✅ No Performance Regressions Detected</h3>
            <p>All performance metrics are within acceptable thresholds.</p>
        </div>
      ''';
    }

    final buffer = StringBuffer();
    buffer.writeln('<div class="alert alert-warning">');
    buffer.writeln('<h3>⚠️ Performance Regressions Detected</h3>');
    buffer.writeln('<ul>');
    
    for (final regression in regressions) {
      buffer.writeln('<li>');
      buffer.writeln('<strong>${regression.metric}</strong> in ${regression.configuration}: ');
      buffer.writeln('${regression.degradation.toStringAsFixed(1)}% slower ');
      buffer.writeln('(${regression.baselineValue.toStringAsFixed(1)} → ${regression.currentValue.toStringAsFixed(1)})');
      buffer.writeln('</li>');
    }
    
    buffer.writeln('</ul>');
    buffer.writeln('</div>');
    
    return buffer.toString();
  }

  /// Build benchmark results table
  String _buildBenchmarkTable(List<BenchmarkData> benchmarks) {
    final buffer = StringBuffer();
    
    buffer.writeln('<table class="benchmark-table">');
    buffer.writeln('<thead>');
    buffer.writeln('<tr>');
    buffer.writeln('<th>Date</th>');
    buffer.writeln('<th>Configuration</th>');
    buffer.writeln('<th>Scan Time (ms)</th>');
    buffer.writeln('<th>Memory (MB)</th>');
    buffer.writeln('<th>Files/sec</th>');
    buffer.writeln('<th>Keys Found</th>');
    buffer.writeln('<th>Status</th>');
    buffer.writeln('</tr>');
    buffer.writeln('</thead>');
    buffer.writeln('<tbody>');
    
    for (final benchmark in benchmarks.take(50)) { // Limit to 50 most recent
      final statusClass = benchmark.scanTime < 1000 ? 'status-good' : 
                         benchmark.scanTime < 3000 ? 'status-warning' : 'status-poor';
      
      buffer.writeln('<tr>');
      buffer.writeln('<td>${benchmark.date}</td>');
      buffer.writeln('<td>${benchmark.configuration}</td>');
      buffer.writeln('<td>${benchmark.scanTime.toStringAsFixed(0)}</td>');
      buffer.writeln('<td>${benchmark.memoryUsage.toStringAsFixed(1)}</td>');
      buffer.writeln('<td>${benchmark.throughput.toStringAsFixed(1)}</td>');
      buffer.writeln('<td>${benchmark.keysFound}</td>');
      buffer.writeln('<td><span class="status-badge $statusClass">${_getPerformanceStatus(benchmark.scanTime)}</span></td>');
      buffer.writeln('</tr>');
    }
    
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');
    
    return buffer.toString();
  }

  /// Build recommendations section
  String _buildRecommendations(PerformanceAnalysisResults results) {
    final recommendations = _generateRecommendations(results);
    
    final buffer = StringBuffer();
    buffer.writeln('<ul class="recommendations-list">');
    
    for (final recommendation in recommendations) {
      buffer.writeln('<li class="recommendation-item">$recommendation</li>');
    }
    
    buffer.writeln('</ul>');
    
    return buffer.toString();
  }

  /// Generate performance recommendations
  List<String> _generateRecommendations(PerformanceAnalysisResults results) {
    final recommendations = <String>[];
    
    // Check scan time performance
    if (results.summary.averageScanTime > 3000) {
      recommendations.add('🚀 <strong>Enable parallel processing</strong> - Average scan time is ${results.summary.averageScanTime.toStringAsFixed(0)}ms, which is above optimal range');
    }
    
    if (results.summary.averageScanTime > 1000) {
      recommendations.add('💾 <strong>Enable caching</strong> - Implement incremental scanning and aggressive caching for better performance');
    }
    
    // Check memory usage
    if (results.summary.averageMemoryUsage > 500) {
      recommendations.add('🧠 <strong>Optimize memory usage</strong> - Average memory usage is ${results.summary.averageMemoryUsage.toStringAsFixed(0)}MB, consider lazy loading');
    }
    
    // Check for regressions
    if (results.regressions.isNotEmpty) {
      recommendations.add('⚠️ <strong>Address performance regressions</strong> - ${results.regressions.length} performance regressions detected');
    }
    
    // Throughput recommendations
    final avgThroughput = results.benchmarks.isNotEmpty 
        ? results.benchmarks.map((b) => b.throughput).reduce((a, b) => a + b) / results.benchmarks.length
        : 0;
    
    if (avgThroughput < 50) {
      recommendations.add('⚡ <strong>Improve throughput</strong> - Current throughput is ${avgThroughput.toStringAsFixed(1)} files/sec, target is >50 files/sec');
    }
    
    // Configuration recommendations
    final configPerformance = <String, double>{};
    for (final benchmark in results.benchmarks) {
      configPerformance[benchmark.configuration] = 
          (configPerformance[benchmark.configuration] ?? 0) + benchmark.scanTime;
    }
    
    if (configPerformance.isNotEmpty) {
      final bestConfig = configPerformance.entries.reduce((a, b) => a.value < b.value ? a : b).key;
      if (!recommendations.any((r) => r.contains('parallel'))) {
        recommendations.add('🔧 <strong>Use optimal configuration</strong> - "$bestConfig" shows best performance in current tests');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('✅ <strong>Performance is optimal</strong> - All metrics are within target ranges');
    }
    
    return recommendations;
  }

  /// Generate stylesheet
  Future<void> _generateStylesheet() async {
    final cssContent = '''
/* Performance Dashboard Styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f8f9fa;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.dashboard-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 30px;
    border-radius: 10px;
    margin-bottom: 30px;
    text-align: center;
}

.dashboard-header h1 {
    font-size: 2.5rem;
    margin-bottom: 10px;
}

.header-info {
    display: flex;
    justify-content: center;
    gap: 30px;
    flex-wrap: wrap;
}

.info-item {
    background: rgba(255, 255, 255, 0.2);
    padding: 5px 15px;
    border-radius: 20px;
    font-size: 0.9rem;
}

.summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 30px;
}

.summary-card {
    background: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    text-align: center;
}

.summary-card h3 {
    color: #666;
    margin-bottom: 10px;
    font-size: 1rem;
}

.metric-value {
    font-size: 2.5rem;
    font-weight: bold;
    margin-bottom: 5px;
}

.metric-value.good { color: #28a745; }
.metric-value.warning { color: #ffc107; }
.metric-value.poor { color: #dc3545; }

.metric-label {
    color: #888;
    font-size: 0.9rem;
}

.alert {
    padding: 20px;
    border-radius: 10px;
    margin-bottom: 30px;
}

.alert-success {
    background-color: #d4edda;
    border: 1px solid #c3e6cb;
    color: #155724;
}

.alert-warning {
    background-color: #fff3cd;
    border: 1px solid #ffeeba;
    color: #856404;
}

.charts-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
    gap: 30px;
    margin-bottom: 40px;
}

.chart-container {
    background: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.chart-container h3 {
    margin-bottom: 20px;
    color: #333;
}

.chart-container canvas {
    max-height: 300px;
}

.detailed-analysis, .recommendations {
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    margin-bottom: 30px;
}

.benchmark-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

.benchmark-table th,
.benchmark-table td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

.benchmark-table th {
    background-color: #f8f9fa;
    font-weight: 600;
    color: #333;
}

.benchmark-table tr:hover {
    background-color: #f8f9fa;
}

.status-badge {
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: 600;
}

.status-good {
    background-color: #d4edda;
    color: #155724;
}

.status-warning {
    background-color: #fff3cd;
    color: #856404;
}

.status-poor {
    background-color: #f8d7da;
    color: #721c24;
}

.recommendations-list {
    list-style: none;
}

.recommendation-item {
    padding: 15px;
    margin-bottom: 10px;
    background: #f8f9fa;
    border-left: 4px solid #007bff;
    border-radius: 5px;
}

.dashboard-footer {
    text-align: center;
    padding: 20px;
    color: #666;
    border-top: 1px solid #ddd;
    margin-top: 40px;
}

@media (max-width: 768px) {
    .container {
        padding: 10px;
    }
    
    .dashboard-header h1 {
        font-size: 2rem;
    }
    
    .header-info {
        flex-direction: column;
        gap: 10px;
    }
    
    .charts-grid {
        grid-template-columns: 1fr;
    }
    
    .chart-container {
        min-width: 0;
    }
}
''';

    final cssFile = File(path.join(outputDir, 'dashboard.css'));
    await cssFile.writeAsString(cssContent);
  }

  /// Generate chart scripts
  Future<void> _generateChartScripts(PerformanceAnalysisResults results) async {
    final jsContent = '''
// Performance Dashboard Charts

document.addEventListener('DOMContentLoaded', function() {
    const chartColors = {
        primary: '#667eea',
        secondary: '#764ba2',
        success: '#28a745',
        warning: '#ffc107',
        danger: '#dc3545',
        info: '#17a2b8'
    };

    // Performance Trends Chart
    if (document.getElementById('performanceTrendsChart')) {
        const ctx = document.getElementById('performanceTrendsChart').getContext('2d');
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: ${json.encode(results.trends.map((t) => t.date).toList())},
                datasets: [{
                    label: 'Scan Time (ms)',
                    data: ${json.encode(results.trends.map((t) => t.scanTime).toList())},
                    borderColor: chartColors.primary,
                    backgroundColor: chartColors.primary + '20',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Time (ms)'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top'
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false
                    }
                }
            }
        });
    }

    // Memory Usage Trends Chart
    if (document.getElementById('memoryTrendsChart')) {
        const ctx = document.getElementById('memoryTrendsChart').getContext('2d');
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: ${json.encode(results.trends.map((t) => t.date).toList())},
                datasets: [{
                    label: 'Memory Usage (MB)',
                    data: ${json.encode(results.trends.map((t) => t.memoryUsage).toList())},
                    borderColor: chartColors.info,
                    backgroundColor: chartColors.info + '20',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Memory (MB)'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top'
                    }
                }
            }
        });
    }

    // Configuration Comparison Chart
    if (document.getElementById('configComparisonChart')) {
        const configData = ${json.encode(_getConfigurationComparisonData(results.benchmarks))};
        const ctx = document.getElementById('configComparisonChart').getContext('2d');
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: configData.labels,
                datasets: [{
                    label: 'Average Scan Time (ms)',
                    data: configData.scanTimes,
                    backgroundColor: chartColors.primary + '80',
                    borderColor: chartColors.primary,
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Time (ms)'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    // Throughput Chart
    if (document.getElementById('throughputChart')) {
        const ctx = document.getElementById('throughputChart').getContext('2d');
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: ${json.encode(results.trends.map((t) => t.date).toList())},
                datasets: [{
                    label: 'Throughput (files/sec)',
                    data: ${json.encode(results.trends.map((t) => t.throughput).toList())},
                    borderColor: chartColors.success,
                    backgroundColor: chartColors.success + '20',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Files per Second'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top'
                    }
                }
            }
        });
    }
});
''';

    final jsFile = File(path.join(outputDir, 'dashboard.js'));
    await jsFile.writeAsString(jsContent);
  }

  /// Generate supporting files
  Future<void> _generateSupportingFiles(PerformanceAnalysisResults results) async {
    // Generate data files for external tools
    await _generateCsvData(results);
    await _generateMetricsJson(results);
  }

  /// Generate CSV data for external analysis
  Future<void> _generateCsvData(PerformanceAnalysisResults results) async {
    final csvContent = StringBuffer();
    csvContent.writeln('Date,Configuration,ScanTime,MemoryUsage,Throughput,KeysFound');
    
    for (final benchmark in results.benchmarks) {
      csvContent.writeln('${benchmark.date},${benchmark.configuration},${benchmark.scanTime},${benchmark.memoryUsage},${benchmark.throughput},${benchmark.keysFound}');
    }
    
    final csvFile = File(path.join(outputDir, 'performance_data.csv'));
    await csvFile.writeAsString(csvContent.toString());
  }

  /// Generate metrics JSON for CI integration
  Future<void> _generateMetricsJson(PerformanceAnalysisResults results) async {
    final metricsData = {
      'performance_score': results.summary.overallScore,
      'average_scan_time': results.summary.averageScanTime,
      'average_memory_usage': results.summary.averageMemoryUsage,
      'regression_count': results.regressions.length,
      'latest_benchmark': results.benchmarks.isNotEmpty ? {
        'date': results.benchmarks.last.date,
        'configuration': results.benchmarks.last.configuration,
        'scan_time': results.benchmarks.last.scanTime,
        'memory_usage': results.benchmarks.last.memoryUsage,
        'throughput': results.benchmarks.last.throughput,
      } : null,
    };
    
    const encoder = JsonEncoder.withIndent('  ');
    final jsonContent = encoder.convert(metricsData);
    
    final metricsFile = File(path.join(outputDir, 'metrics.json'));
    await metricsFile.writeAsString(jsonContent);
  }

  /// Get configuration comparison data for charts
  Map<String, dynamic> _getConfigurationComparisonData(List<BenchmarkData> benchmarks) {
    final configGroups = <String, List<double>>{};
    
    for (final benchmark in benchmarks) {
      configGroups.putIfAbsent(benchmark.configuration, () => []).add(benchmark.scanTime);
    }
    
    final labels = configGroups.keys.toList();
    final scanTimes = labels.map((config) {
      final times = configGroups[config]!;
      return times.reduce((a, b) => a + b) / times.length;
    }).toList();
    
    return {
      'labels': labels,
      'scanTimes': scanTimes,
    };
  }

  /// Get score CSS class
  String _getScoreClass(double score) {
    if (score >= 80) return 'good';
    if (score >= 60) return 'warning';
    return 'poor';
  }

  /// Get score text description
  String _getScoreText(double score) {
    if (score >= 80) return '✅ Excellent';
    if (score >= 60) return '⚠️ Good';
    if (score >= 40) return '⚠️ Fair';
    return '❌ Poor';
  }

  /// Get performance status
  String _getPerformanceStatus(double scanTime) {
    if (scanTime < 1000) return 'Good';
    if (scanTime < 3000) return 'Warning';
    return 'Poor';
  }
}

/// Performance data analyzer
class PerformanceDataAnalyzer {
  final String inputDir;
  final int days;

  PerformanceDataAnalyzer(this.inputDir, this.days);

  /// Analyze performance data from input directory
  Future<PerformanceAnalysisResults> analyzePerformanceData() async {
    print('📈 Analyzing performance data...');

    final benchmarks = await _loadBenchmarkData();
    final trends = _calculateTrends(benchmarks);
    final regressions = _detectRegressions(benchmarks);
    final summary = _generateSummary(benchmarks, regressions);

    return PerformanceAnalysisResults(
      summary: summary,
      trends: trends,
      regressions: regressions,
      benchmarks: benchmarks,
    );
  }

  /// Load benchmark data from files
  Future<List<BenchmarkData>> _loadBenchmarkData() async {
    final benchmarks = <BenchmarkData>[];
    final inputDirectory = Directory(inputDir);

    if (!await inputDirectory.exists()) {
      print('⚠️ Input directory does not exist: $inputDir');
      return benchmarks;
    }

    await for (final entity in inputDirectory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final data = json.decode(content) as Map<String, dynamic>;
          
          final fileBenchmarks = _parseBenchmarkData(data, entity.path);
          benchmarks.addAll(fileBenchmarks);
        } catch (e) {
          print('⚠️ Error reading ${entity.path}: $e');
        }
      }
    }

    // Sort by date
    benchmarks.sort((a, b) => a.date.compareTo(b.date));
    
    // Filter by date range
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return benchmarks.where((b) => DateTime.parse(b.date).isAfter(cutoffDate)).toList();
  }

  /// Parse benchmark data from JSON
  List<BenchmarkData> _parseBenchmarkData(Map<String, dynamic> data, String filePath) {
    final benchmarks = <BenchmarkData>[];
    final timestamp = data['timestamp'] as String? ?? DateTime.now().toIso8601String();
    final results = data['results'] as Map<String, dynamic>? ?? {};

    // Extract scanning results
    final scanning = results['scanning'] as Map<String, dynamic>?;
    if (scanning != null) {
      final performanceResults = scanning['performance_results'] as Map<String, dynamic>?;
      if (performanceResults != null) {
        for (final entry in performanceResults.entries) {
          final config = entry.key;
          final metrics = entry.value as Map<String, dynamic>;
          
          benchmarks.add(BenchmarkData(
            date: timestamp.split('T')[0], // Extract date part
            configuration: config,
            scanTime: (metrics['total_time_ms'] as num?)?.toDouble() ?? 0,
            memoryUsage: double.tryParse(metrics['memory_used_mb']?.toString() ?? '0') ?? 0,
            throughput: double.tryParse(metrics['files_per_second']?.toString() ?? '0') ?? 0,
            keysFound: (metrics['keys_found'] as num?)?.toInt() ?? 0,
            filePath: filePath,
          ));
        }
      }
    }

    return benchmarks;
  }

  /// Calculate performance trends
  List<TrendData> _calculateTrends(List<BenchmarkData> benchmarks) {
    final dailyData = <String, List<BenchmarkData>>{};
    
    for (final benchmark in benchmarks) {
      dailyData.putIfAbsent(benchmark.date, () => []).add(benchmark);
    }

    final trends = <TrendData>[];
    for (final entry in dailyData.entries) {
      final date = entry.key;
      final dayBenchmarks = entry.value;
      
      final avgScanTime = dayBenchmarks.map((b) => b.scanTime).reduce((a, b) => a + b) / dayBenchmarks.length;
      final avgMemory = dayBenchmarks.map((b) => b.memoryUsage).reduce((a, b) => a + b) / dayBenchmarks.length;
      final avgThroughput = dayBenchmarks.map((b) => b.throughput).reduce((a, b) => a + b) / dayBenchmarks.length;
      
      trends.add(TrendData(
        date: date,
        scanTime: avgScanTime,
        memoryUsage: avgMemory,
        throughput: avgThroughput,
      ));
    }

    trends.sort((a, b) => a.date.compareTo(b.date));
    return trends;
  }

  /// Detect performance regressions
  List<PerformanceRegression> _detectRegressions(List<BenchmarkData> benchmarks) {
    final regressions = <PerformanceRegression>[];
    
    if (benchmarks.length < 2) return regressions;

    // Group by configuration
    final configGroups = <String, List<BenchmarkData>>{};
    for (final benchmark in benchmarks) {
      configGroups.putIfAbsent(benchmark.configuration, () => []).add(benchmark);
    }

    // Check each configuration for regressions
    for (final entry in configGroups.entries) {
      final config = entry.key;
      final configBenchmarks = entry.value;
      
      if (configBenchmarks.length < 2) continue;
      
      // Compare recent vs baseline (first 25% of data)
      final baselineCount = (configBenchmarks.length * 0.25).ceil();
      final recentCount = (configBenchmarks.length * 0.25).ceil();
      
      final baseline = configBenchmarks.take(baselineCount).toList();
      final recent = configBenchmarks.skip(configBenchmarks.length - recentCount).toList();
      
      final baselineAvgTime = baseline.map((b) => b.scanTime).reduce((a, b) => a + b) / baseline.length;
      final recentAvgTime = recent.map((b) => b.scanTime).reduce((a, b) => a + b) / recent.length;
      
      final timeRegression = ((recentAvgTime - baselineAvgTime) / baselineAvgTime) * 100;
      
      if (timeRegression > 20) { // 20% threshold
        regressions.add(PerformanceRegression(
          configuration: config,
          metric: 'scan_time',
          baselineValue: baselineAvgTime,
          currentValue: recentAvgTime,
          degradation: timeRegression,
        ));
      }
    }

    return regressions;
  }

  /// Generate performance summary
  PerformanceSummary _generateSummary(List<BenchmarkData> benchmarks, List<PerformanceRegression> regressions) {
    if (benchmarks.isEmpty) {
      return PerformanceSummary(
        overallScore: 0,
        averageScanTime: 0,
        averageMemoryUsage: 0,
        regressionCount: 0,
      );
    }

    final avgScanTime = benchmarks.map((b) => b.scanTime).reduce((a, b) => a + b) / benchmarks.length;
    final avgMemory = benchmarks.map((b) => b.memoryUsage).reduce((a, b) => a + b) / benchmarks.length;

    // Calculate overall performance score (0-100)
    double score = 100;
    
    // Penalize slow scan times
    if (avgScanTime > 3000) score -= 30;
    else if (avgScanTime > 1000) score -= 15;
    
    // Penalize high memory usage
    if (avgMemory > 500) score -= 20;
    else if (avgMemory > 200) score -= 10;
    
    // Penalize regressions
    score -= regressions.length * 10;
    
    score = max(0, score);

    return PerformanceSummary(
      overallScore: score,
      averageScanTime: avgScanTime,
      averageMemoryUsage: avgMemory,
      regressionCount: regressions.length,
    );
  }
}

/// Performance analysis results
class PerformanceAnalysisResults {
  final PerformanceSummary summary;
  final List<TrendData> trends;
  final List<PerformanceRegression> regressions;
  final List<BenchmarkData> benchmarks;

  PerformanceAnalysisResults({
    required this.summary,
    required this.trends,
    required this.regressions,
    required this.benchmarks,
  });
}

/// Performance summary data
class PerformanceSummary {
  final double overallScore;
  final double averageScanTime;
  final double averageMemoryUsage;
  final int regressionCount;

  PerformanceSummary({
    required this.overallScore,
    required this.averageScanTime,
    required this.averageMemoryUsage,
    required this.regressionCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'overall_score': overallScore,
      'average_scan_time': averageScanTime,
      'average_memory_usage': averageMemoryUsage,
      'regression_count': regressionCount,
    };
  }
}

/// Trend data point
class TrendData {
  final String date;
  final double scanTime;
  final double memoryUsage;
  final double throughput;

  TrendData({
    required this.date,
    required this.scanTime,
    required this.memoryUsage,
    required this.throughput,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'scan_time': scanTime,
      'memory_usage': memoryUsage,
      'throughput': throughput,
    };
  }
}

/// Performance regression data
class PerformanceRegression {
  final String configuration;
  final String metric;
  final double baselineValue;
  final double currentValue;
  final double degradation;

  PerformanceRegression({
    required this.configuration,
    required this.metric,
    required this.baselineValue,
    required this.currentValue,
    required this.degradation,
  });

  Map<String, dynamic> toMap() {
    return {
      'configuration': configuration,
      'metric': metric,
      'baseline_value': baselineValue,
      'current_value': currentValue,
      'degradation': degradation,
    };
  }
}

/// Benchmark data point
class BenchmarkData {
  final String date;
  final String configuration;
  final double scanTime;
  final double memoryUsage;
  final double throughput;
  final int keysFound;
  final String filePath;

  BenchmarkData({
    required this.date,
    required this.configuration,
    required this.scanTime,
    required this.memoryUsage,
    required this.throughput,
    required this.keysFound,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'configuration': configuration,
      'scan_time': scanTime,
      'memory_usage': memoryUsage,
      'throughput': throughput,
      'keys_found': keysFound,
      'file_path': filePath,
    };
  }
}