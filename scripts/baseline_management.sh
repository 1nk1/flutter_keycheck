#!/bin/bash

# Flutter KeyCheck Baseline Management Script
# Handles baseline updates, regression detection, and quality gates

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GOLDEN_WORKSPACE="$PROJECT_ROOT/test/golden_workspace"
EXPECTED_KEYS_FILE="$GOLDEN_WORKSPACE/expected_keycheck.json"
PERFORMANCE_BASELINE="$GOLDEN_WORKSPACE/performance_baseline.json"
REPORTS_DIR="$GOLDEN_WORKSPACE/reports"

# Quality gate thresholds
COVERAGE_THRESHOLD=80
PERFORMANCE_THRESHOLD=30000
CRITICAL_KEYS_MIN=4
REGRESSION_THRESHOLD=0.20

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "\n${PURPLE}🔸 $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check if flutter_keycheck binary exists
check_binary() {
    local binary_path="$PROJECT_ROOT/flutter_keycheck"
    
    if [ ! -f "$binary_path" ]; then
        log_info "Compiling flutter_keycheck binary..."
        cd "$PROJECT_ROOT"
        dart compile exe bin/flutter_keycheck.dart -o flutter_keycheck
        log_success "Binary compiled successfully"
    fi
    
    # Test the binary
    if ! "$binary_path" --help > /dev/null 2>&1; then
        log_error "Flutter KeyCheck binary is not working correctly"
        exit 1
    fi
}

# Run validation and capture metrics
run_validation() {
    local output_file="$1"
    local binary_path="$PROJECT_ROOT/flutter_keycheck"
    
    log_info "Running Flutter KeyCheck validation..."
    
    # Capture start time
    local start_time=$(date +%s%3N)
    
    # Run validation and capture output
    if "$binary_path" \
        --keys "$EXPECTED_KEYS_FILE" \
        --path "$GOLDEN_WORKSPACE" \
        --verbose \
        --strict > "$output_file" 2>&1; then
        local exit_code=0
    else
        local exit_code=$?
    fi
    
    # Capture end time
    local end_time=$(date +%s%3N)
    local scan_duration=$((end_time - start_time))
    
    echo "$scan_duration" > "$REPORTS_DIR/scan_duration.txt"
    echo "$exit_code" > "$REPORTS_DIR/exit_code.txt"
    
    return $exit_code
}

# Parse validation results
parse_results() {
    local output_file="$1"
    
    # Extract metrics from output
    local total_keys=$(grep -o "Total keys found:[[:space:]]*[0-9]*" "$output_file" | grep -o "[0-9]*" || echo "0")
    local critical_keys=$(grep -o "Critical keys:[[:space:]]*[0-9]*" "$output_file" | grep -o "[0-9]*" || echo "0")
    local scan_duration=$(cat "$REPORTS_DIR/scan_duration.txt")
    local exit_code=$(cat "$REPORTS_DIR/exit_code.txt")
    
    # Calculate coverage score
    local expected_keys=14
    local coverage_score="0.0"
    if [ "$total_keys" -gt 0 ]; then
        coverage_score=$(echo "scale=1; $total_keys * 100 / $expected_keys" | bc -l)
    fi
    
    # Create results summary
    cat > "$REPORTS_DIR/validation_summary.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "summary": {
    "totalKeys": $total_keys,
    "expectedKeys": $expected_keys,
    "criticalKeys": $critical_keys,
    "coverageScore": $coverage_score,
    "scanDuration": $scan_duration,
    "exitCode": $exit_code
  }
}
EOF

    # Export for use in other functions
    export TOTAL_KEYS="$total_keys"
    export CRITICAL_KEYS="$critical_keys"
    export COVERAGE_SCORE="$coverage_score"
    export SCAN_DURATION="$scan_duration"
    export EXIT_CODE="$exit_code"
}

# Validate quality gates
validate_quality_gates() {
    log_section "Quality Gates Validation"
    
    local gates_passed=0
    local gates_total=3
    
    # Gate 1: Coverage threshold
    log_info "Checking coverage gate..."
    if (( $(echo "$COVERAGE_SCORE >= $COVERAGE_THRESHOLD" | bc -l) )); then
        log_success "Coverage Gate: ${COVERAGE_SCORE}% >= ${COVERAGE_THRESHOLD}%"
        gates_passed=$((gates_passed + 1))
    else
        log_error "Coverage Gate: ${COVERAGE_SCORE}% < ${COVERAGE_THRESHOLD}%"
    fi
    
    # Gate 2: Critical keys
    log_info "Checking critical keys gate..."
    if [ "$CRITICAL_KEYS" -ge "$CRITICAL_KEYS_MIN" ]; then
        log_success "Critical Keys Gate: $CRITICAL_KEYS/$CRITICAL_KEYS_MIN found"
        gates_passed=$((gates_passed + 1))
    else
        log_error "Critical Keys Gate: Only $CRITICAL_KEYS/$CRITICAL_KEYS_MIN found"
    fi
    
    # Gate 3: Performance threshold
    log_info "Checking performance gate..."
    if [ "$SCAN_DURATION" -lt "$PERFORMANCE_THRESHOLD" ]; then
        log_success "Performance Gate: ${SCAN_DURATION}ms < ${PERFORMANCE_THRESHOLD}ms"
        gates_passed=$((gates_passed + 1))
    else
        log_warning "Performance Gate: ${SCAN_DURATION}ms >= ${PERFORMANCE_THRESHOLD}ms"
    fi
    
    # Summary
    echo
    if [ "$gates_passed" -eq "$gates_total" ]; then
        log_success "All quality gates passed ($gates_passed/$gates_total)"
        return 0
    else
        log_error "Quality gate validation failed ($gates_passed/$gates_total passed)"
        return 1
    fi
}

