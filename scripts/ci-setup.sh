#!/bin/bash
set -euo pipefail

# CI/CD Setup Script for Flutter KeyCheck
# Prepares environment for GitLab CI pipeline execution

echo "🚀 Flutter KeyCheck CI/CD Setup"

# Function to log with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running in CI environment
if [ "${CI:-false}" = "true" ]; then
    log "Running in CI environment: ${CI_RUNNER_DESCRIPTION:-unknown}"
else
    log "Running in local environment"
fi

# Dart SDK validation
log "Validating Dart SDK..."
dart --version

# Check Dart SDK version compatibility
DART_VERSION=$(dart --version 2>&1 | grep -oP 'Dart SDK version: \K[0-9]+\.[0-9]+\.[0-9]+')
log "Detected Dart SDK version: $DART_VERSION"

# Minimum required version check (3.3.0)
if ! dpkg --compare-versions "$DART_VERSION" "ge" "3.3.0"; then
    log "❌ ERROR: Dart SDK version $DART_VERSION is below minimum required version 3.3.0"
    exit 1
fi

log "✅ Dart SDK version check passed"

# Set up pub cache directory
PUB_CACHE_DIR="${PUB_CACHE:-/opt/pub-cache}"
log "Setting up pub cache at: $PUB_CACHE_DIR"
mkdir -p "$PUB_CACHE_DIR"
export PUB_CACHE="$PUB_CACHE_DIR"

# Install dependencies
log "Installing project dependencies..."
dart pub get

# Create required directories
log "Creating required directories..."
mkdir -p reports artifacts performance/baseline performance/results

# Pre-compile analysis for faster CI runs
log "Pre-compiling analysis..."
dart compile snapshot bin/flutter_keycheck.dart -o .dart_tool/flutter_keycheck.snapshot || {
    log "⚠️ Pre-compilation failed, will use interpreted mode"
}

# Validate project structure
log "Validating project structure..."
required_files=(
    "pubspec.yaml"
    "bin/flutter_keycheck.dart"
    "lib/src/checker.dart"
    "test/"
    ".flutter_keycheck.yaml"
)

for file in "${required_files[@]}"; do
    if [ ! -e "$file" ]; then
        log "❌ ERROR: Required file/directory not found: $file"
        exit 1
    fi
done

log "✅ Project structure validation passed"

# Optimize for CI performance
if [ "${CI:-false}" = "true" ]; then
    log "Applying CI-specific optimizations..."
    
    # Set environment variables for optimal performance
    export DART_VM_OPTIONS="--disable-dart-dev"
    export FKC_CACHE_TTL_HOURS="0"  # Deterministic cache
    
    # Pre-warm analysis cache
    log "Pre-warming analysis cache..."
    dart analyze --no-fatal-infos --no-fatal-warnings > /dev/null 2>&1 || true
    
    log "✅ CI optimizations applied"
fi

# Install flutter_keycheck globally for testing
log "Installing flutter_keycheck CLI tool..."
dart pub global activate --source path .
export PATH="$PATH:$PUB_CACHE/bin"

# Verify installation
if command -v flutter_keycheck >/dev/null 2>&1; then
    log "✅ flutter_keycheck installed successfully"
    flutter_keycheck --version
else
    log "❌ ERROR: flutter_keycheck installation failed"
    exit 1
fi

# Run quick smoke test
log "Running smoke test..."
flutter_keycheck scan --scope workspace-only --output json > /tmp/smoke_test.json || {
    log "❌ ERROR: Smoke test failed"
    exit 1
}

log "✅ Smoke test passed"

# Performance baseline setup
if [ ! -f "performance/baseline/benchmark_main.json" ]; then
    log "Creating initial performance baseline..."
    
    # Run benchmark and create baseline
    if [ -f "tool/run_benchmark.dart" ]; then
        dart run tool/run_benchmark.dart --output json > performance/baseline/benchmark_main.json 2>/dev/null || {
            log "⚠️ Could not create performance baseline, continuing..."
        }
    else
        log "⚠️ Benchmark tool not found, skipping baseline creation"
    fi
fi

# Final validation
log "Performing final validation..."

# Check if essential commands work
commands_to_test=(
    "dart analyze --no-fatal-infos"
    "dart test --help"
    "flutter_keycheck --help"
)

for cmd in "${commands_to_test[@]}"; do
    if ! $cmd >/dev/null 2>&1; then
        log "❌ ERROR: Command failed: $cmd"
        exit 1
    fi
done

log "✅ All essential commands validated"

# Environment summary
log "Environment setup completed successfully!"
log "Summary:"
log "  - Dart SDK: $DART_VERSION"
log "  - Pub Cache: $PUB_CACHE"
log "  - Flutter KeyCheck: $(flutter_keycheck --version 2>&1 | head -n1 || echo 'installed')"
log "  - CI Mode: ${CI:-false}"

log "🎉 CI/CD environment ready for pipeline execution"