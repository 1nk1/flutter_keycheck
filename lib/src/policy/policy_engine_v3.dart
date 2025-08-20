import 'package:flutter_keycheck/src/models/scan_result.dart';

/// Package policy validation result
class PackagePolicyResult {
  final List<String> missingInApp;
  final List<KeyCollision> collisions;
  final bool passed;

  PackagePolicyResult({
    required this.missingInApp,
    required this.collisions,
    required this.passed,
  });

  Map<String, dynamic> toMap() {
    return {
      'missing_in_app': missingInApp,
      'collisions': collisions.map((c) => c.toMap()).toList(),
      'passed': passed,
    };
  }
}

/// Key collision information
class KeyCollision {
  final String key;
  final List<String> sources;

  KeyCollision({required this.key, required this.sources});

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'sources': sources,
    };
  }
}

/// Enhanced policy engine with package policies
class PolicyEngineV3 {
  /// Check for keys in packages but missing in app
  static PackagePolicyResult checkPackagePolicies({
    required Map<String, KeyUsage> keyUsages,
    required bool failOnPackageMissing,
    required bool failOnCollision,
  }) {
    final missingInApp = <String>[];
    final collisions = <KeyCollision>[];

    // Group keys by ID to check for collisions and track unique keys
    final keySourceMap = <String, Set<String>>{};
    final packageKeys = <String>{};
    final workspaceKeys = <String>{};

    for (final usage in keyUsages.values) {
      final keyId = usage.id;

      // Track source for collision detection
      final source = usage.package ?? usage.source;
      keySourceMap.putIfAbsent(keyId, () => {}).add(source);

      // Track which keys are in packages and which are in workspace
      if (usage.source == 'package') {
        packageKeys.add(keyId);
      } else if (usage.source == 'workspace') {
        workspaceKeys.add(keyId);
      }
    }

    // Find keys that are in packages but not in workspace
    missingInApp.addAll(packageKeys.difference(workspaceKeys));

    // Check for collisions (keys defined in multiple sources)
    for (final entry in keySourceMap.entries) {
      if (entry.value.length > 1) {
        collisions.add(KeyCollision(
          key: entry.key,
          sources: entry.value.toList(),
        ));
      }
    }

    // Determine if policies passed
    bool passed = true;
    if (failOnPackageMissing && missingInApp.isNotEmpty) {
      passed = false;
    }
    if (failOnCollision && collisions.isNotEmpty) {
      passed = false;
    }

    return PackagePolicyResult(
      missingInApp: missingInApp,
      collisions: collisions,
      passed: passed,
    );
  }
}
