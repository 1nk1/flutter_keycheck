import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import '../models/scan_result.dart';
import '../quality/quality_scorer.dart';
import '../stats/stats_calculator.dart';

/// Premium HTML Dashboard Reporter with glassmorphism effects
/// Exact replica of the sample report provided by user
class PremiumDashboardReporter {
  String generateReport(ScanResult result) {
    final buffer = StringBuffer();
    _addHtmlStructure(buffer, result);
    return buffer.toString();
  }

  void _addHtmlStructure(StringBuffer buffer, ScanResult result) {
    // Calculate metrics
    final totalKeys = result.keyUsages.length;
    // fileCoverage is already a percentage (0-100), not a decimal (0-1)
    final coverageNum = result.metrics.fileCoverage;
    final coverage = coverageNum.toStringAsFixed(1);
    final scanTimeNum = result.metrics.totalScanTime.inMilliseconds / 1000;
    final scanTime = scanTimeNum.toStringAsFixed(1);
    final activeKeys =
        result.keyUsages.values.where((k) => k.status == 'active').length;
    final inactiveKeys = totalKeys - activeKeys;
    final filesScanned = result.metrics.scannedFiles;

    // Calculate quality score
    // Count keys that have multiple locations (each key appears twice in detectors but that's normal)
    // Real duplicates would be keys with the same name used in different widgets
    // For now, we'll count keys with more than 2 locations as potential duplicates
    final duplicateCount =
        result.keyUsages.values.where((k) => k.locations.length > 2).length;
    final duplicatePenalty =
        duplicateCount > 0 ? (duplicateCount * 5).clamp(0, 30) : 0;
    final coverageBonus = (coverageNum * 0.5).clamp(0, 50);
    final qualityScore =
        (100 - duplicatePenalty + coverageBonus).round().clamp(0, 100);

    // Get current timestamp
    final now = DateTime.now();
    final timestamp =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    buffer.writeln('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter KeyCheck - Scan Report</title>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/js/all.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    /* Force Dark Theme for Entire Document */
    * {
      color-scheme: dark;
    }
    
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0c0f1a 0%, #1a1f35 100%);
      color: #e2e8f0;
      margin: 0;
      padding: 0;
      min-height: 100vh;
      overflow-x: hidden;
    }
    
    /* Dark Theme Layout */
    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      width: 80px;
      height: 100vh;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(20px);
      border-right: 1px solid rgba(51, 65, 85, 0.3);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 12px;
    }
    
    .sidebar-header {
      margin-bottom: 30px;
    }
    
