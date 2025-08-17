@Tags(['nonblocking'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  group('Package Scope Scanning', () {
    late Directory tempDir;
    late ConfigV3 config;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_test_');
      config = ConfigV3.defaults();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('workspace-only scope scans only workspace files', () async {
      // Create test files
      final libFile = File('${tempDir.path}/lib/main.dart');
      await libFile.create(recursive: true);
      await libFile.writeAsString('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('workspace_key'),
    );
  }
}
''');

      final scanner = AstScannerV3(
        projectPath: tempDir.path,
        scope: ScanScope.workspaceOnly,
        config: config,
      );

      final result = await scanner.scan();

      expect(result.keyUsages.length, equals(1));
      expect(result.keyUsages['workspace_key']?.source, equals('workspace'));
      expect(result.keyUsages['workspace_key']?.package, isNull);
    });

    test('deps-only scope scans only dependency files', () async {
      // Create a mock package_config.json
      final packageConfigDir = Directory('${tempDir.path}/.dart_tool');
      await packageConfigDir.create(recursive: true);

      // For this test, we'll simulate having no dependencies
      final packageConfig =
          File('${packageConfigDir.path}/package_config.json');
      await packageConfig.writeAsString('''
{
  "configVersion": 2,
  "packages": []
}
''');

      final scanner = AstScannerV3(
        projectPath: tempDir.path,
        scope: ScanScope.depsOnly,
        config: config,
      );

      final result = await scanner.scan();

      // With no dependencies, should have no keys
      expect(result.keyUsages.length, equals(0));
    });

    test('all scope scans both workspace and dependencies', () async {
      // Create workspace file
      final libFile = File('${tempDir.path}/lib/main.dart');
      await libFile.create(recursive: true);
      await libFile.writeAsString('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('workspace_key'),
    );
  }
}
''');

      // Create package config
      final packageConfigDir = Directory('${tempDir.path}/.dart_tool');
      await packageConfigDir.create(recursive: true);
      final packageConfig =
          File('${packageConfigDir.path}/package_config.json');
      await packageConfig.writeAsString('''
{
  "configVersion": 2,
  "packages": []
}
''');

      final scanner = AstScannerV3(
        projectPath: tempDir.path,
        scope: ScanScope.all,
        config: config,
      );

      final result = await scanner.scan();

      // Should have the workspace key
      expect(result.keyUsages.containsKey('workspace_key'), isTrue);
      expect(result.keyUsages['workspace_key']?.source, equals('workspace'));
    });

    test('keys from packages have correct source and package info', () async {
      // This test would require setting up a more complex mock environment
      // with actual package dependencies, which is complex in a unit test
      // We'll mark this as a placeholder for integration testing

      // For now, test that the KeyUsage model properly stores package info
      final usage = KeyUsage(
        id: 'test_key',
        source: 'package',
        package: 'some_package@1.0.0',
      );

      expect(usage.source, equals('package'));
      expect(usage.package, equals('some_package@1.0.0'));

      final map = usage.toMap();
      expect(map['source'], equals('package'));
      expect(map['package'], equals('some_package@1.0.0'));
    });
  });
}
