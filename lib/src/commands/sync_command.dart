import 'dart:io';

import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/registry/key_registry_v3.dart';

/// Sync command to pull/push central registry
class SyncCommand extends BaseCommandV3 {
  @override
  final String name = 'sync';

  @override
  final String description = 'Synchronize with team registry';

  SyncCommand() {
    argParser
      ..addOption(
        'action',
        abbr: 'a',
        help: 'Sync action',
        allowed: ['pull', 'push', 'status'],
        defaultsTo: 'pull',
      )
      ..addOption(
        'repo',
        help: 'Git repository URL for registry',
      )
      ..addOption(
        'branch',
        help: 'Git branch for registry',
        defaultsTo: 'main',
      )
      ..addOption(
        'path',
        help: 'Path to registry file',
        defaultsTo: 'key-registry.yaml',
      )
      ..addOption(
        'url',
        help: 'Storage URL for registry (s3://, gs://, etc)',
      )
      ..addOption(
        'package',
        help: 'Package name for package-based registry',
      )
      ..addFlag(
        'force',
        help: 'Force push even with conflicts',
        defaultsTo: false,
      )
      ..addOption(
        'message',
        abbr: 'm',
        help: 'Commit message for push',
      );
  }

  @override
  Future<int> run() async {
    try {
      final config = await loadConfig();
      final action = argResults!['action'] as String;

      // Get appropriate registry based on type
      final registry = await _getRegistry(config);

      switch (action) {
        case 'pull':
          return await _pull(registry, config);
        case 'push':
          return await _push(registry, config);
        case 'status':
          return await _status(registry, config);
        default:
          stderr.writeln('Unknown action: $action');
          return 2; // Invalid config exit code
      }
    } catch (e) {
      return handleError(e);
    }
  }

  Future<KeyRegistry> _getRegistry(dynamic config) async {
    // Create RegistryConfig from arguments or config
    final registryConfig = RegistryConfig(
      type: argResults!['registry'] as String? ?? 'git',
      repo: argResults!['repo'] as String?,
      branch: argResults!['branch'] as String? ?? 'main',
      path: argResults!['path'] as String? ?? 'key-registry.yaml',
      url: argResults!['url'] as String?,
      package: argResults!['package'] as String?,
    );

    return await KeyRegistry.create(registryConfig);
  }

  Future<int> _pull(dynamic registry, dynamic config) async {
    stdout.writeln('📥 Pulling registry from ${registry.type}...');

    try {
      final keyRegistry = await registry.pull();

      // Save locally
      final localPath = argResults!['path'] as String? ??
          '.flutter_keycheck/key-registry.yaml';
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(keyRegistry.toYaml());

      stdout.writeln('✅ Registry pulled successfully');
      stdout.writeln('   Version: ${keyRegistry.version}');
      stdout.writeln('   Packages: ${keyRegistry.packages.length}');
      stdout.writeln(
          '   Total keys: ${keyRegistry.packages.fold(0, (sum, p) => sum + p.keys.length)}');
      stdout
          .writeln('   Last updated: ${keyRegistry.lastUpdated ?? 'unknown'}');
      stdout.writeln('   Saved to: $localPath');

      return 0; // Success
    } catch (e) {
      stderr.writeln('Failed to pull registry: $e');
      return 3; // IO error
    }
  }

