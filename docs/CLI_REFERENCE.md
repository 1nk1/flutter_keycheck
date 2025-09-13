# 🖥️ CLI Reference Guide

## Overview

Flutter KeyCheck v3 provides a comprehensive command-line interface with six core commands designed for enterprise Flutter development workflows. The CLI follows modern subcommand patterns with deterministic exit codes for reliable CI/CD integration.

**Available Commands:**
- `scan` - Analyze Flutter projects for key coverage
- `validate` - Validate against baselines and quality policies
- `diff` - Compare scan results between versions
- `report` - Generate reports from existing scan data
- `sync` - Synchronize key configurations across teams
- `fix` - Automatically fix common key issues

## Command Structure

```bash
flutter_keycheck <command> [options]
```

### Alternative Execution Methods

For development and testing, you can also run Flutter KeyCheck directly:

```bash
# Direct execution from source (development)
dart bin/flutter_keycheck.dart <command> [options]

# Global installation
dart pub global activate flutter_keycheck
flutter_keycheck <command> [options]

# Local project dependency
dart run flutter_keycheck <command> [options]
```

### Global Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--version` | `-V` | Show version information | - |
| `--verbose` | `-v` | Show detailed output | `false` |
| `--config` | `-c` | Path to configuration file | `.flutter_keycheck.yaml` |

### Exit Codes

Flutter KeyCheck v3 uses deterministic exit codes for reliable CI/CD integration:

| Code | Name | Description |
|------|------|-------------|
| `0` | Success | Operation completed successfully |
| `1` | Policy Violation | Quality gates failed, coverage thresholds not met |
| `2` | Invalid Configuration | Configuration file errors, invalid arguments |
| `3` | I/O Error | File system errors, permission issues |
| `4` | Internal Error | Unexpected errors, crashes |

##ds

### 1. `scan` - Project Analysis

Analyzes Flutter projects for key coverage using AST parsing.

```bash
flutter_keycheck scan [options]
```

