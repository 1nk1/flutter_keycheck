/// Flutter Key Integration Validator
///
/// This library provides functionality to:
/// - Validate that all required keys are present in Flutter code
/// - Locate where each key is used in the codebase
/// - Identify extra keys not in the specification
/// - Verify required integration test dependencies
/// - Support both YAML and Markdown key definition files
/// - Handle string interpolation for dynamic keys
/// - Support configuration files (.flutter_keycheck.yaml)
library;

// V3 Command System exports
export 'src/commands/base_command_v3.dart';
export 'src/commands/scan_command_v3.dart';
export 'src/commands/validate_command_v3.dart';
export 'src/commands/diff_command.dart';
export 'src/commands/report_command.dart';
export 'src/commands/sync_command.dart';
export 'src/commands/fix_command.dart';

// V3 Core functionality exports
export 'src/analysis/duplicate_detector.dart';
export 'src/cache/cache_manager.dart';
export 'src/metrics/metrics_collector.dart';
export 'src/performance/performance_profiler.dart';
export 'src/semantics/semantics_analyzer.dart';
export 'src/semantics/semantics_detector.dart';

// Legacy exports (kept for backward compatibility)
export 'src/checker.dart';
export 'src/cli.dart';
export 'src/config.dart';