  Future<int> _push(dynamic registry, dynamic config) async {
    // TODO: Implement for v3
    stderr.writeln('Push command not yet implemented for v3');
    return 2; // Invalid config exit code
    /*
    stdout.writeln('📤 Pushing registry to ${registry.type}...');

    // Load local registry
    final localPath =
        argResults!['path'] as String? ?? '.flutter_keycheck/key-registry.yaml';
    final file = File(localPath);

    if (!await file.exists()) {
      stderr.writeln('Local registry not found: $localPath');
      stderr.writeln('Run "flutter_keycheck baseline create" first');
      return 3;
    }

    final yaml = await file.readAsString();
    // TODO: Fix for v3 registry
    // final keyRegistry = KeyRegistry.fromYaml(yaml);
    final keyRegistry = null;

    // Update timestamp
    /* TODO: Fix for v3
    final updated = KeyRegistry(
      version: keyRegistry.version,
      monorepo: keyRegistry.monorepo,
      packages: keyRegistry.packages,
      policies: keyRegistry.policies,
      lastUpdated: DateTime.now(),
    );
    */
    final updated = null;

    try {
      // Check for conflicts unless forced
      if (!argResults!['force']) {
        final remote = await registry.pull();
        if (remote.lastUpdated != null &&
            keyRegistry.lastUpdated != null &&
            remote.lastUpdated!.isAfter(keyRegistry.lastUpdated!)) {
          stderr.writeln('⚠️ Remote registry is newer than local');
          stderr.writeln('   Remote: ${remote.lastUpdated}');
          stderr.writeln('   Local: ${keyRegistry.lastUpdated}');
          stderr.writeln('   Use --force to override or pull first');
          return 1;
        }
      }

      // Push with message
      final message = argResults!['message'] as String? ??
          'Update key registry from ${Platform.environment['USER'] ?? 'unknown'}';

      await registry.push(updated, message: message);

      // Update local file with new timestamp
      await file.writeAsString(updated.toYaml());

      stdout.writeln('✅ Registry pushed successfully');
      stdout.writeln('   Message: $message');
      stdout.writeln('   Updated: ${updated.lastUpdated}');

      return 0;
    } catch (e) {
      stderr.writeln('Failed to push registry: $e');
      return 3;
    }
    */
  }

  Future<int> _status(dynamic registry, dynamic config) async {
    // TODO: Implement for v3
    stderr.writeln('Status command not yet implemented for v3');
    return 2;
    /*
    stdout.writeln('🔍 Checking registry status...\n');

    try {
      // Load local registry
      final localPath = argResults!['path'] as String? ??
          '.flutter_keycheck/key-registry.yaml';
      final file = File(localPath);

      if (!await file.exists()) {
        stdout.writeln('❌ No local registry found at $localPath');
        stdout.writeln('   Run "flutter_keycheck sync --action pull" to fetch');
        return 0;
      }

      final localYaml = await file.readAsString();
      // TODO: Fix for v3
      // final local = KeyRegistry.fromYaml(localYaml);
      final local = null;

      stdout.writeln('📍 Local Registry:');
      stdout.writeln('   Path: $localPath');
      stdout.writeln('   Version: ${local.version}');
      stdout.writeln('   Packages: ${local.packages.length}');
      stdout.writeln(
          '   Keys: ${local.packages.fold(0, (sum, p) => sum + p.keys.length)}');
      stdout.writeln('   Updated: ${local.lastUpdated ?? 'unknown'}');

      // Check remote
      stdout.writeln('\n🌐 Remote Registry:');
      try {
        final remote = await registry.pull();
        stdout.writeln('   Type: ${registry.type}');
        stdout.writeln('   Version: ${remote.version}');
        stdout.writeln('   Packages: ${remote.packages.length}');
        stdout.writeln(
            '   Keys: ${remote.packages.fold(0, (sum, p) => sum + p.keys.length)}');
        stdout.writeln('   Updated: ${remote.lastUpdated ?? 'unknown'}');

        // Compare
        if (remote.lastUpdated != null && local.lastUpdated != null) {
          if (remote.lastUpdated!.isAfter(local.lastUpdated!)) {
            stdout.writeln('\n⚠️ Remote is newer - consider pulling');
          } else if (local.lastUpdated!.isAfter(remote.lastUpdated!)) {
            stdout.writeln('\n📤 Local is newer - consider pushing');
          } else {
            stdout.writeln('\n✅ Local and remote are in sync');
          }
        }
      } catch (e) {
        stdout.writeln('   ❌ Unable to reach remote: $e');
      }

      return 0;
    } catch (e) {
      stderr.writeln('Failed to check status: $e');
      return 3;
    }
    */
  }
}
