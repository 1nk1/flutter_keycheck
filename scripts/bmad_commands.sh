#!/bin/bash

# BMAD Agent Commands for flutter_keycheck
# Usage: source scripts/bmad_commands.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base project directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ========================================
# ANALYST Agent Commands
# ========================================
function bmad_analyst() {
    echo -e "${BLUE}🔍 ANALYST Agent: Analyzing project structure...${NC}"
    
    # Project analysis
    echo "📊 Project Statistics:"
    find "$PROJECT_ROOT/lib" -name "*.dart" | wc -l | xargs echo "  Dart files:"
    find "$PROJECT_ROOT/test" -name "*_test.dart" | wc -l | xargs echo "  Test files:"
    
    # Dependency analysis
    echo -e "\n📦 Dependency Analysis:"
    cd "$PROJECT_ROOT" && dart pub outdated
    
    # Code metrics
    echo -e "\n📈 Code Metrics:"
    echo "  Lines of code: $(find lib -name '*.dart' -exec wc -l {} + | tail -1 | awk '{print $1}')"
    echo "  Test coverage: Pending implementation"
}

# ========================================
# ARCHITECT Agent Commands
# ========================================
function bmad_architect() {
    echo -e "${BLUE}🏗️ ARCHITECT Agent: Reviewing architecture...${NC}"
    
    # Architecture review
    echo "📐 Architecture Components:"
    echo "  ├── CLI Layer: $(ls -1 $PROJECT_ROOT/lib/src/commands/*.dart 2>/dev/null | wc -l) commands"
    echo "  ├── Core Engine: $(ls -1 $PROJECT_ROOT/lib/src/scanner/*.dart 2>/dev/null | wc -l) scanners"
    echo "  ├── Data Layer: $(ls -1 $PROJECT_ROOT/lib/src/models/*.dart 2>/dev/null | wc -l) models"
    echo "  └── Output Layer: $(ls -1 $PROJECT_ROOT/lib/src/reporter/*.dart 2>/dev/null | wc -l) reporters"
    
    # Duplicate detection
    echo -e "\n⚠️  Issues Detected:"
    if [ -f "$PROJECT_ROOT/lib/src/reporter/html_reporter.dart" ] && [ -f "$PROJECT_ROOT/lib/src/reporter/html_reporter_optimized.dart" ]; then
        echo "  - Duplicate reporter implementations found"
    fi
}

# ========================================
# DEV Agent Commands
# ========================================
function bmad_dev() {
    echo -e "${GREEN}💻 DEV Agent: Development tasks...${NC}"
    
    case "${1:-help}" in
        update-deps)
            echo "📦 Updating dependencies..."
            cd "$PROJECT_ROOT" && dart pub upgrade --major-versions
            ;;
        fix-deps)
            echo "🔧 Fixing dependency conflicts..."
            cd "$PROJECT_ROOT" && dart pub deps
            ;;
        format)
            echo "🎨 Formatting code..."
            cd "$PROJECT_ROOT" && dart format lib test
            ;;
        analyze)
            echo "🔍 Analyzing code..."
            cd "$PROJECT_ROOT" && dart analyze
            ;;
        build)
            echo "🏗️ Building project..."
            cd "$PROJECT_ROOT" && dart compile exe bin/flutter_keycheck.dart
            ;;
        *)
            echo "Available commands:"
            echo "  bmad_dev update-deps  - Update dependencies"
            echo "  bmad_dev fix-deps     - Fix dependency conflicts"
            echo "  bmad_dev format       - Format code"
            echo "  bmad_dev analyze      - Analyze code"
            echo "  bmad_dev build        - Build executable"
            ;;
    esac
}

