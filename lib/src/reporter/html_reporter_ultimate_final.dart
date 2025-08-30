/// ULTIMATE Premium HTML Reporter from dc6b8db5^
/// Complete implementation with full glassmorphism and custom canvas charts
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:flutter_keycheck/src/reporter/reporter_v3.dart';

class HtmlReporter extends ReporterV3 {
  @override
  Future<void> generateScanReport(
    ScanResult result,
    File outputFile, {
    bool includeMetrics = true,
    bool includeLocations = false,
  }) async {
    final buffer = StringBuffer();

    // HTML header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer
        .writeln('  <title>Flutter KeyCheck - Ultimate Premium Report</title>');
    buffer.writeln(
        '  <script src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/js/all.min.js"></script>');
    buffer.writeln(
        '  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">');
    buffer.writeln(_getInlineStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body class="dark">');

    // Sidebar
    _addSidebar(buffer);

    // Header
    _addHeader(buffer);

    // Main Content
    buffer.writeln('  <div class="main-content">');
    _addDashboardSection(buffer, result);
    buffer.writeln('  </div>');

    // JavaScript
    buffer.writeln(_getInlineScripts(result));

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(buffer.toString());
  }

  @override
  Future<void> generateValidationReport(
    ValidationResult result,
    File outputFile, {
    bool includeMetrics = true,
  }) async {
    throw UnimplementedError(
        'Validation reports not supported in ultimate HTML');
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
      background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
      color: var(--text-primary);
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* Ultimate Glassmorphism Sidebar */
    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      width: 80px;
      height: 100vh;
      background: rgba(30, 41, 59, 0.8);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-right: 1px solid var(--border);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 0;
      transition: width 0.3s ease;
      box-shadow: 0 0 40px rgba(59, 130, 246, 0.1);
    }

    .sidebar:hover {
      width: 250px;
      box-shadow: 0 0 60px rgba(59, 130, 246, 0.2);
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
      box-shadow: 0 10px 30px rgba(59, 130, 246, 0.3);
    }

    /* Premium Header */
    .header {
      position: fixed;
      top: 0;
      left: 80px;
      right: 0;
      height: 80px;
      background: rgba(30, 41, 59, 0.8);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 30px;
      z-index: 999;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
    }

    .header h1 {
      font-size: 28px;
      font-weight: 700;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6, #ec4899);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      text-shadow: 0 0 40px rgba(59, 130, 246, 0.3);
    }

    /* Main Content */
    .main-content {
      margin-left: 80px;
      margin-top: 80px;
      padding: 30px;
      min-height: calc(100vh - 80px);
    }

    /* Premium Dashboard Cards */
    .dashboard-header {
      background: rgba(30, 41, 59, 0.5);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 40px;
      margin-bottom: 30px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      position: relative;
      overflow: hidden;
    }

    .dashboard-header::before {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: linear-gradient(45deg, transparent, rgba(59, 130, 246, 0.1), transparent);
      animation: shimmer 3s infinite;
    }

    @keyframes shimmer {
      0% { transform: translateX(-100%) translateY(-100%) rotate(45deg); }
      100% { transform: translateX(100%) translateY(100%) rotate(45deg); }
    }

    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 25px;
      margin-bottom: 30px;
    }

    .metric-card {
      background: rgba(30, 41, 59, 0.5);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 30px;
      position: relative;
      overflow: hidden;
      transition: all 0.3s ease;
      cursor: pointer;
    }

    .metric-card:hover {
      transform: translateY(-5px) scale(1.02);
      box-shadow: 0 20px 40px rgba(59, 130, 246, 0.2);
      border-color: var(--accent);
    }