# Check for performance regression
check_performance_regression() {
    log_section "Performance Regression Analysis"
    
    if [ ! -f "$PERFORMANCE_BASELINE" ]; then
        log_warning "Performance baseline not found. Creating initial baseline..."
        create_performance_baseline
        return 0
    fi
    
    # Load baseline
    local baseline_duration=$(grep -o '"avgDuration":[0-9]*' "$PERFORMANCE_BASELINE" | grep -o '[0-9]*')
    log_info "Baseline average duration: ${baseline_duration}ms"
    log_info "Current scan duration: ${SCAN_DURATION}ms"
    
    # Calculate regression threshold
    local regression_limit=$(echo "scale=0; $baseline_duration * (1 + $REGRESSION_THRESHOLD)" | bc)
    
    if [ "$SCAN_DURATION" -le "$regression_limit" ]; then
        local improvement=$(echo "scale=1; ($baseline_duration - $SCAN_DURATION) * 100 / $baseline_duration" | bc)
        if (( $(echo "$improvement > 0" | bc -l) )); then
            log_success "Performance improved by ${improvement}%"
        else
            log_success "Performance within acceptable range"
        fi
        return 0
    else
        local regression=$(echo "scale=1; ($SCAN_DURATION - $baseline_duration) * 100 / $baseline_duration" | bc)
        log_error "Performance regression detected: ${regression}% slower than baseline"
        return 1
    fi
}

# Create or update performance baseline
create_performance_baseline() {
    log_info "Creating performance baseline..."
    
    # Run multiple measurements for accuracy
    local runs=3
    local total_duration=0
    local measurements="["
    
    for i in $(seq 1 $runs); do
        log_info "Measurement run $i/$runs..."
        
        local temp_output=$(mktemp)
        run_validation "$temp_output"
        local duration=$(cat "$REPORTS_DIR/scan_duration.txt")
        
        total_duration=$((total_duration + duration))
        
        if [ "$i" -gt 1 ]; then
            measurements="$measurements,"
        fi
        
        measurements="$measurements{\"duration\":$duration,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}"
        
        rm -f "$temp_output"
    done
    
    measurements="$measurements]"
    local avg_duration=$((total_duration / runs))
    
    # Create baseline file
    cat > "$PERFORMANCE_BASELINE" << EOF
{
  "avgDuration": $avg_duration,
  "measurements": $measurements,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "version": "$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | cut -d' ' -f2)"
}
EOF
    
    log_success "Performance baseline created: ${avg_duration}ms average"
}

# Update baseline (manual operation)
update_baseline() {
    log_section "Baseline Update"
    
    # Confirm with user
    echo -n "Are you sure you want to update the performance baseline? (y/N): "
    read -r confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        log_info "Baseline update cancelled"
        return 0
    fi
    
    # Backup existing baseline
    if [ -f "$PERFORMANCE_BASELINE" ]; then
        local backup_file="$PERFORMANCE_BASELINE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$PERFORMANCE_BASELINE" "$backup_file"
        log_info "Existing baseline backed up to: $backup_file"
    fi
    
    # Create new baseline
    create_performance_baseline
}

