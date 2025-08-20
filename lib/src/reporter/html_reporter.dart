/// Premium HTML reporter with glassmorphism design
/// 
/// Creates self-contained HTML reports with interactive dashboard,
/// quality scoring, responsive design, dark/light themes, and canvas charts.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'base_reporter.dart';
import '../quality/quality_scorer.dart';
import '../stats/stats_calculator.dart';

/// Premium glassmorphism HTML reporter
class HtmlReporter extends BaseReporter {
  final bool darkTheme;
  final bool includeCharts;
  final bool responsive;

  HtmlReporter({
    this.darkTheme = false,
    this.includeCharts = true,
    this.responsive = true,
  });

  @override
  String generate(ReportData data) {
    // Generate quality analysis
    final quality = QualityScorer.calculateQuality(
      expectedKeys: data.expectedKeys,
      foundKeys: data.foundKeys,
      missingKeys: data.missingKeys,
      extraKeys: data.extraKeys,
      keyUsageCounts: data.keyUsageCounts,
      keyLocations: data.keyLocations,
      scannedFiles: data.scannedFiles,
      scanDuration: data.scanDuration,
    );

    // Generate statistics
    final stats = StatsCalculator.calculateStatistics(
      expectedKeys: data.expectedKeys,
      foundKeys: data.foundKeys,
      missingKeys: data.missingKeys,
      extraKeys: data.extraKeys,
      keyUsageCounts: data.keyUsageCounts,
      keyLocations: data.keyLocations,
      scannedFiles: data.scannedFiles,
      scanDuration: data.scanDuration,
    );

    // Analyze file coverage
    final fileCoverage = StatsCalculator.analyzeFileCoverage(
      keyLocations: data.keyLocations,
      scannedFiles: data.scannedFiles,
      foundKeys: data.foundKeys,
    );

    return _buildHtmlDocument(data, quality, stats, fileCoverage);
  }

  /// Build the complete HTML document
  String _buildHtmlDocument(ReportData data, QualityBreakdown quality, 
                           KeyStatistics stats, List<FileCoverageResult> fileCoverage) {
    final reportData = _prepareReportData(data, quality, stats, fileCoverage);
    
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flutter KeyCheck Report - ${data.projectPath}</title>
    ${_buildStyles()}
</head>
<body class="${darkTheme ? 'dark-theme' : 'light-theme'}" data-theme="${darkTheme ? 'dark' : 'light'}">
    <div class="app-container">
        ${_buildHeader(data, quality)}
        ${_buildDashboard(data, quality, stats)}
        ${_buildQualitySection(quality)}
        ${_buildIssuesSection(data)}
        ${_buildStatisticsSection(stats)}
        ${_buildFileCoverageSection(fileCoverage)}
        ${_buildRecommendationsSection(quality)}
        ${_buildFooter(data)}
    </div>
    
    <script>
        // Embed report data
        window.reportData = ${jsonEncode(reportData)};
        
        ${_buildJavaScript()}
    </script>
</body>
</html>
''';
  }

  /// Build CSS styles with glassmorphism design
  String _buildStyles() {
    return '''
<style>
/* Reset and base styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    /* Light theme colors */
    --bg-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    --bg-secondary: rgba(255, 255, 255, 0.25);
    --bg-glass: rgba(255, 255, 255, 0.15);
    --bg-card: rgba(255, 255, 255, 0.1);
    --text-primary: #2d3748;
    --text-secondary: #4a5568;
    --text-muted: #718096;
    --border-color: rgba(255, 255, 255, 0.18);
    --shadow-color: rgba(0, 0, 0, 0.1);
    --success-color: #48bb78;
    --warning-color: #ed8936;
    --error-color: #f56565;
    --info-color: #4299e1;
    
    /* Dark theme colors */
    --dark-bg-primary: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
    --dark-bg-secondary: rgba(45, 55, 72, 0.95);
    --dark-bg-glass: rgba(45, 55, 72, 0.25);
    --dark-bg-card: rgba(45, 55, 72, 0.15);
    --dark-text-primary: #f7fafc;
    --dark-text-secondary: #e2e8f0;
    --dark-text-muted: #a0aec0;
    --dark-border-color: rgba(255, 255, 255, 0.1);
    --dark-shadow-color: rgba(0, 0, 0, 0.3);
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    line-height: 1.6;
    color: var(--text-primary);
    background: var(--bg-primary);
    min-height: 100vh;
    transition: all 0.3s ease;
}

.dark-theme {
    --bg-primary: var(--dark-bg-primary);
    --bg-secondary: var(--dark-bg-secondary);
    --bg-glass: var(--dark-bg-glass);
    --bg-card: var(--dark-bg-card);
    --text-primary: var(--dark-text-primary);
    --text-secondary: var(--dark-text-secondary);
    --text-muted: var(--dark-text-muted);
    --border-color: var(--dark-border-color);
    --shadow-color: var(--dark-shadow-color);
}

.app-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

/* Glassmorphism components */
.glass-card {
    background: var(--bg-glass);
    backdrop-filter: blur(10px);
    border-radius: 20px;
    border: 1px solid var(--border-color);
    box-shadow: 0 8px 32px var(--shadow-color);
    padding: 24px;
    margin-bottom: 24px;
    transition: all 0.3s ease;
}

.glass-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 12px 40px var(--shadow-color);
}

