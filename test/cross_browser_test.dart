import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter_keycheck/src/reporter/premium_dashboard_reporter.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'test_constants.dart';

/// Cross-browser compatibility tests for HTML reports
/// Validates that generated HTML works across different browsers and screen sizes
void main() {
  group('Cross-Browser Compatibility Tests', () {
    late PremiumDashboardReporter reporter;
    late Directory tempDir;

    setUp(() {
      reporter = PremiumDashboardReporter();
      tempDir = Directory.systemTemp.createTempSync('cross_browser_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('HTML Standards Compliance', () {
      test('should generate valid HTML5', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify HTML5 doctype
        expect(html, startsWith('<!DOCTYPE html>'));
        
        // Verify required HTML5 structure
        expect(html, contains('<html lang="en">'));
        expect(html, contains('<head>'));
        expect(html, contains('<meta charset="UTF-8">'));
        expect(html, contains('</head>'));
        expect(html, contains('<body>'));
        expect(html, contains('</body>'));
        expect(html, contains('</html>'));

        // Verify viewport meta tag for mobile
        expect(html, contains('<meta name="viewport" content="width=device-width, initial-scale=1.0">'));
      });

      test('should use semantic HTML elements', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify semantic structure exists (even if minimal)
        expect(html, contains('<title>'));
        expect(html, contains('<style>'));
        expect(html, contains('<script>'));
        
        // Verify no deprecated HTML elements
        expect(html, isNot(contains('<font')));
        expect(html, isNot(contains('<center')));
        expect(html, isNot(contains('<marquee')));
      });

      test('should have proper CSS standards compliance', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify modern CSS properties are used
        expect(html, contains('display: flex'));
        expect(html, contains('border-radius:'));
        expect(html, contains('box-shadow:'));
        
        // Verify vendor prefixes are included where needed
        expect(html, contains('backdrop-filter:'));
        
        // Verify no deprecated CSS
        expect(html, isNot(contains('filter: alpha(')));
        expect(html, isNot(contains('-ms-filter:')));
      });
    });

    group('Responsive Design Tests', () {
      test('should include responsive viewport configuration', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify viewport meta tag
        expect(html, contains('name="viewport"'));
        expect(html, contains('width=device-width'));
        expect(html, contains('initial-scale=1.0'));
      });

      test('should use flexible layouts', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify flexbox usage for responsive layouts
        expect(html, contains('display: flex'));
        expect(html, contains('flex-direction:'));
        
        // Verify responsive units
        expect(html, contains('vh')); // Viewport height
        expect(html, contains('%')); // Percentage units
        
        // Verify no fixed pixel widths for main layout
        final fixedWidthPattern = RegExp(r'width:\s*\d{3,}px'); // 100+ px widths
        final mainLayoutMatches = fixedWidthPattern.allMatches(html).where((match) {
          final context = html.substring(
            math.max(0, match.start - 100),
            math.min(html.length, match.end + 100)
          );
          // Allow fixed widths for small UI elements like buttons, icons
          return !context.contains('sidebar') && 
                 !context.contains('icon') && 
                 !context.contains('button') &&
                 !context.contains('min-width');
        });
        
        // Main layout should not use large fixed widths
        expect(mainLayoutMatches.length, lessThan(5));
      });

      test('should handle mobile screen sizes', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify mobile-friendly font sizes (not too small)
        final fontSizePattern = RegExp(r'font-size:\s*(\d+)px');
        final fontSizes = fontSizePattern.allMatches(html).map((match) {
          return int.parse(match.group(1)!);
        }).toList();

        // Most font sizes should be >= 12px for mobile readability
        final smallFonts = fontSizes.where((size) => size < 12).length;
        expect(smallFonts / fontSizes.length, lessThan(0.3)); // Less than 30% small fonts

        // Verify touch-friendly interaction areas
        expect(html, contains('padding: 12px')); // Adequate touch targets
        expect(html, contains('min-width: 40px')); // Minimum touch size
      });
    });

    group('Browser Feature Support', () {
      test('should use widely supported CSS features', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify flexbox (supported in all modern browsers)
        expect(html, contains('display: flex'));
        
        // Verify border-radius (widely supported)
        expect(html, contains('border-radius:'));
        
        // Verify box-shadow (widely supported)
        expect(html, contains('box-shadow:'));
        
        // Verify transforms are used carefully
        if (html.contains('transform:')) {
          // Should include vendor prefixes for better compatibility
          expect(html, contains('-webkit-transform:') || !html.contains('transform: rotate'));
        }
      });

      test('should handle modern CSS with fallbacks', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Check for backdrop-filter with potential fallbacks
        if (html.contains('backdrop-filter:')) {
          // Modern feature should be used progressively
          expect(html, contains('background:')); // Fallback background
        }

        // Verify CSS Grid is used carefully (if at all)
        if (html.contains('display: grid')) {
          // Should have flexbox fallbacks
          expect(html, contains('display: flex'));
        }
      });

      test('should avoid problematic JavaScript features', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify no ES6+ features without transpilation
        expect(html, isNot(contains('let '))); // Use var for IE11
        expect(html, isNot(contains('const '))); // Use var for IE11
        expect(html, isNot(contains('=>'))); // Arrow functions
        expect(html, isNot(contains('`template'))); // Template literals
        
        // Verify no modern APIs without polyfills
        expect(html, isNot(contains('.find(')));
        expect(html, isNot(contains('.includes(')));
      });
    });

    group('Font and Typography Tests', () {
      test('should use web-safe font stacks', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify fallback font stacks
        expect(html, contains('font-family:'));
        
        // Should include system fonts and web-safe fallbacks
        expect(html, contains('sans-serif') || contains('serif') || contains('monospace'));
        
        // Verify Google Fonts loading (if used)
        if (html.contains('fonts.googleapis.com')) {
          expect(html, contains('display=swap')); // For better loading performance
        }
      });

      test('should handle font loading gracefully', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify font preloading hints
        expect(html, contains('preconnect'));
        
        // Verify font-display for better loading
        if (html.contains('@font-face') || html.contains('fonts.googleapis.com')) {
          expect(html, contains('display=swap') || contains('font-display: swap'));
        }
      });
    });

    group('JavaScript Compatibility Tests', () {
      test('should use compatible JavaScript patterns', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify no strict mode issues
        expect(html, isNot(contains('use strict')));
        
        // Verify compatible event handling
        expect(html, contains('addEventListener'));
        expect(html, isNot(contains('attachEvent'))); // IE-specific
        
        // Verify compatible DOM methods
        expect(html, contains('querySelector') || contains('getElementById'));
        expect(html, isNot(contains('document.all'))); // IE-specific
      });

      test('should handle DOM manipulation safely', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify safe DOM insertion
        expect(html, contains('innerHTML') || contains('textContent'));
        
        // Verify no eval or dangerous patterns
        expect(html, isNot(contains('eval(')));
        expect(html, isNot(contains('document.write(')));
        expect(html, isNot(contains('setTimeout("')));
      });
    });

    group('Performance Tests', () {
      test('should optimize for loading performance', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify external resources are optimized
        if (html.contains('cdn.jsdelivr.net') || html.contains('cdnjs.cloudflare.com')) {
          expect(html, contains('https://')); // Secure loading
        }

        // Verify CSS is embedded or optimized
        expect(html, contains('<style>')); // Embedded CSS reduces requests
        
        // Verify minimal external dependencies
        final externalResources = RegExp(r'https://[^"\']+').allMatches(html);
        expect(externalResources.length, lessThan(10)); // Keep external deps low
      });

      test('should minimize DOM complexity', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify reasonable DOM depth
        final maxNesting = _calculateMaxNestingDepth(html);
        expect(maxNesting, lessThan(15)); // Reasonable nesting depth

        // Verify no excessive empty elements
        final emptyDivs = RegExp(r'<div[^>]*></div>').allMatches(html);
        expect(emptyDivs.length, lessThan(5)); // Minimal empty divs
      });
    });

    group('Accessibility Tests', () {
      test('should include basic accessibility features', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify lang attribute
        expect(html, contains('lang="en"'));
        
        // Verify color contrast considerations
        expect(html, contains('color: #')); // Explicit colors defined
        expect(html, contains('background:')); // Background colors defined
        
        // Verify no accessibility anti-patterns
        expect(html, isNot(contains('color: red; background: green;')));
      });

      test('should support keyboard navigation', () {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Verify focusable elements have proper handling
        if (html.contains('tabindex')) {
          expect(html, isNot(contains('tabindex="-1"'))); // Avoid removing from tab order
        }

        // Verify button elements are used properly
        if (html.contains('onclick')) {
          // Interactive elements should be proper buttons or links
          expect(html, contains('<button') || contains('<a href'));
        }
      });
    });

    group('File Generation Tests', () {
      test('should generate valid file for browser testing', () async {
        final result = _createSampleScanResult();
        final html = reporter.generateReport(result);

        // Write test file
        final testFile = File(path.join(tempDir.path, 'browser_test.html'));
        await testFile.writeAsString(html);

        expect(testFile.existsSync(), isTrue);
        expect(testFile.lengthSync(), greaterThan(1000));

        // Verify file can be read back correctly
        final readHtml = await testFile.readAsString();
        expect(readHtml, equals(html));
        
        print('Browser test file generated: ${testFile.path}');
        print('File size: ${(testFile.lengthSync() / 1024).toStringAsFixed(1)}KB');
      });

      test('should handle file system encoding correctly', () async {
        // Create result with unicode content
        final keyUsage = KeyUsage(
          key: 'unicodeKey',
          type: 'Key',
          value: 'unicode_test',
          filePath: '/test/lib/unicode.dart',
          lineNumber: 10,
          context: 'Text("Unicode test: 你好 🌍 Café naïve résumé");',
          locations: [
            KeyLocation(
              file: '/test/lib/unicode.dart',
              line: 10,
              context: 'Text("Unicode test: 你好 🌍 Café naïve résumé");',
            ),
          ],
        );

        final result = ScanResult(
          keyUsages: {'unicodeKey': keyUsage},
          metrics: ScanMetrics(
            scannedFiles: 1,
            totalScanTime: Duration(milliseconds: 100),
            fileCoverage: 95.0,
          ),
        );

        final html = reporter.generateReport(result);
        
        // Write unicode test file
        final unicodeFile = File(path.join(tempDir.path, 'unicode_test.html'));
        await unicodeFile.writeAsString(html, encoding: utf8);

        expect(unicodeFile.existsSync(), isTrue);

        // Verify unicode content is preserved
        final readHtml = await unicodeFile.readAsString(encoding: utf8);
        expect(readHtml, contains('Unicode test'));
        expect(readHtml, contains('你好'));
        expect(readHtml, contains('🌍'));
        expect(readHtml, contains('Café'));
        
        print('Unicode test file generated successfully');
      });
    });
  });
}

