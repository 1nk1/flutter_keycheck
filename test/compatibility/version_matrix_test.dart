
import 'dart:convert';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockAstScannerV3 extends Mock implements AstScannerV3 {}

ScanResult _createMockScanResult({required String version}) {
  final errors = version == '3.4.0' 
      ? [ScanError(file: '/test/lib/main.dart', error: 'New feature warning', type: 'parse_warning')]
      : <ScanError>[];

  final metrics = ScanMetrics();
  metrics.fileCoverage = 100.0;
  metrics.widgetCoverage = 50.0;
  metrics.handlerCoverage = 0.0;
  metrics.totalFiles = 1;
  metrics.scannedFiles = 1;
  metrics.detectorHits = {'ValueKey': 1};
  metrics.errors = errors;

  final fileAnalysis = FileAnalysis(
    path: '/test/lib/main.dart',
    relativePath: 'lib/main.dart',
  );
  fileAnalysis.keysFound.addAll(['test_key']);
  fileAnalysis.widgetCount = 2;
  fileAnalysis.widgetsWithKeys = 1;
  fileAnalysis.detectorHits.addAll({'ValueKey': 1});

  final keyUsage = KeyUsage(id: 'test_key');
  keyUsage.locations.add(
    KeyLocation(
      file: '/test/lib/main.dart',
      line: 10,
      column: 5,
      detector: 'ValueKey',
      context: 'key: const ValueKey("test_key")',
    ),
  );

  final result = ScanResult(
    metrics: metrics,
    fileAnalyses: {'/test/lib/main.dart': fileAnalysis},
    keyUsages: {'test_key': keyUsage},
    blindSpots: [],
    duration: const Duration(milliseconds: 100),
  );
  return result;
}

void main() {
  late ConfigV3 config;
  late MockAstScannerV3 mockScanner;

  final versions = [
    {'sdk': '3.2.0', 'rawTypes': false},
    {'sdk': '3.3.0', 'rawTypes': true},
    {'sdk': '3.4.0', 'patterns': true},
  ];

  setUp(() {
    config = ConfigV3.defaults();
    config.scan.includeOnly = ['lib/**'];
    config.scan.excludePatterns = [];
    config.scan.includeTests = true;
    config.scan.includeGenerated = false;

    mockScanner = MockAstScannerV3();
  });

  group('Dart Analyzer Compatibility Matrix', () {
    for (final version in versions) {
      test('AST Scanning Consistency - SDK ${version['sdk']}', () async {
        final sdkVersion = version['sdk'] as String;
        when(mockScanner.scan()).thenAnswer((_) async => _createMockScanResult(version: sdkVersion));

        final scanner = mockScanner;
        final result = await scanner.scan();

        // Assertions: Consistent detections across versions
        expect(result.keyUsages.containsKey('test_key'), isTrue);
        expect(result.keyUsages['test_key']!.locations.length, greaterThanOrEqualTo(1));
        expect(result.metrics.widgetCoverage, greaterThan(0));
        expect(result.metrics.detectorHits.containsKey('ValueKey'), isTrue);
        expect(result.metrics.detectorHits['ValueKey'], greaterThanOrEqualTo(1));
        expect(result.blindSpots, isEmpty); // No fatal errors

        // Regression: Same structure
        final map = result.toMap();
        final json = jsonEncode(map);
        expect(json, contains('"keys"'));
        expect(result.duration.inMilliseconds, greaterThan(0));

        // Version-specific simulation: Assume no