.glass-header {
    background: var(--bg-card);
    backdrop-filter: blur(20px);
    border-radius: 25px;
    border: 1px solid var(--border-color);
    box-shadow: 0 8px 32px var(--shadow-color);
    padding: 32px;
    margin-bottom: 32px;
    text-align: center;
}

/* Header styles */
.header-title {
    font-size: 2.5em;
    font-weight: 700;
    margin-bottom: 16px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.header-subtitle {
    font-size: 1.2em;
    color: var(--text-secondary);
    margin-bottom: 24px;
}

.status-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 12px 24px;
    border-radius: 25px;
    font-weight: 600;
    font-size: 1.1em;
    backdrop-filter: blur(10px);
    border: 1px solid var(--border-color);
}

.status-passed {
    background: linear-gradient(135deg, rgba(72, 187, 120, 0.2), rgba(72, 187, 120, 0.1));
    color: var(--success-color);
}

.status-failed {
    background: linear-gradient(135deg, rgba(245, 101, 101, 0.2), rgba(245, 101, 101, 0.1));
    color: var(--error-color);
}

/* Dashboard grid */
.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 24px;
    margin-bottom: 32px;
}

.metric-card {
    background: var(--bg-glass);
    backdrop-filter: blur(15px);
    border-radius: 16px;
    border: 1px solid var(--border-color);
    padding: 24px;
    text-align: center;
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
}

.metric-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, #667eea, #764ba2);
    opacity: 0;
    transition: opacity 0.3s ease;
}

.metric-card:hover::before {
    opacity: 1;
}

.metric-value {
    font-size: 2.5em;
    font-weight: 700;
    margin-bottom: 8px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.metric-label {
    font-size: 0.95em;
    color: var(--text-secondary);
    font-weight: 500;
}

.metric-change {
    font-size: 0.85em;
    margin-top: 8px;
    padding: 4px 12px;
    border-radius: 12px;
    display: inline-block;
}

.change-positive {
    background: rgba(72, 187, 120, 0.1);
    color: var(--success-color);
}

.change-negative {
    background: rgba(245, 101, 101, 0.1);
    color: var(--error-color);
}

/* Progress bars */
.progress-container {
    margin: 16px 0;
}

.progress-label {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
    font-size: 0.9em;
    color: var(--text-secondary);
}

.progress-bar {
    height: 8px;
    background: var(--bg-card);
    border-radius: 10px;
    overflow: hidden;
    box-shadow: inset 0 2px 4px var(--shadow-color);
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #667eea, #764ba2);
    border-radius: 10px;
    transition: width 0.8s ease;
    position: relative;
}

.progress-fill::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
    animation: shimmer 2s infinite;
}

@keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
}

/* Quality gates */
.quality-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
}

.quality-gate {
    background: var(--bg-card);
    border-radius: 12px;
    padding: 16px;
    border: 1px solid var(--border-color);
    transition: all 0.3s ease;
}

.quality-gate:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 20px var(--shadow-color);
}

.gate-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
}

.gate-name {
    font-weight: 600;
    color: var(--text-primary);
}

.gate-status {
    font-size: 1.2em;
}

.gate-score {
    font-size: 1.5em;
    font-weight: 700;
    text-align: center;
    margin-bottom: 8px;
}

/* Tables */
.data-table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 4px 20px var(--shadow-color);
}

.data-table th,
.data-table td {
    padding: 16px;
    text-align: left;
    border-bottom: 1px solid var(--border-color);
}

.data-table th {
    background: var(--bg-card);
    font-weight: 600;
    color: var(--text-primary);
}

.data-table tbody tr {
    background: var(--bg-glass);
    transition: background-color 0.2s ease;
}

.data-table tbody tr:hover {
    background: var(--bg-card);
}

/* Charts container */
.chart-container {
    position: relative;
    height: 300px;
    margin: 24px 0;
    padding: 16px;
    background: var(--bg-card);
    border-radius: 12px;
    border: 1px solid var(--border-color);
}

.chart-canvas {
    width: 100%;
    height: 100%;
}

/* Issues styling */
.issue-item {
    background: var(--bg-card);
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
    border-left: 4px solid var(--border-color);
    transition: all 0.3s ease;
}

.issue-critical {
    border-left-color: var(--error-color);
    background: rgba(245, 101, 101, 0.05);
}

.issue-warning {
    border-left-color: var(--warning-color);
    background: rgba(237, 137, 54, 0.05);
}

.issue-info {
    border-left-color: var(--info-color);
    background: rgba(66, 153, 225, 0.05);
}

.issue-header {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 600;
    margin-bottom: 8px;
}

.issue-description {
    color: var(--text-secondary);
    font-size: 0.9em;
}

/* Recommendations */
.recommendation-item {
    background: var(--bg-card);
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
    border-left: 4px solid var(--info-color);
    transition: all 0.3s ease;
}

.recommendation-item:hover {
    transform: translateX(4px);
}

/* Footer */
.footer {
    text-align: center;
    padding: 32px;
    margin-top: 48px;
    background: var(--bg-glass);
    backdrop-filter: blur(10px);
    border-radius: 20px;
    border: 1px solid var(--border-color);
}

/* Theme toggle */
.theme-toggle {
    position: fixed;
    top: 24px;
    right: 24px;
    background: var(--bg-glass);
    backdrop-filter: blur(10px);
    border: 1px solid var(--border-color);
    border-radius: 50%;
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.3s ease;
    z-index: 1000;
}

.theme-toggle:hover {
    transform: scale(1.1);
    box-shadow: 0 4px 20px var(--shadow-color);
}

/* Responsive design */
@media (max-width: 768px) {
    .app-container {
        padding: 16px;
    }
    
    .dashboard-grid {
        grid-template-columns: 1fr;
        gap: 16px;
    }
    
    .header-title {
        font-size: 2em;
    }
    
    .glass-card {
        padding: 16px;
    }
    
    .quality-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 480px) {
    .metric-value {
        font-size: 2em;
    }
    
    .data-table th,
    .data-table td {
        padding: 12px 8px;
        font-size: 0.9em;
    }
}

/* Utility classes */
.text-success { color: var(--success-color); }
.text-warning { color: var(--warning-color); }
.text-error { color: var(--error-color); }
.text-info { color: var(--info-color); }
.text-muted { color: var(--text-muted); }

