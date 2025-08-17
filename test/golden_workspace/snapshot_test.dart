import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
    'NO_COLOR': '1', // Disable colored output for deterministic results
  };

  group('Snapshot Comparison Tests', () {
    final expectedSnapshotPath = p.join(workspaceDir, 'expected_keycheck.json');

    setUpAll(() {
      // Verify expected snapshot exists
      expect(File(expectedSnapshotPath).existsSync(), isTrue,
          reason: 'Expected snapshot must exist at $expectedSnapshotPath');
    });

    test('scan output matches expected snapshot (tolerant comparison)',
        () async {
      // Load expected snapshot
      final expectedFile = File(expectedSnapshotPath);
      final expectedJson = jsonDecode(await expectedFile.readAsString());

      // Run actual scan
      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      expect(result.exitCode, equals(0),
          reason: 'Scan should succeed with exit code 0');

      final actualJson = jsonDecode(result.stdout.toString());

      // Tolerant comparison - ignore timestamps and ordering
      _compareSnapshots(expectedJson, actualJson);
    });

    test('detects snapshot format changes', () async {
      // Run scan
      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      expect(result.exitCode, equals(0));
      final actualJson = jsonDecode(result.stdout.toString());

      // Check critical fields that must not change
      expect(actualJson, contains('schemaVersion'),
          reason: 'Schema version field must be present');
      expect(actualJson['schemaVersion'], equals('1.0'),
          reason: 'Schema version must remain 1.0');

      expect(actualJson, contains('keys'),
          reason: 'Keys array must be present');
      expect(actualJson['keys'], isList, reason: 'Keys must be an array');

      expect(actualJson, contains('summary'),
          reason: 'Summary object must be present');
      expect(actualJson['summary'], isMap, reason: 'Summary must be an object');
    });

    test('detects missing critical keys', () async {
      final expectedFile = File(expectedSnapshotPath);
      final expectedJson = jsonDecode(await expectedFile.readAsString());

      // Extract critical keys from expected snapshot
      final expectedCriticalKeys = (expectedJson['keys'] as List)
          .where((k) => k['critical'] == true)
          .map((k) => k['key'] as String)
          .toSet();

      // Run actual scan
      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      expect(result.exitCode, equals(0));
      final actualJson = jsonDecode(result.stdout.toString());

      // Extract actual keys
      final actualKeys =
          (actualJson['keys'] as List).map((k) => k['key'] as String).toSet();

      // Verify all critical keys are present
      for (final criticalKey in expectedCriticalKeys) {
        expect(actualKeys, contains(criticalKey),
            reason:
                'Critical key "$criticalKey" must be present in scan output');
      }
    });

    test('detects unexpected new keys', () async {
      final expectedFile = File(expectedSnapshotPath);
      final expectedJson = jsonDecode(await expectedFile.readAsString());

      // Extract expected keys
      final expectedKeys =
          (expectedJson['keys'] as List).map((k) => k['key'] as String).toSet();

      // Run actual scan
      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      expect(result.exitCode, equals(0));
      final actualJson = jsonDecode(result.stdout.toString());

      // Extract actual keys
      final actualKeys =
          (actualJson['keys'] as List).map((k) => k['key'] as String).toSet();

      // Find unexpected keys (this is informational, not a failure)
      final unexpectedKeys = actualKeys.difference(expectedKeys);
      if (unexpectedKeys.isNotEmpty) {
        print(
            'INFO: New keys detected that are not in snapshot: $unexpectedKeys');
        // This is not a failure - just informational
        // Teams can decide if new keys should trigger a snapshot update
      }
    });

    test('validates snapshot structure consistency', () async {
      // Note: expectedFile could be used to validate structure
      // final expectedFile = File(expectedSnapshotPath);
      // final expectedJson = jsonDecode(await expectedFile.readAsString());

      // Run actual scan
      final result = await Process.run(
        'dart',
        [binPath, 'scan', '--report', 'json'],
        workingDirectory: workspaceDir,
        environment: testEnv,
      );

      expect(result.exitCode, equals(0));
      final actualJson = jsonDecode(result.stdout.toString());

      // Verify structure of each key entry
      final actualKeys = actualJson['keys'] as List;
      for (final keyEntry in actualKeys) {
        expect(keyEntry, isMap, reason: 'Each key entry must be an object');
        expect(keyEntry, contains('key'),
            reason: 'Each key entry must have a "key" field');
        expect(keyEntry, contains('file'),
            reason: 'Each key entry must have a "file" field');
        expect(keyEntry, contains('line'),
            reason: 'Each key entry must have a "line" field');
        expect(keyEntry, contains('type'),
            reason: 'Each key entry must have a "type" field');
      }

      // Verify summary structure (use safe access)
      final summary = actualJson['summary'] ?? actualJson['metrics'] ?? {};
      final totalKeysField = summary.containsKey('totalKeys') ? 'totalKeys' : 'total_keys';
      final filesScannedField = summary.containsKey('filesScanned') ? 'filesScanned' : 'scanned_files';
      
      expect(summary, contains(totalKeysField),
          reason: 'Summary must contain totalKeys or total_keys');
      expect(summary, contains(filesScannedField),
          reason: 'Summary must contain filesScanned or scanned_files');
    });
  });
}