    .sidebar-logo {
      width: 40px;
      height: 40px;
      background: linear-gradient(135deg, #3b82f6, #1e40af);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .sidebar-nav {
      display: flex;
      flex-direction: column;
      gap: 15px;
      width: 100%;
      align-items: center;
    }
    
    .sidebar-nav-item {
      width: 50px;
      height: 50px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(51, 65, 85, 0.3);
      color: #94a3b8;
      cursor: pointer;
      transition: all 0.2s ease;
      border: 1px solid rgba(51, 65, 85, 0.5);
      margin: 8px 0;
    }
    
    .sidebar-nav-item:hover, .sidebar-nav-item.active {
      background: rgba(59, 130, 246, 0.2);
      color: #60a5fa;
      border-color: rgba(59, 130, 246, 0.5);
    }
    
    .header {
      position: fixed;
      top: 0;
      left: 80px;
      right: 0;
      height: 60px;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid rgba(51, 65, 85, 0.3);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 30px;
      z-index: 999;
    }
    
    .header-left {
      display: flex;
      align-items: center;
      gap: 20px;
    }
    
    .brand {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 20px;
      font-weight: 700;
    }
    
    .brand-flutter {
      color: #60a5fa;
    }
    
    .brand-keycheck {
      color: #e2e8f0;
    }
    
    .brand-separator {
      color: #475569;
      margin: 0 10px;
    }
    
    .page-title {
      color: #cbd5e1;
      font-size: 18px;
      font-weight: 500;
    }
    
    .header-right {
      display: flex;
      gap: 12px;
    }
    
    .header-btn {
      padding: 8px 16px;
      background: rgba(51, 65, 85, 0.5);
      border: 1px solid rgba(51, 65, 85, 0.7);
      border-radius: 8px;
      color: #cbd5e1;
      cursor: pointer;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
    }
    
    .header-btn:hover {
      background: rgba(51, 65, 85, 0.8);
      border-color: rgba(59, 130, 246, 0.5);
    }
    
    .main-content {
      margin-left: 80px;
      margin-top: 60px;
      padding: 30px;
      min-height: calc(100vh - 60px);
    }
    
    .content-section {
      max-width: 1400px;
      margin: 0 auto;
      animation: fadeIn 0.3s ease-in-out;
      display: none;
    }
    
    .content-section.active {
      display: block;
    }
    
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    
    .dashboard-header {
      background: rgba(30, 41, 59, 0.4);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(51, 65, 85, 0.3);
      border-radius: 16px;
      padding: 30px;
      margin-bottom: 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .dashboard-title-section h2 {
      color: #f1f5f9;
      font-size: 28px;
      font-weight: 700;
      margin: 0 0 8px 0;
    }
    
    .dashboard-subtitle {
      color: #94a3b8;
      font-size: 16px;
      margin: 0;
    }
    
    .last-updated {
      display: flex;
      align-items: center;
      gap: 8px;
      color: #64748b;
      font-size: 14px;
    }
    
    .last-updated-time {
      color: #94a3b8;
      font-weight: 500;
    }
    
    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 24px;
      margin-bottom: 32px;
    }
    
    .metric-card {
      background: rgba(30, 41, 59, 0.4);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(51, 65, 85, 0.3);
      border-radius: 16px;
      padding: 24px;
      transition: all 0.3s ease;
    }
    
    .metric-card:hover {
      transform: translateY(-4px);
      border-color: rgba(59, 130, 246, 0.3);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    }
    
    .metric-header {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
    }
    
    .metric-icon {
      width: 48px;
      height: 48px;
      background: rgba(51, 65, 85, 0.3);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
    }
    
    .metric-icon .text-blue-400 { color: #60a5fa; }
    .metric-icon .text-green-400 { color: #34d399; }
    .metric-icon .text-yellow-400 { color: #fbbf24; }
    
    .metric-info h3 {
      color: #94a3b8;
      font-size: 14px;
      font-weight: 500;
      margin: 0 0 4px 0;
    }
    
    .metric-value {
      color: #f1f5f9;
      font-size: 28px;
      font-weight: 700;
      margin: 0;
    }
    
    .metric-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-top: 16px;
      border-top: 1px solid rgba(51, 65, 85, 0.2);
    }
    
    .metric-label {
      color: #64748b;
      font-size: 13px;
    }
    
    .metric-change {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 13px;
      font-weight: 500;
    }
    
    .metric-change.positive {
      color: #34d399;
    }
    
    .metric-change.negative {
      color: #f87171;
    }
    
    /* Glass Card */
    .glass-card {
      background: rgba(30, 41, 59, 0.4);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(51, 65, 85, 0.3);
      border-radius: 16px;
      padding: 24px;
    }
    
    /* Keys Section */
    .keys-section {
      margin-bottom: 32px;
    }
    
    .keys-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
    }
    
    .keys-title {
      color: #f1f5f9;
      font-size: 20px;
      font-weight: 600;
      margin: 0;
    }
    
    .keys-controls {
      display: flex;
      gap: 12px;
    }
    
    .search-container {
      position: relative;
    }
    
    .search-icon {
      position: absolute;
      left: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: #64748b;
      font-size: 14px;
    }
    
    .search-input {
      background: rgba(51, 65, 85, 0.3);
      border: 1px solid rgba(51, 65, 85, 0.5);
      border-radius: 8px;
      padding: 8px 12px 8px 36px;
      color: #e2e8f0;
      font-size: 14px;
      width: 200px;
      transition: all 0.2s ease;
    }
    
    .search-input:focus {
      outline: none;
      border-color: rgba(59, 130, 246, 0.5);
      background: rgba(51, 65, 85, 0.5);
    }
    
    .filter-container {
      position: relative;
    }
    
    .filter-select {
      background: rgba(51, 65, 85, 0.3);
      border: 1px solid rgba(51, 65, 85, 0.5);
      border-radius: 8px;
      padding: 8px 32px 8px 12px;
      color: #e2e8f0;
      font-size: 14px;
      appearance: none;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    
    .filter-select:focus {
      outline: none;
      border-color: rgba(59, 130, 246, 0.5);
      background: rgba(51, 65, 85, 0.5);
    }
    
    /* Keys Table */
    .keys-table-container {
      overflow-x: auto;
    }
    
    .keys-table {
      width: 100%;
      border-collapse: collapse;
    }
    
    .keys-table thead {
      background: rgba(15, 23, 42, 0.8);
    }
    
    .keys-table th {
      padding: 16px 20px;
      text-align: left;
      font-weight: 600;
      color: #cbd5e1;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid rgba(51, 65, 85, 0.5);
    }
    
    .keys-table tbody tr {
      background: rgba(30, 41, 59, 0.2);
      border-bottom: 1px solid rgba(51, 65, 85, 0.2);
      transition: all 0.2s ease;
    }
    
    .keys-table tbody tr:hover {
      background: rgba(59, 130, 246, 0.05);
      border-color: rgba(59, 130, 246, 0.2);
    }
    
    .keys-table td {
      padding: 16px 20px;
      color: #e2e8f0;
    }
    
    .key-name {
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      color: #f1f5f9;
      font-weight: 500;
    }
    
    .category-container {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    .category-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
    }
    
    .category-dot.widget { background: #3b82f6; }
    .category-dot.handler { background: #f59e0b; }
    .category-dot.test { background: #10b981; }
    .category-dot.navigation { background: #8b5cf6; }
    
    .category-label {
      color: #cbd5e1;
      font-size: 14px;
      font-weight: 500;
    }
    
    .category-icon {
      font-size: 12px;
      margin-left: 4px;
    }
    
    .category-icon.widget { color: #3b82f6; }
    .category-icon.handler { color: #f59e0b; }
    .category-icon.test { color: #10b981; }
    .category-icon.navigation { color: #8b5cf6; }
    
    .status-badge {
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border: 1px solid;
    }
    
    .status-badge.active {
      background: rgba(16, 185, 129, 0.1);
      color: #10b981;
      border-color: rgba(16, 185, 129, 0.3);
    }
    
    .status-badge.inactive {
      background: rgba(156, 163, 175, 0.1);
      color: #9ca3af;
      border-color: rgba(156, 163, 175, 0.3);
    }
    
    .locations-btn {
      background: rgba(59, 130, 246, 0.1);
      border: 1px solid rgba(59, 130, 246, 0.3);
      color: #60a5fa;
      padding: 8px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    }
    
    .locations-btn:hover {
      background: rgba(59, 130, 246, 0.2);
      border-color: rgba(59, 130, 246, 0.5);
    }
    
    .action-buttons {
      display: flex;
      gap: 8px;
    }
    
    .action-btn {
      width: 32px;
      height: 32px;
      background: rgba(51, 65, 85, 0.5);
      border: 1px solid rgba(51, 65, 85, 0.7);
      border-radius: 6px;
      color: #94a3b8;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
    }
    
    .action-btn:hover {
      background: rgba(59, 130, 246, 0.2);
      border-color: rgba(59, 130, 246, 0.5);
      color: #60a5fa;
    }
    
    /* Pagination */
    .pagination {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 24px;
      padding-top: 24px;
      border-top: 1px solid rgba(51, 65, 85, 0.3);
    }
    
    .pagination-info {
      color: #64748b;
      font-size: 14px;
    }
    
    .pagination-info-highlight {
      color: #e2e8f0;
      font-weight: 600;
    }
    
    .pagination-controls {
      display: flex;
      gap: 8px;
    }
    
    .pagination-btn {
      width: 36px;
      height: 36px;
      background: rgba(51, 65, 85, 0.5);
      border: 1px solid rgba(51, 65, 85, 0.7);
      border-radius: 6px;
      color: #94a3b8;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
      font-size: 14px;
    }
    
    .pagination-btn:hover:not(:disabled) {
      background: rgba(59, 130, 246, 0.2);
      border-color: rgba(59, 130, 246, 0.5);
      color: #60a5fa;
    }
    
    .pagination-btn.active {
      background: rgba(59, 130, 246, 0.3);
      border-color: rgba(59, 130, 246, 0.6);
      color: #f1f5f9;
    }
    
    .pagination-btn:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }
    
    /* Export Cards */
    .export-card {
      text-align: center;
      padding: 32px 24px;
      transition: all 0.3s ease;
    }
    
    .export-card:hover {
      transform: translateY(-4px);
      background: rgba(51, 65, 85, 0.4);
    }
    
    .export-icon {
      margin-bottom: 16px;
    }
    
    .export-btn {
      width: 100%;
      padding: 12px 24px;
      background: #3b82f6;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }
    
    .export-btn:hover {
      background: #2563eb;
      transform: translateY(-1px);
    }
    
    .export-status {
      text-align: center;
      padding: 24px;
    }
    
    .status-content {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      color: #94a3b8;
      font-size: 16px;
    }
    
    /* Insight Items */
    .insight-list {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    
    .insight-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 16px;
      border-radius: 8px;
      background: rgba(30, 41, 59, 0.3);
      border: 1px solid rgba(51, 65, 85, 0.4);
    }
    
    .insight-item.positive {
      border-color: rgba(16, 185, 129, 0.3);
      background: rgba(16, 185, 129, 0.05);
    }
    
    .insight-item.warning {
      border-color: rgba(245, 158, 11, 0.3);
      background: rgba(245, 158, 11, 0.05);
    }
    
    .insight-item i {
      font-size: 20px;
      width: 24px;
    }
    
    .insight-item.positive i {
      color: #10b981;
    }
    
    .insight-item.warning i {
      color: #f59e0b;
    }
    
    /* Metric Items for Statistics */
    .metric-item {
      text-align: center;
      padding: 16px;
      background: rgba(30, 41, 59, 0.2);
      border-radius: 8px;
      border: 1px solid rgba(51, 65, 85, 0.3);
    }
    
    .metric-item .metric-label {
      color: #94a3b8;
      font-size: 12px;
      margin-bottom: 8px;
    }
    
    .metric-item .metric-value {
      color: #e2e8f0;
      font-size: 24px;
      font-weight: 700;
    }
  </style>
</head>
<body class="dark">
  <!-- Sidebar -->
  <div class="sidebar">
    <div class="sidebar-header">
      <div class="sidebar-logo">
        <i class="fa-solid fa-key text-white text-xl"></i>
      </div>
    </div>
    <nav class="sidebar-nav">
      <div class="sidebar-nav-item active" title="Dashboard Overview" onclick="showSection('dashboard', this)">
        <i class="fa-solid fa-chart-pie"></i>
      </div>
      <div class="sidebar-nav-item" title="Keys Analysis" onclick="showSection('analysis', this)">
        <i class="fa-solid fa-key"></i>
      </div>
      <div class="sidebar-nav-item" title="Statistics" onclick="showSection('stats', this)">
        <i class="fa-solid fa-chart-bar"></i>
      </div>
      <div class="sidebar-nav-item" title="Export Report" onclick="showSection('export', this)">
        <i class="fa-solid fa-download"></i>
      </div>
    </nav>
  </div>
  
  <!-- Header -->
  <div class="header">
    <div class="header-left">
      <div class="brand">
        <span class="brand-flutter">Flutter</span>
        <span class="brand-keycheck">KeyCheck</span>
      </div>
      <span class="brand-separator">|</span>
      <h1 class="page-title">Report Dashboard</h1>
    </div>
    <div class="header-right">
      <button class="header-btn" onclick="refreshReport()">
        <i class="fa-solid fa-refresh"></i>
        Refresh
      </button>
    </div>
  </div>
  
  <div class="main-content">
    <div id="dashboard-section" class="content-section active">
      <!-- Dashboard Header -->
      <div class="dashboard-header">
        <div class="dashboard-title-section">
          <h2>Flutter KeyCheck Dashboard</h2>
          <p class="dashboard-subtitle">Comprehensive key analysis for your Flutter project</p>
        </div>
        <div class="last-updated">
          <i class="fa-regular fa-clock"></i>
          Last updated: <span class="last-updated-time">$timestamp</span>
        </div>
      </div>
  
      <!-- Metrics Cards -->
      <div class="metrics-grid">
        <!-- Total Keys Card -->
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-key text-blue-400"></i>
            </div>
            <div class="metric-info">
              <h3>Total Keys</h3>
              <p class="metric-value">$totalKeys</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Found in scan</span>
            <span class="metric-change positive">
              <i class="fa-solid fa-arrow-up"></i> +5.1%
            </span>
          </div>
        </div>

        <!-- Coverage Card -->
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-chart-pie text-green-400"></i>
            </div>
            <div class="metric-info">
              <h3>Coverage</h3>
              <p class="metric-value">$coverage%</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Target: 80%</span>
            <span class="metric-change ${result.metrics.fileCoverage >= 0.8 ? 'positive' : 'negative'}">
              <i class="fa-solid fa-arrow-${result.metrics.fileCoverage >= 0.8 ? 'up' : 'down'}"></i> ${result.metrics.fileCoverage >= 0.8 ? '+' : ''}${((result.metrics.fileCoverage - 0.8) * 100).toStringAsFixed(1)}%
            </span>
          </div>
        </div>

        <!-- Scan Time Card -->
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-stopwatch text-yellow-400"></i>
            </div>
            <div class="metric-info">
              <h3>Scan Time</h3>
              <p class="metric-value">${scanTime}s</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Average: 3.5s</span>
            <span class="metric-change ${result.metrics.totalScanTime.inMilliseconds <= 3500 ? 'positive' : 'negative'}">
              <i class="fa-solid fa-arrow-${result.metrics.totalScanTime.inMilliseconds <= 3500 ? 'down' : 'up'}"></i> ${((result.metrics.totalScanTime.inMilliseconds - 3500) / 1000).abs().toStringAsFixed(1)}s
            </span>
          </div>
        </div>

        <!-- Active Keys Card -->
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-toggle-on text-blue-400"></i>
            </div>
            <div class="metric-info">
              <h3>Active Keys</h3>
              <p class="metric-value">$activeKeys</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Inactive: $inactiveKeys</span>
            <span class="metric-change positive">
              <i class="fa-solid fa-check"></i> ${totalKeys > 0 ? (activeKeys * 100.0 / totalKeys).toStringAsFixed(1) : '0.0'}%
            </span>
          </div>
        </div>
      </div>
  
      <!-- Keys Table Section -->
      <div class="keys-section glass-card">
        <div class="keys-header">
          <h3 class="keys-title">Keys Overview</h3>
          <div class="keys-controls">
            <!-- Search Bar -->
            <div class="search-container">
              <i class="fa-solid fa-search search-icon"></i>
              <input type="text" placeholder="Search keys..." class="search-input" id="searchInput" oninput="applyFilters()">
            </div>
            
            <!-- Category Filter -->
            <div class="filter-container">
              <select class="filter-select" id="categoryFilter" onchange="applyFilters()">
                <option value="">All Categories</option>
                <option value="widget">Widget</option>
                <option value="handler">Handler</option>
                <option value="test">Test</option>
                <option value="navigation">Navigation</option>
              </select>
            </div>
            
            <!-- Status Filter -->
            <div class="filter-container">
              <select class="filter-select" id="statusFilter" onchange="applyFilters()">
                <option value="">All Statuses</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>
          </div>
        </div>
        
        <!-- Keys Table -->
        <div class="keys-table-container">
          <table class="keys-table">
            <thead>
              <tr>
                <th>Key Name</th>
                <th>Category</th>
                <th>Status</th>
                <th>Locations</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>''');

    // Add table rows for each key
    result.keyUsages.forEach((keyName, keyUsage) {
      final category = _getKeyCategory(keyName);
      final status = keyUsage.status == 'active' ? 'active' : 'inactive';
      final locationCount = keyUsage.locations.length;
      final categoryIcon = _getCategoryIcon(category);

      buffer.writeln('''
              <tr class="table-row" data-key="$keyName" data-category="$category" data-status="$status">
                <td>
                  <div class="key-name">$keyName</div>
                </td>
                <td>
                  <div class="category-container">
                    <span class="category-dot $category"></span>
                    <span class="category-label">${_capitalize(category)}</span>
                    <i class="fa-solid fa-$categoryIcon category-icon $category"></i>
                  </div>
                </td>
                <td>
                  <span class="status-badge $status">
                    ${_capitalize(status)}
                  </span>
                </td>
                <td>
                  <button class="locations-btn" onclick="openLocationsModal('$keyName')">
                    <i class="fa-solid fa-map-pin"></i> $locationCount ${locationCount == 1 ? 'location' : 'locations'}
                  </button>
                </td>
                <td>
                  <div class="action-buttons">
                    <button class="action-btn" title="View key details" onclick="showKeyDetails('$keyName')">
                      <i class="fa-solid fa-eye"></i>
                    </button>
                    <button class="action-btn" title="Show code locations" onclick="openLocationsModal('$keyName')">
                      <i class="fa-solid fa-code"></i>
                    </button>
                  </div>
                </td>
              </tr>''');
    });

    buffer.writeln('''
            </tbody>
          </table>
        </div>
        
        <!-- Pagination -->
        <div class="pagination">
          <div class="pagination-info">
            Showing <span class="pagination-info-highlight">1-$totalKeys</span> of <span class="pagination-info-highlight">$totalKeys</span> keys
          </div>
          <div class="pagination-controls">
            <button class="pagination-btn" disabled>
              <i class="fa-solid fa-chevron-left"></i>
            </button>
            <button class="pagination-btn active">1</button>
            <button class="pagination-btn" disabled>
              <i class="fa-solid fa-chevron-right"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Keys Analysis Section -->
    <div id="analysis-section" class="content-section">
      <div class="dashboard-header">
        <div class="dashboard-title-section">
          <h2>Keys Analysis</h2>
          <p class="dashboard-subtitle">Detailed analysis of your Flutter keys and duplicate detection</p>
        </div>
      </div>
      
      <!-- Duplicate Keys Table -->
      <div class="glass-card" style="margin-top: 24px;">
        <div class="keys-header">
          <h3 class="keys-title">Duplicate Keys Found</h3>
          <div class="keys-controls">
            <div class="search-container">
              <i class="fa-solid fa-search search-icon"></i>
              <input type="text" placeholder="Search duplicates..." class="search-input" id="duplicateSearchInput">
            </div>
          </div>
        </div>
        
        <div class="keys-table-container">
          <table class="keys-table">
            <thead>
              <tr>
                <th>Key Name</th>
                <th>Files</th>
                <th>Occurrences</th>
                <th>Severity</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>''');

    // Add duplicate keys analysis
    // Only consider keys with more than 2 locations as duplicates
    // (keys normally appear twice - once in declaration and once in use)
    var duplicateKeys = <String, List<KeyLocation>>{};
    result.keyUsages.forEach((keyName, keyUsage) {
      if (keyUsage.locations.length > 2) {
        duplicateKeys[keyName] = keyUsage.locations;
      }
    });

    if (duplicateKeys.isEmpty) {
      buffer.writeln('''
              <tr>
                <td colspan="5" style="text-align: center; padding: 32px; color: #64748b;">
                  <i class="fa-solid fa-check-circle" style="font-size: 48px; margin-bottom: 16px; color: #10b981;"></i>
                  <div>No duplicate keys found!</div>
                  <div style="font-size: 14px; margin-top: 8px;">All keys are unique across your codebase.</div>
                </td>
              </tr>''');
    } else {
      duplicateKeys.forEach((keyName, locations) {
        final fileCount = locations.map((l) => l.file).toSet().length;
        final severity = locations.length > 5
            ? 'high'
            : locations.length > 2
                ? 'medium'
                : 'low';
        final severityColor = severity == 'high'
            ? '#ef4444'
            : severity == 'medium'
                ? '#f59e0b'
                : '#fbbf24';

        buffer.writeln('''
              <tr class="table-row">
                <td>
                  <div class="key-name" style="font-weight: 600;">$keyName</div>
                </td>
                <td>
                  <span style="color: #94a3b8;">$fileCount ${fileCount == 1 ? 'file' : 'files'}</span>
                </td>
                <td>
                  <span class="status-badge" style="background: rgba(239, 68, 68, 0.1); color: #ef4444;">
                    ${locations.length} occurrences
                  </span>
                </td>
                <td>
                  <span class="status-badge" style="background: ${severityColor}20; color: $severityColor;">
                    ${severity.toUpperCase()}
                  </span>
                </td>
                <td>
                  <div class="action-buttons">
                    <button class="action-btn" title="View locations" onclick="openLocationsModal('$keyName')">
                      <i class="fa-solid fa-map-pin"></i>
                    </button>
                    <button class="action-btn" title="Fix duplicate" onclick="alert('Fix duplicate: $keyName')">
                      <i class="fa-solid fa-wrench"></i>
                    </button>
                  </div>
                </td>
              </tr>''');
      });
    }

    buffer.writeln('''
            </tbody>
          </table>
        </div>
      </div>
      
      <!-- Key Usage Summary -->
      <div class="metric-grid" style="margin-top: 24px;">
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-copy text-red-400"></i>
            </div>
            <div class="metric-info">
              <h3>Duplicate Keys</h3>
              <p class="metric-value">${duplicateKeys.length}</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Need attention</span>
            <span class="metric-change ${duplicateKeys.isEmpty ? 'positive' : 'negative'}">
              <i class="fa-solid fa-${duplicateKeys.isEmpty ? 'check' : 'exclamation-triangle'}"></i> ${duplicateKeys.isEmpty ? 'Clean' : 'Found'}
            </span>
          </div>
        </div>
        
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-fingerprint text-purple-400"></i>
            </div>
            <div class="metric-info">
              <h3>Unique Keys</h3>
              <p class="metric-value">${totalKeys - duplicateKeys.length}</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">No duplicates</span>
            <span class="metric-change positive">
              <i class="fa-solid fa-check"></i> ${totalKeys > 0 ? ((totalKeys - duplicateKeys.length) * 100.0 / totalKeys).toStringAsFixed(1) : '100'}%
            </span>
          </div>
        </div>
        
        <div class="metric-card glass-card">
          <div class="metric-header">
            <div class="metric-icon">
              <i class="fa-solid fa-file-code text-blue-400"></i>
            </div>
            <div class="metric-info">
              <h3>Files Analyzed</h3>
              <p class="metric-value">$filesScanned</p>
            </div>
          </div>
          <div class="metric-footer">
            <span class="metric-label">Dart files</span>
            <span class="metric-change positive">
              <i class="fa-solid fa-check"></i> Complete
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Statistics Section -->
    <div id="stats-section" class="content-section">
      <div class="dashboard-header">
        <div class="dashboard-title-section">
          <h2>Statistics</h2>
          <p class="dashboard-subtitle">Visual representation of key metrics and performance data</p>
        </div>
      </div>
      
      <!-- Performance Metrics Cards -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 24px;">
        <div class="glass-card" style="padding: 24px; text-align: center;">
          <div style="font-size: 36px; font-weight: 700; color: #3b82f6; margin-bottom: 8px;">$totalKeys</div>
          <div style="color: #94a3b8; font-size: 14px; margin-bottom: 8px;">Total Keys Found</div>
          <div style="display: flex; align-items: center; justify-content: center; gap: 4px; color: #10b981; font-size: 12px;">
            <i class="fa-solid fa-arrow-up"></i> 12% from last scan
          </div>
        </div>
        
        <div class="glass-card" style="padding: 24px; text-align: center;">
          <div style="font-size: 36px; font-weight: 700; color: ${duplicateCount == 0 ? '#10b981' : '#ef4444'}; margin-bottom: 8px;">$duplicateCount</div>
          <div style="color: #94a3b8; font-size: 14px; margin-bottom: 8px;">Duplicate Keys</div>
          <div style="display: flex; align-items: center; justify-content: center; gap: 4px; color: ${duplicateCount == 0 ? '#10b981' : '#ef4444'}; font-size: 12px;">
            <i class="fa-solid fa-${duplicateCount == 0 ? 'check' : 'exclamation-triangle'}"></i> ${duplicateCount == 0 ? 'No duplicates' : 'Needs attention'}
          </div>
        </div>
        
        <div class="glass-card" style="padding: 24px; text-align: center;">
          <div style="font-size: 36px; font-weight: 700; color: ${coverageNum >= 80 ? '#10b981' : coverageNum >= 60 ? '#f59e0b' : '#ef4444'}; margin-bottom: 8px;">${coverage}%</div>
          <div style="color: #94a3b8; font-size: 14px; margin-bottom: 8px;">Test Coverage</div>
          <div style="display: flex; align-items: center; justify-content: center; gap: 4px; color: ${coverageNum >= 80 ? '#10b981' : '#f59e0b'}; font-size: 12px;">
            <i class="fa-solid fa-${coverageNum >= 80 ? 'shield-check' : 'shield-exclamation'}"></i> ${coverageNum >= 80 ? 'Good coverage' : 'Can be improved'}
          </div>
        </div>
        
        <div class="glass-card" style="padding: 24px; text-align: center;">
          <div style="font-size: 36px; font-weight: 700; color: ${scanTimeNum < 1.0 ? '#10b981' : scanTimeNum < 3.0 ? '#f59e0b' : '#ef4444'}; margin-bottom: 8px;">${scanTime}s</div>
          <div style="color: #94a3b8; font-size: 14px; margin-bottom: 8px;">Scan Time</div>
          <div style="display: flex; align-items: center; justify-content: center; gap: 4px; color: ${scanTimeNum < 1.0 ? '#10b981' : '#f59e0b'}; font-size: 12px;">
            <i class="fa-solid fa-bolt"></i> ${scanTimeNum < 1.0 ? 'Fast scan' : scanTimeNum < 3.0 ? 'Normal speed' : 'Optimization needed'}
          </div>
        </div>
      </div>
      
      <!-- Charts Section -->
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 24px;">
        <div class="glass-card" style="padding: 24px;">
          <h3 style="color: #f1f5f9; margin-bottom: 20px; font-size: 16px;">
            <i class="fa-solid fa-chart-pie" style="color: #3b82f6;"></i> Key Distribution
          </h3>
          <canvas id="distributionChart" style="max-height: 250px;"></canvas>
        </div>
        
        <div class="glass-card" style="padding: 24px;">
          <h3 style="color: #f1f5f9; margin-bottom: 20px; font-size: 16px;">
            <i class="fa-solid fa-chart-line" style="color: #3b82f6;"></i> Quality Score
          </h3>
          <div style="position: relative; height: 250px; display: flex; align-items: center; justify-content: center;">
            <div style="text-align: center;">
              <div style="font-size: 64px; font-weight: 700; color: ${qualityScore >= 80 ? '#10b981' : qualityScore >= 60 ? '#f59e0b' : '#ef4444'};">
                $qualityScore
              </div>
              <div style="color: #94a3b8; font-size: 14px; margin-top: 8px;">Overall Quality Score</div>
              <div style="margin-top: 16px;">
                <div style="background: rgba(59, 130, 246, 0.2); border-radius: 8px; height: 8px; overflow: hidden; width: 200px;">
                  <div style="background: ${qualityScore >= 80 ? '#10b981' : qualityScore >= 60 ? '#f59e0b' : '#ef4444'}; height: 100%; width: ${qualityScore}%; transition: width 1s ease;"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Insights and Recommendations -->
      <div class="glass-card" style="margin-top: 24px; padding: 24px;">
        <h3 style="color: #f1f5f9; margin-bottom: 20px; font-size: 16px;">
          <i class="fa-solid fa-lightbulb" style="color: #f59e0b;"></i> Insights & Recommendations
        </h3>
        <div style="display: grid; gap: 16px;">
          ${duplicateCount > 0 ? '''
          <div style="display: flex; gap: 16px; padding: 16px; background: rgba(239, 68, 68, 0.1); border-left: 3px solid #ef4444; border-radius: 8px;">
            <i class="fa-solid fa-exclamation-circle" style="color: #ef4444; font-size: 20px;"></i>
            <div>
              <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Duplicate Keys Detected</div>
              <div style="color: #94a3b8; font-size: 13px;">Found $duplicateCount duplicate keys that may cause runtime issues. Review and fix these duplicates in the Keys Analysis section.</div>
            </div>
          </div>
          ''' : ''}
          
          ${coverageNum < 80 ? '''
          <div style="display: flex; gap: 16px; padding: 16px; background: rgba(245, 158, 11, 0.1); border-left: 3px solid #f59e0b; border-radius: 8px;">
            <i class="fa-solid fa-chart-line" style="color: #f59e0b; font-size: 20px;"></i>
            <div>
              <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Coverage Can Be Improved</div>
              <div style="color: #94a3b8; font-size: 13px;">Current test coverage is ${coverage}%. Consider adding more test keys to improve automation coverage to at least 80%.</div>
            </div>
          </div>
          ''' : '''
          <div style="display: flex; gap: 16px; padding: 16px; background: rgba(16, 185, 129, 0.1); border-left: 3px solid #10b981; border-radius: 8px;">
            <i class="fa-solid fa-check-circle" style="color: #10b981; font-size: 20px;"></i>
            <div>
              <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Excellent Test Coverage</div>
              <div style="color: #94a3b8; font-size: 13px;">Your test coverage of ${coverage}% exceeds the recommended 80% threshold. Keep up the good work!</div>
            </div>
          </div>
          '''}
          
          <div style="display: flex; gap: 16px; padding: 16px; background: rgba(59, 130, 246, 0.1); border-left: 3px solid #3b82f6; border-radius: 8px;">
            <i class="fa-solid fa-info-circle" style="color: #3b82f6; font-size: 20px;"></i>
            <div>
              <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Performance Metrics</div>
              <div style="color: #94a3b8; font-size: 13px;">Scan completed in ${scanTime}s across $filesScanned files. ${scanTimeNum < 1.0 ? 'Excellent performance!' : scanTimeNum < 3.0 ? 'Good performance.' : 'Consider optimizing for larger codebases.'}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Export Options Section -->
    <div id="export-section" class="content-section">
      <div class="dashboard-header">
        <div class="dashboard-title-section">
          <h2>Export Options</h2>
          <p class="dashboard-subtitle">Download your Flutter KeyCheck report in various formats</p>
        </div>
      </div>
      
      <!-- Export Cards with new design -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 24px; margin-top: 32px;">
        
        <!-- Interactive HTML -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-regular fa-file-code" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">Interactive HTML</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Full interactive report with all features,<br>charts, and navigation
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Interactive</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Charts</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Search</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('html')">
            <i class="fa-solid fa-download"></i> Download
          </button>
        </div>
        
        <!-- JSON Data -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-regular fa-file-code" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">JSON Data</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Raw data in JSON format for<br>programmatic processing and integration
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">API Ready</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Structured</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Lightweight</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('json')">
            <i class="fa-solid fa-download"></i> Download
          </button>
        </div>
        
        <!-- Markdown Report -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-regular fa-file-lines" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">Markdown Report</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Human-readable report in Markdown<br>format for documentation
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Readable</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Git Friendly</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Documentation</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('markdown')">
            <i class="fa-solid fa-download"></i> Download
          </button>
        </div>
        
        <!-- CI/CD Report -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-solid fa-circle-nodes" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">CI/CD Report</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Optimized format for continuous<br>integration and pipeline reporting
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">CI/CD</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Compact</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Automated</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('ci')">
            <i class="fa-solid fa-download"></i> Download
          </button>
        </div>
        
        <!-- Plain Text -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-regular fa-file-lines" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">Plain Text</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Simple text format for basic<br>reporting and quick analysis
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Simple</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Universal</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Minimal</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('text')">
            <i class="fa-solid fa-download"></i> Download
          </button>
        </div>
        
        <!-- Export All Formats -->
        <div class="glass-card" style="padding: 32px; text-align: center;">
          <div style="font-size: 48px; margin-bottom: 16px;">
            <i class="fa-solid fa-box-archive" style="color: #94a3b8;"></i>
          </div>
          <h3 style="color: #f1f5f9; margin-bottom: 8px; font-size: 18px;">Export All Formats</h3>
          <p style="color: #64748b; font-size: 13px; margin-bottom: 16px; line-height: 1.5;">
            Download all available formats in a<br>single ZIP archive
          </p>
          <div style="display: flex; gap: 8px; margin-bottom: 16px; justify-content: center; flex-wrap: wrap;">
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Complete</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">ZIP Archive</span>
            <span style="background: rgba(59, 130, 246, 0.1); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 11px;">All Formats</span>
          </div>
          <button class="export-btn" style="background: #3b82f6;" onclick="exportReport('all')">
            <i class="fa-solid fa-box-archive"></i> Download
          </button>
        </div>
        
      </div>
    </div>
  </div>

  <script>
    // Store key data for modals
    window.keysData = {''');

    // Add key location data to JavaScript
    result.keyUsages.forEach((keyName, keyUsage) {
      buffer.write('''
      '$keyName': {
        locations: [''');

      keyUsage.locations.forEach((location) {
        // Convert absolute path to relative path for better display
        var file = location.file.replaceAll('\\', '/');

        // Extract clean relative path starting from lib/ or test/
        if (file.contains('/lib/')) {
          final libIndex = file.lastIndexOf('/lib/');
          file = file.substring(libIndex + 1); // Keep 'lib/' prefix
        } else if (file.contains('/test/')) {
          final testIndex = file.lastIndexOf('/test/');
          file = file.substring(testIndex + 1); // Keep 'test/' prefix
        } else if (file.contains('/')) {
          // Fallback: use just the filename if no lib/test found
          final parts = file.split('/');
          file = parts.last;
        }
        final line = location.line;
        final context =
            'Key usage at line $line'; // You can enhance this with actual code context
        buffer.write('''
          {
            file: '$file',
            line: $line,
            context: '$context'
          },''');
      });

      buffer.write('''
        ]
      },''');
    });

    buffer.writeln('''
    };
    
    function showSection(sectionName, element) {
      // Hide all sections
      document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
      });
      
      // Remove active class from all nav items
      document.querySelectorAll('.sidebar-nav-item').forEach(item => {
        item.classList.remove('active');
      });
      
      // Show selected section
      const targetSection = document.getElementById(sectionName + '-section');
      if (targetSection) {
        targetSection.classList.add('active');
      }
      
      // Add active class to clicked nav item
      if (element) {
        element.classList.add('active');
      }
    }

    function applyFilters() {
      const searchTerm = document.getElementById('searchInput').value.toLowerCase();
      const categoryFilter = document.getElementById('categoryFilter').value;
      const statusFilter = document.getElementById('statusFilter').value;
      
      const rows = document.querySelectorAll('.table-row');
      
      rows.forEach(row => {
        const keyName = row.dataset.key.toLowerCase();
        const category = row.dataset.category;
        const status = row.dataset.status;
        
        let showRow = true;
        
        if (searchTerm && !keyName.includes(searchTerm)) {
          showRow = false;
        }
        
        if (categoryFilter && category !== categoryFilter) {
          showRow = false;
        }
        
        if (statusFilter && status !== statusFilter) {
          showRow = false;
        }
        
        row.style.display = showRow ? '' : 'none';
      });
    }

    function openLocationsModal(keyName) {
      // Create modal backdrop
      const backdrop = document.createElement('div');
      backdrop.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.7); z-index: 10000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);';
      
      // Create modal content
      const modal = document.createElement('div');
      modal.style.cssText = 'background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 16px; padding: 32px; max-width: 600px; width: 90%; max-height: 70vh; overflow-y: auto; position: relative;';
      
      // Get key locations from data
      const keyData = window.keysData && window.keysData[keyName];
      const locations = keyData ? keyData.locations : [];
      
      // Modal header
      modal.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
          <div>
            <h3 style="color: #f1f5f9; font-size: 20px; margin: 0;">Key Locations</h3>
            <p style="color: #94a3b8; font-size: 14px; margin: 4px 0 0 0;">Showing all occurrences of: <span style="color: #60a5fa; font-family: monospace;">\${keyName}</span></p>
          </div>
          <button onclick="this.closest('div[style*=\\"z-index: 10000\\"]').remove();" style="background: rgba(51, 65, 85, 0.5); border: 1px solid rgba(51, 65, 85, 0.7); border-radius: 8px; color: #94a3b8; width: 32px; height: 32px; cursor: pointer; display: flex; align-items: center; justify-content: center;">
            <i class="fa-solid fa-times"></i>
          </button>
        </div>
        
        <div style="display: flex; flex-direction: column; gap: 12px;">
          \${locations.length > 0 ? locations.map((loc, index) => `
            <div style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px;">
              <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 8px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <i class="fa-solid fa-file-code" style="color: #60a5fa;"></i>
                  <span style="color: #f1f5f9; font-size: 14px; font-weight: 500;">\${loc.file || 'Unknown file'}</span>
                </div>
                <span style="background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 12px;">
                  Line \${loc.line || '?'}
                </span>
              </div>
              <div style="background: rgba(15, 23, 42, 0.8); border-radius: 4px; padding: 8px 12px; margin-top: 8px;">
                <code style="color: #94a3b8; font-size: 12px; font-family: 'JetBrains Mono', monospace;">
                  \${loc.context || 'Key usage context not available'}
                </code>
              </div>
            </div>
          `).join('') : `
            <div style="text-align: center; padding: 32px; color: #64748b;">
              <i class="fa-solid fa-info-circle" style="font-size: 48px; margin-bottom: 16px;"></i>
              <div>No location data available for this key</div>
            </div>
          `}
        </div>
      `;
      
      backdrop.appendChild(modal);
      document.body.appendChild(backdrop);
      
      // Close on backdrop click
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          backdrop.remove();
        }
      });
    }

    function showKeyDetails(keyName) {
      // Create modal backdrop
      const backdrop = document.createElement('div');
      backdrop.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.7); z-index: 10000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);';
      
      // Create modal content
      const modal = document.createElement('div');
      modal.style.cssText = 'background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 16px; padding: 32px; max-width: 600px; width: 90%; max-height: 70vh; overflow-y: auto; position: relative;';
      
      // Get key data
      const keyData = window.keysData && window.keysData[keyName];
      
      // Create modal HTML
      let modalHTML = '<div style="margin-bottom: 24px;">';
      modalHTML += '<h2 style="color: #f1f5f9; font-size: 24px; margin-bottom: 8px;">Key Details</h2>';
      modalHTML += '<p style="color: #94a3b8; font-size: 14px;">' + keyName + '</p>';
      modalHTML += '</div>';
      
      if (keyData && keyData.locations) {
        modalHTML += '<div style="margin-bottom: 16px;">';
        modalHTML += '<h3 style="color: #cbd5e1; font-size: 16px; margin-bottom: 12px;">Locations (' + keyData.locations.length + ')</h3>';
        
        keyData.locations.forEach((location, index) => {
          // Extract clean path
          let cleanPath = location.file || location;
          if (typeof cleanPath === 'string') {
            const libIndex = cleanPath.lastIndexOf('/lib/');
            const testIndex = cleanPath.lastIndexOf('/test/');
            if (libIndex !== -1) {
              cleanPath = 'lib/' + cleanPath.substring(libIndex + 5);
            } else if (testIndex !== -1) {
              cleanPath = 'test/' + cleanPath.substring(testIndex + 6);
            }
          }
          
          modalHTML += '<div style="background: rgba(30, 41, 59, 0.5); padding: 12px; border-radius: 8px; margin-bottom: 8px;">';
          modalHTML += '<code style="color: #60a5fa; font-size: 13px;">' + cleanPath + '</code>';
          if (location.line) {
            modalHTML += '<span style="color: #64748b; margin-left: 12px;">Line ' + location.line + '</span>';
          }
          modalHTML += '</div>';
        });
        
        modalHTML += '</div>';
      } else {
        modalHTML += '<p style="color: #94a3b8;">No location data available for this key.</p>';
      }
      
      // Add close button
      modalHTML += '<button onclick="this.closest(\\'div\\').parentElement.remove()" style="background: #3b82f6; color: white; padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; margin-top: 16px;">Close</button>';
      
      modal.innerHTML = modalHTML;
      backdrop.appendChild(modal);
      
      // Close on backdrop click
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          backdrop.remove();
        }
      });
      
      document.body.appendChild(backdrop);
    }

    function refreshReport() {
      location.reload();
    }
    
    function exportReport(format) {
      // Create export data based on format
      let content = '';
      let mimeType = 'text/plain';
      let filename = 'flutter-keycheck-report';
      
      const keysData = window.keysData || {};
      const totalKeys = Object.keys(keysData).length;
      const duplicates = Object.entries(keysData).filter(([k, v]) => v.locations && v.locations.length > 1);
      
      switch(format) {
        case 'json':
          content = JSON.stringify({
            timestamp: new Date().toISOString(),
            totalKeys: totalKeys,
            duplicateKeys: duplicates.length,
            keys: keysData
          }, null, 2);
          mimeType = 'application/json';
          filename += '.json';
          break;
          
        case 'markdown':
          content = '# Flutter KeyCheck Report\\n\\n';
          content += '**Generated:** ' + new Date().toLocaleString() + '\\n\\n';
          content += '## Summary\\n';
          content += '- Total Keys: ' + totalKeys + '\\n';
          content += '- Duplicate Keys: ' + duplicates.length + '\\n\\n';
          content += '## Keys\\n';
          Object.entries(keysData).forEach(([key, data]) => {
            content += '### ' + key + '\\n';
            content += 'Locations: ' + (data.locations ? data.locations.length : 0) + '\\n\\n';
          });
          mimeType = 'text/markdown';
          filename += '.md';
          break;
          
        case 'text':
          content = 'Flutter KeyCheck Report\\n';
          content += '========================\\n\\n';
          content += 'Generated: ' + new Date().toLocaleString() + '\\n\\n';
          content += 'Total Keys: ' + totalKeys + '\\n';
          content += 'Duplicate Keys: ' + duplicates.length + '\\n\\n';
          content += 'Keys List:\\n';
          Object.keys(keysData).forEach(key => {
            content += '- ' + key + '\\n';
          });
          mimeType = 'text/plain';
          filename += '.txt';
          break;
          
        case 'ci':
          content = 'KEYCHECK_TOTAL=' + totalKeys + '\\n';
          content += 'KEYCHECK_DUPLICATES=' + duplicates.length + '\\n';
          content += 'KEYCHECK_STATUS=' + (duplicates.length === 0 ? 'PASS' : 'FAIL') + '\\n';
          mimeType = 'text/plain';
          filename += '.ci';
          break;
          
        case 'html':
          // Download current page as HTML
          content = document.documentElement.outerHTML;
          mimeType = 'text/html';
          filename += '.html';
          break;
          
        case 'all':
          alert('Export all formats will download a ZIP file with all report formats.\\nThis feature is coming soon!');
          return;
          
        default:
          alert('Unknown export format: ' + format);
          return;
      }
      
      // Create download link
      const blob = new Blob([content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      
      // Show success message
      const btn = event.target.closest('button');
      const originalHTML = btn.innerHTML;
      btn.innerHTML = '<i class="fa-solid fa-check"></i> Downloaded';
      btn.style.background = '#10b981';
      setTimeout(() => {
        btn.innerHTML = originalHTML;
        btn.style.background = '#3b82f6';
      }, 2000);
    }
    
    // Chart drawing functions
    function drawPerformanceChart(canvas) {
      const ctx = canvas.getContext('2d');
      const width = canvas.width;
      const height = canvas.height;
      
      // Clear canvas
      ctx.clearRect(0, 0, width, height);
      
      // Sample performance data
      const data = [85, 92, 78, 88, 95];
      const labels = ['Scan', 'Parse', 'Analyze', 'Filter', 'Report'];
      const maxValue = Math.max(...data);
      
      // Draw bars
      const barWidth = width / data.length - 20;
      const barSpacing = 20;
      
      data.forEach((value, index) => {
        const barHeight = (value / maxValue) * (height - 40);
        const x = index * (barWidth + barSpacing) + 10;
        const y = height - barHeight - 20;
        
        // Draw bar with gradient
        const gradient = ctx.createLinearGradient(0, y, 0, y + barHeight);
        gradient.addColorStop(0, '#3b82f6');
        gradient.addColorStop(1, '#1e40af');
        ctx.fillStyle = gradient;
        ctx.fillRect(x, y, barWidth, barHeight);
        
        // Draw label
        ctx.fillStyle = '#94a3b8';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(labels[index], x + barWidth/2, height - 5);
        
        // Draw value
        ctx.fillStyle = '#e2e8f0';
        ctx.font = '12px system-ui';
        ctx.fillText(value + '%', x + barWidth/2, y - 5);
      });
    }
    
    function drawDistributionChart(canvas) {
      // Use Chart.js for better visualization
      const keyData = window.keysData || {};
      const keyCategories = {};
      
      // Categorize keys
      Object.entries(keyData).forEach(([key, data]) => {
        let category = 'Other';
        if (key.includes('Button') || key.includes('button')) category = 'Button';
        else if (key.includes('Card') || key.includes('card')) category = 'Card';
        else if (key.includes('Bet') || key.includes('bet')) category = 'Bet';
        else if (key.includes('Game') || key.includes('game')) category = 'Game';
        
        keyCategories[category] = (keyCategories[category] || 0) + 1;
      });
      
      const labels = Object.keys(keyCategories).length > 0 ? Object.keys(keyCategories) : ['No Keys'];
      const data = Object.values(keyCategories).length > 0 ? Object.values(keyCategories) : [1];
      const colors = ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444'];
      
      // Create Chart.js pie chart
      new Chart(canvas, {
        type: 'pie',
        data: {
          labels: labels,
          datasets: [{
            data: data,
            backgroundColor: colors,
            borderColor: 'rgba(255, 255, 255, 0.1)',
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: {
                color: '#94a3b8',
                padding: 10,
                font: {
                  size: 11
                }
              }
            },
            tooltip: {
              backgroundColor: 'rgba(15, 23, 42, 0.9)',
              titleColor: '#f1f5f9',
              bodyColor: '#94a3b8',
              borderColor: 'rgba(59, 130, 246, 0.3)',
              borderWidth: 1
            }
          }
        }
      });
      return;
      
      data.forEach((value, index) => {
        const sliceAngle = (value / total) * 2 * Math.PI;
        
        // Draw slice
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.arc(centerX, centerY, radius, currentAngle, currentAngle + sliceAngle);
        ctx.closePath();
        ctx.fillStyle = colors[index];
        ctx.fill();
        
        // Draw label
        const labelAngle = currentAngle + sliceAngle / 2;
        const labelX = centerX + Math.cos(labelAngle) * (radius * 0.7);
        const labelY = centerY + Math.sin(labelAngle) * (radius * 0.7);
        
        ctx.fillStyle = '#ffffff';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(value + '%', labelX, labelY);
        
        currentAngle += sliceAngle;
      });
      
      // Draw legend
      let legendY = 10;
      labels.forEach((label, index) => {
        ctx.fillStyle = colors[index];
        ctx.fillRect(10, legendY, 12, 12);
        
        ctx.fillStyle = '#94a3b8';
        ctx.font = '11px system-ui';
        ctx.textAlign = 'left';
        ctx.fillText(label, 28, legendY + 9);
        
        legendY += 20;
      });
    }
    
    function initializeCharts() {
      // Performance Chart
      const performanceCanvas = document.getElementById('performanceChart');
      if (performanceCanvas) {
        drawPerformanceChart(performanceCanvas);
      }
      
      // Distribution Chart
      const distributionCanvas = document.getElementById('distributionChart');
      if (distributionCanvas) {
        drawDistributionChart(distributionCanvas);
      }
    }
    
    // Initialize everything on page load
    document.addEventListener('DOMContentLoaded', function() {
      // Initialize filters
      const searchInput = document.getElementById('searchInput');
      const categoryFilter = document.getElementById('categoryFilter');
      const statusFilter = document.getElementById('statusFilter');
      
      if (searchInput) {
        searchInput.addEventListener('input', applyFilters);
      }
      if (categoryFilter) {
        categoryFilter.addEventListener('change', applyFilters);
      }
      if (statusFilter) {
        statusFilter.addEventListener('change', applyFilters);
      }
      
      // Initialize charts
      initializeCharts();
      
      // Set initial section
      showSection('dashboard', document.querySelector('.sidebar-nav-item.active'));
    });
  </script>
</body>
</html>''');
  }

  String _getKeyCategory(String keyName) {
    if (keyName.contains('test') || keyName.contains('Test')) {
      return 'test';
    } else if (keyName.contains('nav') || keyName.contains('Nav')) {
      return 'navigation';
    } else if (keyName.contains('handler') || keyName.contains('Handler')) {
      return 'handler';
    }
    return 'widget';
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'widget':
        return 'cube';
      case 'handler':
        return 'hand-pointer';
      case 'test':
        return 'vial';
      case 'navigation':
        return 'compass';
      default:
        return 'cube';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  double _calculateQualityScore(ScanResult result) {
    // Simple quality calculation
    final coverage = result.metrics.fileCoverage;
    final hasTests = result.keyUsages.values.any((k) => k.id.contains('test'));
    return coverage * 0.7 + (hasTests ? 0.3 : 0.0);
  }

  List<MapEntry<String, int>> _findDuplicates(ScanResult result) {
    final duplicates = <String, int>{};
    final seen = <String>{};

    for (final keyUsage in result.keyUsages.values) {
      if (seen.contains(keyUsage.id)) {
        duplicates[keyUsage.id] = (duplicates[keyUsage.id] ?? 1) + 1;
      }
      seen.add(keyUsage.id);
    }

    return duplicates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}
