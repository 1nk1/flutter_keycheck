import 'package:test/test.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/policy/policy_engine.dart';

void main() {
  group('Policy Engine', () {
    late PolicyEngine engine;

    setUp(() {
      engine = PolicyEngine();
    });

    test('detects lost critical keys', () {
      final baseline = _createScanResult(['login_button', 'submit_button']);
      final current = _createScanResult(['submit_button']);

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(
          failOnLost: true,
          protectedTags: ['critical'],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.violations.any((v) => v.type == 'lost'), isTrue);
    });

    test('allows non-critical keys to be lost', () {
      // Create baseline with both optional and critical keys
      final baseline = _createScanResult(['optional_key', 'submit_button']);
      // Mark only submit_button as critical
      baseline.keyUsages['submit_button']!.tags.clear();
      baseline.keyUsages['submit_button']!.tags.add('critical');
      baseline.keyUsages['optional_key']!.tags.clear(); // Not critical

      final current = _createScanResult(['submit_button']);
      current.keyUsages['submit_button']!.tags.clear();
      current.keyUsages['submit_button']!.tags.add('critical');

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(
          failOnLost: true,
          protectedTags: ['critical'],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('detects extra keys when configured', () {
      final baseline = _createScanResult(['login_button']);
      final current = _createScanResult(['login_button', 'new_button']);

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(
          failOnExtra: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.violations.any((v) => v.type == 'extra'), isTrue);
    });

    test('detects renamed keys', () {
      // Use keys that will be detected as similar by the _isSimilarKey method
      // The method splits on [._-] and needs >60% similarity
      // app_main -> app_main_view has 66.6% similarity (2 common parts out of 3 total unique)
      final baseline = _createScanResult(['app_main']);
      final current = _createScanResult(['app_main_view']);

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(
          failOnRename: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.violations.any((v) => v.type == 'renamed'), isTrue);
    });

    test('respects max drift threshold', () {
      final baseline = _createScanResult(
        List.generate(100, (i) => 'key_$i'),
      );
      final current = _createScanResult(
        List.generate(90, (i) => 'key_$i'), // 10% lost
      );

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(
          maxDrift: 5, // 5% max
        ),
      );

      expect(result.passed, isFalse);
      expect(result.violations.any((v) => v.type == 'drift'), isTrue);
    });

    test('passes when no violations', () {
      final baseline = _createScanResult(['button1', 'button2']);
      final current = _createScanResult(['button1', 'button2']);

      final result = engine.validate(
        baseline: baseline,
        current: current,
        config: PolicyConfig(),
      );

      expect(result.passed, isTrue);
      expect(result.violations, isEmpty);
    });
  });
}

ScanResult _createScanResult(List<String> keys) {
  final keyUsages = <String, KeyUsage>{};

  for (final key in keys) {
    final usage = KeyUsage(id: key);
    usage.locations.add(KeyLocation(
      file: 'lib/main.dart',
      line: 10,
      column: 0,
      detector: 'ValueKey',
      context: 'ElevatedButton',
    ));
    usage.tags.add('critical');
    keyUsages[key] = usage;
  }

  return ScanResult(
    metrics: ScanMetrics(),
    fileAnalyses: {},
    keyUsages: keyUsages,
    blindSpots: [],
    duration: Duration.zero,
  );
}
