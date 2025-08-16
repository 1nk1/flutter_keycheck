import 'package:test/test.dart';
import 'package:flutter_keycheck/src/policy/policy_engine_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

void main() {
  group('Package Policy Validation', () {
    test('detects keys missing in app', () {
      final keyUsages = <String, KeyUsage>{
        'app_key': KeyUsage(id: 'app_key', source: 'workspace'),
        'package_key': KeyUsage(
            id: 'package_key',
            source: 'package',
            package: 'some_package@1.0.0'),
        'shared_key': KeyUsage(id: 'shared_key', source: 'workspace'),
      };

      // Add another usage for shared_key from package
      keyUsages['shared_key_pkg'] = KeyUsage(
        id: 'shared_key',
        source: 'package',
        package: 'some_package@1.0.0',
      );

      final result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: true,
        failOnCollision: false,
      );

      expect(result.missingInApp, contains('package_key'));
      expect(result.missingInApp.length, equals(1));
      expect(result.passed, isFalse);
    });

    test('detects key collisions', () {
      final keyUsages = <String, KeyUsage>{
        'collision_key_workspace': KeyUsage(
          id: 'collision_key',
          source: 'workspace',
        ),
        'collision_key_package': KeyUsage(
          id: 'collision_key',
          source: 'package',
          package: 'package_a@1.0.0',
        ),
      };

      final result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: false,
        failOnCollision: true,
      );

      expect(result.collisions.length, equals(1));
      expect(result.collisions.first.key, equals('collision_key'));
      expect(result.passed, isFalse);
    });

    test('passes when no violations', () {
      final keyUsages = <String, KeyUsage>{
        'app_key': KeyUsage(id: 'app_key', source: 'workspace'),
        'another_key': KeyUsage(id: 'another_key', source: 'workspace'),
      };

      final result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: true,
        failOnCollision: true,
      );

      expect(result.missingInApp, isEmpty);
      expect(result.collisions, isEmpty);
      expect(result.passed, isTrue);
    });

    test('handles multiple package sources in collision', () {
      final keyUsages = <String, KeyUsage>{
        'multi_key_workspace': KeyUsage(
          id: 'multi_key',
          source: 'workspace',
        ),
        'multi_key_pkg_a': KeyUsage(
          id: 'multi_key',
          source: 'package',
          package: 'package_a@1.0.0',
        ),
        'multi_key_pkg_b': KeyUsage(
          id: 'multi_key',
          source: 'package',
          package: 'package_b@2.0.0',
        ),
      };

      final result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: false,
        failOnCollision: true,
      );

      expect(result.collisions.length, equals(1));
      final collision = result.collisions.first;
      expect(collision.key, equals('multi_key'));
      expect(collision.sources.length, equals(3));
      expect(collision.sources,
          containsAll(['workspace', 'package_a@1.0.0', 'package_b@2.0.0']));
    });

    test('only fails on enabled policies', () {
      final keyUsages = <String, KeyUsage>{
        'package_key': KeyUsage(
          id: 'package_key',
          source: 'package',
          package: 'some_package@1.0.0',
        ),
      };

      // With failOnPackageMissing disabled
      var result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: false,
        failOnCollision: false,
      );
      expect(result.passed, isTrue);

      // With failOnPackageMissing enabled
      result = PolicyEngineV3.checkPackagePolicies(
        keyUsages: keyUsages,
        failOnPackageMissing: true,
        failOnCollision: false,
      );
      expect(result.passed, isFalse);
    });
  });
}