.mb-1 { margin-bottom: 0.5rem; }
.mb-2 { margin-bottom: 1rem; }
.mb-3 { margin-bottom: 1.5rem; }
.mb-4 { margin-bottom: 2rem; }

.text-center { text-align: center; }
.text-right { text-align: right; }

.d-flex { display: flex; }
.align-items-center { align-items: center; }
.justify-content-between { justify-content: space-between; }
.gap-2 { gap: 0.5rem; }
.gap-3 { gap: 1rem; }
</style>
''';
  }

  /// Build the header section
  String _buildHeader(ReportData data, QualityBreakdown quality) {
    final status = data.passed ? 'passed' : 'failed';
    final statusIcon = data.passed ? '✅' : '❌';
    final statusText = data.passed ? 'All Checks Passed' : 'Issues Found';
    
    return '''
<div class="glass-header">
    <div class="theme-toggle" onclick="toggleTheme()">
        <span id="theme-icon">🌙</span>
    </div>
    
    <h1 class="header-title">🔑 Flutter KeyCheck Report</h1>
    <p class="header-subtitle">${_escapeHtml(data.projectPath)}</p>
    <p class="text-muted mb-3">Generated on ${data.timestamp.toIso8601String()}</p>
    
    <div class="status-badge status-$status">
        <span>$statusIcon</span>
        <span>$statusText</span>
    </div>
    
    <div class="progress-container">
        <div class="progress-label">
            <span>Overall Quality Score</span>
            <span>${quality.overall.toStringAsFixed(1)}/100</span>
        </div>
        <div class="progress-bar">
            <div class="progress-fill" style="width: ${quality.overall}%"></div>
        </div>
    </div>
</div>
''';
  }

  /// Build the dashboard section
  String _buildDashboard(ReportData data, QualityBreakdown quality, KeyStatistics stats) {
    return '''
<div class="glass-card">
    <h2 class="mb-3">📊 Dashboard Overview</h2>
    
    <div class="dashboard-grid">
        <div class="metric-card">
            <div class="metric-value">${data.coverage.toStringAsFixed(1)}%</div>
            <div class="metric-label">Test Coverage</div>
            <div class="metric-change ${data.coverage >= 80 ? 'change-positive' : 'change-negative'}">
                ${data.coverage >= 80 ? '📈 Good' : '📉 Needs Improvement'}
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">${data.expectedKeys.length}</div>
            <div class="metric-label">Expected Keys</div>
            <div class="metric-change change-positive">📋 Total Target</div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">${data.foundKeys.length}</div>
            <div class="metric-label">Found Keys</div>
            <div class="metric-change ${data.foundKeys.length >= data.expectedKeys.length ? 'change-positive' : 'change-negative'}">
                ${data.foundKeys.length >= data.expectedKeys.length ? '✅ Complete' : '⚠️ Partial'}
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">${data.missingKeys.length}</div>
            <div class="metric-label">Missing Keys</div>
            <div class="metric-change ${data.missingKeys.isEmpty ? 'change-positive' : 'change-negative'}">
                ${data.missingKeys.isEmpty ? '🎯 Perfect' : '🔍 Action Needed'}
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">${quality.overall.toStringAsFixed(0)}</div>
            <div class="metric-label">Quality Score</div>
            <div class="metric-change ${quality.overall >= 80 ? 'change-positive' : quality.overall >= 60 ? 'change-warning' : 'change-negative'}">
                ${_getQualityBadge(quality.overall)}
            </div>
        </div>
        
        <div class="metric-card">
            <div class="metric-value">${data.scanDuration?.inMilliseconds ?? 0}ms</div>
            <div class="metric-label">Scan Time</div>
            <div class="metric-change change-positive">⚡ Performance</div>
        </div>
    </div>
