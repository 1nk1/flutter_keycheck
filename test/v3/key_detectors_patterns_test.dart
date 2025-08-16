import 'package:test/test.dart';

void main() {
  group('KeyDetector Regex Patterns', () {
    group('PatrolFinder pattern', () {
      test('captures \$(...) with single-quoted token', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        final match = re.firstMatch(r'''$('login_button')''');
        expect(match, isNotNull);
        expect(match?.group(2), 'login_button');
      });

      test('captures \$(...) with double-quoted token', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        final match = re.firstMatch(r'''$("email_field")''');
        expect(match, isNotNull);
        expect(match?.group(2), 'email_field');
      });

      test('does not match \$(...) without quotes', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        expect(re.hasMatch(r'$(login_button)'), isFalse);
      });

      test('does not match mismatched quotes', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        expect(re.hasMatch(r'''$('login_button")'''), isFalse);
        expect(re.hasMatch(r'''$("login_button')'''), isFalse);
      });

      test('handles empty strings', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        final match1 = re.firstMatch(r'''$('')''');
        expect(match1?.group(2), '');
        final match2 = re.firstMatch(r'''$("")''');
        expect(match2?.group(2), '');
      });

      test('handles special characters in key', () {
        final re = RegExp(r'''\$\((["'])(.*?)\1\)''');
        final match = re.firstMatch(r'''$('button-123_test')''');
        expect(match?.group(2), 'button-123_test');
      });
    });

    group('IntegrationTestKey pattern', () {
      test('captures key: "..." format', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        final match = re.firstMatch(r'''key: "password_field"''');
        expect(match, isNotNull);
        expect(match?.group(1), 'password_field');
      });

      test('captures key: \'...\' format', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        final match = re.firstMatch(r'''key: 'submit_button' ''');
        expect(match, isNotNull);
        expect(match?.group(1), 'submit_button');
      });

      test('handles multiple spaces after colon', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        final match = re.firstMatch(r'''key:     "test_key"''');
        expect(match?.group(1), 'test_key');
      });

      test('handles no space after colon', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        final match = re.firstMatch(r'''key:"compact_key"''');
        expect(match?.group(1), 'compact_key');
      });

      test('does not match key without quotes', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        expect(re.hasMatch('key: 123'), isFalse);
        expect(re.hasMatch('key: unquoted_key'), isFalse);
      });

      test('does not match empty key', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        expect(re.hasMatch(r'''key: ""'''), isFalse);
        expect(re.hasMatch(r'''key: '' '''), isFalse);
      });

      test('handles keys with special characters', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        final match = re.firstMatch(r'''key: "user_123-form.field"''');
        expect(match?.group(1), 'user_123-form.field');
      });
    });

    group('MaterialKey pattern', () {
      test('captures MaterialKey("...") format', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: MaterialKey("app_bar_title")''');
        expect(match, isNotNull);
        expect(match?.group(1), 'app_bar_title');
      });

      test('captures MaterialKey(\'...\') format', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: MaterialKey('drawer_menu')''');
        expect(match, isNotNull);
        expect(match?.group(1), 'drawer_menu');
      });

      test('handles spaces around parentheses', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: MaterialKey( "spaced_key" )''');
        expect(match?.group(1), 'spaced_key');
      });

      test('does not match MaterialKey without quotes', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch('key: MaterialKey(unquoted)'), isFalse);
      });

      test('does not match empty MaterialKey', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch(r'''key: MaterialKey("")'''), isFalse);
        expect(re.hasMatch(r'''key: MaterialKey('')'''), isFalse);
      });

      test('does not match MaterialKey without key prefix', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch(r'''MaterialKey("test")'''), isFalse);
      });

      test('handles MaterialKey with complex key names', () {
        final re = RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: MaterialKey("widget_123.sub-component")''');
        expect(match?.group(1), 'widget_123.sub-component');
      });
    });

    group('CupertinoKey pattern', () {
      test('captures CupertinoKey("...") format', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: CupertinoKey("ios_button")''');
        expect(match, isNotNull);
        expect(match?.group(1), 'ios_button');
      });

      test('captures CupertinoKey(\'...\') format', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: CupertinoKey('picker_item')''');
        expect(match, isNotNull);
        expect(match?.group(1), 'picker_item');
      });

      test('handles spaces around parentheses', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: CupertinoKey( 'spaced_key' )''');
        expect(match?.group(1), 'spaced_key');
      });

      test('does not match CupertinoKey without quotes', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch('key: CupertinoKey(unquoted)'), isFalse);
      });

      test('does not match empty CupertinoKey', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch(r'''key: CupertinoKey("")'''), isFalse);
        expect(re.hasMatch(r'''key: CupertinoKey('')'''), isFalse);
      });

      test('does not match CupertinoKey without key prefix', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        expect(re.hasMatch(r'''CupertinoKey("test")'''), isFalse);
      });

      test('handles CupertinoKey with complex key names', () {
        final re = RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)''');
        final match = re.firstMatch(r'''key: CupertinoKey("ios.widget_123-component")''');
        expect(match?.group(1), 'ios.widget_123-component');
      });
    });

    group('Regex compilation safety', () {
      test('all patterns compile without errors', () {
        // Ensure no parsing errors on compilation
        expect(() => RegExp(r'''\$\((["'])(.*?)\1\)'''), returnsNormally);
        expect(() => RegExp(r'''key:\s*["']([^"']+)["']'''), returnsNormally);
        expect(() => RegExp(r'''key:\s*MaterialKey\(["']([^"']+)["']\)'''), returnsNormally);
        expect(() => RegExp(r'''key:\s*CupertinoKey\(["']([^"']+)["']\)'''), returnsNormally);
      });

      test('patterns work with multiline strings', () {
        final patrolRe = RegExp(r'''\$\((["'])(.*?)\1\)''');
        final multiline = '''
          \$('first_key')
          some other text
          \$("second_key")
        ''';
        final matches = patrolRe.allMatches(multiline).toList();
        expect(matches.length, 2);
        expect(matches[0].group(2), 'first_key');
        expect(matches[1].group(2), 'second_key');
      });

      test('patterns handle edge cases with special regex characters', () {
        final re = RegExp(r'''key:\s*["']([^"']+)["']''');
        // Should NOT interpret the brackets or special chars as regex
        final match = re.firstMatch(r'''key: "[test]"''');
        expect(match?.group(1), '[test]');
        
        final match2 = re.firstMatch(r'''key: "test.key"''');
        expect(match2?.group(1), 'test.key');
        
        final match3 = re.firstMatch(r'''key: "test*key"''');
        expect(match3?.group(1), 'test*key');
      });
    });
  });
}