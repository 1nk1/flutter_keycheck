# Flutter KeyCheck Brownfield PRD (Product Requirements Document)

## Executive Summary

Flutter KeyCheck is an enterprise-grade Flutter widget key analyzer CLI tool currently at v3.2.0. It provides static analysis of Flutter codebases to identify and validate widget keys for QA automation, with premium HTML reports, CI/CD integration, and advanced analytics. The tool has evolved from v2 to v3 with breaking changes, performance improvements, and a modernized architecture.

## Current State Assessment

### Product Maturity
- **Version**: 3.2.0 (Latest stable)
- **Package Status**: Published on pub.dev
- **User Base**: QA automation engineers, Flutter development teams, DevOps engineers, package maintainers
- **Platform Support**: Linux, macOS, Windows, Android, iOS, Web
- **Dart SDK**: >=3.2.0 <4.0.0
- **Performance**: 60% faster than v2, 84KB package size

### Technical Architecture
- **Language**: Dart
- **Architecture Pattern**: Command-based CLI with subcommands
- **Core Technology**: AST (Abstract Syntax Tree) parsing using analyzer package
- **Key Dependencies**: 
  - analyzer: ^5.3.0 (AST parsing)
  - args: >=2.4.2 <3.0.0 (CLI arguments)
  - ansicolor: ^2.0.2 (Terminal colors)
  - crypto: >=3.0.3 <4.0.0 (Caching/checksums)

### Current Capabilities

#### Core Features
1. **AST-Based Key Detection**
   - Traditional patterns: `Key('string')`, `ValueKey('string')`
   - Modern patterns: `Key(KeyConstants.field)`, `ValueKey(KeyConstants.field)`
   - Dynamic methods: `KeyConstants.keyMethod()`
   - Test finders: `find.byKey()`, `find.byValueKey()`

2. **Premium Reporting**
   - Glassmorphism HTML reports with advanced analytics
   - Terminal CI/CD output with ANSI colors
   - Multiple formats: HTML, CI, JSON, Markdown, Text, JUnit XML
   - Quality scoring (0-100) with performance charts
   - Interactive tables with search and filtering

3. **CI/CD Integration**
   - Deterministic exit codes (0=success, 1=policy, 2=config, 3=I/O, 4=internal)
   - GitLab CI/CD ready with collapsible sections
   - GitHub Actions support
   - Quality gates and thresholds
   - JUnit XML output for test reporting

4. **Advanced Filtering**
   - Include/exclude patterns with regex support
   - Tag-based filtering (aqa_*, e2e_*)
   - Tracked keys for critical elements
   - Scope-based scanning (workspace-only, deps-only, all)

### Technical Debt & Constraints

#### Known Issues
1. **Performance**: Some reporter modules have duplicated logic (html_reporter.dart vs html_reporter_optimized.dart)
2. **Version Fragmentation**: Multiple v2/v3 command variants still exist in codebase
3. **Cache Management**: Dependency caching implementation incomplete
4. **Test Coverage**: Limited integration test coverage (phase2_integration_test.dart incomplete)

#### Architecture Constraints
1. **Breaking Changes from v2**: CLI redesigned with subcommands, requires migration
2. **Exit Code Standards**: Deterministic codes now enforced, may break existing CI/CD
3. **Scope Requirements**: New scope-based scanning affects default behavior
4. **Reporter Complexity**: Multiple reporter implementations create maintenance burden

### Business Context

#### Target Users
1. **QA Automation Engineers**: Need reliable key tracking for UI testing
2. **Flutter Development Teams**: Require consistent key naming and testability
3. **DevOps Engineers**: Need CI/CD quality gates and automation
4. **Package Maintainers**: Must validate example apps and demos

#### Success Metrics
- **Scan Performance**: <30 seconds for large projects
- **Coverage Requirements**: 80% widget key coverage
- **Quality Score**: Target 85+ quality score
- **False Positive Rate**: <5% for key detection
- **CI/CD Integration**: Zero-config for major platforms

## Enhancement Opportunities

### High Priority Improvements

#### 1. Performance Optimization
- **Problem**: Duplicate reporter implementations cause confusion
- **Solution**: Consolidate html_reporter.dart and html_reporter_optimized.dart
- **Impact**: Cleaner codebase, better performance, easier maintenance

#### 2. Complete Cache Implementation
- **Problem**: Dependency caching partially implemented
- **Solution**: Complete cache_manager.dart with proper invalidation
- **Impact**: Faster subsequent scans, reduced I/O operations

#### 3. Enhanced Test Coverage
- **Problem**: Integration tests incomplete, especially phase2 features
- **Solution**: Complete phase2_integration_test.dart, add E2E tests
- **Impact**: Higher reliability, safer releases

