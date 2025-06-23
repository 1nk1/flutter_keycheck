import 'dart:io';

import 'package:flutter_keycheck/src/checker.dart';
import 'package:test/test.dart';

void main() {
  group('KeyConstants Detection Tests', () {
    late Directory tempDir;
    late Directory libDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_keycheck_test_');
      libDir = Directory('${tempDir.path}/lib')..createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should detect modern Key(KeyConstants.*) patterns', () {
      final testFile = File('${libDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
        import 'key_constants.dart';

        class TestWidget {
          void build() {
            var widget1 = Widget(key: const Key(KeyConstants.loginButton));
            var widget2 = Widget(key: Key(KeyConstants.emailField));
          }
        }
      ''');

      final foundKeys = KeyChecker.findKeysInProject(tempDir.path);

      expect(foundKeys.keys, contains('loginButton'));
      expect(foundKeys.keys, contains('emailField'));
      expect(foundKeys['loginButton'], contains(testFile.path));
      expect(foundKeys['emailField'], contains(testFile.path));
    });

    test('should detect ValueKey(KeyConstants.*) patterns', () {
      final testFile = File('${libDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
        import 'key_constants.dart';

        class TestWidget {
          void build() {
            var widget1 = Widget(key: const ValueKey(KeyConstants.passwordField));
            var widget2 = Widget(key: ValueKey(KeyConstants.submitButton));
          }
        }
      ''');

      final foundKeys = KeyChecker.findKeysInProject(tempDir.path);

      expect(foundKeys.keys, contains('passwordField'));
      expect(foundKeys.keys, contains('submitButton'));
    });

    test('should detect finder methods with KeyConstants', () {
      final testFile = File('${libDir.path}/test_finder.dart');
      testFile.writeAsStringSync('''
        import 'key_constants.dart';

        class TestFinder {
          void findElements() {
            var finder1 = find.byValueKey(KeyConstants.loginButton);
            var finder2 = find.byValueKey(KeyConstants.emailField);
          }
        }
      ''');

      final foundKeys = KeyChecker.findKeysInProject(tempDir.path);

      expect(foundKeys.keys, contains('loginButton'));
      expect(foundKeys.keys, contains('emailField'));
    });

    test('should still detect traditional key patterns', () {
      final testFile = File('${libDir.path}/test_traditional.dart');
      testFile.writeAsStringSync('''
        class TestWidget {
          void build() {
            var widget1 = Widget(key: const ValueKey('traditional_key'));
            var widget2 = Widget(key: const Key('another_key'));
            var finder = find.byValueKey('finder_key');
          }
        }
      ''');

      final foundKeys = KeyChecker.findKeysInProject(tempDir.path);

      expect(foundKeys.keys, contains('traditional_key'));
      expect(foundKeys.keys, contains('another_key'));
      expect(foundKeys.keys, contains('finder_key'));
    });
  });

  group('KeyConstants Validation Tests', () {
    late Directory tempDir;
    late Directory libDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_keycheck_test_');
      libDir = Directory('${tempDir.path}/lib')..createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should validate KeyConstants class structure', () {
      final keyConstantsFile = File('${libDir.path}/key_constants.dart');
      keyConstantsFile.writeAsStringSync('''
        class KeyConstants {
          static const String loginButton = 'login_button';
          static const String emailField = 'email_field';
          static const String passwordField = 'password_field';

          static Key gameCardKey(String gameId) => Key('game_card_\$gameId');
          static Key userProfileKey(int userId) => Key('user_profile_\$userId');
        }
      ''');

      final validation = KeyChecker.validateKeyConstants(tempDir.path);

      expect(validation['hasKeyConstants'], isTrue);
      expect(validation['filePath'], equals(keyConstantsFile.path));

      final constants = validation['constantsFound'] as List<String>;
      expect(constants, contains('loginButton'));
      expect(constants, contains('emailField'));
      expect(constants, contains('passwordField'));

      final methods = validation['methodsFound'] as List<String>;
      expect(methods, contains('gameCardKey'));
      expect(methods, contains('userProfileKey'));
    });

    test('should detect missing KeyConstants class', () {
      final validation = KeyChecker.validateKeyConstants(tempDir.path);

      expect(validation['hasKeyConstants'], isFalse);
      expect(validation['constantsFound'], isEmpty);
      expect(validation['methodsFound'], isEmpty);
      expect(validation['filePath'], isNull);
    });

    test('should detect empty KeyConstants class', () {
      final keyConstantsFile = File('${libDir.path}/key_constants.dart');
      keyConstantsFile.writeAsStringSync('''
        class KeyConstants {
          // Empty class
        }
      ''');

      final validation = KeyChecker.validateKeyConstants(tempDir.path);

      expect(validation['hasKeyConstants'], isTrue);
      expect(validation['constantsFound'], isEmpty);
      expect(validation['methodsFound'], isEmpty);
    });
  });

  group('KeyConstants Report Tests', () {
    late Directory tempDir;
    late Directory libDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_keycheck_test_');
      libDir = Directory('${tempDir.path}/lib')..createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should generate comprehensive key usage report', () {
      // Create KeyConstants class
      final keyConstantsFile = File('${libDir.path}/key_constants.dart');
      keyConstantsFile.writeAsStringSync('''
        class KeyConstants {
          static const String loginButton = 'login_button';
          static const String emailField = 'email_field';

          static Key gameCardKey(String gameId) => Key('game_card_\$gameId');
        }
      ''');

      // Create widget file with mixed key usage
      final widgetFile = File('${libDir.path}/test_widget.dart');
      widgetFile.writeAsStringSync('''
        import 'key_constants.dart';

        class TestWidget {
          void build() {
            // KeyConstants usage
            var modern1 = Widget(key: const Key(KeyConstants.loginButton));
            var modern2 = Widget(key: ValueKey(KeyConstants.emailField));

            // Traditional usage
            var traditional1 = Widget(key: const ValueKey('old_key'));
            var traditional2 = Widget(key: const Key('another_old_key'));
          }
        }
      ''');

      final report = KeyChecker.generateKeyReport(tempDir.path);

      expect(
          report['totalKeysFound'],
          equals(
              5)); // 2 KeyConstants + 2 traditional + 1 from method definition

      final traditionalKeys = report['traditionalKeys'] as List<String>;
      expect(traditionalKeys, contains('old_key'));
      expect(traditionalKeys, contains('another_old_key'));

      final constantKeys = report['constantKeys'] as List<String>;
      expect(constantKeys, contains('loginButton'));
      expect(constantKeys, contains('emailField'));

      final recommendations = report['recommendations'] as List<String>;
      expect(recommendations, isNotEmpty);
      expect(
          recommendations
              .any((r) => r.contains('traditional string-based keys')),
          isTrue);
    });

    test('should recommend creating KeyConstants when missing', () {
      // Create only traditional key usage
      final widgetFile = File('${libDir.path}/test_widget.dart');
      widgetFile.writeAsStringSync('''
        class TestWidget {
          void build() {
            var widget = Widget(key: const ValueKey('some_key'));
          }
        }
      ''');

      final report = KeyChecker.generateKeyReport(tempDir.path);

      final recommendations = report['recommendations'] as List<String>;
      expect(
          recommendations
              .any((r) => r.contains('Consider creating a KeyConstants class')),
          isTrue);
    });
  });
}
