import 'package:test/test.dart';
import 'package:flutter_keycheck/src/policy/policy_engine.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';

void main() {
  group('Policy Engine', () {
    late PolicyEngine engine;
    late ScanResult baseline;
    late ScanResult current;

    setUp(() {
      engine = PolicyEngine(
        strict: false,
        failOnLost: true,
        failOnRename: false,
        failOnExtra: false,
        protectedTags: ['critical', 'aqa'],
        maxDrift: 10.0,
      );

      // Create baseline scan result
      baseline = _createScanResult({
        'login_button': ['critical', 'aqa'],
        'submit_button': ['aqa'],
        'cancel_button': [],
        'profile_link': ['navigation'],
      });

      // Current scan starts as copy of baseline
      current = baseline;
    });

    group('Lost Keys Detection', () {
      test('detects lost keys', () async {
        // Remove a key from current
        current = _createScanResult({
          'login_button': ['critical', 'aqa'],
          'submit_button': ['aqa'],
          // 'cancel_button' is missing
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.summary.lostKeys, equals(1));
        expect(result.violations, isNotEmpty);
      });

      test('protected tags trigger error severity', () async {
        // Remove a critical key
        current = _createScanResult({
          // 'login_button' is missing (has critical tag)
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        final violation = result.violations.firstWhere(
          (v) => v.key?.id == 'login_button',
        );
        expect(violation.severity, equals('error'));
        expect(violation.type, equals('lost'));
      });

      test('non-protected keys trigger warning in non-strict mode', () async {
        // Remove a non-critical key
        current = _createScanResult({
          'login_button': ['critical', 'aqa'],
          'submit_button': ['aqa'],
          // 'cancel_button' is missing (no protected tags)
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        // In non-strict mode with failOnLost, non-protected keys are warnings
        expect(result.warnings, isNotEmpty);
      });
    });

    group('Renamed Keys Detection', () {
      test('detects renamed keys using similarity heuristic', () async {
        current = _createScanResult({
          'auth.login_button': ['critical', 'aqa'], // renamed from login_button
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.summary.renamedKeys, greaterThan(0));
      });

      test('respects failOnRename policy', () async {
        engine = PolicyEngine(
          strict: false,
          failOnLost: true,
          failOnRename: true, // Enable fail on rename
          failOnExtra: false,
          protectedTags: ['critical', 'aqa'],
          maxDrift: 10.0,
        );

        current = _createScanResult({
          'auth_login_button': ['critical', 'aqa'], // renamed
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.violations.any((v) => v.type == 'renamed'), isTrue);
      });
    });

    group('Extra Keys Detection', () {
      test('detects extra keys', () async {
        current = _createScanResult({
          'login_button': ['critical', 'aqa'],
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
          'new_feature_button': [], // Extra key
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.summary.addedKeys, equals(1));
      });

      test('respects failOnExtra policy', () async {
        engine = PolicyEngine(
          strict: false,
          failOnLost: true,
          failOnRename: false,
          failOnExtra: true, // Enable fail on extra
          protectedTags: ['critical', 'aqa'],
          maxDrift: 10.0,
        );

        current = _createScanResult({
          'login_button': ['critical', 'aqa'],
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
          'extra_button': [], // Extra key
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.violations.any((v) => v.type == 'extra'), isTrue);
      });
    });

    group('Drift Calculation', () {
      test('calculates drift percentage correctly', () async {
        // Remove 2 keys and add 1 (3 changes out of 4 baseline keys = 75% drift)
        current = _createScanResult({
          // 'login_button' missing
          // 'submit_button' missing
          'cancel_button': [],
          'profile_link': ['navigation'],
          'new_button': [], // Added
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.summary.driftPercentage, equals(75.0));
      });

      test('triggers violation when drift exceeds threshold', () async {
        engine = PolicyEngine(
          strict: false,
          failOnLost: false,
          failOnRename: false,
          failOnExtra: false,
          protectedTags: ['critical', 'aqa'],
          maxDrift: 5.0, // Low threshold
        );

        // Make changes that exceed 5% drift
        current = _createScanResult({
          'submit_button': ['aqa'],
          'cancel_button': [],
          'profile_link': ['navigation'],
          'new_button': [],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.violations.any((v) => v.type == 'drift'), isTrue);
      });
    });

    group('Deprecated Keys', () {
      test('warns about deprecated keys still in use', () async {
        baseline = _createScanResult({
          'old_button': [],
        }, statuses: {
          'old_button': 'deprecated',
        });

        current = _createScanResult({
          'old_button': [],
        }, statuses: {
          'old_button': 'deprecated',
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        expect(result.summary.deprecatedInUse, equals(1));
        expect(result.warnings, contains(contains('deprecated')));
      });
    });

    group('Strict Mode', () {
      test('strict mode treats all lost keys as violations', () async {
        engine = PolicyEngine(
          strict: true, // Enable strict mode
          failOnLost: true,
          failOnRename: false,
          failOnExtra: false,
          protectedTags: ['critical', 'aqa'],
          maxDrift: 10.0,
        );

        // Remove a non-protected key
        current = _createScanResult({
          'login_button': ['critical', 'aqa'],
          'submit_button': ['aqa'],
          // 'cancel_button' missing (no protected tags)
          'profile_link': ['navigation'],
        });

        final result = await engine.validate(
          baseline: baseline,
          current: current,
        );

        // In strict mode, even non-protected keys cause violations
        expect(result.violations.any(
          (v) => v.key?.id == 'cancel_button' && v.type == 'lost',
        ), isTrue);
      });
    });
  });
}

ScanResult _createScanResult(
  Map<String, List<String>> keys, {
  Map<String, String>? statuses,
}) {
  final keyUsages = <String, KeyUsage>{};
  
  for (final entry in keys.entries) {
    final usage = KeyUsage(id: entry.key);
    usage.tags.addAll(entry.value);
    usage.status = statuses?[entry.key] ?? 'active';
    usage.locations.add(KeyLocation(
      file: 'lib/test.dart',
      line: 1,
      column: 1,
      detector: 'Test',
      context: 'test',
    ));
    keyUsages[entry.key] = usage;
  }

  return ScanResult(
    metrics: ScanMetrics(),
    fileAnalyses: {},
    keyUsages: keyUsages,
    blindSpots: [],
    duration: Duration.zero,
  );
}