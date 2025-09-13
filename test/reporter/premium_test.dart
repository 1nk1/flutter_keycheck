import 'package:test/test.dart';
import 'package:flutter_keycheck/src/reporter/base_reporter.dart';
import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  group('Premium Report Generation Tests', () {
    late PremiumDashboardReporter premiumReporter;
    late HtmlReporter htmlReporter;
    late ReportData simpleData;
    late ScanResult simpleScanResult;

    setUp(() {
      premiumReporter = PremiumDashboardReporter();
      htmlReporter = HtmlReporter();

      simpleData = ReportData(
        expectedKeys: {'testKey', 'expectedKey'},
        foundKeys: {'testKey'},
        missingKeys: {'expectedKey'},
        extraKeys: {'extraKey'},
        keyUsageCounts: {'testKey': 1},
        keyLocations: {'testKey': ['lib/widget.dart']},
        scannedFiles: ['lib/widget.dart'],
        scanDuration: Duration(milliseconds: 2500),
        projectPath: '/project',
        timestamp: DateTime.now(),
      );

      final metrics = ScanMetrics();
      metrics.fileCoverage = 75.0;
      metrics.totalScanTime = Duration(milliseconds: 2500);
      metrics.scannedFiles = 5;

      final keyUsage = KeyUsage(id: 'testKey');
      final keyLocation = KeyLocation(
        file: 'lib/widget.dart',
        line: 42,
        column: 1,
        detector: 'widget',
        context: 'Widget(key: Key("testKey"));',
      );
      keyUsage.locations.add(keyLocation);
      keyUsage.status = 'active';

      final keyUsage2 = KeyUsage(id: 'inactiveKey');
      keyUsage2.locations.addAll([keyLocation, keyLocation, keyLocation]);
      keyUsage2.status = 'inactive';

      simpleScanResult = ScanResult(
        metrics: metrics,
        fileAnalyses: {'lib/widget.dart': FileAnalysis(path: 'lib/widget.dart', relativePath: 'widget.dart')},
        keyUsages: {'testKey': keyUsage, 'inactiveKey': keyUsage2},
        blindSpots: [],
        duration: Duration(milliseconds: 2500),
      );
    });

    test('PremiumDashboardReporter generates HTML with correct structure', () {
      final html = premiumReporter.generateReport(simpleScanResult);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>Flutter KeyCheck - Scan Report</title>'));
      expect(html, contains('Flutter KeyCheck Dashboard'));
      expect(html, contains('class="sidebar"'));
      expect(html, contains('class="header"'));
      expect(html, contains('class="main-content"'));
      expect(html, contains('id="dashboard-section"'));
      expect(html, contains('Chart.js'));
      expect(html, contains('Prism.js'));
    });

    test('PremiumDashboardReporter includes correct metrics in HTML', () {
      final html = premiumReporter.generateReport(simpleScanResult);
      expect(html, contains('75.0%')); // coverage
      expect(html, contains('2.5s')); // scan time
      expect(html, contains('5')); // files scanned
      expect(html, contains('2')); // total keys
      expect(html, contains('1')); // active keys
    });

    test('PremiumDashboardReporter generates keys table with correct data', () {
      final html = premiumReporter.generateReport(simpleScanResult);
      expect(html, contains('<div class="key-name">testKey</div>'));
      expect(html, contains('class="status-badge active"'));
      expect(html, contains('1 location'));
      expect(html, contains('<div class="key-name">inactiveKey</div>'));
      expect(html, contains('class="status-badge inactive"'));
      expect(html, contains('3 locations')); // duplicate
    });

    test('PremiumDashboardReporter includes JavaScript data for keys', () {
      final html = premiumReporter.generateReport(simpleScanResult);
      expect(html, contains("'testKey': {"));
      expect(html, contains("locations: ["));
      expect(html, contains('file: \'widget.dart\''));
      expect(html, contains('line: 42'));
      expect(html, contains('context: \'Widget(key: Key("testKey"));\''));
    });

    test('PremiumDashboardReporter handles duplicates in analysis section', () {
      final html = premiumReporter.generateReport(simpleScanResult);
      expect(html, contains('Duplicate Keys Found'));
      expect(html, contains('inactiveKey'));
      expect(html, contains('3 occurrences'));
      expect(html, contains('class="status-badge" style="background: rgba(239, 68, 68, 0.1); color: #ef4444;">'));
    });

    test('HtmlReporter generates HTML with dashboard and quality', () {
      final html = htmlReporter.generate(simpleData);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>Flutter KeyCheck Report'));
      expect(html, contains('class="glass-card"'));
      expect(html, contains('Dashboard Overview'));
      expect(html, contains('50.0%')); // coverage
      expect(html, contains('Quality Gates'));
    });

    test('HtmlReporter includes issues section with missing/extra keys', () {
      final htmlReporterPremium = HtmlReporter(isPremium: true);
      final html = htmlReporterPremium.generate(simpleData);
      expect(html, contains('Critical: Missing Keys (1)'));
      expect(html, contains('expectedKey'));
      expect(html, contains('Warning: Extra Keys (1)'));
      expect(html, contains('extraKey'));
    });

    group('Other Formats', () {
      test('JsonReporter generates JSON', () {
        final reporter = JsonReporter();
        final json = reporter.generate(simpleData);
        expect(json, contains('"expectedKeys":'));
        expect(json, contains('"coverage":'));
        expect(json, isNotEmpty);
      });

      test('MarkdownReporter generates Markdown', () {
        final reporter = MarkdownReporter();
        final md = reporter.generate(simpleData);
        expect(md, contains('# Flutter KeyCheck Report'));
        expect(md, contains('| Expected Keys | 2 |'));
        expect(md, contains('Missing Keys'));
        expect(md, contains('expectedKey'));
      });
    });

    group('Premium Behaviors', () {
      test('Full access mode includes all features', () {
        // Tests assume full premium access; no enforcement
        final html = premiumReporter.generateReport(simpleScanResult);
        expect(html.length > 5000, isTrue); // Full output with JS, styles
      });
    });
  });
}