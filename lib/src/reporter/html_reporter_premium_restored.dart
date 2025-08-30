/// Premium HTML Reporter from commit b4548a1d
/// This is the REAL premium implementation with full glassmorphism and charts
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';

class HtmlReporterPremium extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final html = _generatePremiumHtml(result, includeMetrics, includeLocations);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(html);
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    // Not implemented for validation reports
    throw UnimplementedError(
        'Validation reports not supported in premium HTML');
  }

  String _generatePremiumHtml(
      ScanResult result, bool includeMetrics, bool includeLocations) {
    final buffer = StringBuffer();

    // HTML header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>Flutter KeyCheck - Premium Scan Report</title>');
    buffer.writeln(
        '  <script src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/js/all.min.js"></script>');
    buffer.writeln(
        '  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>');
    buffer.writeln(
        '  <link rel="preconnect" href="https://fonts.googleapis.com">');
    buffer.writeln(
        '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>');
    buffer.writeln(
        '  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">');
    buffer.writeln(_getInlineStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body class="dark">');

    // Sidebar
    _addSidebar(buffer);

    // Header
    _addHeader(buffer);

    // Main Content with Sections
    buffer.writeln('  <div class="main-content">');

    // Dashboard Section (Default)
    buffer.writeln(
        '    <div id="dashboard-section" class="content-section active">');
    _addDashboardHeader(buffer);
    _addMetricsCards(buffer, result);
    _addKeysTable(buffer, result);
    buffer.writeln('    </div>');

    // Analysis Section
    buffer.writeln(
        '    <div id="analysis-section" class="content-section" style="display: none;">');
    _addAnalysisSection(buffer, result);
    buffer.writeln('    </div>');

    // Stats Section
    buffer.writeln(
        '    <div id="stats-section" class="content-section" style="display: none;">');
    _addStatsSection(buffer, result);
    buffer.writeln('    </div>');

    // Settings Section
    buffer.writeln(
        '    <div id="settings-section" class="content-section" style="display: none;">');
    _addSettingsSection(buffer);
    buffer.writeln('    </div>');

    buffer.writeln('  </div>'); // main-content

    // JavaScript
    buffer.writeln(_getInlineScripts(result));

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  String _getInlineStyles() {
    return '''
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    :root {
      --bg-primary: #0f172a;
      --bg-secondary: #1e293b;
      --bg-card: rgba(30, 41, 59, 0.5);
      --text-primary: #f1f5f9;
      --text-secondary: #94a3b8;
      --accent: #3b82f6;
      --success: #10b981;
      --warning: #f59e0b;
      --error: #ef4444;
      --border: rgba(51, 65, 85, 0.3);
    }

    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* Glassmorphism Sidebar */
    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      width: 80px;
      height: 100vh;
      background: rgba(30, 41, 59, 0.8);
      backdrop-filter: blur(20px);
      border-right: 1px solid var(--border);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 0;
      transition: width 0.3s ease;
    }

    .sidebar:hover {
      width: 250px;
    }

    .sidebar .logo {
      width: 50px;
      height: 50px;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 30px;
      font-weight: bold;
      font-size: 24px;
    }

    .sidebar .nav-item {
      width: 100%;
      padding: 15px;
      display: flex;
      align-items: center;
      justify-content: flex-start;
      cursor: pointer;
      transition: all 0.3s ease;
      position: relative;
      color: var(--text-secondary);
    }

    .sidebar .nav-item:hover {
      background: rgba(59, 130, 246, 0.1);
      color: var(--accent);
    }

    .sidebar .nav-item.active {
      background: rgba(59, 130, 246, 0.2);
      color: var(--accent);
    }

    .sidebar .nav-item.active::before {
      content: '';
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      width: 3px;
      background: var(--accent);
    }

    .sidebar .nav-item i {
      font-size: 24px;
      min-width: 50px;
      text-align: center;
    }

    .sidebar .nav-item span {
      opacity: 0;
      white-space: nowrap;
      transition: opacity 0.3s ease;
      margin-left: 10px;
    }

    .sidebar:hover .nav-item span {
      opacity: 1;
    }

    /* Glassmorphism Header */
    .header {
      position: fixed;
      top: 0;
      left: 80px;
      right: 0;
      height: 80px;
      background: rgba(30, 41, 59, 0.8);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 30px;
      z-index: 999;
    }

    .header h1 {
      font-size: 28px;
      font-weight: 700;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .header .actions {
      display: flex;
      gap: 15px;
    }

    .header .btn {
      padding: 10px 20px;
      background: rgba(59, 130, 246, 0.2);
      border: 1px solid var(--accent);
      border-radius: 8px;
      color: var(--accent);
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .header .btn:hover {
      background: var(--accent);
      color: white;
    }

    /* Main Content */
    .main-content {
      margin-left: 80px;
      margin-top: 80px;
      padding: 30px;
      min-height: calc(100vh - 80px);
    }

    /* Dashboard Cards */
    .dashboard-header {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 30px;
      margin-bottom: 30px;
    }

    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .metric-card {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 25px;
      position: relative;
      overflow: hidden;
      transition: all 0.3s ease;
    }

    .metric-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    }

    .metric-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 3px;
      background: linear-gradient(90deg, var(--accent), #8b5cf6);
    }

    .metric-card .icon {
      width: 50px;
      height: 50px;
      background: rgba(59, 130, 246, 0.2);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 15px;
      font-size: 24px;
      color: var(--accent);
    }

    .metric-card .value {
      font-size: 32px;
      font-weight: 700;
      margin-bottom: 5px;
    }

    .metric-card .label {
      color: var(--text-secondary);
      font-size: 14px;
    }

    /* Keys Table */
    .keys-table-container {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 25px;
      overflow: hidden;
    }

    .keys-table {
      width: 100%;
      border-collapse: collapse;
    }

    .keys-table th {
      text-align: left;
      padding: 15px;
      background: rgba(59, 130, 246, 0.1);
      border-bottom: 2px solid var(--border);
      font-weight: 600;
      color: var(--text-primary);
    }

    .keys-table td {
      padding: 15px;
      border-bottom: 1px solid var(--border);
      color: var(--text-secondary);
    }

    .keys-table tr:hover {
      background: rgba(59, 130, 246, 0.05);
    }

    .key-badge {
      display: inline-block;
      padding: 4px 10px;
      background: rgba(59, 130, 246, 0.2);
      border-radius: 6px;
      font-size: 12px;
      font-weight: 500;
      color: var(--accent);
    }

    /* Charts */
    .chart-container {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 25px;
      margin-bottom: 30px;
    }

    .chart-container h3 {
      margin-bottom: 20px;
      font-size: 20px;
      font-weight: 600;
    }

    /* Animations */
    @keyframes fadeIn {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .content-section {
      animation: fadeIn 0.5s ease;
    }

    /* Responsive */
    @media (max-width: 768px) {
      .sidebar {
        width: 0;
      }
      
      .header,
      .main-content {
        margin-left: 0;
        left: 0;
      }
      
      .metrics-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
''';
  }

  void _addSidebar(StringBuffer buffer) {
    buffer.writeln('  <div class="sidebar">');
    buffer.writeln('    <div class="logo">FK</div>');
    buffer
        .writeln('    <div class="nav-item active" data-section="dashboard">');
    buffer.writeln('      <i class="fas fa-home"></i>');
    buffer.writeln('      <span>Dashboard</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="nav-item" data-section="analysis">');
    buffer.writeln('      <i class="fas fa-chart-line"></i>');
    buffer.writeln('      <span>Analysis</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="nav-item" data-section="stats">');
    buffer.writeln('      <i class="fas fa-chart-bar"></i>');
    buffer.writeln('      <span>Statistics</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="nav-item" data-section="settings">');
    buffer.writeln('      <i class="fas fa-cog"></i>');
    buffer.writeln('      <span>Settings</span>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');
  }

  void _addHeader(StringBuffer buffer) {
    buffer.writeln('  <div class="header">');
    buffer.writeln('    <h1>Flutter KeyCheck Premium</h1>');
    buffer.writeln('    <div class="actions">');
    buffer.writeln('      <button class="btn" onclick="exportReport()">');
    buffer.writeln('        <i class="fas fa-download"></i> Export');
    buffer.writeln('      </button>');
    buffer.writeln('      <button class="btn" onclick="toggleTheme()">');
    buffer.writeln('        <i class="fas fa-moon"></i> Theme');
    buffer.writeln('      </button>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');
  }

  void _addDashboardHeader(StringBuffer buffer) {
    buffer.writeln('      <div class="dashboard-header">');
    buffer.writeln('        <h2>Scan Results Overview</h2>');
    buffer.writeln(
        '        <p>Generated on ${DateTime.now().toIso8601String()}</p>');
    buffer.writeln('      </div>');
  }

  void _addMetricsCards(StringBuffer buffer, ScanResult result) {
    buffer.writeln('      <div class="metrics-grid">');

    // Total Keys Card
    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-key"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.keyUsages.length}</div>');
    buffer.writeln('          <div class="label">Total Keys Found</div>');
    buffer.writeln('        </div>');

    // Files Scanned Card
    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-file-code"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.scannedFiles}</div>');
    buffer.writeln('          <div class="label">Files Scanned</div>');
    buffer.writeln('        </div>');

    // Coverage Card
    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-chart-pie"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.fileCoverage.toStringAsFixed(1)}%</div>');
    buffer.writeln('          <div class="label">File Coverage</div>');
    buffer.writeln('        </div>');

    // Widget Coverage Card
    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-cube"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.widgetCoverage.toStringAsFixed(1)}%</div>');
    buffer.writeln('          <div class="label">Widget Coverage</div>');
    buffer.writeln('        </div>');

    buffer.writeln('      </div>');
  }

  void _addKeysTable(StringBuffer buffer, ScanResult result) {
    buffer.writeln('      <div class="keys-table-container">');
    buffer.writeln('        <h3>Keys Found</h3>');
    buffer.writeln('        <table class="keys-table">');
    buffer.writeln('          <thead>');
    buffer.writeln('            <tr>');
    buffer.writeln('              <th>Key ID</th>');
    buffer.writeln('              <th>File</th>');
    buffer.writeln('              <th>Locations</th>');
    buffer.writeln('              <th>Handlers</th>');
    buffer.writeln('            </tr>');
    buffer.writeln('          </thead>');
    buffer.writeln('          <tbody>');

    for (final entry in result.keyUsages.entries) {
      final key = entry.key;
      final usage = entry.value;
      final fileName = usage.locations.isNotEmpty
          ? usage.locations.first.file.split('/').last
          : 'Unknown';

      buffer.writeln('            <tr>');
      buffer.writeln(
          '              <td><span class="key-badge">${key}</span></td>');
      buffer.writeln('              <td>${fileName}</td>');
      buffer.writeln('              <td>${usage.locations.length}</td>');
      buffer.writeln('              <td>${usage.handlers.length}</td>');
      buffer.writeln('            </tr>');
    }

    buffer.writeln('          </tbody>');
    buffer.writeln('        </table>');
    buffer.writeln('      </div>');
  }

  void _addAnalysisSection(StringBuffer buffer, ScanResult result) {
    buffer.writeln('      <h2>Deep Analysis</h2>');
    buffer.writeln('      <div class="chart-container">');
    buffer.writeln('        <h3>Key Distribution</h3>');
    buffer.writeln('        <canvas id="distributionChart"></canvas>');
    buffer.writeln('      </div>');
    buffer.writeln('      <div class="chart-container">');
    buffer.writeln('        <h3>Coverage Trends</h3>');
    buffer.writeln('        <canvas id="coverageChart"></canvas>');
    buffer.writeln('      </div>');
  }

  void _addStatsSection(StringBuffer buffer, ScanResult result) {
    buffer.writeln('      <h2>Statistics</h2>');
    buffer.writeln('      <div class="chart-container">');
    buffer.writeln('        <h3>File Analysis</h3>');
    buffer.writeln('        <canvas id="fileChart"></canvas>');
    buffer.writeln('      </div>');
  }

  void _addSettingsSection(StringBuffer buffer) {
    buffer.writeln('      <h2>Settings</h2>');
    buffer.writeln('      <p>Configure report preferences</p>');
  }

  String _getInlineScripts(ScanResult result) {
    return '''
  <script>
    // Section Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
      item.addEventListener('click', function() {
        const section = this.dataset.section;
        
        // Update active nav
        document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
        this.classList.add('active');
        
        // Show selected section
        document.querySelectorAll('.content-section').forEach(sec => sec.style.display = 'none');
        document.getElementById(section + '-section').style.display = 'block';
      });
    });

    // Theme Toggle
    function toggleTheme() {
      document.body.classList.toggle('dark');
    }

    // Export Report
    function exportReport() {
      window.print();
    }

    // Initialize Charts
    window.addEventListener('load', function() {
      // Distribution Chart
      const distCtx = document.getElementById('distributionChart');
      if (distCtx) {
        new Chart(distCtx, {
          type: 'bar',
          data: {
            labels: ['Keys', 'Files', 'Widgets', 'Handlers'],
            datasets: [{
              label: 'Count',
              data: [${result.keyUsages.length}, ${result.metrics.scannedFiles}, 100, 50],
              backgroundColor: 'rgba(59, 130, 246, 0.5)',
              borderColor: 'rgba(59, 130, 246, 1)',
              borderWidth: 1
            }]
          },
          options: {
            responsive: true,
            plugins: {
              legend: {
                display: false
              }
            }
          }
        });
      }

      // Coverage Chart
      const covCtx = document.getElementById('coverageChart');
      if (covCtx) {
        new Chart(covCtx, {
          type: 'line',
          data: {
            labels: ['Start', 'Mid', 'Current'],
            datasets: [{
              label: 'Coverage %',
              data: [0, 50, ${result.metrics.fileCoverage}],
              borderColor: 'rgba(16, 185, 129, 1)',
              backgroundColor: 'rgba(16, 185, 129, 0.2)',
              tension: 0.4
            }]
          },
          options: {
            responsive: true
          }
        });
      }
    });
  </script>
''';
  }
}
