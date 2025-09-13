import 'package:test/test.dart';
import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  group('Visual Modal Code Display Tests', () {
    late PremiumDashboardReporter reporter;

    setUp(() {
      reporter = PremiumDashboardReporter();
    });

    test('should generate HTML with new tokenizer functions', () {
      // Create a simple test case
      final keyUsage = KeyUsage(id: 'test_key');
      keyUsage.locations.add(KeyLocation(
        file: 'test.dart',
        line: 5,
        column: 10,
        detector: 'test',
        context: 'Key("test_key")',
      ));

      final result = ScanResult(
        metrics: ScanMetrics(),
        fileAnalyses: {},
        keyUsages: {'test_key': keyUsage},
        blindSpots: [],
        duration: Duration(milliseconds: 100),
      );

      final html = reporter.generateReport(result);

      // Verify new implementation is present
      expect(html, contains('formatCodeContext'));
      expect(html, contains('highlightDartCode'));
      expect(html, contains('tokenizeDartCode'));
      
      // Verify it contains the expected CSS classes
      expect(html, contains('syntax-keyword'));
      expect(html, contains('syntax-type'));
      expect(html, contains('syntax-string'));
      expect(html, contains('syntax-number'));
      expect(html, contains('syntax-comment'));
      expect(html, contains('syntax-function'));
      expect(html, contains('syntax-property'));
      expect(html, contains('syntax-error'));
    });

    test('should handle empty result gracefully', () {
      final result = ScanResult(
        metrics: ScanMetrics(),
        fileAnalyses: {},
        keyUsages: {},
        blindSpots: [],
        duration: Duration(milliseconds: 50),
      );

      expect(() => reporter.generateReport(result), returnsNormally);
      
      final html = reporter.generateReport(result);
      expect(html, isNotEmpty);
      expect(html, contains('formatCodeContext'));
    });

    test('should escape HTML entities properly', () {
      final keyUsage = KeyUsage(id: 'security_test');
      keyUsage.locations.add(KeyLocation(
        file: 'security.dart',
        line: 1,
        column: 1,
        detector: 'test',
        context: '<script>alert("test")</script>',
      ));

      final result = ScanResult(
        metrics: ScanMetrics(),
        fileAnalyses: {},
        keyUsages: {'security_test': keyUsage},
        blindSpots: [],
        duration: Duration(milliseconds: 100),
      );

      final html = reporter.generateReport(result);
      
      // Should escape HTML entities
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('alert'));
      
      // Should NOT contain raw HTML
      expect(html, isNot(contains('<script>alert')));
    });

    test('should generate valid HTML structure', () {
      final keyUsage = KeyUsage(id: 'structure_test');
      keyUsage.locations.add(KeyLocation(
        file: 'structure.dart',
        line: 10,
        column: 5,
        detector: 'test',
        context: 'final key = Key("structure_test");',
      ));

      final result = ScanResult(
        metrics: ScanMetrics(),
        fileAnalyses: {},
        keyUsages: {'structure_test': keyUsage},
        blindSpots: [],
        duration: Duration(milliseconds: 100),
      );

      final html = reporter.generateReport(result);
      
      // Should start and end with proper HTML tags
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html.trim(), endsWith('</html>'));
      
      // Should contain proper meta tags
      expect(html, contains('<meta charset="UTF-8">'));
      expect(html, contains('<meta name="viewport"'));
      
      // Should contain key dashboard elements
      expect(html, contains('sidebar'));
      expect(html, contains('Flutter KeyCheck - Scan Report'));
    });

    test('should handle multiple keys efficiently', () {
      final keyUsages = <String, KeyUsage>{};
      
      // Create multiple keys with different contexts
      for (int i = 0; i < 10; i++) {
        final keyUsage = KeyUsage(id: 'key_$i');
        keyUsage.locations.add(KeyLocation(
          file: 'test_$i.dart',
          line: i + 1,
          column: 5,
          detector: 'test',
          context: 'Key("key_$i")',
        ));
        keyUsages['key_$i'] = keyUsage;
      }

      final result = ScanResult(
        metrics: ScanMetrics(),
        fileAnalyses: {},
        keyUsages: keyUsages,
        blindSpots: [],
        duration: Duration(milliseconds: 200),
      );

      final stopwatch = Stopwatch()..start();
      final html = reporter.generateReport(result);
      stopwatch.stop();

      expect(html, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(html, contains('formatCodeContext'));
    });
  });
}