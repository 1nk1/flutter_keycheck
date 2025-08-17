import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/cli.dart';

void main() {
  group('Demo App Smoke Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keycheck_demo_test_');

      // Create main project
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_package
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      await Directory('${tempDir.path}/lib').create();
      await File('${tempDir.path}/lib/main.dart').writeAsString('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(key: const Key('main_key'));
  }
}
''');

      // Create example app with keys
      await Directory('${tempDir.path}/example/demo_app/lib').create(recursive: true);
      await File('${tempDir.path}/example/demo_app/pubspec.yaml').writeAsString('''
name: demo_app
version: 1.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  test_package:
    path: ../..
''');

      await File('${tempDir.path}/example/demo_app/lib/main.dart').writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Container(key: const Key('demo_key_1')),
            Container(key: const Key('demo_key_2')),
            Container(key: const Key('demo_key_3')),
          ],
        ),
      ),
    );
  }
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('scan finds keys in example/demo_app by default', () async {
      final result = await runCli(['scan', '--report', 'json'], projectRoot: tempDir.path);

      expect(result.exitCode, equals(0));

      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final keyUsages = (json['keys'] ?? []) as List;
      final keys = keyUsages.map((u) => u['key']).toSet();

      // Should find both main project and demo app keys
      expect(keys, contains('main_key'));
      expect(keys, contains('demo_key_1'));
      expect(keys, contains('demo_key_2'));
      expect(keys, contains('demo_key_3'));
    });

    test('scan --no-include-examples excludes demo app', () async {
      final result =
          await runCli(['scan', '--report', 'json', '--no-include-examples'], projectRoot: tempDir.path);

      expect(result.exitCode, equals(0));

      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final keyUsages = (json['keys'] ?? []) as List;
      final keys = keyUsages.map((u) => u['key']).toSet();

      // Should only find main project keys
      expect(keys, contains('main_key'));
      expect(keys, isNot(contains('demo_key_1')));
      expect(keys, isNot(contains('demo_key_2')));
      expect(keys, isNot(contains('demo_key_3')));
    });

    test('scan detects multiple example apps', () async {
      // Create another example app
      await Directory('${tempDir.path}/example/another_demo/lib').create(recursive: true);
      await File('${tempDir.path}/example/another_demo/lib/main.dart').writeAsString('''
import 'package:flutter/material.dart';

class AnotherApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(key: const Key('another_demo_key'));
  }
}
''');

      final result = await runCli(['scan', '--report', 'json'], projectRoot: tempDir.path);

      expect(result.exitCode, equals(0));

      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final keyUsages = (json['keys'] ?? []) as List;
      final keys = keyUsages.map((u) => u['key']).toSet();

      // Should find keys from both example apps
      expect(keys, contains('demo_key_1'));
      expect(keys, contains('another_demo_key'));
    });

    test('scan handles examples folder variant', () async {
      // Create examples folder (plural)
      await Directory('${tempDir.path}/examples/sample_app/lib').create(recursive: true);
      await File('${tempDir.path}/examples/sample_app/lib/main.dart').writeAsString('''
import 'package:flutter/material.dart';

class SampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(key: const Key('sample_key'));
  }
}
''');

      final result = await runCli(['scan', '--report', 'json'], projectRoot: tempDir.path);

      expect(result.exitCode, equals(0));

      final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final keyUsages = (json['keys'] ?? []) as List;
      final keys = keyUsages.map((u) => u['key']).toSet();

      // Should find keys from examples folder too
      expect(keys, contains('sample_key'));
    });
  });
}