</div>
''';
  }

  /// Build quality gates section
  String _buildQualitySection(QualityBreakdown quality) {
    final gates = [
      ('Coverage', quality.coverage, 80.0, '🎯'),
      ('Organization', quality.organization, 70.0, '📁'),
      ('Consistency', quality.consistency, 75.0, '🔄'),
      ('Efficiency', quality.efficiency, 70.0, '⚡'),
      ('Maintainability', quality.maintainability, 65.0, '🔧'),
    ];

    final gateItems = gates.map((gate) {
      final name = gate.$1;
      final score = gate.$2;
      final threshold = gate.$3;
      final icon = gate.$4;
      final passed = score >= threshold;
      final statusIcon = passed ? '✅' : '❌';
      
      return '''
<div class="quality-gate">
    <div class="gate-header">
        <span class="gate-name">$icon $name</span>
        <span class="gate-status">$statusIcon</span>
    </div>
    <div class="gate-score ${passed ? 'text-success' : 'text-error'}">
        ${score.toStringAsFixed(1)}%
    </div>
    <div class="progress-bar">
        <div class="progress-fill" style="width: ${math.min(score, 100)}%"></div>
    </div>
    <div class="text-muted text-center" style="font-size: 0.8em; margin-top: 8px;">
        Threshold: ${threshold.toStringAsFixed(0)}%
    </div>
</div>
''';
    }).join('\n');

    return '''
<div class="glass-card">
    <h2 class="mb-3">🎯 Quality Gates</h2>
    <div class="quality-grid">
        $gateItems
    </div>
</div>
''';
  }

  /// Build issues section
  String _buildIssuesSection(ReportData data) {
    if (data.missingKeys.isEmpty && data.extraKeys.isEmpty) {
      return '''
<div class="glass-card">
    <h2 class="mb-3">✨ Issues Analysis</h2>
    <div class="text-center">
        <div style="font-size: 4em; margin-bottom: 16px;">🎉</div>
        <h3 class="text-success">No Issues Found!</h3>
        <p class="text-muted">All keys are properly organized and accounted for.</p>
    </div>
</div>
''';
    }

    final issues = StringBuffer();
    
    // Missing keys
    if (data.missingKeys.isNotEmpty) {
      issues.writeln('<h3 class="text-error mb-2">🔴 Critical: Missing Keys (${data.missingKeys.length})</h3>');
      for (final key in data.missingKeys.take(10)) {
        issues.writeln('''
<div class="issue-item issue-critical">
    <div class="issue-header">
        <span>❌</span>
        <span>${_escapeHtml(key)}</span>
    </div>
    <div class="issue-description">This key is expected but not found in the codebase</div>
</div>
''');
      }
      if (data.missingKeys.length > 10) {
        issues.writeln('<p class="text-muted">... and ${data.missingKeys.length - 10} more missing keys</p>');
      }
    }
    
    // Extra keys
    if (data.extraKeys.isNotEmpty) {
      issues.writeln('<h3 class="text-warning mb-2">🟡 Warning: Extra Keys (${data.extraKeys.length})</h3>');
      for (final key in data.extraKeys.take(10)) {
        issues.writeln('''
<div class="issue-item issue-warning">
    <div class="issue-header">
        <span>⚠️</span>
        <span>${_escapeHtml(key)}</span>
    </div>
    <div class="issue-description">This key was found but is not in the expected keys list</div>
</div>
''');
      }
      if (data.extraKeys.length > 10) {
        issues.writeln('<p class="text-muted">... and ${data.extraKeys.length - 10} more extra keys</p>');
      }
    }

    return '''
<div class="glass-card">
    <h2 class="mb-3">🚨 Issues Analysis</h2>
    $issues
</div>
''';
  }

  /// Build statistics section
  String _buildStatisticsSection(KeyStatistics stats) {
    return '''
