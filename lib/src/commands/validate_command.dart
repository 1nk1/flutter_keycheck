import 'dart:io';

import 'package:flutter_keycheck/src/commands/base_command.dart';
import 'package:flutter_keycheck/src/scanner/workspace_scanner.dart';
import 'package:flutter_keycheck/src/validator/policy_validator.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';

/// Validate command for CI gate enforcement
class ValidateCommand extends BaseCommand {
  @override
  final String name = 'validate';

  @override
  final String description = 'CI gate: enforce policies on key changes';

  ValidateCommand() {
    argParser
      ..addFlag(
        'fail-on-lost',
        help: 'Fail if keys are lost',
        defaultsTo: true,
      )
      ..addFlag(
        'fail-on-rename',
        help: 'Fail if keys are renamed',
        defaultsTo: false,
      )
      ..addFlag(
        'fail-on-extra',
        help: 'Fail if extra keys are found',
        defaultsTo: false,
      )
      ..addOption(
        'max-drift',
        help: 'Maximum allowed drift percentage',
        defaultsTo: '0',
      )
      ..addMultiOption(
        'report',
        help: 'Output formats (can specify multiple)',
        allowed: ['json', 'junit', 'md', 'text'],
        defaultsTo: ['text'],
      )
      ..addOption(
        'out-dir',
        help: 'Output directory for reports',
        defaultsTo: './reports',
      )
      ..addMultiOption(
        'protected-tags',
        help: 'Tags that must not be lost',
        defaultsTo: ['critical', 'aqa'],
      );
  }

  @override
  Future<int> run() async {
    try {
      final config = await loadConfig();
      
      // Get registry
      final registry = await getRegistry(config);
      final keyRegistry = await registry.load();
      
      // Scan current workspace
      final scanner = WorkspaceScanner(config);
      final snapshot = await scanner.scan();
      
      // Create validator with policies
      final validator = PolicyValidator(
        registry: keyRegistry,
        failOnLost: argResults!['fail-on-lost'] as bool,
        failOnRename: argResults!['fail-on-rename'] as bool,
        failOnExtra: argResults!['fail-on-extra'] as bool,
        maxDrift: int.parse(argResults!['max-drift'] as String),
        protectedTags: argResults!['protected-tags'] as List<String>,
      );
      
      // Validate
      final result = await validator.validate(snapshot);
      
      // Generate reports
      final formats = argResults!['report'] as List<String>;
      final outDir = argResults!['out-dir'] as String;
      
      // Ensure output directory exists
      final dir = Directory(outDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Generate each requested report format
      for (final format in formats) {
        final reporter = getReporter(config, format);
        final report = reporter.generateValidationReport(result);
        
        if (format == 'text') {
          // Print to stdout for human consumption
          stdout.writeln(report);
        } else {
          // Save to file
          final reportFile = File('$outDir/validation-report.${reporter.extension}');
          await reportFile.writeAsString(report);
          if (config.verbose) {
            stdout.writeln('📄 Generated $format report: ${reportFile.path}');
          }
        }
      }
      
      // Print summary
      _printSummary(result);
      
      // Determine exit code based on violations
      if (result.hasViolations) {
        stderr.writeln('\n❌ Validation failed with ${result.totalViolations} violations');
        return BaseCommand.exitPolicyViolation;
      }
      
      stdout.writeln('\n✅ All validation checks passed');
      return BaseCommand.exitOk;
    } catch (e) {
      return handleError(e);
    }
  }

  void _printSummary(ValidationResult result) {
    stdout.writeln('\n📊 Validation Summary:');
    
    if (result.lostKeys.isNotEmpty) {
      stdout.writeln('  🔥 Lost keys: ${result.lostKeys.length}');
      if (argResults!['verbose'] as bool) {
        for (final key in result.lostKeys.take(5)) {
          stdout.writeln('     - ${key.id} (${key.tags.join(', ')})');
        }
        if (result.lostKeys.length > 5) {
          stdout.writeln('     ... and ${result.lostKeys.length - 5} more');
        }
      }
    }
    
    if (result.renamedKeys.isNotEmpty) {
      stdout.writeln('  ♻️  Renamed keys: ${result.renamedKeys.length}');
      if (argResults!['verbose'] as bool) {
        for (final rename in result.renamedKeys.take(3)) {
          stdout.writeln('     - ${rename.oldId} → ${rename.newId}');
        }
        if (result.renamedKeys.length > 3) {
          stdout.writeln('     ... and ${result.renamedKeys.length - 3} more');
        }
      }
    }
    
    if (result.extraKeys.isNotEmpty) {
      stdout.writeln('  ➕ Extra keys: ${result.extraKeys.length}');
    }
    
    if (result.deprecatedInUse.isNotEmpty) {
      stdout.writeln('  ⚠️  Deprecated keys in use: ${result.deprecatedInUse.length}');
    }
    
    if (result.removedInUse.isNotEmpty) {
      stdout.writeln('  🚫 Removed keys in use: ${result.removedInUse.length}');
    }
    
    stdout.writeln('  📈 Drift: ${result.driftPercentage.toStringAsFixed(1)}%');
  }
}