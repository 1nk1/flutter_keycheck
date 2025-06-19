import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/checker.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_keycheck_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('findKeysInProject finds all types of keys', () {
    // Create test files
    final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      Widget build(BuildContext context) {
        return Column(
          children: [
            TextField(key: const ValueKey('email_input')),
            ElevatedButton(
              key: const Key('submit_button'),
              onPressed: () {},
              child: Text('Submit'),
            ),
          ],
        );
      }
    ''');

    final integrationTestFile = File(path.join(tempDir.path, 'integration_test', 'app_test.dart'));
    integrationTestFile.createSync(recursive: true);
    integrationTestFile.writeAsStringSync('''
      void main() {
        testWidgets('test keys', (tester) async {
          await tester.tap(find.byValueKey('login_button'));
          await tester.enterText(find.bySemanticsLabel('password_field'), 'test');
          await tester.tap(find.byTooltip('help_tooltip'));
        });
      }
    ''');

    final result = KeyChecker.findKeysInProject(tempDir.path);

    expect(result.keys, containsAll([
      'email_input',
      'submit_button',
      'login_button',
      'password_field',
      'help_tooltip'
    ]));
    expect(result['email_input'], contains(testFile.path));
    expect(result['submit_button'], contains(testFile.path));
    expect(result['login_button'], contains(integrationTestFile.path));
    expect(result['password_field'], contains(integrationTestFile.path));
    expect(result['help_tooltip'], contains(integrationTestFile.path));
  });

  test('loadExpectedKeys loads keys from yaml file', () {
    final keysFile = File(path.join(tempDir.path, 'keys.yaml'));
    keysFile.writeAsStringSync('''
      keys:
        - email_input
        - submit_button
        - password_field
        - login_button
        - help_tooltip
    ''');

    final keys = KeyChecker.loadExpectedKeys(keysFile.path);

    expect(keys, containsAll([
      'email_input',
      'submit_button',
      'password_field',
      'login_button',
      'help_tooltip'
    ]));
  });

  test('validateKeys identifies missing and extra keys', () {
    // Create test files
    final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      Widget build(BuildContext context) {
        return Column(
          children: [
            TextField(key: const ValueKey('email_input')),
            ElevatedButton(
              key: const Key('extra_button'),
              onPressed: () {},
              child: Text('Submit'),
            ),
          ],
        );
      }
    ''');

    final keysFile = File(path.join(tempDir.path, 'keys.yaml'));
    keysFile.writeAsStringSync('''
      keys:
        - email_input
        - submit_button
    ''');

    final result = KeyChecker.validateKeys(
      keysPath: keysFile.path,
      sourcePath: tempDir.path,
      strict: true,
    );

    expect(result.missingKeys, contains('submit_button'));
    expect(result.extraKeys, contains('extra_button'));
    expect(result.matchedKeys['email_input'], contains(testFile.path));
  });

  test('checkDependencies verifies required packages', () {
    final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('''
      name: test_app
      dependencies:
        integration_test: ^1.0.0
      dev_dependencies:
        appium_flutter_server: ^1.0.0
    ''');

    expect(KeyChecker.checkDependencies(tempDir.path), isTrue);
  });

  test('checkIntegrationTests verifies test setup', () {
    final testFile = File(path.join(tempDir.path, 'integration_test', 'appium_test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      import 'package:appium_flutter_server/appium_flutter_server.dart';
      void main() {
        initializeTest();
      }
    ''');

    expect(KeyChecker.checkIntegrationTests(tempDir.path), isTrue);
  });
}