<div class="glass-card">
    <h2 class="mb-3">📈 Detailed Statistics</h2>
    
    <div class="mb-4">
        <h3 class="mb-2">Coverage Analysis</h3>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Metric</th>
                    <th>Value</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Coverage Percentage</td>
                    <td>${stats.coverage['percentage']?.toStringAsFixed(1) ?? 0}%</td>
                    <td class="${_getCoverageStatusClass(stats.coverage['percentage'] ?? 0)}">${_getCoverageStatusText(stats.coverage['percentage'] ?? 0)}</td>
                </tr>
                <tr>
                    <td>Files Scanned</td>
                    <td>${stats.coverage['filesScanned'] ?? 0}</td>
                    <td class="text-info">📄 Analyzed</td>
                </tr>
                <tr>
                    <td>Files with Keys</td>
                    <td>${stats.coverage['filesWithKeys'] ?? 0}</td>
                    <td class="text-info">🔑 Active</td>
                </tr>
            </tbody>
        </table>
    </div>

    ${includeCharts ? '''
    <div class="mb-4">
        <h3 class="mb-2">Key Distribution</h3>
        <div class="chart-container">
            <canvas id="distributionChart" class="chart-canvas"></canvas>
        </div>
    </div>
    ''' : ''}

    <div class="mb-4">
        <h3 class="mb-2">Performance Metrics</h3>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Metric</th>
                    <th>Value</th>
                    <th>Rating</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Scan Time</td>
                    <td>${stats.performance['scanTimeMs'] ?? 0}ms</td>
                    <td class="${_getPerformanceStatusClass(stats.performance['scanTimeMs'] ?? 0)}">${_getPerformanceStatusText(stats.performance['scanTimeMs'] ?? 0)}</td>
                </tr>
                <tr>
                    <td>Keys per Second</td>
                    <td>${stats.performance['keysPerSecond']?.toStringAsFixed(1) ?? 0}</td>
                    <td class="text-info">⚡ Speed</td>
                </tr>
                <tr>
                    <td>Performance Score</td>
                    <td>${stats.performance['score']?.toStringAsFixed(1) ?? 0}/100</td>
                    <td class="${_getQualityStatusClass(stats.performance['score'] ?? 0)}">${_getQualityStatusText(stats.performance['score'] ?? 0)}</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>
''';
  }

  /// Build file coverage section
  String _buildFileCoverageSection(List<FileCoverageResult> fileCoverage) {
    if (fileCoverage.isEmpty) {
      return '';
    }

    final rows = fileCoverage.take(10).map((file) {
      final coverage = file.coverageScore.toStringAsFixed(1);
      final statusClass = _getCoverageStatusClass(file.coverageScore);
      final statusText = _getCoverageStatusText(file.coverageScore);
      final fileType = file.isTestFile ? '🧪 Test' : (file.hasKeyConstants ? '🔑 Keys' : '📄 Source');
      
      return '''
<tr>
    <td>${_escapeHtml(file.filePath)}</td>
    <td>${file.keyCount}</td>
    <td>$coverage%</td>
    <td class="$statusClass">$statusText</td>
    <td>$fileType</td>
</tr>
''';
    }).join('\n');

    return '''
<div class="glass-card">
    <h2 class="mb-3">📁 File Coverage Analysis</h2>
    
    <table class="data-table">
        <thead>
            <tr>
                <th>File Path</th>
                <th>Key Count</th>
                <th>Coverage</th>
                <th>Status</th>
                <th>Type</th>
            </tr>
        </thead>
        <tbody>
            $rows
        </tbody>
    </table>
    
    ${fileCoverage.length > 10 ? '<p class="text-muted text-center">... and ${fileCoverage.length - 10} more files</p>' : ''}
</div>
''';
  }

  /// Build recommendations section
  String _buildRecommendationsSection(QualityBreakdown quality) {
    if (quality.recommendations.isEmpty) {
      return '';
    }

    final recommendations = quality.recommendations.map((rec) => '''
<div class="recommendation-item">
    <div class="d-flex align-items-center gap-2">
        <span>💡</span>
        <span>$rec</span>
    </div>
