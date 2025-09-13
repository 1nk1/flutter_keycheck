# Documentation Update Summary

## Overview
Updated Flutter KeyCheck documentation to reflect the current state of the codebase, particularly focusing on CLI command structure, configuration options, and new features in v3.2.0.

## Files Updated

### 1. README.md
- **Local Installation Section**: Added direct bin execution method (`dart bin/flutter_keycheck.dart --help`)
- **Quick Start Examples**: Added new scan options including `--since`, `--light-html`
- **Version References**: Updated from v3.0.0 to v3.2.0 in dependency examples
- **Configuration Example**: Updated to reflect v3 schema with proper sections for registry, scan, policies, and report settings

### 2. docs/CLI_REFERENCE.md
- **Command Structure**: Added alternative execution methods section showing direct bin execution
- **Scan Command Options**: Added missing options:
  - `--include-generated` - Include generated files
  - `--include-examples` - Scan example packages (default: true)
  - `--since <commit>` - Incremental scan since git commit/branch
  - `--filter <pattern>` - Filter packages by pattern (for monorepo)
  - `--light-html` - Generate lightweight HTML report
- **Examples Section**: Added new examples showcasing incremental scanning, monorepo filtering, and lightweight HTML generation
- **Configuration Example**: Updated to match v3 schema structure

### 3. CHANGELOG.md
- **Version 3.2.0**: Updated release date and added comprehensive list of new features
- **Added Section**: Documented new scan command options and enhanced configuration structure
- **Changed Section**: Added note about updated documentation
- **Fixed Section**: Maintained existing bug fixes

## Key Changes Documented

### New CLI Options
1. **Incremental Scanning**: `--since <commit>` for faster CI/CD builds
2. **Monorepo Support**: `--filter <pattern>` for package filtering
3. **Performance Options**: `--light-html` for faster report generation
4. **Generated Files**: `--include-generated` for comprehensive analysis
5. **Example Packages**: `--include-examples` (enabled by default)

### Enhanced Configuration
- Updated from v1 to v3 schema
- Separated configuration into logical sections:
  - `registry` - Team synchronization settings
  - `scan` - Scanning behavior configuration
  - `policies` - Quality gate and validation rules
  - `report` - Output format and directory settings

### Execution Methods
- Global installation: `flutter_keycheck <command>`
- Local dependency: `dart run flutter_keycheck <command>`
- Direct execution: `dart bin/flutter_keycheck.dart <command>` (for development)

## Impact
These updates ensure that the documentation accurately reflects the current capabilities of Flutter KeyCheck v3.2.0, making it easier for users to:
- Understand all available CLI options
- Configure the tool properly using the v3 schema
- Leverage new performance and monorepo features
- Execute the tool in different environments (global, local, development)

## Validation
All documented commands and options have been verified against the current codebase implementation to ensure accuracy and completeness.
