# Flutter KeyCheck - Brownfield Architecture Document

## Executive Summary

Flutter KeyCheck v3.2.0 is a mature CLI tool for Flutter widget key analysis, currently undergoing significant refactoring. This document captures the ACTUAL current state, including technical debt, workarounds, and architectural realities.

## Current System State

### Version & Status
- **Current Version**: 3.2.0
- **Branch**: flutter_keycheck_v3 (uncommitted changes)
- **Package Status**: Published on pub.dev
- **Refactoring Phase**: Active (reporter consolidation, V2 removal)

### Technology Stack (Reality)

| Component | Technology | Version | Issues/Notes |
|-----------|------------|---------|--------------|
| Language | Dart | 3.35.1 | SDK constraint: >=3.2.0 <4.0.0 |
| Analyzer | analyzer | 7.7.1 | Recently updated from 5.13.0, some tests failing |
| CLI Framework | args | >=2.4.2 <3.0.0 | Stable |
| Testing | test | 1.26.3 | 16 tests failing post-update |
| Linting | lints | 5.0.0 | Updated from 4.0.0 |
| Color Output | ansicolor | 2.0.2 | Working |
| Caching | crypto | >=3.0.3 <4.0.0 | Cache implementation incomplete |

## Architectural Layers (Current Reality)

### 1. CLI Layer - FRAGMENTED
```
bin/
└── flutter_keycheck.dart (entry point)

lib/src/cli/
└── cli_runner.dart (main runner)

lib/src/commands/ (DUPLICATED V2/V3)
├── base_command.dart.v2.old (archived)
├── base_command_v3.dart (active)
├── scan_command.dart.v2.old (archived)
├── scan_command_v3.dart (active)
├── validate_command.dart.v2.old (archived)
├── validate_command_v3.dart (active)
├── baseline_command.dart (legacy)
├── diff_command.dart (legacy)
├── report_command.dart (legacy)
└── sync_command.dart (legacy)
```

**Issues**:
- Dual command system (V2/V3) causing confusion
- Legacy commands still present but unused
- Inconsistent naming conventions

### 2. Core Engine - PARTIALLY DUPLICATED
```
lib/src/
├── ast_scanner.dart (v2 implementation)
├── scanner/
│   ├── ast_scanner_v3.dart (v3 implementation)
│   ├── key_detectors.dart (v2 patterns)
│   ├── key_detectors_v3.dart (v3 patterns)
│   └── workspace_scanner.dart (shared)
```

**Issues**:
- Two AST scanner implementations
- Duplicate key detector logic
- Unclear which version is canonical

### 3. Reporter System - TRIPLE IMPLEMENTATION
```
lib/src/reporter/
├── base_reporter.dart (interface)
├── reporter_v3.dart (5000+ lines, contains HtmlReporter)
├── html_reporter.dart.old (1198 lines, archived)
├── html_reporter_optimized.dart (556 lines, ACTIVE)
├── ci_reporter.dart (working)
└── coverage_reporter.dart (working)
```

**Critical Issue**: 
- THREE different HTML reporter implementations
- OptimizedHtmlReporter extends ReporterV3, not BaseReporter
- Inheritance hierarchy broken after consolidation attempt

### 4. Data Layer - STABLE BUT INCOMPLETE
```
lib/src/
├── cache/
│   ├── cache_manager.dart (INCOMPLETE - has unused _statsFile)
│   ├── scan_cache.dart (working)
│   └── dependency_cache.dart (partial)
├── models/
│   ├── scan_result.dart (stable)
│   ├── validation_result.dart (stable)
│   └── scan_metrics.dart (stable)
├── registry/
│   ├── key_registry_v3.dart (working)
│   └── package_registry.dart (working)
```

**Issues**:
- Cache invalidation not implemented
- Dependency caching incomplete
- Stats collection not working

### 5. Quality & Performance - UNDERUTILIZED
```
lib/src/
├── quality/
│   └── quality_scorer.dart (has linting issues)
├── performance/
│   └── performance_profiler.dart (basic)
├── metrics/
│   └── metrics_collector.dart (basic)
└── stats/
    └── stats_calculator.dart (has linting issues)
```

**Issues**:
- Multiple linting warnings (curly braces in flow control)
- Unused methods in reporter_v3.dart
- Performance profiling minimal

