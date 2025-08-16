import 'dart:io';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';

/// Key registry for central key management v3
class KeyRegistry {
  final RegistryConfig config;

  KeyRegistry(this.config);

  /// Create registry based on configuration
  static Future<KeyRegistry> create(RegistryConfig config) async {
    switch (config.type) {
      case 'git':
        return GitKeyRegistry(config);
      case 'path':
        return PathKeyRegistry(config);
      case 'pkg':
        return PackageKeyRegistry(config);
      default:
        return PathKeyRegistry(config);
    }
  }

  /// Get baseline from registry
  Future<ScanResult?> getBaseline() async {
    throw UnimplementedError('Subclass must implement');
  }

  /// Save baseline to registry
  Future<void> saveBaseline(ScanResult result) async {
    throw UnimplementedError('Subclass must implement');
  }
}

/// Git-based registry
class GitKeyRegistry extends KeyRegistry {
  GitKeyRegistry(super.config);

  @override
  Future<ScanResult?> getBaseline() async {
    // Clone or pull the registry repo
    final tempDir = await Directory.systemTemp.createTemp('keycheck_');

    try {
      // Clone repo
      final cloneResult = await Process.run(
        'git',
        [
          'clone',
          '--depth',
          '1',
          '-b',
          config.branch ?? 'main',
          config.repo!,
          tempDir.path
        ],
      );

      if (cloneResult.exitCode != 0) {
        return null;
      }

      // Read baseline file
      final baselineFile = File('${tempDir.path}/${config.path}');
      if (await baselineFile.exists()) {
        final content = await baselineFile.readAsString();
        return ScanResult.fromJson(content);
      }

      return null;
    } finally {
      // Cleanup temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> saveBaseline(ScanResult result) async {
    // For Git registry, this would push to the repo
    // For now, save locally and expect manual push
    final localFile = File('.flutter_keycheck/${config.path}');
    await localFile.parent.create(recursive: true);
    await localFile.writeAsString(result.toJson());
  }
}

/// Path-based registry (local file)
class PathKeyRegistry extends KeyRegistry {
  PathKeyRegistry(super.config);

  @override
  Future<ScanResult?> getBaseline() async {
    final file = File(config.path ?? '.flutter_keycheck/baseline.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      return ScanResult.fromJson(content);
    }
    return null;
  }

  @override
  Future<void> saveBaseline(ScanResult result) async {
    final file = File(config.path ?? '.flutter_keycheck/baseline.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(result.toJson());
  }
}

/// Package-based registry
class PackageKeyRegistry extends KeyRegistry {
  PackageKeyRegistry(super.config);

  @override
  Future<ScanResult?> getBaseline() async {
    // Would resolve package and load baseline
    // For now, return null
    return null;
  }

  @override
  Future<void> saveBaseline(ScanResult result) async {
    // Would save to package assets
    // For now, save locally
    final localFile = File('.flutter_keycheck/baseline.json');
    await localFile.parent.create(recursive: true);
    await localFile.writeAsString(result.toJson());
  }
}