# ========================================
# QA Agent Commands
# ========================================
function bmad_qa() {
    echo -e "${YELLOW}🧪 QA Agent: Quality assurance...${NC}"
    
    case "${1:-help}" in
        test)
            echo "🧪 Running tests..."
            cd "$PROJECT_ROOT" && dart test
            ;;
        coverage)
            echo "📊 Generating coverage..."
            cd "$PROJECT_ROOT" && dart test --coverage=coverage
            ;;
        integration)
            echo "🔗 Running integration tests..."
            cd "$PROJECT_ROOT" && dart test test/phase2_integration_test.dart
            ;;
        validate)
            echo "✅ Validating project..."
            cd "$PROJECT_ROOT" && ./bin/flutter_keycheck scan --scope workspace-only
            ;;
        *)
            echo "Available commands:"
            echo "  bmad_qa test         - Run unit tests"
            echo "  bmad_qa coverage     - Generate test coverage"
            echo "  bmad_qa integration  - Run integration tests"
            echo "  bmad_qa validate     - Validate project keys"
            ;;
    esac
}

# ========================================
# PM Agent Commands
# ========================================
function bmad_pm() {
    echo -e "${BLUE}📋 PM Agent: Project management...${NC}"
    
    # Show sprint status
    echo "📅 Current Sprint Status:"
    echo "  Sprint 1: Dependency Management & Reporter Consolidation"
    echo "  Progress: In Development"
    
    # Show stories
    echo -e "\n📝 Active Stories:"
    echo "  1. [HIGH] Dependency Management - 3 points"
    echo "  2. [HIGH] Reporter Consolidation - 8 points"
    echo "  3. [HIGH] Test Coverage Enhancement - 8 points"
    
    # Show blockers
    echo -e "\n🚧 Blockers:"
    echo "  - Analyzer package version conflict"
    echo "  - Missing flutter_gates_of_olympus example"
}

# ========================================
# DEVOPS Agent Commands
# ========================================
function bmad_devops() {
    echo -e "${GREEN}🚀 DEVOPS Agent: CI/CD operations...${NC}"
    
    case "${1:-help}" in
        ci-local)
            echo "🏃 Running CI locally..."
            bmad_dev format && bmad_dev analyze && bmad_qa test
            ;;
        publish-dry)
            echo "📦 Dry run for publishing..."
            cd "$PROJECT_ROOT" && dart pub publish --dry-run
            ;;
        version)
            echo "🏷️ Current version:"
            grep "^version:" "$PROJECT_ROOT/pubspec.yaml"
            ;;
        *)
            echo "Available commands:"
            echo "  bmad_devops ci-local     - Run CI pipeline locally"
            echo "  bmad_devops publish-dry  - Dry run for publishing"
            echo "  bmad_devops version      - Show current version"
            ;;
    esac
}

# ========================================
# Main BMAD Command
# ========================================
function bmad() {
    case "${1:-help}" in
        analyst)
            shift
            bmad_analyst "$@"
            ;;
        architect)
            shift
            bmad_architect "$@"
            ;;
        dev)
            shift
            bmad_dev "$@"
            ;;
        qa)
            shift
            bmad_qa "$@"
            ;;
        pm)
            shift
            bmad_pm "$@"
            ;;
        devops)
            shift
            bmad_devops "$@"
            ;;
        all)
            echo -e "${BLUE}🤖 Running all BMAD agents...${NC}\n"
            bmad_analyst
            echo ""
            bmad_architect
            echo ""
            bmad_pm
            ;;
        *)
            echo -e "${BLUE}🤖 BMAD Agent System for flutter_keycheck${NC}"
            echo ""
            echo "Usage: bmad <agent> [command]"
            echo ""
            echo "Available agents:"
            echo "  analyst   - Project analysis and metrics"
            echo "  architect - Architecture review and design"
            echo "  dev       - Development tasks and tools"
            echo "  qa        - Testing and quality assurance"
            echo "  pm        - Project management and tracking"
            echo "  devops    - CI/CD and deployment"
            echo "  all       - Run all agent reports"
            echo ""
            echo "Examples:"
            echo "  bmad analyst          - Run project analysis"
            echo "  bmad dev format       - Format code"
            echo "  bmad qa test          - Run tests"
            echo "  bmad all              - Run all agents"
            ;;
    esac
}

# Export functions for use in other scripts
export -f bmad bmad_analyst bmad_architect bmad_dev bmad_qa bmad_pm bmad_devops

echo -e "${GREEN}✅ BMAD commands loaded! Type 'bmad' for help.${NC}"