</div>
''').join('\n');

    return '''
<div class="glass-card">
    <h2 class="mb-3">💡 Recommendations</h2>
    $recommendations
</div>
''';
  }

  /// Build footer section
  String _buildFooter(ReportData data) {
    return '''
<div class="footer">
    <p class="text-muted">
        Report generated by <strong>Flutter KeyCheck v3.x</strong><br>
        ${data.timestamp.toIso8601String()}
    </p>
</div>
''';
  }

  /// Build JavaScript for interactivity
  String _buildJavaScript() {
    return '''
// Theme toggle functionality
function toggleTheme() {
    const body = document.body;
    const icon = document.getElementById('theme-icon');
    const currentTheme = body.getAttribute('data-theme');
    
    if (currentTheme === 'dark') {
        body.className = 'light-theme';
        body.setAttribute('data-theme', 'light');
        icon.textContent = '🌙';
    } else {
        body.className = 'dark-theme';
        body.setAttribute('data-theme', 'dark');
        icon.textContent = '☀️';
    }
}

// Chart rendering functionality
function initCharts() {
    const distributionCanvas = document.getElementById('distributionChart');
    if (!distributionCanvas) return;
    
    const ctx = distributionCanvas.getContext('2d');
    const data = window.reportData;
    
    if (!data || !data.stats || !data.stats.distribution) return;
    
    drawDistributionChart(ctx, data.stats.distribution);
}

