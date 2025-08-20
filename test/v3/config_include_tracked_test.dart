import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ConfigV3 includeOnly and trackedKeys parsing', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('config_test_');
      originalDir = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() async {
      Directory.current = Directory(originalDir);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses include_only from YAML', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  include_only:
    - 'lib/screens/**'
    - 'lib/widgets/**'
  exclude_patterns:
    - '**/*.g.dart'
''');

      final config = await ConfigV3.load(configFile.path);

      expect(config.scan.includeOnly, isNotNull);
      expect(config.scan.includeOnly, hasLength(2));
      expect(config.scan.includeOnly, contains('lib/screens/**'));
      expect(config.scan.includeOnly, contains('lib/widgets/**'));
    });

    test('parses tracked_keys from YAML', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  tracked_keys:
    - 'login_button'
    - 'submit_button'
    - 'email_field'
  exclude_patterns:
    - '**/*.g.dart'
''');

      final config = await ConfigV3.load(configFile.path);

      expect(config.scan.trackedKeys, isNotNull);
      expect(config.scan.trackedKeys, hasLength(3));
      expect(config.scan.trackedKeys, contains('login_button'));
      expect(config.scan.trackedKeys, contains('submit_button'));
      expect(config.scan.trackedKeys, contains('email_field'));
    });

    test('handles both include_only and tracked_keys together', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  include_only:
    - 'lib/features/**'
  tracked_keys:
    - 'critical_key_1'
    - 'critical_key_2'
  exclude_patterns:
    - '**/*.freezed.dart'
''');

      final config = await ConfigV3.load(configFile.path);

      expect(config.scan.includeOnly, isNotNull);
      expect(config.scan.includeOnly, hasLength(1));
      expect(config.scan.includeOnly, contains('lib/features/**'));

      expect(config.scan.trackedKeys, isNotNull);
      expect(config.scan.trackedKeys, hasLength(2));
      expect(config.scan.trackedKeys, contains('critical_key_1'));
      expect(config.scan.trackedKeys, contains('critical_key_2'));
    });

    test('handles missing include_only and tracked_keys gracefully', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  exclude_patterns:
    - '**/*.g.dart'
''');

      final config = await ConfigV3.load(configFile.path);

      expect(config.scan.includeOnly, isNull);
      expect(config.scan.trackedKeys, isNull);
      expect(config.scan.excludePatterns, isNotEmpty);
    });

    test('preserves exclude_patterns when parsing include_only', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  include_only:
    - 'lib/**'
  exclude_patterns:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
    - 'test/**'
''');

      final config = await ConfigV3.load(configFile.path);

      expect(config.scan.includeOnly, isNotNull);
      expect(config.scan.includeOnly, hasLength(1));

      expect(config.scan.excludePatterns, isNotNull);
      expect(config.scan.excludePatterns, hasLength(3));
      expect(config.scan.excludePatterns, contains('**/*.g.dart'));
      expect(config.scan.excludePatterns, contains('**/*.freezed.dart'));
      expect(config.scan.excludePatterns, contains('test/**'));
    });

    test('toMap() includes includeOnly and trackedKeys when present', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  include_only:
    - 'lib/**'
  tracked_keys:
    - 'key1'
    - 'key2'
''');

      final config = await ConfigV3.load(configFile.path);
      final map = config.toMap();

      expect(map['scan'], isNotNull);
      expect(map['scan']['include_only'], isNotNull);
      expect(map['scan']['include_only'], contains('lib/**'));
      expect(map['scan']['tracked_keys'], isNotNull);
      expect(map['scan']['tracked_keys'], contains('key1'));
      expect(map['scan']['tracked_keys'], contains('key2'));
    });

    test('empty lists are handled as null', () async {
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString('''
version: '3'
scan:
  include_only: []
  tracked_keys: []
''');

      final config = await ConfigV3.load(configFile.path);

      // Empty lists might be treated as null or empty depending on implementation
      // This test ensures they don't cause errors
      if (config.scan.includeOnly != null) {
        expect(config.scan.includeOnly, isEmpty);
      }
      if (config.scan.trackedKeys != null) {
        expect(config.scan.trackedKeys, isEmpty);
      }
    });

    test('defaults config does not have includeOnly or trackedKeys', () {
      final config = ConfigV3.defaults();

      expect(config.scan.includeOnly, isNull);
      expect(config.scan.trackedKeys, isNull);
      expect(config.scan.excludePatterns, isNotEmpty);
      expect(config.scan.excludePatterns, contains('**/*.g.dart'));
    });
  });
}
