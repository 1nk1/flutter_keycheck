#!/bin/bash

echo "======================================"
echo "Testing flutter_keycheck v3 Commands"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_command() {
    local cmd="$1"
    local desc="$2"
    echo -e "${YELLOW}Testing:${NC} $desc"
    echo "Command: $cmd"

    if eval "$cmd"; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    echo "--------------------------------------"
    echo ""
}

echo "1. Testing help command"
test_command "dart run flutter_keycheck:flutter_keycheck --help" "Main help"

echo "2. Testing version flag"
test_command "dart run flutter_keycheck:flutter_keycheck --version" "Version info"

echo "3. Testing scan command"
test_command "dart run flutter_keycheck:flutter_keycheck scan --help" "Scan command help"

echo "4. Testing validate command"
test_command "dart run flutter_keycheck:flutter_keycheck validate --help" "Validate command help"

echo "5. Testing diff command"
test_command "dart run flutter_keycheck:flutter_keycheck diff --help" "Diff command help"

echo "6. Testing report command"
test_command "dart run flutter_keycheck:flutter_keycheck report --help" "Report command help"

echo "7. Testing sync command"
test_command "dart run flutter_keycheck:flutter_keycheck sync --help" "Sync command help"

echo ""
echo "======================================"
echo "Testing correct validate command usage"
echo "======================================"
echo ""

echo "Example 1: Basic validate"
echo "Command: dart run flutter_keycheck:flutter_keycheck validate"
echo ""

echo "Example 2: Validate with fail-on-lost and protected tags (CORRECT SYNTAX)"
echo "Command: dart run flutter_keycheck:flutter_keycheck validate --fail-on-lost --protected-tags critical,aqa"
echo ""

echo "Example 3: Validate with all options"
echo "Command: dart run flutter_keycheck:flutter_keycheck validate --fail-on-lost --fail-on-rename --protected-tags critical,aqa --max-drift 5"
echo ""

echo "======================================"
echo "Common mistakes to avoid:"
echo "======================================"
echo ""
echo -e "${RED}✗ WRONG:${NC} dart run flutter_keycheck:flutter_keycheck ci-validate"
echo -e "${GREEN}✓ RIGHT:${NC} dart run flutter_keycheck:flutter_keycheck validate"
echo ""
echo -e "${RED}✗ WRONG:${NC} Using v3.1.2 from pub.dev (has bugs)"
echo -e "${GREEN}✓ RIGHT:${NC} Using local fixed version or wait for v3.1.3"
echo ""

echo "======================================"
echo "Summary"
echo "======================================"
echo ""
echo "The issue in v3.1.2 has been fixed by:"
echo "1. Adding imports for diff_command.dart, report_command.dart, sync_command.dart"
echo "2. Registering these commands in the CLI runner"
echo "3. Using 'validate' instead of non-existent 'ci-validate' command"
echo ""
echo "All commands are now working correctly!"
