import 'dart:io';

import 'package:flutter_keycheck/src/cli/cli_runner.dart';
import 'package:flutter_keycheck/src/commands/base_command_v3.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart' as config_v3;
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/policy/policy_engine.dart';
import 'package:flutter_keycheck/src/scanner/ast_scanner_v3.dart';
import 'package:flutter_keycheck/src/models/validation_result.dart';
import 'package:path/path.dart' as path;

/// Validate command - CI gate enforcement (primary command)
class ValidateCommandV3 extends BaseCommandV3 {
  @override
  final name = 'validate';

  @override
  final description = 'Validate keys against policies (CI gate enforcement)';

  @override
  final aliases = ['ci-validate']; // Alias for CI usage

  ValidateCommandV3() {
    argParser
      ..addFlag(
        'strict',
        help: 'Enable strict validation mode',
        defaultsTo: false,
      )
      ..addFlag(
        'fail-on-lost',
        help: 'Fail if keys are lost (not found in scan)',
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
      ..addMultiOption(
        'protected-tags',
        help: 'Tags that cannot be lost or renamed',
        defaultsTo: ['critical', 'aqa'],
      )
      ..addOption(
        'max-drift',
        help: 'Maximum allowed drift percentage',
        defaultsTo: '10',
      )
      ..addMultiOption(
        'report',
        help: 'Report formats to generate',
        allowed: ['json', 'junit', 'md'],
        defaultsTo: ['json'],
      )
      ..addOption(
        'baseline',
        help: 'Baseline source (registry, file path)',
        defaultsTo: 'registry',
      );
  }

  @override
  Future<int> run() async {
    try {
      logInfo('🔍 Validating keys...');

      final config = await loadConfig();
      final outDir = await ensureOutputDir();

      // Load or fetch baseline
      final baseline = await _loadBaseline(config);
      if (baseline == null) {
        logError(
            'No baseline found. Run "flutter_keycheck baseline create" first.');
        return ExitCode.invalidConfig;
      }

      // Perform current scan
      logVerbose('Scanning current project state...');
      final scanner = AstScannerV3(
        projectPath: Directory.current.path,
        config: config,
      );
      final scanResult = await scanner.scan();

      // Configure policy engine
      final policyEngine = PolicyEngine();
      
      // Create policy config from arguments
      final policyConfig = PolicyConfig(
        failOnLost: argResults!['fail-on-lost'] as bool,
        failOnRename: argResults!['fail-on-rename'] as bool,
        failOnExtra: argResults!['fail-on-extra'] as bool,
        protectedTags: argResults!['protected-tags'] as List<String>,
        maxDrift: double.parse(argResults!['max-drift'] as String),
      );

      // Run validation
      final validationResult = policyEngine.validate(
        baseline: baseline,
        current: scanResult,
        config: policyConfig,
      );

      // Log results
      _logValidationResults(validationResult);

      // Generate reports
      final formats = argResults!['report'] as List<String>;
      for (final format in formats) {
        final reporter = getReporter(format);
        final reportFile = File(path.join(
          outDir.path,
          'validation-report.${_getExtension(format)}',
        ));
        await reporter.generateValidationReport(validationResult, reportFile);
        logInfo(
            '📊 ${format.toUpperCase()} report saved to: ${reportFile.path}');
      }

      // Return appropriate exit code
      if (validationResult.hasViolations) {
        logError(
            '❌ Validation failed with ${validationResult.violations.length} violations');
        return ExitCode.policyViolation;
      } else {
        logInfo('✅ All validation checks passed!');
        return ExitCode.ok;
      }
    } catch (e) {
      return handleError(e);
    }
  }

  Future<ScanResult?> _loadBaseline(config_v3.ConfigV3 config) async {
    final baselineSource = argResults!['baseline'] as String;

    if (baselineSource == 'registry') {
      // Load from registry
      final registry = await getRegistry(config);
      return await registry.getBaseline();
    } else {
      // Load from file
      final file = File(baselineSource);
      if (!await file.exists()) {
        return null;
      }
      return ScanResult.fromJson(await file.readAsString());
    }
  }

  void _logValidationResults(ValidationResult result) {
    logInfo('📊 Validation Summary:');
    logInfo('  • Total keys: ${result.summary.totalKeys}');
    logInfo('  • Lost keys: ${result.summary.lostKeys}');
    logInfo('  • Added keys: ${result.summary.addedKeys}');
    logInfo('  • Renamed keys: ${result.summary.renamedKeys}');
    logInfo('  • Drift: ${result.summary.driftPercentage.toStringAsFixed(1)}%');

    if (result.violations.isNotEmpty) {
      logWarning('⚠️  Violations found:');
      for (final violation in result.violations) {
        logError('  • [${violation.severity}] ${violation.message}');
        if (argResults!['verbose'] as bool) {
          logVerbose('    Remediation: ${violation.remediation}');
        }
      }
    }

    if (result.warnings.isNotEmpty) {
      logWarning('⚠️  Warnings:');
      for (final warning in result.warnings) {
        logWarning('  • $warning');
      }
    }
  }

  String _getExtension(String format) {
    switch (format) {
      case 'json':
        return 'json';
      case 'junit':
        return 'xml';
      case 'md':
        return 'md';
      default:
        return format;
    }
  }
}
