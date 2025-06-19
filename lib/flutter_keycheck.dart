/// Flutter Key Integration Validator
///
/// This library provides functionality to:
/// - Validate that all required keys are present in Flutter code
/// - Locate where each key is used in the codebase
/// - Identify extra keys not in the specification
/// - Verify required integration test dependencies
/// - Support both YAML and Markdown key definition files
/// - Handle string interpolation for dynamic keys
library;

export 'src/checker.dart';
export 'src/cli.dart';