/// Safe getter for total keys with fallback
int _safeGetTotalKeys(Map<String, dynamic> json) {
  final summary = json['summary'] as Map<String, dynamic>?;
  if (summary != null) {
    if (summary.containsKey('totalKeys')) return asInt(summary['totalKeys']);
    if (summary.containsKey('total_keys')) return asInt(summary['total_keys']);
  }
  
  final metrics = json['metrics'] as Map<String, dynamic>?;
  if (metrics != null) {
    if (metrics.containsKey('total_keys')) return asInt(metrics['total_keys']);
  }
  
  // Fallback to keys array length
  final keys = json['keys'] as List?;
  return keys?.length ?? 0;
}

/// Safe getter for files scanned with fallback
int _safeGetFilesScanned(Map<String, dynamic> json) {
  final summary = json['summary'] as Map<String, dynamic>?;
  if (summary != null) {
    if (summary.containsKey('filesScanned')) return asInt(summary['filesScanned']);
    if (summary.containsKey('scanned_files')) return asInt(summary['scanned_files']);
  }
  
  final metrics = json['metrics'] as Map<String, dynamic>?;
  if (metrics != null) {
    if (metrics.containsKey('scanned_files')) return asInt(metrics['scanned_files']);
  }
  
  // Fallback to file_analyses count
  final fileAnalyses = json['file_analyses'] as Map<String, dynamic>?;
  return fileAnalyses?.length ?? 0;
}

/// Compares two snapshots with tolerance for timestamps and ordering
void _compareSnapshots(
    Map<String, dynamic> expected, Map<String, dynamic> actual) {
  // Compare schema version (must match exactly)
  expect(actual['schemaVersion'], equals(expected['schemaVersion']),
      reason: 'Schema version must match');

  // Compare summary (tolerant of scan duration differences)
  final expectedSummary = asMap(expected['summary']);
  final actualSummary = asMap(actual['summary'] ?? {});

  // Safe access with fallback to metrics or keys length
  final expectedTotalKeys = _safeGetTotalKeys(expected);
  final actualTotalKeys = _safeGetTotalKeys(actual);

  expect(actualTotalKeys, equals(expectedTotalKeys),
      reason: 'Total keys count must match');
  
  // Safe access for files scanned
  final expectedFilesScanned = _safeGetFilesScanned(expected);
  final actualFilesScanned = _safeGetFilesScanned(actual);
  
  expect(actualFilesScanned, equals(expectedFilesScanned),
      reason: 'Files scanned count must match');

  // Don't compare scanDuration as it will vary
  // Don't compare timestamp as it will always be different

  // Compare keys (order-independent)
  final expectedKeys =
      (expected['keys'] as List).map((k) => k['key'] as String).toSet();
  final actualKeys =
      (actual['keys'] as List).map((k) => k['key'] as String).toSet();

  // Check all expected keys are present
  final missingKeys = expectedKeys.difference(actualKeys);
  expect(missingKeys, isEmpty,
      reason: 'Missing keys from snapshot: $missingKeys');

  // Check critical keys match
  final expectedCriticalKeys = (expected['keys'] as List)
      .where((k) => k['critical'] == true)
      .map((k) => k['key'] as String)
      .toSet();

  for (final criticalKey in expectedCriticalKeys) {
    expect(actualKeys, contains(criticalKey),
        reason: 'Critical key "$criticalKey" must be present');
  }

  // Verify metadata structure exists (but don't compare values)
  if (expected.containsKey('metadata')) {
    expect(actual, contains('metadata'),
        reason: 'Metadata field must be present if in snapshot');
  }
}
