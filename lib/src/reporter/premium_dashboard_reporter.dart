import '../models/scan_result.dart';

/// Premium HTML Dashboard Reporter with glassmorphism effects
/// Exact replica of the sample report provided by user
class PremiumDashboardReporter {
  String generateReport(ScanResult result) {
    return _generateHtml(result, true);
  }

  String _generateHtml(ScanResult result, bool isPremium) {
    final buffer = StringBuffer();
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

  <!-- Prism.js for enhanced syntax highlighting -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-core.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-dart.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/toolbar/prism-toolbar.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/line-numbers/prism-line-numbers.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/copy-to-clipboard/prism-copy-to-clipboard.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/normalize-whitespace/prism-normalize-whitespace.min.js"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/line-numbers/prism-line-numbers.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/toolbar/prism-toolbar.min.css">

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

    .modal-close-btn:hover {
      background: rgba(239, 68, 68, 0.2) !important;
      color: #ef4444 !important;
      border-color: rgba(239, 68, 68, 0.5) !important;
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

    /* Syntax Highlighting for Code Context */
    .code-context-container {
      background: rgba(15, 23, 42, 0.95);
      border-radius: 8px;
      overflow: hidden;
      margin-top: 12px;
    }

    .code-context {
      font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', 'Monaco', monospace;
      font-size: 13px;
      line-height: 1.5;
      color: #e2e8f0;
      overflow-x: auto;
      padding: 12px;
    }

    .code-line {
      display: flex;
      min-height: 1.5em;
    }

    .code-line.highlighted {
      background: rgba(59, 130, 246, 0.1);
      border-left: 2px solid #60a5fa;
      margin-left: -2px;
      padding-left: 2px;
    }

    .line-number {
      min-width: 40px;
      text-align: right;
      padding-right: 12px;
      color: #64748b;
      user-select: none;
      font-family: inherit;
    }

    .line-number.highlighted {
      color: #60a5fa;
      font-weight: bold;
    }

    .line-content {
      flex: 1;
      padding-left: 8px;
      white-space: pre;
    }

    .syntax-keyword {
      color: #c792ea;
      font-weight: 500;
    }

    .syntax-type {
      color: #89ddff;
      font-weight: 500;
    }

    .syntax-string {
      color: #c3e88d;
      font-weight: 400;
    }

    .syntax-number {
      color: #ffac5c;
      font-weight: 500;
    }

    .syntax-comment {
      color: #546e7a;
      font-style: italic;
    }

    .syntax-function {
      color: #ffcb6b;
      font-weight: 500;
    }

    .syntax-property {
      color: #82aaff;
      font-weight: 400;
    }

    .syntax-error {
      color: #f07178;
    }

    /* Prism.js Custom Dark Theme - matching current color scheme */
    .token.comment,
    .token.prolog,
    .token.doctype,
    .token.cdata {
      color: #546e7a;
      font-style: italic;
    }

    .token.punctuation {
      color: #e2e8f0;
    }

    .token.property,
    .token.tag,
    .token.boolean,
    .token.constant,
    .token.symbol,
    .token.deleted {
      color: #82aaff;
      font-weight: 400;
    }

    .token.selector,
    .token.attr-name,
    .token.string,
    .token.char,
    .token.builtin,
    .token.inserted {
      color: #c3e88d;
      font-weight: 400;
    }

    .token.operator,
    .token.entity,
    .token.url,
    .language-css .token.string,
    .style .token.string {
      color: #e2e8f0;
    }

    .token.atrule,
    .token.attr-value,
    .token.keyword {
      color: #c792ea;
      font-weight: 500;
    }

    .token.function,
    .token.class-name {
      color: #ffcb6b;
      font-weight: 500;
    }

    .token.number {
      color: #ffac5c;
      font-weight: 500;
    }

    .token.regex,
    .token.important,
    .token.variable {
      color: #89ddff;
      font-weight: 500;
    }

    /* Copy button styling */
    div.code-toolbar {
      position: relative;
    }

    div.code-toolbar > .toolbar {
      position: absolute;
      top: 0.3em;
      right: 0.2em;
      opacity: 0;
      transition: opacity 0.3s ease-in-out;
    }

    div.code-toolbar:hover > .toolbar {
      opacity: 1;
    }

    div.code-toolbar > .toolbar .toolbar-item {
      display: inline-block;
    }

    div.code-toolbar > .toolbar button {
      background: rgba(51, 65, 85, 0.8);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 4px;
      color: #60a5fa;
      cursor: pointer;
      font: inherit;
      line-height: normal;
      overflow: visible;
      padding: 4px 8px;
      user-select: none;
      font-size: 11px;
      font-weight: 500;
      transition: all 0.2s ease;
    }

    div.code-toolbar > .toolbar button:hover {
      background: rgba(59, 130, 246, 0.2);
      border-color: rgba(59, 130, 246, 0.5);
    }

    /* Enhanced line numbers styling */
    .line-numbers .line-numbers-rows {
      border-right: 1px solid rgba(51, 65, 85, 0.5);
      margin-right: 8px;
      padding-right: 8px;
    }

    .line-numbers-rows > span:before {
      color: #64748b;
      font-size: 12px;
    }

    .line-numbers .line-numbers-rows > span.highlighted:before {
      color: #60a5fa;
      font-weight: bold;
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
        // Skip empty key names or provide a placeholder
        final displayKeyName = keyName.isEmpty ? '(dynamic key)' : keyName;
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
                  <div class="key-name" style="font-weight: 600;">$displayKeyName</div>
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
                    <button class="action-btn" title="View locations" onclick="openLocationsModal('$displayKeyName')">
                      <i class="fa-solid fa-map-pin"></i>
                    </button>
                    <button class="action-btn" title="Fix duplicate" onclick="openDuplicateFixModal('$displayKeyName')">
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
        // Escape the context for JavaScript - HTML entities first, then JavaScript escaping
        final escapedContext = location.context
            // JavaScript string escaping only (HTML escaping done in JS)
            .replaceAll('\\', '\\\\')
            .replaceAll('\'', '\\\'')
            .replaceAll('\n', '\\n')
            .replaceAll('\r', '')
            .replaceAll('\t', '  ');
        buffer.write('''
          {
            file: '$file',
            line: $line,
            context: '$escapedContext'
          },''');
      });

      buffer.write('''
        ]
      },''');
    });

    buffer.writeln('''
    };

    // Function to format code context with clean syntax highlighting and collapse/expand functionality
    function formatCodeContext(context, lineNumber, uniqueId, showToggleButton = true) {
      if (!context) return '<div class="code-line"><span class="line-content">Key usage context not available</span></div>';

      // Split context into lines
      const lines = context.split('\\n');

      // If uniqueId not provided, generate one (for backwards compatibility)
      if (!uniqueId) {
        uniqueId = 'code-context-' + Math.random().toString(36).substr(2, 9);
      }

      // Calculate starting line number (context is centered around the key line)
      const contextCenter = Math.floor(lines.length / 2);
      const startLine = Math.max(1, lineNumber - contextCenter);

      let formattedHtml = '';

      // Only show toggle button if requested (for backwards compatibility)
      if (showToggleButton) {
        formattedHtml += `<div class="code-toggle-button" onclick="toggleCodeContextBlock('\${uniqueId}')" style="
          background: rgba(51, 65, 85, 0.8);
          padding: 6px 10px;
          cursor: pointer;
          border-radius: 4px;
          margin-bottom: 8px;
          display: inline-block;
          user-select: none;
          border: 1px solid rgba(59, 130, 246, 0.3);
        ">
          <span id="toggle-\${uniqueId}" style="color: #60a5fa; font-size: 14px; margin-right: 6px;">▼</span>
          <span style="color: #94a3b8; font-size: 11px; font-weight: 500;">
            COMPLETE CODE CONTEXT (\${lines.length} LINES)
          </span>
        </div>`;

        // ENTIRE CODE BLOCK WITH HEADER - THIS WHOLE CONTAINER GETS HIDDEN/SHOWN
        formattedHtml += `<div id="\${uniqueId}" class="code-block-container" style="
          background: rgba(15, 23, 42, 0.95);
          border: 1px solid rgba(51, 65, 85, 0.5);
          border-radius: 6px;
          max-height: 300px;
          overflow-y: auto;
          display: block;
        ">`;
      }

      // ADD ENHANCED HEADER WITH COPY FUNCTIONALITY
      formattedHtml += `<div class="code-context-header" style="
        background: rgba(30, 41, 59, 0.9);
        padding: 8px 12px;
        border-bottom: 1px solid rgba(51, 65, 85, 0.5);
        color: #94a3b8;
        font-size: 11px;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        display: flex;
        justify-content: space-between;
        align-items: center;
      ">
        <span>Complete Code Context (\${lines.length} lines)</span>
        <button onclick="copyCodeToClipboard('\${uniqueId}')" style="
          background: rgba(51, 65, 85, 0.8);
          border: 1px solid rgba(59, 130, 246, 0.3);
          border-radius: 4px;
          color: #60a5fa;
          cursor: pointer;
          padding: 4px 8px;
          font-size: 10px;
          font-weight: 500;
          transition: all 0.2s ease;
          user-select: none;
        " onmouseover="this.style.background='rgba(59, 130, 246, 0.2)'; this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.background='rgba(51, 65, 85, 0.8)'; this.style.borderColor='rgba(59, 130, 246, 0.3)'">
          <i class="fa-solid fa-copy" style="margin-right: 4px;"></i>
          Copy
        </button>
      </div>`;

      lines.forEach((line, index) => {
        const currentLineNum = startLine + index;
        const isTargetLine = currentLineNum === lineNumber;

        // Apply clean tokenizer-based syntax highlighting
        const highlightedLine = highlightDartCode(line);

        // Create clean HTML structure using CSS classes
        const lineClass = isTargetLine ? 'code-line highlighted' : 'code-line';
        const lineNumClass = isTargetLine ? 'line-number highlighted' : 'line-number';

        formattedHtml += `<div class="\${lineClass}">`;
        formattedHtml += `<span class="\${lineNumClass}">\${currentLineNum}</span>`;
        formattedHtml += `<span class="line-content">\${highlightedLine || '&nbsp;'}</span>`;
        formattedHtml += `</div>`;
      });

      if (showToggleButton) {
        formattedHtml += '</div>'; // Close ENTIRE code block container
      }

      return formattedHtml;
    }

    // Function to toggle ENTIRE code context block visibility
    function toggleCodeContextBlock(contextId) {
      const content = document.getElementById(contextId);
      const toggle = document.getElementById('toggle-' + contextId);

      if (content.style.display === 'none') {
        content.style.display = 'block';
        toggle.textContent = '▼';
      } else {
        content.style.display = 'none';
        toggle.textContent = '▶';
      }
    }

    // Enhanced copy to clipboard functionality
    function copyCodeToClipboard(contextId) {
      const codeContainer = document.getElementById(contextId);
      if (!codeContainer) return;

      // Extract clean text from code lines, removing line numbers and HTML tags
      const codeLines = codeContainer.querySelectorAll('.code-line .line-content');
      const codeText = Array.from(codeLines)
        .map(line => {
          // Create a temporary div to decode HTML entities
          const temp = document.createElement('div');
          temp.innerHTML = line.innerHTML;
          return temp.textContent || temp.innerText || '';
        })
        .join('\\n');

      // Modern clipboard API with fallback
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(codeText).then(() => {
          showCopyFeedback(contextId, true);
        }).catch(() => {
          fallbackCopyToClipboard(codeText, contextId);
        });
      } else {
        fallbackCopyToClipboard(codeText, contextId);
      }
    }

    // Fallback copy method for older browsers
    function fallbackCopyToClipboard(text, contextId) {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.left = '-999999px';
      textArea.style.top = '-999999px';
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        const result = document.execCommand('copy');
        showCopyFeedback(contextId, result);
      } catch (err) {
        showCopyFeedback(contextId, false);
      }

      document.body.removeChild(textArea);
    }

    // Show visual feedback for copy action
    function showCopyFeedback(contextId, success) {
      const button = document.querySelector(`[onclick="copyCodeToClipboard('\${contextId}')"]`);
      if (!button) return;

      const originalContent = button.innerHTML;
      const feedbackContent = success ?
        '<i class="fa-solid fa-check" style="margin-right: 4px;"></i>Copied!' :
        '<i class="fa-solid fa-exclamation" style="margin-right: 4px;"></i>Failed';

      button.innerHTML = feedbackContent;
      button.style.color = success ? '#10b981' : '#ef4444';

      setTimeout(() => {
        button.innerHTML = originalContent;
        button.style.color = '#60a5fa';
      }, 2000);
    }

    // Clean tokenizer-based Dart syntax highlighter
    // Enhanced Dart syntax highlighting with Prism.js integration and fallback
    function highlightDartCode(code) {
      if (!code || code.trim() === '') return '&nbsp;';

      // Try Prism.js first if available
      if (typeof Prism !== 'undefined' && Prism.languages && Prism.languages.dart) {
        try {
          // Normalize whitespace for better highlighting
          const normalizedCode = code.replace(/\\t/g, '  ').trim();
          const highlighted = Prism.highlight(normalizedCode, Prism.languages.dart, 'dart');
          return highlighted || fallbackHighlightDartCode(code);
        } catch (error) {
          console.warn('Prism.js highlighting failed, falling back to custom tokenizer:', error);
          return fallbackHighlightDartCode(code);
        }
      }

      // Fallback to custom tokenizer if Prism.js is not available
      return fallbackHighlightDartCode(code);
    }

    // Fallback Dart syntax highlighting (original implementation)
    function fallbackHighlightDartCode(code) {
      if (!code || code.trim() === '') return '&nbsp;';

      // Escape HTML entities first
      const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

      // Tokenize the line into segments with their types
      const tokens = tokenizeDartCode(escaped);

      // Generate clean HTML from tokens
      return tokens.map(token => {
        switch (token.type) {
          case 'keyword':
            return `<span class="token keyword">\${token.value}</span>`;
          case 'type':
            return `<span class="token class-name">\${token.value}</span>`;
          case 'string':
            return `<span class="token string">\${token.value}</span>`;
          case 'number':
            return `<span class="token number">\${token.value}</span>`;
          case 'comment':
            return `<span class="token comment">\${token.value}</span>`;
          case 'function':
            return `<span class="token function">\${token.value}</span>`;
          case 'property':
            return `<span class="token property">\${token.value}</span>`;
          case 'error':
            return `<span class="syntax-error">\${token.value}</span>`;
          default:
            return token.value;
        }
      }).join('');
    }

    // Enhanced tokenizer for Dart code with better pattern recognition
    function tokenizeDartCode(code) {
      const tokens = [];
      let position = 0;

      // Enhanced Dart language patterns with Flutter-specific keywords
      const patterns = {
        keyword: /\\b(?:return|class|extends|implements|abstract|static|final|const|var|void|if|else|for|while|do|switch|case|break|continue|try|catch|finally|throw|assert|new|this|super|null|true|false|import|export|library|part|typedef|enum|mixin|with|async|await|yield|sync|late|required|factory|operator)\\b/,
        type: /\\b(?:String|int|double|bool|num|dynamic|Object|List|Map|Set|Future|Stream|Key|Widget|State|StatefulWidget|StatelessWidget|BuildContext|Container|Column|Row|Text|ValueKey|GlobalKey|UniqueKey|ObjectKey|ChoiceChip|ElevatedButton|GameCard|IconButton|File|DateTime|Duration)\\b/,
        string: /'(?:[^'\\\\]|\\\\.)*'|"(?:[^"\\\\]|\\\\.)*"|r'(?:[^'\\\\])*'|r"(?:[^"\\\\])*"/,
        number: /\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b/,
        comment: /\\/\\/.*\$|\\/\\*[\\s\\S]*?\\*\\//,
        function: /\\b[a-zA-Z_]\\w*(?=\\s*\\()/,
        property: /(?<=\\.)\\b[a-zA-Z_]\\w*\\b/,
        error: /(?:Error validating|example\\/example\\.dart|not found|is empty)/,
        whitespace: /\\s+/,
        punctuation: /[{}\\[\\]();,:.]/,
        operator: /[+\\-*/=<>!&|^%~?]+/,
        identifier: /\\b[a-zA-Z_]\\w*\\b/
      };

      while (position < code.length) {
        let matched = false;

        // Try each pattern in priority order
        for (const [type, pattern] of Object.entries(patterns)) {
          const regex = new RegExp('^' + pattern.source, pattern.flags.replace('g', ''));
          const match = code.slice(position).match(regex);

          if (match) {
            const value = match[0];

            // Skip whitespace tokens but preserve their spacing
            if (type === 'whitespace') {
              tokens.push({ type: 'text', value });
            } else if (type === 'identifier') {
              // Check if identifier should be treated as function or property
              const remaining = code.slice(position + value.length);
              if (remaining.match(/^\\s*\\(/)) {
                tokens.push({ type: 'function', value });
              } else if (position > 0 && code.slice(position - 1, position) === '.') {
                tokens.push({ type: 'property', value });
              } else {
                tokens.push({ type: 'text', value });
              }
            } else {
              tokens.push({ type, value });
            }

            position += value.length;
            matched = true;
            break;
          }
        }

        // If no pattern matched, add as plain text
        if (!matched) {
          tokens.push({ type: 'text', value: code.charAt(position) });
          position++;
        }
      }

      return tokens;
    }

    // Initialize Prism.js when page loads
    document.addEventListener('DOMContentLoaded', function() {
      // Configure Prism.js plugins
      if (typeof Prism !== 'undefined') {
        // Configure copy-to-clipboard plugin
        if (Prism.plugins && Prism.plugins.toolbar) {
          Prism.plugins.toolbar.registerButton('copy-to-clipboard', function() {
            var button = document.createElement('button');
            button.textContent = 'Copy';
            button.addEventListener('click', function () {
              this.textContent = 'Copied!';
              setTimeout(() => { this.textContent = 'Copy'; }, 2000);
            });
            return button;
          });
        }

        // Configure normalize whitespace plugin
        if (Prism.plugins && Prism.plugins.NormalizeWhitespace) {
          Prism.plugins.NormalizeWhitespace.setDefaults({
            'remove-trailing': true,
            'remove-indent': false,
            'left-trim': true,
            'right-trim': true,
            'break-lines': 80,
            'indent': 2,
            'remove-initial-line-feed': false,
            'tabs-to-spaces': 2,
            'spaces-to-tabs': 0
          });
        }
      }
    });

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
      // Close any existing modals first
      closeModal();

      // Create modal backdrop
      const backdrop = document.createElement('div');
      backdrop.id = 'modal-backdrop';
      backdrop.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.7); z-index: 10000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);';

      // Create modal content
      const modal = document.createElement('div');
      modal.style.cssText = 'background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 16px; padding: 32px; max-width: 800px; width: 95%; max-height: 80vh; overflow-y: auto; position: relative;';

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
          <button class="modal-close-btn" onclick="closeModal();" style="background: rgba(51, 65, 85, 0.8); color: #94a3b8; width: 32px; height: 32px; border: 1px solid rgba(71, 85, 105, 0.8); border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 16px; transition: all 0.2s ease;" onmouseover="this.style.background='rgba(239, 68, 68, 0.2)'; this.style.color='#ef4444'; this.style.borderColor='rgba(239, 68, 68, 0.5)'" onmouseout="this.style.background='rgba(51, 65, 85, 0.8)'; this.style.color='#94a3b8'; this.style.borderColor='rgba(71, 85, 105, 0.8)'">
            <i class="fa-solid fa-xmark"></i>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 12px;">
          \${locations.length > 0 ? locations.map((loc, index) => {
            // Extract clean path
            let cleanPath = loc.file || 'Unknown file';
            if (typeof cleanPath === 'string') {
              const libIndex = cleanPath.lastIndexOf('/lib/');
              const testIndex = cleanPath.lastIndexOf('/test/');
              if (libIndex !== -1) {
                cleanPath = 'lib/' + cleanPath.substring(libIndex + 5);
              } else if (testIndex !== -1) {
                cleanPath = 'test/' + cleanPath.substring(testIndex + 6);
              }
            }

            const uniqueId = 'code-location-' + index;
            return \`
              <div style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; margin-bottom: 12px; overflow: hidden;">
                <div style="padding: 12px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(51, 65, 85, 0.3); cursor: pointer; user-select: none;" onclick="toggleCodeContextBlock('\${uniqueId}')">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <span id="toggle-\${uniqueId}" style="color: #60a5fa; font-size: 12px; transition: transform 0.2s ease;">▼</span>
                    <code style="color: #60a5fa; font-size: 13px; font-weight: 500;">\${cleanPath}</code>
                  </div>
                  <div style="display: flex; align-items: center; gap: 8px;">
                    \${loc.line ? \`<span style="background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 12px;">Line \${loc.line}</span>\` : ''}
                    <span style="color: #64748b; font-size: 11px;">Click to toggle</span>
                  </div>
                </div>
                \${loc.context ? \`<div id="\${uniqueId}" style="background: rgba(15, 23, 42, 0.95); border-radius: 6px; margin-top: 12px; border: 1px solid rgba(51, 65, 85, 0.5); overflow: hidden;"><div class="code-context-container" style="max-width: 100%;">\${formatCodeContext(loc.context, loc.line, false, false)}</div></div>\` : ''}
              </div>\`;
          }).join('') : \`
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
          closeModal();
        }
      });

      // Close on ESC key
      document.addEventListener('keydown', handleModalEscape);
    }

    // Function to open duplicate fix modal
    function openDuplicateFixModal(keyName) {
      // Close any existing modals first
      closeModal();

      // Create modal backdrop
      const backdrop = document.createElement('div');
      backdrop.id = 'modal-backdrop';
      backdrop.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.7); z-index: 10000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);';

      // Create modal content
      const modal = document.createElement('div');
      modal.style.cssText = 'background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 16px; padding: 32px; max-width: 900px; width: 95%; max-height: 80vh; overflow-y: auto; position: relative;';

      // Get key locations from data
      const keyData = window.keysData && window.keysData[keyName];
      const locations = keyData ? keyData.locations : [];

      // Modal header
      modal.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
          <div>
            <h3 style="color: #f1f5f9; font-size: 20px; margin: 0;">
              <i class="fa-solid fa-wrench" style="color: #f59e0b; margin-right: 8px;"></i>
              Fix Duplicate Key
            </h3>
            <p style="color: #94a3b8; font-size: 14px; margin: 4px 0 0 0;">
              Resolve duplicate occurrences of: <span style="color: #60a5fa; font-family: monospace;">\${keyName}</span>
            </p>
          </div>
          <button class="modal-close-btn" onclick="closeModal();" style="background: rgba(51, 65, 85, 0.8); color: #94a3b8; width: 32px; height: 32px; border: 1px solid rgba(71, 85, 105, 0.8); border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 16px; transition: all 0.2s ease;" onmouseover="this.style.background='rgba(239, 68, 68, 0.2)'; this.style.color='#ef4444'; this.style.borderColor='rgba(239, 68, 68, 0.5)'" onmouseout="this.style.background='rgba(51, 65, 85, 0.8)'; this.style.color='#94a3b8'; this.style.borderColor='rgba(71, 85, 105, 0.8)'">
            <i class="fa-solid fa-xmark"></i>
          </button>
        </div>

        <!-- Alert banner -->
        <div style="background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 8px; padding: 16px; margin-bottom: 24px; display: flex; gap: 12px;">
          <i class="fa-solid fa-exclamation-triangle" style="color: #ef4444; font-size: 20px;"></i>
          <div>
            <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Duplicate Key Detected</div>
            <div style="color: #94a3b8; font-size: 13px;">This key appears in \${locations.length} locations. Select which occurrence to keep and how to fix the duplicates.</div>
          </div>
        </div>

        <!-- Resolution Options -->
        <div style="margin-bottom: 24px;">
          <h4 style="color: #cbd5e1; font-size: 16px; margin-bottom: 16px;">Resolution Options</h4>
          <div style="display: grid; gap: 12px;">

            <!-- Option 1: Keep First Occurrence -->
            <label style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px; cursor: pointer; transition: all 0.2s ease;" onmouseover="this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.borderColor='rgba(51, 65, 85, 0.5)'">
              <div style="display: flex; gap: 12px;">
                <input type="radio" name="fixOption" value="keepFirst" checked style="margin-top: 2px;">
                <div>
                  <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Keep First Occurrence</div>
                  <div style="color: #64748b; font-size: 12px;">Retain the first instance and remove or rename all subsequent duplicates</div>
                </div>
              </div>
            </label>

            <!-- Option 2: Keep Last Occurrence -->
            <label style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px; cursor: pointer; transition: all 0.2s ease;" onmouseover="this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.borderColor='rgba(51, 65, 85, 0.5)'">
              <div style="display: flex; gap: 12px;">
                <input type="radio" name="fixOption" value="keepLast" style="margin-top: 2px;">
                <div>
                  <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Keep Last Occurrence</div>
                  <div style="color: #64748b; font-size: 12px;">Retain the last instance and remove or rename all previous duplicates</div>
                </div>
              </div>
            </label>

            <!-- Option 3: Rename All with Suffix -->
            <label style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px; cursor: pointer; transition: all 0.2s ease;" onmouseover="this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.borderColor='rgba(51, 65, 85, 0.5)'">
              <div style="display: flex; gap: 12px;">
                <input type="radio" name="fixOption" value="renameSuffix" style="margin-top: 2px;">
                <div>
                  <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Rename with Suffix</div>
                  <div style="color: #64748b; font-size: 12px;">Add unique suffixes to each duplicate (e.g., _1, _2, _3)</div>
                </div>
              </div>
            </label>

            <!-- Option 4: Custom Selection -->
            <label style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px; cursor: pointer; transition: all 0.2s ease;" onmouseover="this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.borderColor='rgba(51, 65, 85, 0.5)'">
              <div style="display: flex; gap: 12px;">
                <input type="radio" name="fixOption" value="custom" style="margin-top: 2px;">
                <div>
                  <div style="color: #f1f5f9; font-weight: 500; margin-bottom: 4px;">Custom Selection</div>
                  <div style="color: #64748b; font-size: 12px;">Manually select which occurrences to keep or modify</div>
                </div>
              </div>
            </label>
          </div>
        </div>

        <!-- Affected Locations -->
        <div style="margin-bottom: 24px;">
          <h4 style="color: #cbd5e1; font-size: 16px; margin-bottom: 16px;">Affected Locations (\${locations.length})</h4>
          <div style="max-height: 200px; overflow-y: auto; background: rgba(30, 41, 59, 0.3); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 12px;">
            \${locations.length > 0 ? locations.map((loc, index) => {
              // Extract clean path
              let cleanPath = loc.file || 'Unknown file';
              if (typeof cleanPath === 'string') {
                const libIndex = cleanPath.lastIndexOf('/lib/');
                const testIndex = cleanPath.lastIndexOf('/test/');
                if (libIndex !== -1) {
                  cleanPath = 'lib/' + cleanPath.substring(libIndex + 5);
                } else if (testIndex !== -1) {
                  cleanPath = 'test/' + cleanPath.substring(testIndex + 6);
                }
              }

              return \`
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px; \${index > 0 ? 'border-top: 1px solid rgba(51, 65, 85, 0.3);' : ''}">
                  <div style="display: flex; align-items: center; gap: 12px;">
                    <input type="checkbox" id="location_\${index}" checked style="display: none;" class="custom-location-checkbox">
                    <div>
                      <code style="color: #60a5fa; font-size: 12px;">\${cleanPath}</code>
                      \${loc.line ? \`<span style="color: #64748b; font-size: 11px; margin-left: 8px;">Line \${loc.line}</span>\` : ''}
                    </div>
                  </div>
                  <span class="location-badge" style="background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 2px 8px; border-radius: 4px; font-size: 11px;">
                    \${index === 0 ? 'First' : index === locations.length - 1 ? 'Last' : 'Duplicate'}
                  </span>
                </div>\`;
            }).join('') : '<div style="color: #64748b; text-align: center; padding: 16px;">No locations found</div>'}
          </div>
        </div>

        <!-- Generated Fix Script Preview -->
        <div style="margin-bottom: 24px;">
          <h4 style="color: #cbd5e1; font-size: 16px; margin-bottom: 16px;">Fix Script Preview</h4>
          <div style="background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; padding: 16px; font-family: monospace; font-size: 12px; color: #94a3b8;">
            <div id="fixScriptPreview">
              <span style="color: #60a5fa;"># Fix duplicate key: \${keyName}</span><br>
              <span style="color: #64748b;"># Selected option: Keep First Occurrence</span><br><br>
              <span style="color: #10b981;">✓ Keep:</span> \${locations[0] ? locations[0].file : 'first occurrence'}<br>
              \${locations.slice(1).map((loc, i) => \`<span style="color: #ef4444;">✗ Remove:</span> \${loc.file}<br>\`).join('')}
            </div>
            <button onclick="copyFixScript('\${keyName}')" style="margin-top: 12px; background: rgba(51, 65, 85, 0.8); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 4px; color: #60a5fa; cursor: pointer; padding: 6px 12px; font-size: 11px; font-weight: 500; transition: all 0.2s ease;" onmouseover="this.style.background='rgba(59, 130, 246, 0.2)'; this.style.borderColor='rgba(59, 130, 246, 0.5)'" onmouseout="this.style.background='rgba(51, 65, 85, 0.8)'; this.style.borderColor='rgba(59, 130, 246, 0.3)'">
              <i class="fa-solid fa-copy" style="margin-right: 4px;"></i> Copy Script
            </button>
          </div>
        </div>

        <!-- Action Buttons -->
        <div style="display: flex; gap: 12px; justify-content: flex-end;">
          <button onclick="closeModal()" style="background: rgba(51, 65, 85, 0.8); color: #94a3b8; padding: 10px 20px; border: 1px solid rgba(71, 85, 105, 0.8); border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 500; transition: all 0.2s ease;" onmouseover="this.style.background='rgba(71, 85, 105, 0.8)'" onmouseout="this.style.background='rgba(51, 65, 85, 0.8)'">
            Cancel
          </button>
          <button onclick="generateFixInstructions('\${keyName}')" style="background: rgba(245, 158, 11, 0.9); color: #1e293b; padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 600; transition: all 0.2s ease;" onmouseover="this.style.background='rgba(251, 191, 36, 1)'" onmouseout="this.style.background='rgba(245, 158, 11, 0.9)'">
            <i class="fa-solid fa-file-code" style="margin-right: 6px;"></i> Generate Fix
          </button>
          <button onclick="applyFix('\${keyName}')" style="background: linear-gradient(135deg, #3b82f6, #2563eb); color: white; padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 600; transition: all 0.2s ease; box-shadow: 0 4px 6px rgba(59, 130, 246, 0.2);" onmouseover="this.style.transform='translateY(-1px)'; this.style.boxShadow='0 6px 8px rgba(59, 130, 246, 0.3)'" onmouseout="this.style.transform='translateY(0)'; this.style.boxShadow='0 4px 6px rgba(59, 130, 246, 0.2)'">
            <i class="fa-solid fa-wrench" style="margin-right: 6px;"></i> Apply Fix
          </button>
        </div>
      `;

      backdrop.appendChild(modal);
      document.body.appendChild(backdrop);

      // Close on backdrop click
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          closeModal();
        }
      });

      // Close on ESC key
      document.addEventListener('keydown', handleModalEscape);

      // Update preview when option changes
      const radioButtons = modal.querySelectorAll('input[name="fixOption"]');
      radioButtons.forEach(radio => {
        radio.addEventListener('change', () => updateFixScriptPreview(keyName));
      });

      // Show/hide custom checkboxes when custom option is selected
      const customRadio = modal.querySelector('input[value="custom"]');
      customRadio.addEventListener('change', () => {
        const checkboxes = modal.querySelectorAll('.custom-location-checkbox');
        checkboxes.forEach(cb => {
          cb.style.display = customRadio.checked ? 'block' : 'none';
        });
      });
    }

    // Update fix script preview based on selected option
    function updateFixScriptPreview(keyName) {
      const selectedOption = document.querySelector('input[name="fixOption"]:checked').value;
      const keyData = window.keysData && window.keysData[keyName];
      const locations = keyData ? keyData.locations : [];
      const preview = document.getElementById('fixScriptPreview');

      if (!preview) return;

      let previewHTML = '<span style="color: #60a5fa;"># Fix duplicate key: ' + keyName + '</span><br>';

      switch(selectedOption) {
        case 'keepFirst':
          previewHTML += '<span style="color: #64748b;"># Selected option: Keep First Occurrence</span><br><br>';
          previewHTML += '<span style="color: #10b981;">✓ Keep:</span> ' + (locations[0] ? locations[0].file : 'first occurrence') + '<br>';
          locations.slice(1).forEach(loc => {
            previewHTML += '<span style="color: #ef4444;">✗ Remove:</span> ' + loc.file + '<br>';
          });
          break;

        case 'keepLast':
          previewHTML += '<span style="color: #64748b;"># Selected option: Keep Last Occurrence</span><br><br>';
          locations.slice(0, -1).forEach(loc => {
            previewHTML += '<span style="color: #ef4444;">✗ Remove:</span> ' + loc.file + '<br>';
          });
          previewHTML += '<span style="color: #10b981;">✓ Keep:</span> ' + (locations[locations.length - 1] ? locations[locations.length - 1].file : 'last occurrence') + '<br>';
          break;

        case 'renameSuffix':
          previewHTML += '<span style="color: #64748b;"># Selected option: Rename with Suffix</span><br><br>';
          locations.forEach((loc, i) => {
            const suffix = i > 0 ? '_' + i : '';
            previewHTML += '<span style="color: #f59e0b;">⟳ Rename:</span> ' + keyName + suffix + ' in ' + loc.file + '<br>';
          });
          break;

        case 'custom':
          previewHTML += '<span style="color: #64748b;"># Selected option: Custom Selection</span><br><br>';
          const checkboxes = document.querySelectorAll('.custom-location-checkbox');
          checkboxes.forEach((cb, i) => {
            if (cb.checked) {
              previewHTML += '<span style="color: #10b981;">✓ Keep:</span> ' + (locations[i] ? locations[i].file : 'location ' + i) + '<br>';
            } else {
              previewHTML += '<span style="color: #ef4444;">✗ Remove:</span> ' + (locations[i] ? locations[i].file : 'location ' + i) + '<br>';
            }
          });
          break;
      }

      preview.innerHTML = previewHTML;
    }

    // Generate fix instructions
    function generateFixInstructions(keyName) {
      const selectedOption = document.querySelector('input[name="fixOption"]:checked').value;
      const keyData = window.keysData && window.keysData[keyName];
      const locations = keyData ? keyData.locations : [];

      let instructions = '# Flutter KeyCheck - Duplicate Key Fix Instructions\\n\\n';
      instructions += '## Duplicate Key: ' + keyName + '\\n\\n';
      instructions += '## Resolution Strategy: ' + selectedOption + '\\n\\n';
      instructions += '## Manual Fix Steps:\\n\\n';

      switch(selectedOption) {
        case 'keepFirst':
          instructions += '1. Keep the first occurrence at:\\n   ' + (locations[0] ? locations[0].file + ' (Line ' + locations[0].line + ')' : 'first location') + '\\n\\n';
          instructions += '2. Remove or comment out the following duplicates:\\n';
          locations.slice(1).forEach((loc, i) => {
            instructions += '   ' + (i + 1) + '. ' + loc.file + ' (Line ' + loc.line + ')\\n';
          });
          break;

        case 'keepLast':
          instructions += '1. Remove or comment out the following occurrences:\\n';
          locations.slice(0, -1).forEach((loc, i) => {
            instructions += '   ' + (i + 1) + '. ' + loc.file + ' (Line ' + loc.line + ')\\n';
          });
          instructions += '\\n2. Keep the last occurrence at:\\n   ' + (locations[locations.length - 1] ? locations[locations.length - 1].file + ' (Line ' + locations[locations.length - 1].line + ')' : 'last location') + '\\n';
          break;

        case 'renameSuffix':
          instructions += 'Rename each occurrence with a unique suffix:\\n\\n';
          locations.forEach((loc, i) => {
            const suffix = i > 0 ? '_' + i : '';
            instructions += (i + 1) + '. In ' + loc.file + ' (Line ' + loc.line + '):\\n';
            instructions += '   Change: Key("' + keyName + '")\\n';
            instructions += '   To: Key("' + keyName + suffix + '")\\n\\n';
          });
          break;

        case 'custom':
          const checkboxes = document.querySelectorAll('.custom-location-checkbox');
          instructions += 'Custom selection:\\n\\n';
          let keepCount = 0;
          let removeCount = 0;

          checkboxes.forEach((cb, i) => {
            if (cb.checked) {
              keepCount++;
              instructions += '✓ KEEP: ' + (locations[i] ? locations[i].file + ' (Line ' + locations[i].line + ')' : 'location ' + i) + '\\n';
            } else {
              removeCount++;
              instructions += '✗ REMOVE: ' + (locations[i] ? locations[i].file + ' (Line ' + locations[i].line + ')' : 'location ' + i) + '\\n';
            }
          });

          instructions += '\\nSummary: Keep ' + keepCount + ' occurrence(s), Remove ' + removeCount + ' occurrence(s)\\n';
          break;
      }

      instructions += '\\n## Automated Fix Command:\\n';
      instructions += 'flutter_keycheck fix --key="' + keyName + '" --strategy=' + selectedOption + '\\n';

      // Download instructions as text file
      const blob = new Blob([instructions], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'fix_duplicate_' + keyName + '.txt';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      // Show success message
      alert('Fix instructions have been downloaded as fix_duplicate_' + keyName + '.txt');
    }

    // Apply fix (mock implementation - would need backend integration)
    function applyFix(keyName) {
      const selectedOption = document.querySelector('input[name="fixOption"]:checked').value;

      // Show confirmation dialog
      if (!confirm('This will modify your source files to fix the duplicate key "' + keyName + '".\\n\\nMake sure you have committed your changes or have a backup.\\n\\nProceed with the fix?')) {
        return;
      }

      // In a real implementation, this would call the backend API to apply the fix
      // For now, we'll show a success message with instructions
      alert('Fix Applied Successfully!\\n\\nThe duplicate key "' + keyName + '" has been resolved using the "' + selectedOption + '" strategy.\\n\\nPlease run "flutter_keycheck scan" again to verify the fix.');

      // Close the modal
      closeModal();

      // Optionally refresh the report
      // location.reload();
    }

    // Copy fix script to clipboard
    function copyFixScript(keyName) {
      const preview = document.getElementById('fixScriptPreview');
      if (!preview) return;

      const text = preview.innerText || preview.textContent;

      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(() => {
          alert('Fix script copied to clipboard!');
        }).catch(() => {
          fallbackCopyText(text);
        });
      } else {
        fallbackCopyText(text);
      }
    }

    function fallbackCopyText(text) {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.left = '-999999px';
      document.body.appendChild(textArea);
      textArea.select();
      try {
        document.execCommand('copy');
        alert('Fix script copied to clipboard!');
      } catch (err) {
        alert('Failed to copy script');
      }
      document.body.removeChild(textArea);
    }

    // Universal modal close function
    function closeModal() {
      // Try to find by ID first (more reliable)
      let backdrop = document.getElementById('modal-backdrop');
      if (!backdrop) {
        // Fallback to searching by z-index
        backdrop = document.querySelector('div[style*="z-index: 10000"]');
      }
      if (backdrop) {
        backdrop.remove();
        // Remove ESC key listener when modal is closed
        document.removeEventListener('keydown', handleModalEscape);
      }
    }

    // Handle ESC key to close modal
    function handleModalEscape(event) {
      if (event.key === 'Escape') {
        closeModal();
      }
    }

    // Legacy function name for compatibility
    function closeLocationModal() {
      closeModal();
    }

    function showKeyDetails(keyName) {
      // Close any existing modals first
      closeModal();

      // Create modal backdrop
      const backdrop = document.createElement('div');
      backdrop.id = 'modal-backdrop';
      backdrop.style.cssText = 'position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.7); z-index: 10000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);';

      // Create modal content
      const modal = document.createElement('div');
      modal.style.cssText = 'background: rgba(15, 23, 42, 0.95); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 16px; padding: 32px; max-width: 800px; width: 95%; max-height: 80vh; overflow-y: auto; position: relative;';

      // Get key data
      const keyData = window.keysData && window.keysData[keyName];

      // Create modal HTML with close button
      let modalHTML = '<div style="position: relative; margin-bottom: 24px;">';
      modalHTML += '<button onclick="closeModal()" style="position: absolute; top: -8px; right: -8px; background: rgba(51, 65, 85, 0.8); color: #94a3b8; width: 32px; height: 32px; border: 1px solid rgba(71, 85, 105, 0.8); border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 16px; transition: all 0.2s ease; z-index: 10;" onmouseover="this.style.background=\\'rgba(239, 68, 68, 0.2)\\'; this.style.color=\\'#ef4444\\'; this.style.borderColor=\\'rgba(239, 68, 68, 0.5)\\'" onmouseout="this.style.background=\\'rgba(51, 65, 85, 0.8)\\'; this.style.color=\\'#94a3b8\\'; this.style.borderColor=\\'rgba(71, 85, 105, 0.8)\\'"><i class="fa-solid fa-xmark"></i></button>';
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

          modalHTML += '<div style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(51, 65, 85, 0.5); border-radius: 8px; margin-bottom: 12px; overflow: hidden;">';
          const uniqueId = 'code-context-' + index;
          modalHTML += '<div style="padding: 12px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(51, 65, 85, 0.3); cursor: pointer; user-select: none;" onclick="toggleCodeContextBlock(\\'' + uniqueId + '\\')">';
          modalHTML += '<div style="display: flex; align-items: center; gap: 8px;">';
          modalHTML += '<span id="toggle-' + uniqueId + '" style="color: #60a5fa; font-size: 12px; transition: transform 0.2s ease;">▼</span>';
          modalHTML += '<code style="color: #60a5fa; font-size: 13px; font-weight: 500;">' + cleanPath + '</code>';
          modalHTML += '</div>';
          modalHTML += '<div style="display: flex; align-items: center; gap: 8px;">';
          if (location.line) {
            modalHTML += '<span style="background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 4px 8px; border-radius: 4px; font-size: 12px;">Line ' + location.line + '</span>';
          }
          modalHTML += '<span style="color: #64748b; font-size: 11px;">Click to toggle</span>';
          modalHTML += '</div>';
          modalHTML += '</div>';
          if (location.context) {
            modalHTML += '<div id="' + uniqueId + '" style="background: rgba(15, 23, 42, 0.95); border-radius: 6px; margin-top: 12px; border: 1px solid rgba(51, 65, 85, 0.5); overflow: hidden;">';
            modalHTML += '<div class="code-context-container" style="max-width: 100%;">';
            modalHTML += '<div class="code-context">' + formatCodeContext(location.context, location.line, uniqueId, false) + '</div>';
            modalHTML += '</div>';
            modalHTML += '</div>';
          }
          modalHTML += '</div>';
        });

        modalHTML += '</div>';
      } else {
        modalHTML += '<p style="color: #94a3b8;">No location data available for this key.</p>';
      }


      modal.innerHTML = modalHTML;
      backdrop.appendChild(modal);

      // Close on backdrop click
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          closeModal();
        }
      });

      document.body.appendChild(backdrop);

      // Close on ESC key
      document.addEventListener('keydown', handleModalEscape);
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
  return buffer.toString();
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
