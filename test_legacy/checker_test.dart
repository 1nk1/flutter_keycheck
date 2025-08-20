import 'dart:io';

import 'package:flutter_keycheck/src/checker.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

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

  group('Example Folder Support Tests', () {
    test('resolveProjectPath detects standard Flutter project', () {
      // Create standard project structure
      Directory(path.join(tempDir.path, 'lib')).createSync(recursive: true);
      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();

      final result = KeyChecker.resolveProjectPath(tempDir.path);

      expect(result['projectPath'], equals(tempDir.path));
      expect(result['hasExample'], isFalse);
      expect(result['isInExample'], isFalse);
    });

    test('resolveProjectPath detects project with example folder', () {
      // Create project with example folder
      Directory(path.join(tempDir.path, 'lib')).createSync(recursive: true);
      Directory(path.join(tempDir.path, 'example', 'lib'))
          .createSync(recursive: true);
      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      final result = KeyChecker.resolveProjectPath(tempDir.path);

      expect(result['projectPath'], equals(tempDir.path));
      expect(result['hasExample'], isTrue);
      expect(result['isInExample'], isFalse);
    });

    test('resolveProjectPath detects when running from example folder', () {
      // Create project structure
      Directory(path.join(tempDir.path, 'lib')).createSync(recursive: true);
      Directory(path.join(tempDir.path, 'example', 'lib'))
          .createSync(recursive: true);
      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      final examplePath = path.join(tempDir.path, 'example');
      final result = KeyChecker.resolveProjectPath(examplePath);

      expect(result['projectPath'], equals(examplePath));
      expect(result['hasExample'], isFalse);
      expect(result['isInExample'], isTrue);
    });

    test(
        'resolveProjectPath uses example as project when no lib folder in root',
        () {
      // Create package structure with only example having lib/
      Directory(path.join(tempDir.path, 'example', 'lib'))
          .createSync(recursive: true);
      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      final result = KeyChecker.resolveProjectPath(tempDir.path);

      expect(result['projectPath'], equals(path.join(tempDir.path, 'example')));
      expect(result['hasExample'], isTrue);
      expect(result['isInExample'], isFalse);
    });

    test('findKeysInProject scans both main and example folders', () {
      // Create project with keys in both main and example
      final mainLibFile = File(path.join(tempDir.path, 'lib', 'main.dart'));
      mainLibFile.createSync(recursive: true);
      mainLibFile.writeAsStringSync('''
        Widget build() {
          return TextField(key: const ValueKey('main_field'));
        }
      ''');

      final exampleLibFile =
          File(path.join(tempDir.path, 'example', 'lib', 'example.dart'));
      exampleLibFile.createSync(recursive: true);
      exampleLibFile.writeAsStringSync('''
        Widget build() {
          return TextField(key: const ValueKey('example_field'));
        }
      ''');

      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      final result = KeyChecker.findKeysInProject(tempDir.path);

      expect(result.keys, containsAll(['main_field', 'example_field']));
      expect(result['main_field'], contains(mainLibFile.path));
      expect(result['example_field'], contains(exampleLibFile.path));
    });

    test('checkDependencies checks both main and example pubspec files', () {
      // Create main pubspec without dependencies
      File(path.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: test_package
        dependencies:
          flutter:
            sdk: flutter
      ''');

      // Create example pubspec with integration test dependencies
      Directory(path.join(tempDir.path, 'example')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml'))
          .writeAsStringSync('''
        name: example_app
        dependencies:
          integration_test:
            sdk: flutter
        dev_dependencies:
          appium_flutter_server: ^1.0.0
      ''');

      final result = KeyChecker.checkDependencies(tempDir.path);

      expect(result.hasIntegrationTest, isTrue);
      expect(result.hasAppiumServer, isTrue);
    });

    test('checkIntegrationTests checks both main and example integration tests',
        () {
      // Create integration test in example folder
      final exampleTestFile = File(path.join(
          tempDir.path, 'example', 'integration_test', 'app_test.dart'));
      exampleTestFile.createSync(recursive: true);
      exampleTestFile.writeAsStringSync('''
        import 'package:appium_flutter_server/appium_flutter_server.dart';
        void main() {
          initializeTest();
        }
      ''');

      File(path.join(tempDir.path, 'pubspec.yaml')).createSync();
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      final result = KeyChecker.checkIntegrationTests(tempDir.path);
      expect(result, isTrue);
    });

    test('validateKeys works correctly with example folder structure', () {
      // Create keys file
      final keysFile = File(path.join(tempDir.path, 'keys.yaml'));
      keysFile.writeAsStringSync('''
        keys:
          - main_field
          - example_field
      ''');

      // Create main lib file
      final mainLibFile = File(path.join(tempDir.path, 'lib', 'main.dart'));
      mainLibFile.createSync(recursive: true);
      mainLibFile.writeAsStringSync('''
        Widget build() {
          return TextField(key: const ValueKey('main_field'));
        }
      ''');

      // Create example lib file
      final exampleLibFile =
          File(path.join(tempDir.path, 'example', 'lib', 'example.dart'));
      exampleLibFile.createSync(recursive: true);
      exampleLibFile.writeAsStringSync('''
        Widget build() {
          return TextField(key: const ValueKey('example_field'));
        }
      ''');

      // Create pubspec files
      File(path.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
        name: test_package
        dependencies:
          integration_test:
            sdk: flutter
        dev_dependencies:
          appium_flutter_server: ^1.0.0
      ''');
      File(path.join(tempDir.path, 'example', 'pubspec.yaml')).createSync();

      // Create integration test
      final integrationTestFile =
          File(path.join(tempDir.path, 'integration_test', 'app_test.dart'));
      integrationTestFile.createSync(recursive: true);
      integrationTestFile.writeAsStringSync('''
        import 'package:appium_flutter_server/appium_flutter_server.dart';
        void main() {
          initializeTest();
        }
      ''');

      final result = KeyChecker.validateKeys(
        keysPath: keysFile.path,
        sourcePath: tempDir.path,
      );

      expect(result.missingKeys, isEmpty);
      expect(result.matchedKeys.keys,
          containsAll(['main_field', 'example_field']));
      expect(result.dependencyStatus.hasIntegrationTest, isTrue);
      expect(result.dependencyStatus.hasAppiumServer, isTrue);
      expect(result.hasIntegrationTests, isTrue);
    });
  });

  group('Key Filtering Tests', () {
    test('filterKeys with include_only patterns', () {
      final keys = {
        'qa_login_button',
        'qa_password_field',
        'e2e_submit_button',
        'user_id_field',
        'token_display',
        'status_indicator'
      };

      final result = KeyChecker.filterKeys(
        keys,
        includeOnly: ['qa_', 'e2e_'],
      );

      expect(
          result,
          containsAll(
              ['qa_login_button', 'qa_password_field', 'e2e_submit_button']));
      expect(result, isNot(contains('user_id_field')));
      expect(result, isNot(contains('token_display')));
      expect(result, isNot(contains('status_indicator')));
    });

    test('filterKeys with exclude patterns', () {
      final keys = {
        'qa_login_button',
        'qa_password_field',
        'user_id_field',
        'token_display',
        'status_indicator'
      };

      final result = KeyChecker.filterKeys(
        keys,
        exclude: ['user_id', 'token', 'status'],
      );

      expect(result, containsAll(['qa_login_button', 'qa_password_field']));
      expect(result, isNot(contains('user_id_field')));
      expect(result, isNot(contains('token_display')));
      expect(result, isNot(contains('status_indicator')));
    });

    test('filterKeys with both include_only and exclude patterns', () {
      final keys = {
        'qa_login_button',
        'qa_temp_field',
        'e2e_submit_button',
        'e2e_temp_input',
        'user_id_field',
        'token_display'
      };

      final result = KeyChecker.filterKeys(
        keys,
        includeOnly: ['qa_', 'e2e_'],
        exclude: ['temp'],
      );

      expect(result, containsAll(['qa_login_button', 'e2e_submit_button']));
      expect(result, isNot(contains('qa_temp_field')));
      expect(result, isNot(contains('e2e_temp_input')));
      expect(result, isNot(contains('user_id_field')));
      expect(result, isNot(contains('token_display')));
    });

    test('filterKeys with regex patterns', () {
      final keys = {
        'login_button_1',
        'login_button_2',
        'submit_form',
        'cancel_action',
        'test_field'
      };

      final result = KeyChecker.filterKeys(
        keys,
        includeOnly: [r'.*_button_\d+$'],
      );

      expect(result, containsAll(['login_button_1', 'login_button_2']));
      expect(result, isNot(contains('submit_form')));
      expect(result, isNot(contains('cancel_action')));
      expect(result, isNot(contains('test_field')));
    });

    test('filterKeysMap preserves file locations', () {
      final keysMap = {
        'qa_login_button': ['/lib/login.dart'],
        'qa_password_field': ['/lib/login.dart'],
        'user_id_field': ['/lib/profile.dart'],
        'token_display': ['/lib/auth.dart']
      };

      final result = KeyChecker.filterKeysMap(
        keysMap,
        includeOnly: ['qa_'],
      );

      expect(
          result.keys, containsAll(['qa_login_button', 'qa_password_field']));
      expect(result.keys, isNot(contains('user_id_field')));
      expect(result.keys, isNot(contains('token_display')));
      expect(result['qa_login_button'], equals(['/lib/login.dart']));
      expect(result['qa_password_field'], equals(['/lib/login.dart']));
    });

    test('filterKeys handles empty patterns gracefully', () {
      final keys = {'key1', 'key2', 'key3'};

      final result = KeyChecker.filterKeys(
        keys,
        includeOnly: [],
        exclude: [],
      );

      expect(result, equals(keys));
    });

    test('filterKeys handles null patterns gracefully', () {
      final keys = {'key1', 'key2', 'key3'};

      final result = KeyChecker.filterKeys(
        keys,
        includeOnly: null,
        exclude: null,
      );

      expect(result, equals(keys));
    });
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

    final integrationTestFile =
        File(path.join(tempDir.path, 'integration_test', 'app_test.dart'));
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

    expect(
        result.keys,
        containsAll([
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

  test('findKeysInProject with filtering', () {
    // Create test files with mixed keys
    final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      Widget build(BuildContext context) {
        return Column(
          children: [
            TextField(key: const ValueKey('qa_email_input')),
            TextField(key: const ValueKey('user_id_field')),
            ElevatedButton(
              key: const Key('qa_submit_button'),
              onPressed: () {},
              child: Text('Submit'),
            ),
            ElevatedButton(
              key: const Key('token_display'),
              onPressed: () {},
              child: Text('Token'),
            ),
          ],
        );
      }
    ''');

    final result = KeyChecker.findKeysInProject(
      tempDir.path,
      includeOnly: ['qa_'],
      exclude: ['temp'],
    );

    expect(result.keys, containsAll(['qa_email_input', 'qa_submit_button']));
    expect(result.keys, isNot(contains('user_id_field')));
    expect(result.keys, isNot(contains('token_display')));
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

    expect(
        keys,
        containsAll([
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

  test('validateKeys with filtering', () {
    // Create test files with mixed keys
    final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      Widget build(BuildContext context) {
        return Column(
          children: [
            TextField(key: const ValueKey('qa_email_input')),
            TextField(key: const ValueKey('user_id_field')),
            ElevatedButton(
              key: const Key('qa_submit_button'),
              onPressed: () {},
              child: Text('Submit'),
            ),
            ElevatedButton(
              key: const Key('token_display'),
              onPressed: () {},
              child: Text('Token'),
            ),
          ],
        );
      }
    ''');

    final keysFile = File(path.join(tempDir.path, 'keys.yaml'));
    keysFile.writeAsStringSync('''
      keys:
        - qa_email_input
        - qa_submit_button
        - qa_missing_key
        - user_id_field
        - token_display
    ''');

    final result = KeyChecker.validateKeys(
      keysPath: keysFile.path,
      sourcePath: tempDir.path,
      includeOnly: ['qa_'],
    );

    // Only QA keys should be considered
    expect(result.missingKeys, contains('qa_missing_key'));
    expect(result.missingKeys, isNot(contains('user_id_field')));
    expect(result.missingKeys, isNot(contains('token_display')));
    expect(result.extraKeys, isEmpty); // No extra QA keys found
    expect(result.matchedKeys.keys,
        containsAll(['qa_email_input', 'qa_submit_button']));
    expect(result.matchedKeys.keys, isNot(contains('user_id_field')));
    expect(result.matchedKeys.keys, isNot(contains('token_display')));
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

    final result = KeyChecker.checkDependencies(tempDir.path);
    expect(result.hasIntegrationTest, isTrue);
    expect(result.hasAppiumServer, isTrue);
    expect(result.hasAllDependencies, isTrue);
  });

  test('checkIntegrationTests verifies test setup', () {
    final testFile =
        File(path.join(tempDir.path, 'integration_test', 'appium_test.dart'));
    testFile.createSync(recursive: true);
    testFile.writeAsStringSync('''
      import 'package:appium_flutter_server/appium_flutter_server.dart';
      void main() {
        initializeTest();
      }
    ''');

    expect(KeyChecker.checkIntegrationTests(tempDir.path), isTrue);
  });

  group('validateKeys with tracked_keys', () {
    test('validates only tracked keys when specified', () {
      // Create expected keys file with multiple keys
      final keysFile = File(path.join(tempDir.path, 'expected_keys.yaml'));
      keysFile.writeAsStringSync('''
keys:
  - login_submit_button
  - signup_email_field
  - card_dropdown
  - untracked_key1
  - untracked_key2
''');

      // Create test file with some of the keys
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: ValueKey('login_submit_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        TextField(
          key: ValueKey('signup_email_field'),
          decoration: InputDecoration(labelText: 'Email'),
        ),
        // Missing card_dropdown key
        // Has untracked_key1 which should be ignored
        Container(
          key: ValueKey('untracked_key1'),
          child: Text('Untracked'),
        ),
      ],
    );
  }
}
''');

      // Validate with tracked keys
      final result = KeyChecker.validateKeys(
        keysPath: keysFile.path,
        sourcePath: tempDir.path,
        trackedKeys: [
          'login_submit_button',
          'signup_email_field',
          'card_dropdown'
        ],
      );

      // Should find login_submit_button and signup_email_field
      expect(result.matchedKeys.keys, contains('login_submit_button'));
      expect(result.matchedKeys.keys, contains('signup_email_field'));
      expect(result.matchedKeys.keys, hasLength(2));

      // Should report card_dropdown as missing
      expect(result.missingKeys, contains('card_dropdown'));
      expect(result.missingKeys, hasLength(1));

      // untracked_key1 should be in extra keys (found but not tracked)
      expect(result.extraKeys, contains('untracked_key1'));
    });

    test('falls back to full validation when tracked_keys is null', () {
      // Create expected keys file
      final keysFile = File(path.join(tempDir.path, 'expected_keys.yaml'));
      keysFile.writeAsStringSync('''
keys:
  - login_submit_button
  - signup_email_field
''');

      // Create test file
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: ValueKey('login_submit_button'),
      onPressed: () {},
      child: Text('Login'),
    );
  }
}
''');

      // Validate without tracked keys (should validate all expected keys)
      final result = KeyChecker.validateKeys(
        keysPath: keysFile.path,
        sourcePath: tempDir.path,
        trackedKeys: null,
      );

      // Should find login_submit_button
      expect(result.matchedKeys.keys, contains('login_submit_button'));

      // Should report signup_email_field as missing
      expect(result.missingKeys, contains('signup_email_field'));
    });

    test('handles empty tracked_keys list', () {
      // Create expected keys file
      final keysFile = File(path.join(tempDir.path, 'expected_keys.yaml'));
      keysFile.writeAsStringSync('''
keys:
  - login_submit_button
  - signup_email_field
''');

      // Create test file
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: ValueKey('login_submit_button'),
      onPressed: () {},
      child: Text('Login'),
    );
  }
}
''');

      // Validate with empty tracked keys (should validate all expected keys)
      final result = KeyChecker.validateKeys(
        keysPath: keysFile.path,
        sourcePath: tempDir.path,
        trackedKeys: [],
      );

      // Should find login_submit_button
      expect(result.matchedKeys.keys, contains('login_submit_button'));

      // Should report signup_email_field as missing
      expect(result.missingKeys, contains('signup_email_field'));
    });
  });

  group('generateKeysYaml with tracked_keys', () {
    test('generates only tracked keys when specified', () {
      // Create test file with multiple keys
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: ValueKey('login_submit_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        TextField(
          key: ValueKey('signup_email_field'),
          decoration: InputDecoration(labelText: 'Email'),
        ),
        DropdownButton(
          key: ValueKey('card_dropdown'),
          items: [],
          onChanged: null,
        ),
        Container(
          key: ValueKey('untracked_key'),
          child: Text('Untracked'),
        ),
      ],
    );
  }
}
''');

      // Generate keys with tracked keys filter
      final yaml = KeyChecker.generateKeysYaml(
        sourcePath: tempDir.path,
        trackedKeys: [
          'login_submit_button',
          'signup_email_field',
          'card_dropdown'
        ],
      );

      // Should include tracked keys
      expect(yaml, contains('login_submit_button'));
      expect(yaml, contains('signup_email_field'));
      expect(yaml, contains('card_dropdown'));

      // Should not include untracked key
      expect(yaml, isNot(contains('untracked_key')));

      // Should include comment about tracked keys
      expect(yaml, contains('Generated with tracked_keys:'));
    });

    test('generates all keys when tracked_keys is null', () {
      // Create test file with multiple keys
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: ValueKey('login_submit_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        Container(
          key: ValueKey('untracked_key'),
          child: Text('Untracked'),
        ),
      ],
    );
  }
}
''');

      // Generate keys without tracked keys filter
      final yaml = KeyChecker.generateKeysYaml(
        sourcePath: tempDir.path,
        trackedKeys: null,
      );

      // Should include all keys
      expect(yaml, contains('login_submit_button'));
      expect(yaml, contains('untracked_key'));

      // Should not include tracked keys comment
      expect(yaml, isNot(contains('Generated with tracked_keys:')));
    });

    test('combines tracked_keys with other filters', () {
      // Create test file with multiple keys
      final testFile = File(path.join(tempDir.path, 'lib', 'test.dart'));
      testFile.createSync(recursive: true);
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: ValueKey('qa_login_button'),
          onPressed: () {},
          child: Text('Login'),
        ),
        TextField(
          key: ValueKey('qa_signup_field'),
          decoration: InputDecoration(labelText: 'Email'),
        ),
        Container(
          key: ValueKey('prod_status'),
          child: Text('Status'),
        ),
        Container(
          key: ValueKey('qa_untracked'),
          child: Text('Untracked'),
        ),
      ],
    );
  }
}
''');

      // Generate keys with both tracked keys and include filter
      final yaml = KeyChecker.generateKeysYaml(
        sourcePath: tempDir.path,
        includeOnly: ['qa_'],
        trackedKeys: ['qa_login_button', 'qa_signup_field'],
      );

      // Should include only tracked keys that match include filter
      expect(yaml, contains('qa_login_button'));
      expect(yaml, contains('qa_signup_field'));

      // Should not include qa_untracked (not in tracked keys)
      expect(yaml, isNot(contains('qa_untracked')));

      // Should not include prod_status (doesn't match include filter)
      expect(yaml, isNot(contains('prod_status')));

      // Should include both filter comments
      expect(yaml, contains('Generated with include_only filters:'));
      expect(yaml, contains('Generated with tracked_keys:'));
    });
  });
}
