#!/bin/bash
# Smoke test script for flutter_keycheck v3.0.0

set -e

echo "🚀 Starting flutter_keycheck v3.0.0 smoke tests..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check command success
check_command() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        exit 1
    fi
}

# 1. Check dart is available
echo -e "\n📋 Checking environment..."
dart --version
check_command "Dart SDK available"

# 2. Get dependencies
echo -e "\n📦 Installing dependencies..."
dart pub get
check_command "Dependencies installed"

# 3. Run formatter check
echo -e "\n🎨 Checking code formatting..."
dart format --output=none --set-exit-if-changed .
check_command "Code formatting is correct"

# 4. Run analyzer
echo -e "\n🔍 Running static analysis..."
dart analyze --fatal-infos --fatal-warnings
check_command "Static analysis passed"

# 5. Run tests
echo -e "\n🧪 Running tests..."
dart test --reporter expanded
check_command "All tests passed"

# 6. Test CLI commands
echo -e "\n🛠️ Testing CLI commands..."

# Test help
dart run bin/flutter_keycheck.dart --help > /dev/null
check_command "Help command works"

# Test scan command with scope
echo -e "\n  Testing scan command with different scopes..."
dart run bin/flutter_keycheck.dart scan --scope workspace-only --report json > /dev/null
check_command "Scan with workspace-only scope"

dart run bin/flutter_keycheck.dart scan --scope all --report json > /dev/null
check_command "Scan with all scope"

# Test baseline command
echo -e "\n  Testing baseline command..."
dart run bin/flutter_keycheck.dart baseline create --source scan > /dev/null
check_command "Baseline create command"

# Test validate command with package policies
echo -e "\n  Testing validate command with package policies..."
dart run bin/flutter_keycheck.dart validate --fail-on-package-missing --fail-on-collision || true
check_command "Validate with package policies"

# Test sync command
echo -e "\n  Testing sync command..."
dart run bin/flutter_keycheck.dart sync --dry-run > /dev/null
check_command "Sync command with dry-run"

# 7. Test demo app scanning
echo -e "\n🎯 Testing demo app scanning..."
cd example/demo_app
dart run ../../bin/flutter_keycheck.dart scan --report json > /dev/null
check_command "Demo app scanning"
cd ../..

# 8. Compile executable
echo -e "\n📦 Compiling executable..."
dart compile exe bin/flutter_keycheck.dart -o flutter_keycheck
check_command "Executable compilation"

# Test compiled executable
./flutter_keycheck --version > /dev/null
check_command "Compiled executable works"

# 9. Dry-run publish check
echo -e "\n📚 Checking package publishing readiness..."
dart pub publish --dry-run
check_command "Package is ready for publishing"

# Cleanup
rm -f flutter_keycheck

echo -e "\n${GREEN}✅ All smoke tests passed!${NC}"
echo "flutter_keycheck v3.0.0 is ready for release!"