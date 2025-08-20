# Comprehensive Request Examples for flutter_keycheck

This document provides practical examples of how to effectively use flutter_keycheck agents for various development tasks.

## 📝 Task Management Examples

### Simple Task Request
```bash
"Add support for exporting results to XML format for Jenkins integration"
```
Activates: **report-generator** → creates XML exporter

### Complex Task Request
```bash
"Implement incremental scanning feature:
- Scan only changed files since last run
- Cache results from previous scans
- Support git diff for change detection
- Store cache in .flutter_keycheck/cache/
- Add --incremental flag to CLI"
```
Activates: **orchestrator** → **ast-scanner** + **performance-optimizer** + **config-manager**

### Task with Success Criteria
```bash
"@performance-optimizer Optimize scanning for large projects:
Requirements:
- Scan 10,000 files in < 5 seconds
- Memory usage < 500MB
- Support parallel scanning
- Progress bar for long operations
Create benchmarks before and after optimization"
```

## 📋 Planning Examples

### Refactoring Plan
```bash
"@refactoring-specialist Create migration plan from v2 API to v3:
- Analyze breaking changes
- Component migration order
- Backward compatibility strategy
- Testing plan
- Time estimates"
```

### New Feature Plan
```bash
"Develop plan for adding real-time key monitoring:
1. File watcher for change detection
2. WebSocket server for UI dashboard
3. VS Code extension integration
4. Metrics and alerts
Consider performance and scalability"
```

### Release Plan
```bash
"@flutter-keycheck-senior Prepare v3.0.0 release plan:
- Pre-release checklist
- Breaking changes verification
- Documentation and CHANGELOG updates
- Testing across Flutter versions
- pub.dev publication
- Announcement and migration guide"
```

## 📚 Documentation Examples

### API Documentation
```bash
"@report-generator Create complete API documentation for KeyChecker class:
- Description of all public methods
- Usage examples
- Edge cases and limitations
- Performance characteristics
Format: DartDoc comments"
```

### User Guide
```bash
"Write user guide for QA engineers using flutter_keycheck:
1. Quick start (installation, first run)
2. Project configuration setup
3. CI/CD integration (GitHub Actions, GitLab, Jenkins)
4. Best practices for key naming
5. Troubleshooting common issues
Include real production examples"
```

### Migration Guide
```bash
"@refactoring-specialist Create migration guide from version 2.x to 3.0:
- Breaking changes with before/after examples
- New features and usage
- Step-by-step migration instructions
- Automated migration where possible
- FAQ for common questions"
```

### README Update
```bash
"Update README.md for flutter_keycheck:
- Current badges (pub.dev, CI status, coverage)
- Clear description of tool purpose
- Installation (pub global, compiled binary, Docker)
- 2-minute quick start
- Comparison with alternatives
- Contributing guidelines
Make it attractive for pub.dev"
```

## 🎯 flutter_keycheck Specific Examples

### Codebase Analysis
```bash
"@ast-scanner Analyze key usage in our project:
- Top 10 most used keys
- Keys without prefixes/namespaces
- Dynamic vs static keys
- Potential name conflicts
Output as table with recommendations"
```

### CI/CD Setup
```bash
"@cicd-pipeline Setup GitHub Actions workflow:
- Run on every PR to lib/ and test/
- Cache Dart dependencies
- Parallel runs for different Flutter versions (stable, beta)
- Fail if missing keys found
- PR comment with results
- Artifacts with HTML report"
```

### Testing
```bash
"@test-automation Create comprehensive test suite:
1. Unit tests for all public APIs
2. Integration tests for CLI commands
3. Golden tests for reports
4. Performance tests for large projects
5. Edge cases (empty projects, circular dependencies)
Coverage target: >90%"
```

### Optimization
```bash
"@performance-optimizer Profile and optimize:
- Find bottlenecks in AST parsing
- Implement lazy loading for large files
- Add parallel directory processing
- Optimize regex patterns
- Reduce memory footprint by 30%
Show before/after metrics"
```

## 💡 Best Practices for Request Formulation

1. **Be specific** - The more precise the task, the better the result
2. **Provide context** - Why the feature is needed, who will use it
3. **Define success criteria** - Metrics, performance targets
4. **Break down large tasks** - Use numbered lists for clarity
5. **Indicate priorities** - What's critical vs nice-to-have

## 🔄 Iterative Work Examples

```bash
# First iteration
"Create basic XML exporter for reports"

# After review
"Add JUnit XML format support for Jenkins"

# Final refinement
"Optimize XML generation for reports >10MB"
```

## 🚀 Advanced Agent Coordination

### Multi-Agent Workflow
```bash
"Complete v3 refactoring with performance optimization and full test coverage"
# Activates: refactoring-specialist → performance-optimizer → test-automation
```

### Cross-Domain Task
```bash
"Audit code quality and performance comprehensively"
# Activates: ast-scanner → performance-optimizer → report-generator
```

### Context Sharing Between Agents
```bash
"First analyze all keys, then create report and suggest optimizations"
# context-manager preserves analysis results for subsequent agents
```

## 📊 Metrics and Monitoring

### Dashboard Creation
```bash
"Create dashboard with scanning performance metrics"
```

### Alert Configuration
```bash
"Setup alerts for >20% performance degradation"
```

## 🎯 Domain-Specific Expertise

Each agent is an expert in their domain:
- **ast-scanner**: Deep AST analysis, usage patterns
- **key-validator**: Business logic validation, requirements compliance
- **performance-optimizer**: Profiling, benchmarks, optimization
- **config-manager**: YAML configurations, CLI arguments, environment variables
- **report-generator**: Multi-format reports (JSON, XML, HTML, Markdown)
- **test-automation**: Test suite management, coverage analysis
- **cicd-pipeline**: CI/CD configuration for various platforms
- **refactoring-specialist**: Code quality improvements, technical debt reduction

## 🎨 Output Format Examples

### JSON Report Request
```bash
"Generate JSON report with nested structure for programmatic consumption"
```

### HTML Dashboard Request
```bash
"Create interactive HTML dashboard with charts and filtering capabilities"
```

### Markdown Summary Request
```bash
"Generate concise Markdown summary for PR description"
```

## 🔧 Configuration Examples

### Environment-Specific Config
```bash
"@config-manager Setup multi-environment configuration:
- Development: verbose logging, no caching
- Staging: moderate logging, partial caching
- Production: minimal logging, full caching"
```

### CLI Enhancement
```bash
"Add interactive mode to CLI with prompts for configuration"
```

## 📈 Performance Profiling

### Benchmark Creation
```bash
"Create comprehensive benchmark suite:
- Small project (<100 files)
- Medium project (100-1000 files)
- Large project (1000-10000 files)
- Enterprise project (>10000 files)
Track: time, memory, CPU usage"
```

### Regression Testing
```bash
"Setup performance regression tests with 10% tolerance threshold"
```

---

**Note**: Agents automatically understand context and can be combined for complex tasks. Use natural language for requests, and agents will coordinate through the orchestrator for optimal results.