**Key Options:**
- `--scope <workspace-only|deps-only|all>` - Package scanning scope
- `--report <format>` - Output format (html,premium-html,executive,dashboard,ci,gitlab,json,md,markdown,junit,text)
- `--out-dir <path>` - Output directory for reports
- `--project-root <path>` - Project root directory
- `--include-tests` - Include test files in analysis
- `--include-generated` - Include generated files (.g.dart, .freezed.dart)
- `--include-examples` - Scan example/* packages as part of workspace (default: true)
- `--since <commit>` - Incremental scan since git commit/branch
- `--filter <pattern>` - Filter packages by pattern (for monorepo)
- `--light-html` - Generate lightweight HTML report without heavy effects
- `--cache` - Enable dependency caching

**Report Format Options:**
- `html` - Premium glassmorphism HTML reports with interactive features
- `premium-html` - Enhanced premium HTML reports with advanced dashboard features
- `executive`, `dashboard` - Executive dashboard reports for stakeholder presentations
- `ci`, `gitlab` - Beautiful terminal output optimized for CI/CD pipelines
- `json` - Structured JSON data for API integration and automation
- `md`, `markdown` - Documentation-friendly Markdown with tables
- `junit` - JUnit XML format for CI/CD test reporting integration
- `text` - Simple human-readable text format

**Examples:**
```bash
# Basic workspace scan with HTML report
flutter_keycheck scan --scope workspace-only --report html

# Multi-format reports for CI/CD
flutter_keycheck scan --report ci,json,junit --out-dir reports

# Comprehensive analysis including dependencies
flutter_keycheck scan --scope all --report html --include-tests

# Incremental scan since last commit
flutter_keycheck scan --since HEAD~1 --report json

# Monorepo scanning with package filtering
flutter_keycheck scan --filter "mobile_*" --scope workspace-only

# Lightweight HTML report for faster generation
flutter_keycheck scan --report html --light-html --out-dir reports

# Include generated files in analysis
flutter_keycheck scan --include-generated --include-tests --report html
```

### 2. `validate` - Quality Gates

Validates scan results against baselines and quality policies.

```bash
flutter_keycheck validate [options]
```

**Key Options:**
- `--baseline <file>` - Baseline file for drift detection
- `--strict` - Enforce strict validation rules
- `--fail-on-lost` - Fail if protected keys are removed
- `--protected-tags <tags>` - Comma-separated protected key tags
- `--threshold-file <file>` - Coverage threshold configuration

**Examples:**
```bash
# Basic validation with strict mode
flutter_keycheck validate --strict

# CI/CD validation with protected tags
flutter_keycheck validate --fail-on-lost --protected-tags critical,aqa

# Threshold-based validation
flutter_keycheck validate --threshold-file coverage-thresholds.yaml
```

### 3. `diff` - Change Analysis

Compares scan results between different versions or baselines to identify key changes.

```bash
flutter_keycheck diff [options]
```

**Key Options:**
- `--baseline <file>` - Baseline source (registry, file path, or 'scan')
- `--current <file>` - Current source (scan, file path, or 'scan')
- `--baseline-old <file>` - Old baseline file path (new format)
- `--baseline-new <file>` - New baseline file path (new format)
- `--left <file>` - Left file for comparison (package comparison)
- `--right <file>` - Right file for comparison (package comparison)
- `--rule <rule>` - Diff rule ('default' or 'missing-in-app')
- `--report <formats>` - Report formats (text, json, html, markdown)
- `--output <file>` - Output file for reports
- `--show-locations` - Show file locations for keys
- `--only-changes` - Show only changed keys (default: true)

**Examples:**
```bash
# Compare two scan results with multiple formats
flutter_keycheck diff --baseline previous.json --current current.json --report html,json

# Compare baseline files (new format)
flutter_keycheck diff --baseline-old old_baseline.json --baseline-new new_baseline.json

# Package comparison to find missing keys in app
flutter_keycheck diff --left package_keys.json --right app_keys.json --rule missing-in-app

# Generate detailed HTML diff report
flutter_keycheck diff --baseline old.json --current new.json --report html --show-locations
```

### 4. `report` - Standalone Reporting

Generates reports from existing scan data without re-scanning.

```bash
flutter_keycheck report [options]
```

**Key Options:**
- `--input <file>` - Input scan results (JSON)
- `--format <formats>` - Output formats (comma-separated)
- `--out-dir <path>` - Output directory
- `--template <name>` - Report template name
- `--theme <light|dark>` - Report theme

**Examples:**
```bash
# Convert JSON to HTML report
flutter_keycheck report --input results.json --format html

# Multi-format conversion
flutter_keycheck report --input scan.json --format html,md,ci --out-dir reports

# Custom themed report
flutter_keycheck report --input data.json --format html --theme dark
```

### 5. `sync` - Team Synchronization

Synchronizes key configurations across team members and environments.

```bash
flutter_keycheck sync [options]
```

**Key Options:**
- `--source <file>` - Source configuration file
- `--target <file>` - Target configuration file
- `--dry-run` - Preview changes without applying
- `--backup` - Create backup before sync
- `--merge-strategy <strategy>` - Conflict resolution strategy
- `--force` - Force overwrite conflicts

**Examples:**
```bash
# Sync from master configuration
flutter_keycheck sync --source keys/master.yaml --target keys/local.yaml

# Preview sync changes
flutter_keycheck sync --source master.yaml --target local.yaml --dry-run

# Safe sync with backup
flutter_keycheck sync --source master.yaml --target local.yaml --backup
```

### 6. `fix` - Automated Repairs

Automatically fixes duplicate keys and other common key-related issues in Flutter projects.

```bash
flutter_keycheck fix [options]
```

**Key Options:**
- `--key <name>` - Specific key name to fix (required)
- `--strategy <strategy>` - Fix strategy for duplicates
  - `keepFirst` - Keep first occurrence, remove others
  - `keepLast` - Keep last occurrence, remove others
  - `renameSuffix` - Rename duplicates with numeric suffixes
  - `interactive` - Interactive mode for manual selection (default)

**Examples:**
```bash
# Fix duplicate key interactively
flutter_keycheck fix --key "login_button" --strategy interactive

# Automatically keep first occurrence
flutter_keycheck fix --key "duplicate_key" --strategy keepFirst

# Rename duplicates with suffixes
flutter_keycheck fix --key "submit_button" --strategy renameSuffix

# Fix dynamic keys (shown as "(dynamic key)" in reports)
flutter_keycheck fix --key "(dynamic key)" --strategy interactive
```

**Fix Strategies:**
- **keepFirst**: Keeps the first occurrence and comments out all others
- **keepLast**: Keeps the last occurrence and comments out all others
- **renameSuffix**: Renames duplicates by adding `_1`, `_2`, etc. suffixes
- **interactive**: Prompts for each occurrence with options to Keep, Remove, Skip, or Quit

## Configuration Integration

All commands respect the configuration file hierarchy:

1. Command-line arguments (highest priority)
2. Project configuration (`.flutter_keycheck.yaml`)
3. User configuration (`~/.flutter_keycheck.yaml`)
4. Default values (lowest priority)

### Example Configuration

```yaml
# .flutter_keycheck.yaml
version: 3

# Registry configuration for team synchronization
registry:
  type: git
  repo: your-org/key-registry
  branch: main
  path: key-registry.yaml

# Scanning configuration
scan:
  packages: workspace
  include_tests: false
  include_generated: false
  exclude_patterns:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  include_only:
    - "aqa_*"
    - "e2e_*"
  tracked_keys:
    - login_button
    - checkout_flow

# Policy configuration
policies:
  fail_on_lost: true
  fail_on_extra: false
  fail_on_rename: false
  protected_tags: ["critical", "aqa", "e2e"]
  max_drift: 10.0

# Report configuration
report:
  formats: ["json", "html", "junit"]
  out_dir: reports
```

## CI/CD Integration Examples

### GitHub Actions

```yaml
name: Flutter KeyCheck
on: [push, pull_request]

jobs:
  keycheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1

      - name: Install Flutter KeyCheck
        run: dart pub global activate flutter_keycheck

      - name: Scan and Validate
        run: |
          flutter_keycheck scan --report ci,json --out-dir reports
          flutter_keycheck validate --strict --fail-on-lost

      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: keycheck-reports
          path: reports/
```

### GitLab CI

```yaml
flutter_keycheck:
  stage: analyze
  script:
    - dart pub global activate flutter_keycheck
    - flutter_keycheck scan --report gitlab,junit --out-dir reports
    - flutter_keycheck validate --protected-tags critical,aqa
  artifacts:
    reports:
      junit: reports/*.xml
    paths:
      - reports/
  only:
    - merge_requests
    - main
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('Flutter KeyCheck') {
            steps {
                sh 'dart pub global activate flutter_keycheck'
                sh 'flutter_keycheck scan --report ci,json --out-dir reports'
                sh 'flutter_keycheck validate --threshold-file .keycheck-thresholds.yaml'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/**/*', fingerprint: true
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: '*.html',
                        reportName: 'KeyCheck Report'
                    ])
                }
            }
        }
    }
}
```

## Advanced Usage Patterns

### Multi-Project Workflows

```bash
# Scan multiple projects
for project in app1 app2 app3; do
  flutter_keycheck scan --project-root $project --out-dir reports/$project
