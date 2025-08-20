import 'package:flutter_keycheck/src/config.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  group('FlutterKeycheckConfig v3 Features', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should have v3 configuration defaults', () {
      final config = FlutterKeycheckConfig.defaults();

      // v2 defaults should still work
      expect(config.keys, equals('keys/expected_keys.yaml'));
      expect(config.projectPath, equals('.'));
      expect(config.report, equals('human'));

      // v3 defaults
      expect(config.useAstScanning, equals(false)); // Backward compatibility
      expect(config.includeTestsInAst, equals(false));
      expect(config.cacheDir, equals('.flutter_keycheck_cache'));
      expect(config.enableMetrics, equals(false));
      expect(config.exportPath, isNull);
      expect(config.qualityThresholds, isNull);
    });

    test('should load v3 configuration from YAML', () {
      final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
      configFile.writeAsStringSync('''
keys: keys/expected.yaml
path: ./src
report: json
export_path: reports/output.json
use_ast_scanning: true
include_tests_in_ast: true
cache_dir: .cache
enable_metrics: true
quality_thresholds:
  coverage: 80
  max_missing: 5
''');

      final config = FlutterKeycheckConfig.loadFromFile(configFile.path);

      expect(config, isNotNull);
      expect(config!.keys, equals('keys/expected.yaml'));
      expect(config.projectPath, equals('./src'));
      expect(config.report, equals('json'));
      expect(config.exportPath, equals('reports/output.json'));
      expect(config.useAstScanning, equals(true));
      expect(config.includeTestsInAst, equals(true));
      expect(config.cacheDir, equals('.cache'));
      expect(config.enableMetrics, equals(true));
      expect(config.qualityThresholds, isNotNull);
      expect(config.qualityThresholds!['coverage'], equals(80));
      expect(config.qualityThresholds!['max_missing'], equals(5));
    });

    test('should merge v3 CLI arguments with config', () {
      final baseConfig = FlutterKeycheckConfig(
        keys: 'base.yaml',
        useAstScanning: false,
        enableMetrics: false,
      );

      final merged = baseConfig.mergeWith(
        keys: 'override.yaml',
        useAstScanning: true,
        enableMetrics: true,
        exportPath: 'report.html',
      );

      expect(merged.keys, equals('override.yaml'));
      expect(merged.useAstScanning, equals(true));
      expect(merged.enableMetrics, equals(true));
      expect(merged.exportPath, equals('report.html'));
    });

    test('should provide v3 getter methods', () {
      final config = FlutterKeycheckConfig(
        useAstScanning: true,
        includeTestsInAst: true,
        cacheDir: 'custom_cache',
        enableMetrics: true,
        exportPath: 'output.json',
        qualityThresholds: {'coverage': 90},
      );

      expect(config.isAstScanningEnabled(), equals(true));
      expect(config.shouldIncludeTestsInAst(), equals(true));
      expect(config.getCacheDir(), equals('custom_cache'));
      expect(config.areMetricsEnabled(), equals(true));
      expect(config.getExportPath(), equals('output.json'));
      expect(config.getQualityThresholds()['coverage'], equals(90));
    });

    test('should maintain backward compatibility', () {
      // Test that v2 configuration still works
      final configFile = File(path.join(tempDir.path, '.flutter_keycheck.yaml'));
      configFile.writeAsStringSync('''
keys: keys/expected.yaml
path: ./
strict: true
verbose: true
fail_on_extra: true
include_only:
  - lib/
exclude:
  - test/
tracked_keys:
  - key1
  - key2
report: json
''');

      final config = FlutterKeycheckConfig.loadFromFile(configFile.path);

      expect(config, isNotNull);
      // All v2 fields should work
      expect(config!.keys, equals('keys/expected.yaml'));
      expect(config.projectPath, equals('./'));
      expect(config.strict, equals(true));
      expect(config.verbose, equals(true));
      expect(config.failOnExtra, equals(true));
      expect(config.includeOnly, equals(['lib/']));
      expect(config.exclude, equals(['test/']));
      expect(config.trackedKeys, equals(['key1', 'key2']));
      expect(config.report, equals('json'));

      // v3 fields should have defaults
      expect(config.useAstScanning, isNull);
      expect(config.isAstScanningEnabled(), equals(false));
    });
  });
}