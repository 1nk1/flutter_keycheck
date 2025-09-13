# Design Document

## Overview

This design addresses the critical CLI import failure in Flutter KeyCheck v3.1.2 by ensuring all command files are properly implemented and included in the published package. The solution focuses on creating robust command implementations that extend BaseCommandV3 and providing clear feedback for incomplete functionality.

## Architecture

### Command Structure
The CLI uses a command pattern where:
- `CliRunner` acts as the main command dispatcher
- Each command extends `BaseCommandV3` for consistent behavior
- Commands are registered in the runner's constructor
- All commands follow the same lifecycle: argument parsing → execution → exit code return

### File Organization
```
lib/src/commands/
├── base_command_v3.dart     # Base class (existing)
├── scan_command_v3.dart     # Scan functionality (existing)
├── validate_command_v3.dart # Validation functionality (existing)
├── fix_command.dart         # Fix functionality (existing)
├── diff_command.dart        # Diff functionality (needs verification)
├── report_command.dart      # Report generation (needs verification)
└── sync_command.dart        # Registry sync (needs verification)
```

## Components and Interfaces

### BaseCommandV3 Interface
All commands must implement:
- `String get name` - Command name for CLI registration
- `String get description` - Help text description
- `Future<int> run()` - Main execution method returning exit code
- Access to shared utilities via inheritance (logging, config loading, error handling)

### Command Implementations

#### DiffCommand
- **Purpose**: Compare key snapshots between different states
- **Key Methods**:
  - Snapshot loading from various sources (registry, files, live scan)
  - Diff calculation with change detection
  - Multi-format report generation (text, JSON, HTML, Markdown)
- **Exit Codes**: 0 (no changes), 1 (changes detected), 2+ (errors)

#### ReportCommand
- **Purpose**: Generate reports from existing scan or validation data
- **Key Methods**:
  - Data source detection and loading
  - Multi-format report generation
  - Metrics inclusion control
- **Exit Codes**: 0 (success), 2+ (errors)

#### SyncCommand
- **Purpose**: Synchronize with team key registries
- **Key Methods**:
  - Registry type detection (git, package, storage)
  - Pull/push/status operations
  - Conflict detection and resolution
- **Exit Codes**: 0 (success), 1 (conflicts), 2+ (errors)

## Data Models

### Existing Models (Reused)
- `ScanResult` - Contains scan metrics, file analyses, and key usages
- `ValidationResult` - Contains policy violations and validation metrics
- `ConfigV3` - Configuration management

### New Models (If Needed)
- `DiffResult` - Represents changes between two snapshots
  - `Set<String> added` - Keys added in current vs baseline
  - `Set<String> removed` - Keys removed from baseline
  - `Map<String, String> renamed` - Keys that appear renamed
  - `Set<String> unchanged` - Keys present in both snapshots

## Error Handling

### Import Error Prevention
1. **File Existence**: All imported files must exist in lib/src/commands/
2. **Class Definition**: Each file must contain the expected command class
3. **Inheritance**: All commands must extend BaseCommandV3
4. **Registration**: CliRunner constructor must successfully instantiate all commands

### Runtime Error Handling
1. **Graceful Degradation**: Commands with incomplete implementations should run but show appropriate messages
2. **Exit Codes**: Consistent exit code usage across all commands
3. **Error Logging**: Use inherited logging methods for consistent error reporting

### Publishing Verification
1. **Package Contents**: Verify all command files are included in published package
2. **Import Resolution**: Test that all imports resolve correctly in published environment
3. **Functional Testing**: Verify CLI starts and commands execute without errors

## Testing Strategy

### Unit Testing
- Test each command class instantiation
- Verify inheritance from BaseCommandV3
- Test argument parsing for each command
- Test error handling paths

### Integration Testing
- Test CLI runner registration of all commands
- Test end-to-end command execution
- Test import resolution in clean environment

### Publishing Testing
- Test package build process includes all files
- Verify .pubignore doesn't exclude command files
- Test CLI functionality in published package environment

### Verification Commands
```bash
# Test CLI startup
dart run flutter_keycheck:flutter_keycheck --help

# Test individual commands
dart run flutter_keycheck:flutter_keycheck diff --help
dart run flutter_keycheck:flutter_keycheck report --help
dart run flutter_keycheck:flutter_keycheck sync --help
```

## Implementation Approach

### Phase 1: File Verification
1. Verify all command files exist and have proper structure
2. Check that classes extend BaseCommandV3 correctly
3. Ensure all imports in cli_runner.dart resolve

### Phase 2: Implementation Completion
1. Review existing command implementations for completeness
2. Add placeholder implementations where functionality is incomplete
3. Ensure consistent error handling and exit codes

### Phase 3: Publishing Verification
1. Check .pubignore to ensure command files aren't excluded
2. Test package build process
3. Verify CLI functionality in clean environment

### Phase 4: Testing and Validation
1. Run comprehensive CLI tests
2. Verify all commands start without import errors
3. Test basic functionality of each command
