import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';

/// Policy configuration
class PolicyConfig {
  final bool failOnLost;
  final bool failOnRename;
  final bool failOnExtra;
  final List<String> protectedTags;
  final double maxDrift;

  PolicyConfig({
    this.failOnLost = false,
    this.failOnRename = false,
    this.failOnExtra = false,
    this.protectedTags = const [],
    this.maxDrift = 100.0,
  });
}

/// Policy engine for validating keys against rules
class PolicyEngine {
  PolicyEngine();

  /// Validate current scan against baseline
  ValidationResult validate({
    required ScanResult baseline,
    required ScanResult current,
    required PolicyConfig config,
  }) {
    final violations = <Violation>[];
    final warnings = <String>[];

    // Get key sets
    final baselineKeys = baseline.keyUsages.keys.toSet();
    final currentKeys = current.keyUsages.keys.toSet();

    // Find changes
    final lostKeys = baselineKeys.difference(currentKeys);
    final addedKeys = currentKeys.difference(baselineKeys);
    final unchangedKeys = baselineKeys.intersection(currentKeys);

    // Detect renames (heuristic)
    final renamedKeys = <String, String>{};
    for (final lost in lostKeys) {
      for (final added in addedKeys) {
        if (_isSimilarKey(lost, added)) {
          renamedKeys[lost] = added;
        }
      }
    }

    // Remove renamed from lost/added
    for (final entry in renamedKeys.entries) {
      lostKeys.remove(entry.key);
      addedKeys.remove(entry.value);
    }

    // Check lost keys
    if (lostKeys.isNotEmpty) {
      for (final key in lostKeys) {
        final usage = baseline.keyUsages[key]!;
        final isProtected = _hasProtectedTag(usage.tags, config.protectedTags);
        final isCritical = isProtected || usage.tags.contains('critical');

        if (config.failOnLost && isCritical) {
          violations.add(Violation(
            type: 'lost',
            severity: isProtected ? 'error' : 'warning',
            key: KeyInfo(
              id: key,
              package: _getPackageFromPath(usage.locations.first.file),
              tags: usage.tags.toList(),
              lastSeen: usage.locations.first.file,
              status: usage.status,
            ),
            message: isProtected
                ? "Critical key '$key' not found"
                : "Key '$key' not found in scan",
            remediation: 'Restore key or update registry',
            policy: 'fail_on_lost',
          ));
        } else {
          warnings.add("Key '$key' was removed");
        }
      }
    }

    // Check renamed keys
    if (renamedKeys.isNotEmpty) {
      for (final entry in renamedKeys.entries) {
        final usage = baseline.keyUsages[entry.key]!;
        final isProtected = _hasProtectedTag(usage.tags, config.protectedTags);
        final isCritical = isProtected || usage.tags.contains('critical');

        if (config.failOnRename && isCritical) {
          violations.add(Violation(
            type: 'renamed',
            severity: isProtected ? 'error' : 'warning',
            key: KeyInfo(
              id: entry.key,
              package: _getPackageFromPath(usage.locations.first.file),
              tags: usage.tags.toList(),
              lastSeen: usage.locations.first.file,
              status: usage.status,
            ),
            message: "Key '${entry.key}' renamed to '${entry.value}'",
            remediation: 'Update tests and documentation',
            policy: 'fail_on_rename',
          ));
        } else {
          warnings
              .add("Key '${entry.key}' appears renamed to '${entry.value}'");
        }
      }
    }

    // Check extra keys
    if (config.failOnExtra && addedKeys.isNotEmpty) {
      for (final key in addedKeys) {
        violations.add(Violation(
          type: 'extra',
          severity: 'warning',
          key: KeyInfo(
            id: key,
            package: _getPackageFromPath(
                current.keyUsages[key]!.locations.first.file),
            tags: current.keyUsages[key]!.tags.toList(),
            status: 'new',
          ),
          message: "Extra key '$key' found",
          remediation: 'Add to registry or remove from code',
          policy: 'fail_on_extra',
        ));
      }
    }

    // Check deprecated keys still in use
    int deprecatedInUse = 0;
    for (final key in unchangedKeys) {
      final usage = current.keyUsages[key]!;
      if (usage.status == 'deprecated') {
        deprecatedInUse++;
        warnings.add("Deprecated key '$key' is still in use");
      }
    }

    // Calculate drift
    final totalChanges =
        lostKeys.length + addedKeys.length + renamedKeys.length;
    final totalKeys = baselineKeys.length;
    final driftPercentage =
        totalKeys > 0 ? (totalChanges / totalKeys * 100) : 0.0;

    // Check drift threshold
    if (driftPercentage > config.maxDrift) {
      violations.add(Violation(
        type: 'drift',
        severity: 'error',
        message:
            'Key drift ${driftPercentage.toStringAsFixed(1)}% exceeds maximum ${config.maxDrift}%',
        remediation: 'Review changes and update baseline',
        policy: 'max_drift',
      ));
    }

    // Get scanned packages
    final scannedPackages = <String>{};
    for (final analysis in current.fileAnalyses.values) {
      scannedPackages.add(_getPackageFromPath(analysis.path));
    }

    // Create summary
    final summary = ValidationSummary(
      totalKeys: currentKeys.length,
      lostKeys: lostKeys.length,
      addedKeys: addedKeys.length,
      renamedKeys: renamedKeys.length,
      deprecatedInUse: deprecatedInUse,
      driftPercentage: driftPercentage,
      scannedPackages: scannedPackages.toList(),
    );

    return ValidationResult(
      summary: summary,
      violations: violations,
      warnings: warnings,
      timestamp: DateTime.now(),
    );
  }

  bool _hasProtectedTag(Set<String> tags, List<String> protectedTags) {
    return tags.any((tag) => protectedTags.contains(tag));
  }

  bool _isSimilarKey(String key1, String key2) {
    // Simple heuristic: check if keys share significant parts
    final parts1 = key1.split(RegExp(r'[._-]'));
    final parts2 = key2.split(RegExp(r'[._-]'));

    final common = parts1.toSet().intersection(parts2.toSet());
    if (common.isEmpty) return false;

    final similarity =
        common.length / (parts1.length + parts2.length - common.length);

    return similarity > 0.6; // 60% similarity threshold
  }

  String _getPackageFromPath(String filePath) {
    // Extract package name from path
    // e.g., "packages/feature_auth/lib/src/login.dart" -> "feature_auth"
    if (filePath.contains('packages/')) {
      final parts = filePath.split('/');
      final packagesIndex = parts.indexOf('packages');
      if (packagesIndex >= 0 && packagesIndex < parts.length - 1) {
        return parts[packagesIndex + 1];
      }
    }
    return 'app_main';
  }
}