## Technical Debt Inventory

### Critical Issues
1. **Reporter Inheritance Broken**
   - OptimizedHtmlReporter doesn't extend BaseReporter
   - Factory pattern fails with type mismatch
   - Tests failing due to class hierarchy

2. **Test Suite Failures**
   - 16 tests failing after dependency update
   - Coverage calculation precision issues
   - Reporter tests broken

3. **Command Duplication**
   - V2 and V3 commands coexist
   - Unclear migration path
   - Legacy commands not removed

### Medium Priority
1. **Cache Implementation**
   - Incomplete dependency caching
   - No invalidation strategy
   - Unused stat collection

2. **Code Quality Issues**
   - 30 linting warnings
   - Unused methods and fields
   - Inconsistent formatting

3. **Documentation Gaps**
   - Migration guide incomplete
   - API documentation outdated
   - Architecture diagrams missing

### Low Priority
1. **Performance Optimization**
   - No parallel processing
   - Basic profiling only
   - Cache hit rate ~80% (target 85%)

## Workarounds & Gotchas

### Current Workarounds
1. **Reporter Selection**: Using file extension detection (.old) to avoid loading wrong version
2. **Command Routing**: CLI runner checks for _v3 suffix first, falls back to v2
3. **Test Precision**: Using approximate equality for coverage calculations
4. **BMAD Integration**: Scripts have hardcoded paths, need PROJECT_ROOT fixes

### Known Gotchas
1. **Analyzer API Changes**: v7.x has different API than v5.x, causing test failures
2. **Exit Codes**: Deterministic codes break existing CI/CD setups
3. **Scope Flag**: New --scope flag not backward compatible
4. **Reporter Factory**: Assumes BaseReporter inheritance, breaks with ReporterV3

## Integration Points

### External Dependencies
- pub.dev (published package)
- GitHub (source control)
- BMAD system (partial integration via node_modules)

### CI/CD Status
- GitHub Actions: Configured but needs fixes
- GitLab CI: Template exists, not active
- Local testing: Works with workarounds

## Resource Constraints

### Performance Metrics (Current)
- Scan time: ~30s for 1000 files (target: <20s)
- Memory usage: ~500MB peak (target: <400MB)
- Cache hit rate: ~80% (target: >85%)
- Test execution: ~48s (too slow)

### Development Constraints
- Single maintainer
- Limited test coverage
- No automated release process
- Manual documentation updates

## Migration & Compatibility

### Breaking Changes in V3
1. CLI redesign with subcommands
2. Deterministic exit codes
3. Scope-based scanning
4. Configuration file format changes

### Backward Compatibility Issues
- V2 commands archived but not removed
- Configuration migration not automated
- API changes not documented

## Security & Compliance

### Current Security Posture
- Read-only file access (good)
- No network operations (good)
- Path traversal prevention (good)
- No sensitive data handling (good)

### Compliance Gaps
- No security scanning in CI
- No dependency vulnerability checks
- No automated compliance validation

## Recommendations for Improvement

### Immediate Actions Required
1. Fix OptimizedHtmlReporter inheritance
2. Complete test suite repairs
3. Remove V2 command files completely
4. Fix BMAD script path issues

### Short-term Improvements
1. Complete cache implementation
2. Consolidate scanner implementations
3. Update documentation
4. Add performance benchmarks

### Long-term Architecture Changes
1. Plugin architecture for extensibility
2. Real-time monitoring capabilities
3. Cloud dashboard for metrics
4. IDE integration support

## Appendix: File Structure Reality

### What's Actually Being Used
```
ACTIVE:
- bin/flutter_keycheck.dart
- lib/src/cli/cli_runner.dart
- lib/src/commands/*_v3.dart files
- lib/src/reporter/html_reporter_optimized.dart
- lib/src/scanner/ast_scanner_v3.dart

LEGACY (should remove):
- lib/src/commands/[base|scan|validate]_command.dart
- lib/src/reporter/html_reporter.dart
- lib/src/scanner/ast_scanner.dart

BROKEN:
- lib/src/cache/cache_manager.dart (incomplete)
- Test suite (16 failures)
```

---

*Generated: 2024-12-29 | Winston - BMAD Architect*
*This document reflects the TRUE current state, not the ideal state*