function drawDistributionChart(ctx, distribution) {
    const canvas = ctx.canvas;
    const width = canvas.width = canvas.offsetWidth;
    const height = canvas.height = canvas.offsetHeight;
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Chart data
    const categories = Object.keys(distribution.byCategory || {});
    const values = Object.values(distribution.byCategory || {});
    
    if (categories.length === 0) {
        ctx.fillStyle = '#666';
        ctx.font = '16px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('No data available', width / 2, height / 2);
        return;
    }
    
    // Colors for chart segments
    const colors = [
        '#667eea', '#764ba2', '#f093fb', '#f5576c',
        '#4facfe', '#00f2fe', '#43e97b', '#38f9d7',
        '#ffecd2', '#fcb69f', '#a8edea', '#fed6e3'
    ];
    
    // Calculate total
    const total = values.reduce((sum, val) => sum + val, 0);
    
    // Draw pie chart
    const centerX = width / 2;
    const centerY = height / 2;
    const radius = Math.min(width, height) / 3;
    
    let currentAngle = -Math.PI / 2;
    
    categories.forEach((category, index) => {
        const value = values[index];
        const angle = (value / total) * 2 * Math.PI;
        
        // Draw slice
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.arc(centerX, centerY, radius, currentAngle, currentAngle + angle);
        ctx.closePath();
        
        ctx.fillStyle = colors[index % colors.length];
        ctx.fill();
        
        // Draw label
        const labelAngle = currentAngle + angle / 2;
        const labelX = centerX + Math.cos(labelAngle) * (radius + 30);
        const labelY = centerY + Math.sin(labelAngle) * (radius + 30);
        
        ctx.fillStyle = '#333';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(category, labelX, labelY);
        ctx.fillText(\`\${value}\`, labelX, labelY + 15);
        
        currentAngle += angle;
    });
}

// Initialize animations
function initAnimations() {
    // Animate progress bars
    const progressBars = document.querySelectorAll('.progress-fill');
    progressBars.forEach(bar => {
        const width = bar.style.width;
        bar.style.width = '0%';
        setTimeout(() => {
            bar.style.width = width;
        }, 500);
    });
    
    // Animate metric cards
    const metricCards = document.querySelectorAll('.metric-card');
    metricCards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        setTimeout(() => {
            card.style.transition = 'all 0.6s ease';
            card.style.opacity = '1';
            card.style.transform = 'translateY(0)';
        }, index * 100);
    });
}

// Export functionality
function exportReport(format) {
    if (format === 'json') {
        const data = JSON.stringify(window.reportData, null, 2);
        downloadFile(data, 'flutter-keycheck-report.json', 'application/json');
    } else if (format === 'csv') {
        // Convert to CSV format
        const csv = convertToCSV(window.reportData);
        downloadFile(csv, 'flutter-keycheck-report.csv', 'text/csv');
    }
}

function downloadFile(content, filename, contentType) {
    const blob = new Blob([content], { type: contentType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function convertToCSV(data) {
    // Simple CSV conversion for basic metrics
    let csv = 'Metric,Value\\n';
    csv += \`Coverage,\${data.coverage}%\\n\`;
    csv += \`Expected Keys,\${data.expectedKeys}\\n\`;
    csv += \`Found Keys,\${data.foundKeys}\\n\`;
    csv += \`Missing Keys,\${data.missingKeys}\\n\`;
    csv += \`Extra Keys,\${data.extraKeys}\\n\`;
    return csv;
}

// Initialize everything when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initAnimations();
    setTimeout(initCharts, 100);
});

// Handle window resize for responsive charts
window.addEventListener('resize', function() {
    setTimeout(initCharts, 100);
});
''';
  }

  /// Prepare structured data for JavaScript
  Map<String, dynamic> _prepareReportData(ReportData data, QualityBreakdown quality, 
                                          KeyStatistics stats, List<FileCoverageResult> fileCoverage) {
    return {
      'timestamp': data.timestamp.toIso8601String(),
      'projectPath': data.projectPath,
      'coverage': data.coverage,
      'expectedKeys': data.expectedKeys.length,
      'foundKeys': data.foundKeys.length,
      'missingKeys': data.missingKeys.length,
      'extraKeys': data.extraKeys.length,
      'passed': data.passed,
      'quality': quality.toJson(),
      'stats': stats.toJson(),
      'fileCoverage': fileCoverage.map((f) => f.toJson()).toList(),
      'scanDuration': data.scanDuration?.inMilliseconds,
    };
  }

  /// Helper methods for status classes and text
  String _getCoverageStatusClass(double coverage) {
    if (coverage >= 90) return 'text-success';
    if (coverage >= 80) return 'text-info';
    if (coverage >= 70) return 'text-warning';
    return 'text-error';
  }

  String _getCoverageStatusText(double coverage) {
    if (coverage >= 90) return '🎯 Excellent';
    if (coverage >= 80) return '👍 Good';
    if (coverage >= 70) return '👌 OK';
    return '🔧 Poor';
  }

  String _getPerformanceStatusClass(int timeMs) {
    if (timeMs < 100) return 'text-success';
    if (timeMs < 500) return 'text-info';
    if (timeMs < 2000) return 'text-warning';
    return 'text-error';
  }

  String _getPerformanceStatusText(int timeMs) {
    if (timeMs < 100) return '⚡ Fast';
    if (timeMs < 500) return '👍 Good';
    if (timeMs < 2000) return '👌 OK';
    return '🐌 Slow';
  }

  String _getQualityStatusClass(double score) {
    if (score >= 80) return 'text-success';
    if (score >= 70) return 'text-info';
    if (score >= 60) return 'text-warning';
    return 'text-error';
  }

  String _getQualityStatusText(double score) {
    if (score >= 80) return '🏆 Excellent';
    if (score >= 70) return '⭐ Good';
    if (score >= 60) return '👍 OK';
    return '🔧 Poor';
  }

  String _getQualityBadge(double score) {
    if (score >= 90) return '🏆 Excellent';
    if (score >= 80) return '⭐ Very Good';
    if (score >= 70) return '👍 Good';
    if (score >= 60) return '👌 Fair';
    return '🔧 Needs Work';
  }

  /// Escape HTML characters
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  @override
  String get fileExtension => 'html';

  @override
  String get reportType => 'Premium HTML';
}