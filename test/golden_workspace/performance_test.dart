import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

@Tags(['nonblocking'])

// Safe-cast helper functions for strongly typed JSON parsing
Map<String, dynamic> asMap(dynamic v) => Map<String, dynamic>.from(v as Map);
int asInt(dynamic v) => (v as num).toInt();
double asDouble(dynamic v) => (v as num).toDouble();
String asString(dynamic v) => v as String;
List<dynamic> asList(dynamic v) => v as List;

void main() {
  // Use absolute paths for reliability
  final currentDir = Directory.current.path;
  final workspaceDir = currentDir.endsWith('golden_workspace')
      ? currentDir
      : p.join(currentDir, 'test', 'golden_workspace');
  final projectRoot = currentDir.endsWith('golden_workspace')
      ? p.dirname(p.dirname(currentDir))
      : currentDir;
  final binPath = p.join(projectRoot, 'bin', 'flutter_keycheck.dart');

  // Environment for deterministic output
  final testEnv = {
    ...Platform.environment,
    'TZ': 'UTC',
    'NO_COLOR': '1',
  };

  group('Performance Measurement Tests', () {
    // Performance baseline file path
    final baselineFile =
        File(p.join(workspaceDir, 'performance_baseline.json'));

    test('measure and record performance baseline', () async {
      // Run scan multiple times to get average
      final measurements = <PerformanceMeasurement>[];

      for (var i = 0; i < 3; i++) {
        final startTime = DateTime.now();
        final startMemory = ProcessInfo.currentRss;

        final result = await Process.run(
          'dart',
          [binPath, 'scan', '--report', 'json'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        final endTime = DateTime.now();
        final endMemory = ProcessInfo.currentRss;

        expect(result.exitCode, equals(0),
            reason: 'Scan should succeed for performance measurement');

        final duration = endTime.difference(startTime).inMilliseconds;
        final memoryDelta = endMemory - startMemory;

        // Parse output to get internal timing if available
        final output = jsonDecode(result.stdout.toString());
        final scanDuration = output['summary']?['scanDuration'] ?? duration;

        measurements.add(PerformanceMeasurement(
          duration: duration,
          scanDuration: scanDuration is int ? scanDuration : duration,
          memoryUsage: memoryDelta,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ));
      }

      // Calculate averages
      final avgDuration =
          measurements.map((m) => m.duration).reduce((a, b) => a + b) ~/
              measurements.length;
      final avgScanDuration =
          measurements.map((m) => m.scanDuration).reduce((a, b) => a + b) ~/
              measurements.length;
      final avgMemory =
          measurements.map((m) => m.memoryUsage).reduce((a, b) => a + b) ~/
              measurements.length;

      // Create or update baseline
      final baseline = PerformanceBaseline(
        avgDuration: avgDuration,
        avgScanDuration: avgScanDuration,
        avgMemoryUsage: avgMemory,
        measurements: measurements,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        version: '3.0.0-rc.1',
      );

      // Save baseline for future comparisons
      await baselineFile.writeAsString(jsonEncode(baseline.toJson()));

      print('Performance baseline recorded:');
      print('  Average duration: ${avgDuration}ms');
      print('  Average scan duration: ${avgScanDuration}ms');
      print('  Average memory delta: ${_formatBytes(avgMemory)}');
    });

    test('compare performance against baseline (±20% threshold)', () async {
      // Skip if no baseline exists yet
      if (!baselineFile.existsSync()) {
        print('No baseline exists yet - run the measure test first');
        return;
      }

      // Load baseline
      final baselineJson = jsonDecode(await baselineFile.readAsString());
      final baseline = PerformanceBaseline.fromJson(baselineJson);

      // Run current scan
      final startTime = DateTime.now();
      final startMemory = ProcessInfo.currentRss;

      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      final endTime = DateTime.now();
      final endMemory = ProcessInfo.currentRss;

      expect(result.exitCode, equals(0));

      final duration = endTime.difference(startTime).inMilliseconds;
      final memoryDelta = endMemory - startMemory;

      // Parse output for internal timing
      // Note: output could be used for extracting internal metrics
      // final output = jsonDecode(result.stdout.toString());
      // final scanDuration = output['summary']?['scanDuration'] ?? duration;

      // Check against thresholds (±20%)
      final durationThreshold = baseline.avgDuration * 0.2;
      final memoryThreshold = baseline.avgMemoryUsage * 0.2;

      // Runtime check
      final durationDiff = (duration - baseline.avgDuration).abs();
      final durationDeviation =
          (durationDiff / baseline.avgDuration * 100).round();

      print('Performance comparison:');
      print(
          '  Runtime: ${duration}ms (baseline: ${baseline.avgDuration}ms, deviation: $durationDeviation%)');

      if (durationDiff > durationThreshold) {
        // Warning, not failure - allows for investigation
        print('  ⚠️ WARNING: Runtime deviation exceeds 20% threshold');
        print(
            '     Expected: ${baseline.avgDuration}ms ± ${durationThreshold.round()}ms');
        print('     Actual: ${duration}ms');
      }

      // Memory check (only if significant)
      // Skip memory checks in CI as container memory is highly variable
      final isCI = Platform.environment['CI'] == 'true';
      if (!isCI && baseline.avgMemoryUsage > 1024 * 1024) {
        // Only check if > 1MB and not in CI
        final memoryDiff = (memoryDelta - baseline.avgMemoryUsage).abs();
        final memoryDeviation =
            (memoryDiff / baseline.avgMemoryUsage * 100).round();

        print(
            '  Memory: ${_formatBytes(memoryDelta)} (baseline: ${_formatBytes(baseline.avgMemoryUsage)}, deviation: $memoryDeviation%)');

        if (memoryDiff > memoryThreshold) {
          print('  ⚠️ WARNING: Memory usage deviation exceeds 20% threshold');
          print(
              '     Expected: ${_formatBytes(baseline.avgMemoryUsage)} ± ${_formatBytes(memoryThreshold.round())}');
          print('     Actual: ${_formatBytes(memoryDelta)}');
        }
      } else if (isCI) {
        print('  Memory: Skipped (CI environment - memory is highly variable)');
      }

      // Pass test but log warnings for CI to capture
      expect(result.exitCode, equals(0),
          reason:
              'Scan should complete successfully regardless of performance');
    });

    test('performance regression detection with failure mode', () async {
      // This test can be run with --fail-on-regression flag in CI
      final failOnRegression =
          Platform.environment['FAIL_ON_PERF_REGRESSION'] == 'true';

      if (!baselineFile.existsSync()) {
        print('No baseline exists - skipping regression test');
        return;
      }

      // Load baseline
      final baselineJson = jsonDecode(await baselineFile.readAsString());
      final baseline = PerformanceBaseline.fromJson(baselineJson);

      // Run scan 3 times for average
      final durations = <int>[];
      final memoryDeltas = <int>[];

      for (var i = 0; i < 3; i++) {
        final startTime = DateTime.now();
        final startMemory = ProcessInfo.currentRss;

        final result = await Process.run(
          'dart',
          [binPath, 'scan', '--report', 'json'],
          workingDirectory: workspaceDir,
          environment: testEnv,
        );

        final endTime = DateTime.now();
        final endMemory = ProcessInfo.currentRss;

        expect(result.exitCode, equals(0));

        durations.add(endTime.difference(startTime).inMilliseconds);
        memoryDeltas.add(endMemory - startMemory);
      }

      // Calculate averages
      final avgDuration = durations.reduce((a, b) => a + b) ~/ durations.length;
      final avgMemory =
          memoryDeltas.reduce((a, b) => a + b) ~/ memoryDeltas.length;

      // Check for regression
      final durationRegression =
          ((avgDuration - baseline.avgDuration) / baseline.avgDuration * 100);

      // Skip memory regression checks in CI
      final isCI = Platform.environment['CI'] == 'true';
      final memoryRegression = !isCI && baseline.avgMemoryUsage > 1024 * 1024
          ? ((avgMemory - baseline.avgMemoryUsage) /
              baseline.avgMemoryUsage *
              100)
          : 0;

      print('Performance regression check:');
      print('  Runtime regression: ${durationRegression.toStringAsFixed(1)}%');
      if (!isCI && baseline.avgMemoryUsage > 1024 * 1024) {
        print('  Memory regression: ${memoryRegression.toStringAsFixed(1)}%');
      } else if (isCI) {
        print('  Memory regression: Skipped (CI environment)');
      }

      // Fail if regression exceeds threshold and flag is set
      if (failOnRegression) {
        expect(durationRegression, lessThan(20),
            reason: 'Runtime regression exceeds 20% threshold');

        // Only check memory regression if not in CI
        if (!isCI && baseline.avgMemoryUsage > 1024 * 1024) {
          expect(memoryRegression, lessThan(20),
              reason: 'Memory regression exceeds 20% threshold');
        }
      }
    });
  });
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

class PerformanceMeasurement {
  final int duration;
  final int scanDuration;
  final int memoryUsage;
  final String timestamp;

  PerformanceMeasurement({
    required this.duration,
    required this.scanDuration,
    required this.memoryUsage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'duration': duration,
        'scanDuration': scanDuration,
        'memoryUsage': memoryUsage,
        'timestamp': timestamp,
      };

  factory PerformanceMeasurement.fromJson(Map<String, dynamic> json) =>
      PerformanceMeasurement(
        duration: asInt(json['duration']),
        scanDuration: asInt(json['scanDuration']),
        memoryUsage: asInt(json['memoryUsage']),
        timestamp: asString(json['timestamp']),
      );
}

class PerformanceBaseline {
  final int avgDuration;
  final int avgScanDuration;
  final int avgMemoryUsage;
  final List<PerformanceMeasurement> measurements;
  final String timestamp;
  final String version;

  PerformanceBaseline({
    required this.avgDuration,
    required this.avgScanDuration,
    required this.avgMemoryUsage,
    required this.measurements,
    required this.timestamp,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'avgDuration': avgDuration,
        'avgScanDuration': avgScanDuration,
        'avgMemoryUsage': avgMemoryUsage,
        'measurements': measurements.map((m) => m.toJson()).toList(),
        'timestamp': timestamp,
        'version': version,
      };

  factory PerformanceBaseline.fromJson(Map<String, dynamic> json) =>
      PerformanceBaseline(
        avgDuration: asInt(json['avgDuration']),
        avgScanDuration: asInt(json['avgScanDuration']),
        avgMemoryUsage: asInt(json['avgMemoryUsage']),
        measurements: asList(json['measurements'])
            .map((m) => PerformanceMeasurement.fromJson(asMap(m)))
            .toList(),
        timestamp: asString(json['timestamp']),
        version: asString(json['version']),
      );
}