# Generate comprehensive report
generate_report() {
    log_section "Report Generation"
    
    # Create markdown report
    local report_file="$REPORTS_DIR/validation_report.md"
    
    cat > "$report_file" << EOF
# Flutter KeyCheck Validation Report

**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Branch**: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")  
**Commit**: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")  

## 📊 Validation Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total Keys | ${TOTAL_KEYS}/14 | $(if [ "$TOTAL_KEYS" -ge 14 ]; then echo "✅ Complete"; else echo "⚠️ Incomplete"; fi) |
| Critical Keys | ${CRITICAL_KEYS}/4 | $(if [ "$CRITICAL_KEYS" -ge 4 ]; then echo "✅ Complete"; else echo "❌ Missing"; fi) |
| Coverage Score | ${COVERAGE_SCORE}% | $(if (( $(echo "$COVERAGE_SCORE >= 80" | bc -l) )); then echo "✅ Pass"; else echo "❌ Fail"; fi) |
| Scan Duration | ${SCAN_DURATION}ms | $(if [ "$SCAN_DURATION" -lt 30000 ]; then echo "✅ Fast"; else echo "⚠️ Slow"; fi) |

## 🚦 Quality Gates

$(if validate_quality_gates > /dev/null 2>&1; then echo "✅ **All quality gates passed**"; else echo "❌ **Quality gate failures detected**"; fi)

$(if [ -f "$PERFORMANCE_BASELINE" ]; then
    baseline_duration=$(grep -o '"avgDuration":[0-9]*' "$PERFORMANCE_BASELINE" | grep -o '[0-9]*')
    if check_performance_regression > /dev/null 2>&1; then
        echo "✅ **No performance regression** (${SCAN_DURATION}ms vs ${baseline_duration}ms baseline)"
    else
        echo "❌ **Performance regression detected** (${SCAN_DURATION}ms vs ${baseline_duration}ms baseline)"
    fi
else
    echo "ℹ️ **No performance baseline available**"
fi)

## 📈 Performance Analysis

- **Scan Duration**: ${SCAN_DURATION}ms
- **Performance Grade**: $(if [ "$SCAN_DURATION" -lt 10000 ]; then echo "A (Excellent)"; elif [ "$SCAN_DURATION" -lt 20000 ]; then echo "B (Good)"; else echo "C (Acceptable)"; fi)
$(if [ -f "$PERFORMANCE_BASELINE" ]; then
    baseline_duration=$(grep -o '"avgDuration":[0-9]*' "$PERFORMANCE_BASELINE" | grep -o '[0-9]*')
    echo "- **Baseline Comparison**: ${baseline_duration}ms average"
fi)

---
*Generated by Flutter KeyCheck Baseline Management*
EOF

    log_success "Report generated: $report_file"
}

# Main command handling
case "${1:-help}" in
    "validate")
        log_section "Flutter KeyCheck Baseline Validation"
        
        # Setup
        mkdir -p "$REPORTS_DIR"
        check_binary
        
        # Run validation
        local output_file="$REPORTS_DIR/validation_output.log"
        if run_validation "$output_file"; then
            log_success "Validation completed successfully"
        else
            log_warning "Validation completed with warnings/errors"
        fi
        
        # Parse and analyze results
        parse_results "$output_file"
        
        # Display results
        echo
        log_info "📊 Validation Results:"
        echo "   • Keys Found: $TOTAL_KEYS/14"
        echo "   • Critical Keys: $CRITICAL_KEYS/4"
        echo "   • Coverage Score: ${COVERAGE_SCORE}%"
        echo "   • Scan Duration: ${SCAN_DURATION}ms"
        
        # Run quality gates
        echo
        validate_quality_gates
        
        # Check performance regression
        echo
        check_performance_regression
        
        # Generate report
        echo
        generate_report
        
        # Exit with appropriate code
        if [ "$EXIT_CODE" -eq 0 ] && validate_quality_gates > /dev/null 2>&1; then
            log_success "All validations passed - ready for deployment"
            exit 0
        else
            log_error "Validation or quality gate failures detected"
            exit 1
        fi
        ;;
        
    "baseline")
        log_section "Performance Baseline Management"
        
        check_binary
        mkdir -p "$REPORTS_DIR"
        
        case "${2:-}" in
            "create")
                create_performance_baseline
                ;;
            "update")
                update_baseline
                ;;
            "show")
                if [ -f "$PERFORMANCE_BASELINE" ]; then
                    log_info "Current performance baseline:"
                    cat "$PERFORMANCE_BASELINE" | jq '.'
                else
                    log_warning "No performance baseline found"
                fi
                ;;
            *)
                echo "Usage: $0 baseline {create|update|show}"
                exit 1
                ;;
        esac
        ;;
        
    "report")
        log_section "Report Generation"
        
        if [ -f "$REPORTS_DIR/validation_summary.json" ]; then
            # Load existing results
            source <(cat "$REPORTS_DIR/validation_summary.json" | jq -r '.summary | to_entries[] | "export " + (.key | ascii_upcase) + "=" + (.value | tostring)')
            generate_report
        else
            log_error "No validation results found. Run 'validate' first."
            exit 1
        fi
        ;;
        
    "help"|*)
        echo "Flutter KeyCheck Baseline Management Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  validate              Run full validation with quality gates"
        echo "  baseline create       Create initial performance baseline"
        echo "  baseline update       Update existing performance baseline"
        echo "  baseline show         Show current performance baseline"
        echo "  report                Generate validation report"
        echo "  help                  Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 validate           # Run validation and quality gates"
        echo "  $0 baseline create    # Create performance baseline"
        echo "  $0 report             # Generate markdown report"
        ;;
esac