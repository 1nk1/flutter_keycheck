# Project Organization & Folder Structure

## Root Level Organization

### Core Directories
- **`lib/`** - Main Dart library code (Flutter KeyCheck tool)
- **`cmd/`** - Go command-line applications (`gokeycheck`, `goscan`)
- **`internal/`** - Go internal packages (not exported)
- **`pkg/`** - Go public packages (reusable components)
- **`test/`** - Dart test files and test utilities
- **`testdata/`** - Go test data and sample projects
- **`example/`** - Usage examples and demo Flutter app

### Configuration & Documentation
- **`docs/`** - Comprehensive project documentation
- **`.github/`** - GitHub workflows and templates
- **`.bmad-core/`** - BMAD (Build, Measure, Analyze, Deploy) framework
- **`.claude/`** - Claude AI agent configurations
- **`.kiro/`** - Kiro IDE steering rules and settings

### Generated & Build Artifacts
- **`coverage/`** - Test coverage reports
- **`reports/`** - Generated analysis reports
- **`screenshots/`** - UI screenshots for documentation
- **`bin/`** - Compiled binaries (created by build process)
- **`node_modules/`** - Node.js dependencies

## Dart Library Structure (`lib/`)

### Main Entry Points
- **`lib/flutter_keycheck.dart`** - Main library export file
- **`lib/src/`** - Internal implementation (not directly imported)

### Core Implementation (`lib/src/`)
```
lib/src/
├── commands/           # CLI command implementations
│   ├── base_command_v3.dart
│   ├── scan_command_v3.dart
│   └── validate_command_v3.dart
├── scanner/           # AST scanning and analysis
│   ├── ast_scanner_v3.dart
│   ├── key_detectors_v3.dart
│   └── workspace_scanner.dart
├── reporter/          # Report generation (HTML, CI, JSON)
│   ├── html_reporter_ultimate.dart
│   ├── ci_reporter.dart
│   └── premium_dashboard_reporter.dart
├── models/            # Data structures
│   ├── scan_result.dart
│   ├── key_usage.dart
│   └── validation_result.dart
├── config/            # Configuration handling
│   └── config_v3.dart
├── cache/             # Performance caching
│   └── cache_manager.dart
└── util/              # Utility functions
    └── casts.dart
```

## Go Backend Structure

### Command Applications (`cmd/`)
- **`cmd/gokeycheck/`** - Main Go CLI application
- **`cmd/goscan/`** - Go-based scanning utility

### Internal Packages (`internal/`)
```
internal/
├── ast_detector/      # AST analysis for Go/Dart
├── cache/             # Caching mechanisms
├── detector/          # Key detection logic
├── models/            # Go data models
├── policy/            # Policy enforcement
├── registry/          # Key registries
├── reporter/          # Report generation
└── scanner/           # File scanning
```

### Public Packages (`pkg/`)
```
pkg/
├── config/            # Configuration types
├── models/            # Shared data models
└── types/             # Common type definitions
```

## Test Organization

### Dart Tests (`test/`)
```
test/
├── integration/       # Integration test suites
├── fixtures/          # Test data and fixtures
├── golden_workspace/  # Golden test workspace
├── helpers/           # Test helper utilities
├── semantics/         # Semantic analysis tests
├── utils/             # Test utilities
└── v3/               # Version 3 specific tests
```

### Go Test Data (`testdata/`)
```
testdata/
├── configs/           # Test configuration files
├── expected/          # Expected test outputs
└── projects/          # Sample Flutter projects
    ├── sample1/
    ├── sample2/
    └── minimal/
```

## Configuration Files

### Project Configuration
- **`pubspec.yaml`** - Dart package definition and dependencies
- **`go.mod`** - Go module definition
- **`package.json`** - Node.js dependencies for browser testing
- **`Makefile`** - Go build system and automation

### Analysis & Quality
- **`analysis_options.yaml`** - Dart static analysis configuration
- **`.flutter_keycheck.yaml`** - Tool configuration template
- **`coverage-thresholds.yaml`** - Coverage requirements

### CI/CD & Automation
- **`.github/workflows/`** - GitHub Actions workflows
- **`.gitlab-ci.yml`** - GitLab CI configuration (if present)
- **`Dockerfile`** - Container configuration

## Special Directories

### BMAD Framework (`.bmad-core/`)
- **`agents/`** - AI agent definitions
- **`tasks/`** - Automated task definitions
- **`templates/`** - Code generation templates
- **`workflows/`** - Development workflows

### AI Integration (`.claude/`)
- **`agents/`** - Claude AI agent configurations
- **`commands/`** - Custom AI commands
- **`helpers/`** - AI helper utilities

## File Naming Conventions

### Dart Files
- **Snake case**: `ast_scanner_v3.dart`, `key_detectors.dart`
- **Version suffixes**: `_v3.dart` for version 3 implementations
- **Legacy markers**: `.v2.old` for deprecated files

### Go Files
- **Snake case**: `ast_detector.go`, `cache_manager.go`
- **Test files**: `*_test.go`
- **Example files**: `example_*.go`

### Configuration Files
- **Dot files**: `.flutter_keycheck.yaml`, `.gitignore`
- **Descriptive names**: `coverage-thresholds.yaml`, `test_baseline.yaml`

## Import Patterns

### Dart Imports
```dart
// External packages first
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/args.dart';

// Internal imports with relative paths
import '../models/scan_result.dart';
import '../util/casts.dart';
```

### Go Imports
```go
// Standard library
import "fmt"
import "os"

// External packages
import "github.com/spf13/cobra"

// Internal packages
import "example.com/m/v2/internal/scanner"
```

## Architecture Patterns

### Command Pattern
- All CLI commands extend `BaseCommandV3`
- Consistent argument parsing and validation
- Standardized error handling and exit codes

### Repository Pattern
- Separate data access from business logic
- `*Registry` classes handle data persistence
- Caching layer for performance optimization

### Strategy Pattern
- Multiple reporter implementations (`HTMLReporter`, `CIReporter`)
- Pluggable key detection strategies
- Configurable validation policies
