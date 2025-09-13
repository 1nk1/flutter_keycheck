# Technology Stack & Build System

## Primary Technologies

### Dart/Flutter
- **Dart SDK**: >=3.2.0 <4.0.0
- **Primary Language**: Dart for CLI tool and Flutter widget analysis
- **AST Analysis**: Uses `analyzer` package (^5.3.0) for deep code inspection
- **Package Manager**: pub for Dart dependencies

### Go Backend
- **Go Version**: 1.24.6
- **Module**: example.com/m/v2
- **Build System**: Makefile-based with comprehensive targets
- **Binary**: `gokeycheck` for performance-critical operations

### Node.js/JavaScript
- **Runtime**: Node.js for browser automation and testing
- **Dependencies**:
  - `playwright` (^1.55.0) for browser testing
  - `bmad-method` (^4.41.0) for BMAD integration

## Key Dependencies

### Dart Dependencies
```yaml
dependencies:
  args: ">=2.4.2 <3.0.0"           # CLI argument parsing
  analyzer: "^5.3.0"               # AST analysis and code inspection
  ansicolor: ^2.0.2                # Colored terminal output
  crypto: ">=3.0.3 <4.0.0"         # Caching and checksums
  path: ">=1.9.0 <2.0.0"           # File path utilities
  yaml: ">=3.1.2 <4.0.0"           # Configuration file parsing
```

### Development Dependencies
```yaml
dev_dependencies:
  test: ^1.25.8                    # Unit testing framework
  collection: ^1.18.0              # Collection utilities
  lints: ^4.0.0                    # Dart linting rules
```

## Build Commands

### Dart/Flutter Commands
```bash
# Install globally
dart pub global activate flutter_keycheck

# Local development
dart pub get                      # Install dependencies
dart pub deps                     # Show dependency tree
dart run flutter_keycheck:flutter_keycheck scan  # Run locally

# Testing
dart test                         # Run all tests
dart test --coverage             # Run with coverage
dart test --reporter=github      # GitHub Actions compatible output
dart test --reporter=json        # Machine-readable JSON output
dart run test/comprehensive_validation_test.dart  # Specific tests
dart run test/run_quality_assurance_tests.dart   # QA test suite

# Publishing
dart pub publish --dry-run       # Validate package
dart pub publish                 # Publish to pub.dev

# Analysis
dart analyze                     # Static analysis
dart format .                    # Code formatting
```

### Go Commands (via Makefile)
```bash
# Build
make build                       # Build gokeycheck binary
make build-linux                 # Build for Linux
make install                     # Install to GOPATH/bin

# Testing
make test                        # Run Go tests
make test-coverage               # Run with coverage
make test-race                   # Run with race detection
make test-integration            # Integration tests
make test-all                    # All test suites

# Development
make fmt                         # Format Go code
make vet                         # Run go vet
make lint                        # Run golangci-lint
make check                       # Run all checks

# Dependencies
make deps                        # Manage Go dependencies
make mod-tidy                    # Tidy go.mod

# Examples
make run-example                 # Run basic example
make run-example-json            # JSON output example
make run-example-html            # HTML report example
```

### CI/CD Commands
```bash
# Continuous Integration
make ci                          # Full CI pipeline
make ci-test                     # CI test suite
make ci-build                    # CI build
make ci-lint                     # CI linting

# Release
make release-build               # Multi-platform binaries
make release-dry-run             # Test release process
```

## Project Structure Conventions

### Dart Library Structure
- `lib/` - Main library code
- `lib/src/` - Internal implementation
- `lib/src/commands/` - CLI command implementations
- `lib/src/scanner/` - AST scanning logic
- `lib/src/reporter/` - Report generation
- `lib/src/models/` - Data models
- `test/` - Test files

### Go Structure
- `cmd/` - Command-line applications
- `internal/` - Internal packages
- `pkg/` - Public packages
- `testdata/` - Test data files

### Configuration Files
- `pubspec.yaml` - Dart package configuration
- `analysis_options.yaml` - Dart analyzer configuration
- `go.mod` - Go module definition
- `Makefile` - Go build system
- `.flutter_keycheck.yaml` - Tool configuration

## Development Workflow

1. **Setup**: `dart pub get && make deps`
2. **Development**: Use `make watch` for auto-rebuild
3. **Testing**: `dart test && make test-all`
4. **Validation**: `make check && dart analyze`
5. **Build**: `make build && dart pub global activate --source path .`
