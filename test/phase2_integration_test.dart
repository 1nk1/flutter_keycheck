/// Integration tests for Phase 2 premium reporting features
library;

import 'package:test/test.dart';
import '../lib/src/reporter/base_reporter.dart';
import '../lib/src/reporter/html_reporter.dart';
import '../lib/src/reporter/ci_reporter.dart';
import '../lib/src/quality/quality_scorer.dart';
import '../lib/src/stats/stats_calculator.dart';

void main() {
  group('Phase 2 Premium Reporting Integration Tests', () {
    late ReportData testData;

    setUp(() {
      testData = ReportData(
        expectedKeys: {'loginButton', 'submitButton', 'usernameField', 'passwordField', 'homeScreen'},
        foundKeys: {'loginButton', 'submitButton', 'usernameField', 'extraKey1', 'extraKey2'},
        missingKeys: {'passwordField', 'homeScreen'},
        extraKeys: {'extraKey1', 'extraKey2'},
        keyUsageCounts: {
          'loginButton': 2,
          'submitButton': 1,
          'usernameField': 3,
          'extraKey1': 1,
          'extraKey2': 1,
        },
        keyLocations: {
          'loginButton': [
            {'file': 'lib/screens/login.dart', 'line': 45},
            {'file': 'test/login_test.dart', 'line': 23},
          ],
          'submitButton': [
            {'file': 'lib/screens/login.dart', 'line': 67},
          ],
          'usernameField': [
            {'file': 'lib/screens/login.dart', 'line': 34},
            {'file': 'lib/widgets/form.dart', 'line': 12},
            {'file': 'test/form_test.dart', 'line': 19},
          ],
        },
        scanDuration: Duration(milliseconds: 250),
        scannedFiles: [
          'lib/screens/login.dart',
          'lib/widgets/form.dart',
          'lib/main.dart',
          'test/login_test.dart',
          'test/form_test.dart',
        ],
        projectPath: '/Users/dev/flutter_app',
      );
    });

    group('Quality Scorer Tests', () {
      test('should calculate comprehensive quality breakdown', () {
        final quality = QualityScorer.calculateQuality(
          expectedKeys: testData.expectedKeys,
          foundKeys: testData.foundKeys,
          missingKeys: testData.missingKeys,
          extraKeys: testData.extraKeys,
          keyUsageCounts: testData.keyUsageCounts,
          keyLocations: testData.keyLocations,
          scannedFiles: testData.scannedFiles,
          scanDuration: testData.scanDuration,
        );

        expect(quality.overall, greaterThan(0));
        expect(quality.overall, lessThanOrEqualTo(100));
        expect(quality.coverage, greaterThan(0));
        expect(quality.organization, greaterThan(0));
        expect(quality.consistency, greaterThan(0));
        expect(quality.efficiency, greaterThan(0));
        expect(quality.maintainability, greaterThan(0));
        expect(quality.recommendations, isNotEmpty);
        expect(quality.metrics, isNotEmpty);
      });

      test('should provide actionable recommendations', () {
        final quality = QualityScorer.calculateQuality(
          expectedKeys: testData.expectedKeys,
          foundKeys: testData.foundKeys,
          missingKeys: testData.missingKeys,
          extraKeys: testData.extraKeys,
          keyUsageCounts: testData.keyUsageCounts,
        );

        expect(quality.recommendations, isNotEmpty);
        expect(quality.recommendations.first, contains('Add missing keys'));
      });

      test('should handle edge cases gracefully', () {
        final emptyQuality = QualityScorer.calculateQuality(
          expectedKeys: <String>{},
          foundKeys: <String>{},
          missingKeys: <String>{},
          extraKeys: <String>{},
        );

        expect(emptyQuality.overall, greaterThanOrEqualTo(0));
        expect(emptyQuality.coverage, equals(100.0)); // No expected keys = 100% coverage
      });
    });

    group('Statistics Calculator Tests', () {
      test('should calculate comprehensive statistics', () {
        final stats = StatsCalculator.calculateStatistics(
          expectedKeys: testData.expectedKeys,
          foundKeys: testData.foundKeys,
          missingKeys: testData.missingKeys,
          extraKeys: testData.extraKeys,
          keyUsageCounts: testData.keyUsageCounts,
          keyLocations: testData.keyLocations,
          scannedFiles: testData.scannedFiles,
          scanDuration: testData.scanDuration,
        );

        expect(stats.coverage, isNotEmpty);
        expect(stats.distribution, isNotEmpty);
        expect(stats.usage, isNotEmpty);
        expect(stats.performance, isNotEmpty);
        expect(stats.quality, isNotEmpty);
        expect(stats.trends, isNotEmpty);

        // Verify specific metrics
        expect(stats.coverage['percentage'], equals(60.0)); // 3 out of 5 expected keys found
        expect(stats.performance['scanTimeMs'], equals(250));
      });

      test('should analyze file coverage correctly', () {
        final fileCoverage = StatsCalculator.analyzeFileCoverage(
          keyLocations: testData.keyLocations,
          scannedFiles: testData.scannedFiles,
          foundKeys: testData.foundKeys,
        );

        expect(fileCoverage, isNotEmpty);
        expect(fileCoverage.length, lessThanOrEqualTo(testData.scannedFiles!.length));
        
        final loginFile = fileCoverage.firstWhere(
          (file) => file.filePath.contains('login.dart'),
          orElse: () => throw StateError('Login file not found'),
        );
        
        expect(loginFile.keyCount, greaterThan(0));
        expect(loginFile.coverageScore, greaterThan(0));
      });

      test('should categorize keys properly', () {
        final distribution = StatsCalculator.analyzeKeyDistribution(
          foundKeys: testData.foundKeys,
          keyLocations: testData.keyLocations,
        );

        expect(distribution.byCategory, isNotEmpty);
        expect(distribution.categoryPercentages, isNotEmpty);
        
        // Should categorize loginButton as "Buttons"
        expect(distribution.byCategory['Buttons'], greaterThan(0));
      });
    });

    group('HTML Reporter Tests', () {
      test('should generate premium HTML report', () {
        final reporter = HtmlReporter(
          darkTheme: false,
          includeCharts: true,
          responsive: true,
        );

        final htmlContent = reporter.generate(testData);

        expect(htmlContent, contains('<!DOCTYPE html>'));
        expect(htmlContent, contains('Flutter KeyCheck Report'));
        expect(htmlContent, contains('glassmorphism'));
        expect(htmlContent, contains('Quality Gates'));
        expect(htmlContent, contains('dashboard-grid'));
        expect(htmlContent, contains('chart-container'));
        expect(htmlContent, contains('theme-toggle'));
        expect(htmlContent, contains('window.reportData'));
      });

      test('should generate dark theme HTML report', () {
        final reporter = HtmlReporter(
          darkTheme: true,
          includeCharts: true,
          responsive: true,
        );

        final htmlContent = reporter.generate(testData);

        expect(htmlContent, contains('dark-theme'));
        expect(htmlContent, contains('data-theme="dark"'));
      });

      test('should include interactive features', () {
        final reporter = HtmlReporter();
        final htmlContent = reporter.generate(testData);

        expect(htmlContent, contains('toggleTheme()'));
        expect(htmlContent, contains('initCharts()'));
        expect(htmlContent, contains('initAnimations()'));
        expect(htmlContent, contains('exportReport('));
      });

      test('should escape HTML content properly', () {
        final testDataWithSpecialChars = ReportData(
          expectedKeys: {'<script>alert("xss")</script>'},
          foundKeys: {'<script>alert("xss")</script>'},
          missingKeys: <String>{},
          extraKeys: <String>{},
          projectPath: '/path/with/&<>"\'',
        );

        final reporter = HtmlReporter();
        final htmlContent = reporter.generate(testDataWithSpecialChars);

        expect(htmlContent, isNot(contains('<script>alert("xss")</script>')));
        expect(htmlContent, contains('&lt;script&gt;'));
        expect(htmlContent, contains('&amp;'));
        expect(htmlContent, contains('&quot;'));
      });
    });

    group('CI Reporter Tests', () {
      test('should generate colored CI report', () {
        final reporter = CIReporter(
          enableColors: true,
          enableEmojis: true,
          platform: CIPlatform.generic,
        );

        final ciContent = reporter.generate(testData);

        expect(ciContent, contains('FLUTTER KEYCHECK REPORT'));
        expect(ciContent, contains('Quality Gates'));
        expect(ciContent, contains('CRITICAL: Missing Keys'));
        expect(ciContent, contains('WARNING: Extra Keys'));
        expect(ciContent, contains('✅'));
        expect(ciContent, contains('❌'));
        expect(ciContent, contains('\x1B[')); // ANSI color codes
      });

      test('should generate non-colored CI report', () {
        final reporter = CIReporter(
          enableColors: false,
          enableEmojis: false,
          platform: CIPlatform.jenkins,
        );

        final ciContent = reporter.generate(testData);

        expect(ciContent, contains('FLUTTER KEYCHECK REPORT'));
        expect(ciContent, isNot(contains('\x1B['))); // No ANSI color codes
        expect(ciContent, contains('PASS'));
        expect(ciContent, contains('FAIL'));
      });

      test('should generate GitLab CI collapsible sections', () {
        final reporter = CIReporter(
          platform: CIPlatform.gitlab,
        );

        final ciContent = reporter.generate(testData);

        expect(ciContent, contains('section_start:'));
        expect(ciContent, contains('flutter_keycheck_summary'));
      });

      test('should include performance metrics in verbose mode', () {
        final reporter = CIReporter.autoDetect(verbose: true);
        final ciContent = reporter.generate(testData);

        expect(ciContent, contains('PERFORMANCE'));
        expect(ciContent, contains('Scan Time:'));
        expect(ciContent, contains('Keys/Second:'));
        expect(ciContent, contains('Performance Score:'));
      });

      test('should auto-detect CI platform', () {
        final reporter = CIReporter.autoDetect();
        expect(reporter.platform, isA<CIPlatform>());
      });
    });

    group('Reporter Factory Tests', () {
      test('should create correct reporter types', () {
        expect(ReporterFactory.create('html'), isA<HtmlReporter>());
        expect(ReporterFactory.create('html-premium'), isA<HtmlReporter>());
        expect(ReporterFactory.create('html-dark'), isA<HtmlReporter>());
        expect(ReporterFactory.create('ci'), isA<CIReporter>());
        expect(ReporterFactory.create('ci-verbose'), isA<CIReporter>());
        expect(ReporterFactory.create('json'), isA<JsonReporter>());
        expect(ReporterFactory.create('markdown'), isA<MarkdownReporter>());
        expect(ReporterFactory.create('junit'), isA<JUnitReporter>());
        expect(ReporterFactory.create('human'), isA<HumanReporter>());
        expect(ReporterFactory.create('unknown'), isA<HumanReporter>()); // Default
      });

      test('should list all available formats', () {
        final formats = ReporterFactory.availableFormats;
        
        expect(formats, contains('html'));
        expect(formats, contains('html-premium'));
        expect(formats, contains('html-dark'));
        expect(formats, contains('ci'));
        expect(formats, contains('ci-verbose'));
        expect(formats, contains('json'));
        expect(formats, contains('markdown'));
        expect(formats, contains('junit'));
        expect(formats, contains('human'));
      });
    });

    group('Integration Tests', () {
      test('should generate all report formats without errors', () {
        for (final format in ReporterFactory.availableFormats) {
          final reporter = ReporterFactory.create(format);
          final content = reporter.generate(testData);
          
          expect(content, isNotEmpty, reason: 'Format $format should generate content');
          expect(content.length, greaterThan(100), reason: 'Format $format should generate substantial content');
        }
      });

      test('should maintain data consistency across formats', () {
        final jsonReporter = ReporterFactory.create('json') as JsonReporter;
        final htmlReporter = ReporterFactory.create('html') as HtmlReporter;
        final ciReporter = ReporterFactory.create('ci') as CIReporter;

        final jsonContent = jsonReporter.generate(testData);
        final htmlContent = htmlReporter.generate(testData);
        final ciContent = ciReporter.generate(testData);

        // All should contain project path
        expect(jsonContent, contains(testData.projectPath));
        expect(htmlContent, contains(testData.projectPath));
        expect(ciContent, contains(testData.projectPath));

        // All should reflect the correct coverage percentage
        final expectedCoverage = testData.coverage.toStringAsFixed(1);
        expect(jsonContent, contains(expectedCoverage));
        expect(htmlContent, contains(expectedCoverage));
        expect(ciContent, contains(expectedCoverage));
      });

      test('should handle file writing correctly', () async {
        final tempDir = '/tmp/flutter_keycheck_test_${DateTime.now().millisecondsSinceEpoch}';
        final reporter = ReporterFactory.create('html') as HtmlReporter;

        await reporter.writeToFile(testData, '$tempDir/report.${reporter.fileExtension}');

        // Clean up is handled by OS temp directory cleanup
      });
    });

    group('Quality and Performance Validation', () {
      test('should complete quality analysis within reasonable time', () {
        final stopwatch = Stopwatch()..start();
        
        QualityScorer.calculateQuality(
          expectedKeys: testData.expectedKeys,
          foundKeys: testData.foundKeys,
          missingKeys: testData.missingKeys,
          extraKeys: testData.extraKeys,
          keyUsageCounts: testData.keyUsageCounts,
          keyLocations: testData.keyLocations,
          scannedFiles: testData.scannedFiles,
          scanDuration: testData.scanDuration,
        );
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100), 
               reason: 'Quality analysis should complete quickly');
      });

      test('should complete statistics calculation within reasonable time', () {
        final stopwatch = Stopwatch()..start();
        
        StatsCalculator.calculateStatistics(
          expectedKeys: testData.expectedKeys,
          foundKeys: testData.foundKeys,
          missingKeys: testData.missingKeys,
          extraKeys: testData.extraKeys,
          keyUsageCounts: testData.keyUsageCounts,
          keyLocations: testData.keyLocations,
          scannedFiles: testData.scannedFiles,
          scanDuration: testData.scanDuration,
        );
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(50), 
               reason: 'Statistics calculation should complete quickly');
      });

      test('should generate HTML report within reasonable time', () {
        final stopwatch = Stopwatch()..start();
        final reporter = HtmlReporter();
        
        reporter.generate(testData);
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(200), 
               reason: 'HTML report generation should complete quickly');
      });

      test('should generate CI report within reasonable time', () {
        final stopwatch = Stopwatch()..start();
        final reporter = CIReporter.autoDetect(verbose: true);
        
        reporter.generate(testData);
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100), 
               reason: 'CI report generation should complete quickly');
      });
    });
  });
}