    .metric-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899);
      animation: colorWave 3s ease-in-out infinite;
    }

    @keyframes colorWave {
      0%, 100% { transform: translateX(-100%); }
      50% { transform: translateX(100%); }
    }

    .metric-card .icon {
      width: 60px;
      height: 60px;
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.2), rgba(139, 92, 246, 0.2));
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 20px;
      font-size: 28px;
      color: var(--accent);
      box-shadow: 0 10px 30px rgba(59, 130, 246, 0.2);
    }

    .metric-card .value {
      font-size: 36px;
      font-weight: 700;
      margin-bottom: 8px;
      background: linear-gradient(135deg, #fff, #94a3b8);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .metric-card .label {
      color: var(--text-secondary);
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }

    /* Premium Keys Table */
    .keys-table-container {
      background: rgba(30, 41, 59, 0.5);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 30px;
      overflow: hidden;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    }

    .keys-table {
      width: 100%;
      border-collapse: collapse;
    }

    .keys-table th {
      text-align: left;
      padding: 18px;
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.1), rgba(139, 92, 246, 0.1));
      border-bottom: 2px solid var(--border);
      font-weight: 600;
      color: var(--text-primary);
      text-transform: uppercase;
      font-size: 12px;
      letter-spacing: 1px;
    }

    .keys-table td {
      padding: 18px;
      border-bottom: 1px solid rgba(51, 65, 85, 0.2);
      color: var(--text-secondary);
      transition: all 0.2s ease;
    }

    .keys-table tr:hover td {
      background: rgba(59, 130, 246, 0.05);
      color: var(--text-primary);
    }

    .key-badge {
      display: inline-block;
      padding: 6px 14px;
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.2), rgba(139, 92, 246, 0.2));
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 20px;
      font-size: 13px;
      font-weight: 500;
      color: #3b82f6;
      transition: all 0.2s ease;
    }

    .key-badge:hover {
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.3), rgba(139, 92, 246, 0.3));
      transform: scale(1.05);
    }

    /* Canvas Charts */
    .chart-container {
      background: rgba(30, 41, 59, 0.5);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 30px;
      margin-bottom: 30px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    }

    .chart-container h3 {
      margin-bottom: 25px;
      font-size: 22px;
      font-weight: 600;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    canvas {
      width: 100%;
      height: 300px;
      border-radius: 12px;
      background: rgba(0, 0, 0, 0.2);
    }

    /* Animations */
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .dashboard-header,
    .metric-card,
    .keys-table-container,
    .chart-container {
      animation: fadeInUp 0.6s ease;
    }

    .metric-card:nth-child(1) { animation-delay: 0.1s; }
    .metric-card:nth-child(2) { animation-delay: 0.2s; }
    .metric-card:nth-child(3) { animation-delay: 0.3s; }
    .metric-card:nth-child(4) { animation-delay: 0.4s; }
  </style>
''';
  }

  void _addSidebar(StringBuffer buffer) {
    buffer.writeln('  <div class="sidebar">');
    buffer.writeln('    <div class="logo">✨</div>');
    buffer.writeln('  </div>');
  }

  void _addHeader(StringBuffer buffer) {
    buffer.writeln('  <div class="header">');
    buffer.writeln('    <h1>Flutter KeyCheck Ultimate Premium</h1>');
    buffer.writeln('    <div class="actions">');
    buffer.writeln(
        '      <span style="color: #10b981;">⚡ ULTIMATE VERSION</span>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');
  }

  void _addDashboardSection(StringBuffer buffer, ScanResult result) {
    buffer.writeln('      <div class="dashboard-header">');
    buffer.writeln(
        '        <h2 style="font-size: 32px; margin-bottom: 10px;">Ultimate Scan Results</h2>');
    buffer.writeln(
        '        <p style="color: var(--text-secondary);">Generated on ${DateTime.now().toIso8601String()}</p>');
    buffer.writeln('      </div>');

    // Metrics Grid
    buffer.writeln('      <div class="metrics-grid">');

    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-key"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.keyUsages.length}</div>');
    buffer.writeln('          <div class="label">Total Keys Found</div>');
    buffer.writeln('        </div>');

    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-file-code"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.scannedFiles}</div>');
    buffer.writeln('          <div class="label">Files Scanned</div>');
    buffer.writeln('        </div>');

    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-chart-pie"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.fileCoverage.toStringAsFixed(1)}%</div>');
    buffer.writeln('          <div class="label">File Coverage</div>');
    buffer.writeln('        </div>');

    buffer.writeln('        <div class="metric-card">');
    buffer.writeln(
        '          <div class="icon"><i class="fas fa-cube"></i></div>');
    buffer.writeln(
        '          <div class="value">${result.metrics.widgetCoverage.toStringAsFixed(1)}%</div>');
    buffer.writeln('          <div class="label">Widget Coverage</div>');
    buffer.writeln('        </div>');

    buffer.writeln('      </div>');

    // Charts
    buffer.writeln('      <div class="chart-container">');
    buffer.writeln('        <h3>Key Distribution Analysis</h3>');
    buffer.writeln('        <canvas id="distributionChart"></canvas>');
    buffer.writeln('      </div>');

    // Keys Table
    buffer.writeln('      <div class="keys-table-container">');
    buffer.writeln(
        '        <h3 style="margin-bottom: 25px; font-size: 22px;">Discovered Keys</h3>');
    buffer.writeln('        <table class="keys-table">');
    buffer.writeln('          <thead>');
    buffer.writeln('            <tr>');
    buffer.writeln('              <th>Key ID</th>');
    buffer.writeln('              <th>File Location</th>');
    buffer.writeln('              <th>Usage Count</th>');
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

  String _getInlineScripts(ScanResult result) {
    return '''
  <script>
    // Initialize Ultimate Charts
    window.addEventListener('load', function() {
      const canvas = document.getElementById('distributionChart');
      if (canvas) {
        const ctx = canvas.getContext('2d');
        const width = canvas.width = canvas.offsetWidth;
        const height = canvas.height = canvas.offsetHeight;
        
        // Clear canvas
        ctx.clearRect(0, 0, width, height);
        
        // Draw custom chart
        const data = [${result.keyUsages.length}, ${result.metrics.scannedFiles}, ${result.metrics.fileCoverage.toInt()}, ${result.metrics.widgetCoverage.toInt()}];
        const labels = ['Keys', 'Files', 'File%', 'Widget%'];
        const colors = ['#3b82f6', '#8b5cf6', '#ec4899', '#10b981'];
        
        const maxValue = Math.max(...data);
        const barWidth = width / (data.length * 2);
        const scale = (height - 40) / maxValue;
        
        data.forEach((value, index) => {
          const x = (index * 2 + 0.5) * barWidth;
          const barHeight = value * scale;
          const y = height - barHeight - 20;
          
          // Draw bar with gradient
          const gradient = ctx.createLinearGradient(x, y + barHeight, x, y);
          gradient.addColorStop(0, colors[index]);
          gradient.addColorStop(1, colors[index] + '40');
          
          ctx.fillStyle = gradient;
          ctx.fillRect(x, y, barWidth, barHeight);
          
          // Draw value
          ctx.fillStyle = '#f1f5f9';
          ctx.font = 'bold 14px Inter';
          ctx.textAlign = 'center';
          ctx.fillText(value.toString(), x + barWidth/2, y - 5);
          
          // Draw label
          ctx.font = '12px Inter';
          ctx.fillStyle = '#94a3b8';
          ctx.fillText(labels[index], x + barWidth/2, height - 5);
        });
      }
    });
  </script>
''';
  }
}