/// Helper function to create sample scan result
ScanResult _createSampleScanResult() {
  final keyUsage1 = KeyUsage(
    key: 'testKey1',
    type: 'Key',
    value: 'test_key_1',
    filePath: '/test/lib/test1.dart',
    lineNumber: 15,
    context: '''Container(
  key: Key('testKey1'),
  child: Text('Test 1'),
)''',
    locations: [
      KeyLocation(
        file: '/test/lib/test1.dart',
        line: 15,
        context: 'Container(key: Key("testKey1"), child: Text("Test 1"))',
      ),
    ],
  );

  final keyUsage2 = KeyUsage(
    key: 'testKey2',
    type: 'ValueKey',
    value: 'test_key_2',
    filePath: '/test/lib/test2.dart',
    lineNumber: 25,
    context: '''ElevatedButton(key: Key("elevated_btn_${RANDOM}"), 
  key: ValueKey('testKey2'),
  onPressed: () {},
  child: Text('Button'),
)''',
    locations: [
      KeyLocation(
        file: '/test/lib/test2.dart',
        line: 25,
        context: 'ElevatedButton(key: Key("elevated_btn_${RANDOM}"), key: ValueKey("testKey2"), onPressed: () {}, child: Text("Button"))',
      ),
    ],
  );

  return ScanResult(
    keyUsages: {
      'testKey1': keyUsage1,
      'testKey2': keyUsage2,
    },
    metrics: ScanMetrics(
      scannedFiles: 2,
      totalScanTime: Duration(milliseconds: 150),
      fileCoverage: 92.5,
    ),
  );
}

/// Calculate maximum nesting depth in HTML
int _calculateMaxNestingDepth(String html) {
  int maxDepth = 0;
  int currentDepth = 0;
  
  final tagPattern = RegExp(r'<(\/?[^>]+)>');
  final matches = tagPattern.allMatches(html);
  
  for (final match in matches) {
    final tag = match.group(1)!;
    
    if (tag.startsWith('/')) {
      // Closing tag
      currentDepth--;
    } else if (!tag.endsWith('/')) {
      // Opening tag (not self-closing)
      currentDepth++;
      maxDepth = math.max(maxDepth, currentDepth);
    }
  }
  
  return maxDepth;
}

// Import math for max function
import 'dart:math' as math;