done

# Aggregate validation
flutter_keycheck validate --baseline reports/*/baseline.json --strict
```

### Release Validation

```bash
# Pre-release validation
flutter_keycheck scan --scope all --report json --out-dir release-check
flutter_keycheck validate --strict --fail-on-lost --protected-tags critical

# Generate release documentation
flutter_keycheck report --input release-check/scan.json --format md --out-dir docs
```

### Development Workflow

```bash
# Daily development check
flutter_keycheck scan --scope workspace-only --report ci
flutter_keycheck fix --dry-run --scope workspace-only

# Pre-commit validation
flutter_keycheck validate --fail-on-lost --protected-tags aqa,e2e
```

## Troubleshooting

### Common Issues

1. **Command Not Found**
   ```bash
   # Ensure global activation
   dart pub global activate flutter_keycheck
   # Add to PATH if needed
   export PATH="$PATH":"$HOME/.pub-cache/bin"
   ```

2. **Configuration Errors (Exit Code 2)**
   ```bash
   # Validate configuration syntax
   flutter_keycheck scan --config .flutter_keycheck.yaml --dry-run
   ```

3. **Permission Issues (Exit Code 3)**
   ```bash
   # Check file permissions
   ls -la .flutter_keycheck.yaml
   # Ensure output directory is writable
   mkdir -p reports && chmod 755 reports
   ```

4. **Policy Violations (Exit Code 1)**
   ```bash
   # Review quality gates
   flutter_keycheck validate --verbose
   # Check coverage thresholds
   flutter_keycheck scan --report ci --verbose
   ```

### Debug Mode

Enable verbose output for detailed troubleshooting:

```bash
flutter_keycheck scan --verbose --report ci
flutter_keycheck validate --verbose --strict
```

## Development & Testing Commands

For contributors and advanced users working with the Flutter KeyCheck codebase:

### Testing Commands

```bash
# Run all tests
dart test

# Run with coverage reporting
dart test --coverage

# GitHub Actions compatible output
dart test --reporter=github

# Machine-readable JSON output
dart test --reporter=json

# Run specific test suites
dart run test/comprehensive_validation_test.dart
dart run test/run_quality_assurance_tests.dart
```

### Go Backend Commands

```bash
# Build Go components
make build                       # Build gokeycheck binary
make test                        # Run Go tests
make test-coverage               # Run with coverage
make check                       # Run all checks

# Development workflow
make watch                       # Auto-rebuild on changes
make run-example                 # Test with sample data
```

### Quality Assurance

```bash
# Static analysis
dart analyze

# Code formatting
dart format .

# Local installation for testing
dart pub global activate --source path .
```

This comprehensive CLI reference ensures teams can effectively leverage Flutter KeyCheck v3's powerful command structure for enterprise Flutter development workflows.