#### 4. V2 Migration Tooling
- **Problem**: Breaking changes from v2 to v3 cause adoption friction
- **Solution**: Create migration command or automated converter
- **Impact**: Smoother upgrades, wider v3 adoption

### Medium Priority Enhancements

#### 5. Plugin Architecture
- **Problem**: All features built into core, no extensibility
- **Solution**: Create plugin system for custom reporters/analyzers
- **Impact**: Community contributions, custom enterprise features

#### 6. Real-time Monitoring
- **Problem**: Static analysis only, no runtime validation
- **Solution**: Add optional runtime key validation mode
- **Impact**: Complete testing coverage, catch dynamic key issues

#### 7. IDE Integration
- **Problem**: CLI-only interface, no IDE support
- **Solution**: Create VS Code and IntelliJ plugins
- **Impact**: Developer productivity, inline validation

### Low Priority Features

#### 8. Cloud Dashboard
- **Problem**: Reports are local-only
- **Solution**: Optional cloud dashboard for team analytics
- **Impact**: Team collaboration, historical tracking

#### 9. AI-Powered Suggestions
- **Problem**: Manual key naming decisions
- **Solution**: AI suggestions for key naming patterns
- **Impact**: Consistency improvements, best practices adoption

## Technical Requirements

### Performance Requirements
- Scan time: <30 seconds for 1000+ files
- Memory usage: <500MB for large projects
- Report generation: <5 seconds
- Cache hit rate: >80% for unchanged files

### Compatibility Requirements
- Dart SDK: Maintain 3.2.0+ compatibility
- Flutter: Support latest stable and beta
- CI/CD: GitLab, GitHub Actions, Azure DevOps, CircleCI
- OS: Linux, macOS, Windows full support

### Quality Requirements
- Test coverage: >80% unit, >60% integration
- Documentation: Comprehensive API docs
- Error handling: Graceful failures with actionable messages
- Logging: Verbose mode for debugging

## Migration Considerations

### From V2 to V3
- Provide clear migration guide
- Maintain v2 support branch
- Offer automated migration tools
- Document all breaking changes

### Future Breaking Changes
- Minimize API surface changes
- Use deprecation warnings
- Provide migration period
- Maintain backward compatibility where possible

## Risk Assessment

### Technical Risks
1. **Analyzer Package Changes**: Breaking changes in analyzer API
   - Mitigation: Pin versions, test against multiple versions
   
2. **Performance Regression**: New features slow down scans
   - Mitigation: Performance benchmarks in CI/CD
   
3. **False Positives**: Incorrect key detection patterns
   - Mitigation: Comprehensive test suite, user feedback loop

### Business Risks
1. **Adoption Resistance**: Users stay on v2
   - Mitigation: Clear benefits, migration tooling
   
2. **Competitor Tools**: Alternative solutions emerge
   - Mitigation: Unique features, community engagement
   
3. **Maintenance Burden**: Growing complexity
   - Mitigation: Modular architecture, plugin system

## Recommended Next Steps

### Immediate Actions (Sprint 1)
1. Consolidate reporter implementations
2. Complete dependency caching
3. Fix critical bugs in v3 branch
4. Update documentation

### Short Term (Month 1-2)
1. Complete integration test suite
2. Create v2 to v3 migration tool
3. Optimize performance bottlenecks
4. Add plugin architecture foundation

### Long Term (Quarter 1-2)
1. Develop IDE integrations
2. Implement real-time monitoring
3. Create cloud dashboard MVP
4. Build community plugin ecosystem

## Success Criteria

### Technical Success
- All tests passing (>80% coverage)
- Performance targets met (<30s scan)
- Zero critical bugs
- Clean architecture without duplication

### Business Success
- v3 adoption >50% within 6 months
- Active community contributions
- Enterprise customer adoption
- Positive user feedback (>4.5 stars)

### Quality Metrics
- Quality score consistently >85
- False positive rate <5%
- Scan coverage >80%
- CI/CD integration success rate >95%

## Appendix

### Current File Structure
- **Core**: lib/src/ (checker, cli, config, scanner, reporter)
- **Commands**: lib/src/commands/ (scan, validate, baseline, report)
- **Models**: lib/src/models/ (scan_result, validation_result, metrics)
- **Tests**: test/ (unit tests), test/v3/ (v3-specific tests)
- **Documentation**: docs/ (migration guides, evidence reports)

### Key Technical Decisions
1. AST parsing over regex for accuracy
2. Subcommand architecture for extensibility
3. Deterministic exit codes for CI/CD
4. Plugin architecture for future growth

### Dependencies to Monitor
- analyzer: Critical for AST parsing
- args: CLI argument handling
- yaml: Configuration file parsing
- crypto: Caching and checksums

---

*This PRD reflects the current brownfield state of Flutter KeyCheck v3.2.0 as of 2025-08-30, focusing on realistic enhancements while acknowledging technical debt and constraints.*