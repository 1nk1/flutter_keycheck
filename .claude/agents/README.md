---
name: readme
description: Documentation for flutter_keycheck agent architecture
---

# Flutter KeyCheck Agent Architecture

This directory contains specialized Claude Code subagents for the flutter_keycheck project. All agents are configured using Markdown files with YAML frontmatter, following Claude Code's subagent specification.

## Agent Structure

### Core Agents (`/core/`)
Foundation agents that provide essential capabilities and coordination:

- **base-agent.md**: Foundation agent for task analysis, delegation, and context management
- **orchestrator.md**: Master orchestration for complex multi-agent workflows
- **context-manager.md**: Context preservation and state management across agent interactions

### Main Agents (`/`)
High-level agents for senior engineering and architecture:

- **flutter-keycheck-senior.md**: Principal-level Flutter/Dart architect for high-stakes work
- **main-architect.md**: Systems architecture specialist with CI/CD and release engineering focus

### Specialist Agents (`/specialists/flutter_keycheck/`)
Domain-specific experts for targeted tasks:

- **ast-scanner.md**: AST analysis expert using Dart's analyzer package for key detection
- **key-validator.md**: Validation specialist for checking keys against expected patterns
- **cicd-pipeline.md**: CI/CD specialist for GitHub Actions and GitLab CI integration
- **performance-optimizer.md**: Performance profiling and optimization expert
- **report-generator.md**: Report generation in multiple formats (JSON, XML, Markdown, HTML)
- **test-automation.md**: Test suite creation and coverage management
- **config-manager.md**: Configuration management for YAML files and CLI arguments
- **refactoring-specialist.md**: Code quality and refactoring expert

## Agent Invocation

Agents can be invoked in two ways:

### 1. Automatic Delegation
Claude Code will automatically select the appropriate agent based on context and task requirements.

### 2. Explicit Invocation
You can explicitly request a specific agent:
```
> Use the ast-scanner agent to analyze the key patterns in lib/
```

## Agent Capabilities

All agents are Dart/Flutter specialists with:
- **Zero Python dependencies** - Pure Dart/Flutter focus
- **Production-ready** - Following enterprise best practices
- **Tool integration** - Using appropriate Claude Code tools (Read, Write, Edit, Bash, etc.)
- **Quality focus** - Emphasis on testing, linting, and performance

## Key Features

### Specialized Expertise
Each agent has deep knowledge in their domain:
- AST manipulation and visitor patterns
- CI/CD pipeline optimization
- Performance profiling and benchmarking
- Test-driven development
- Configuration management
- Code refactoring patterns

### Coordination
Agents work together through:
- Shared context via context-manager
- Orchestrated workflows via orchestrator
- Clear handoff protocols between specialists
- Consistent quality standards

### Flutter KeyCheck Focus
All agents understand:
- Key detection patterns (Key, ValueKey, GlobalKey, KeyConstants)
- Flutter project structures
- Dart analyzer package
- pub.dev publishing requirements
- CI/CD best practices for Dart

## Usage Examples

### Scanning for Keys
```
Scan the project for all Flutter automation keys
```
→ Automatically uses ast-scanner agent

### Setting up CI/CD
```
Configure GitHub Actions for key validation
```
→ Automatically uses cicd-pipeline agent

### Performance Optimization
```
Profile and optimize the scanning performance
```
→ Automatically uses performance-optimizer agent

### Complex Workflows
```
Refactor the scanner, update tests, and ensure CI passes
```
→ Orchestrator coordinates multiple agents

## Configuration

Agents are configured with:
- **name**: Unique identifier (lowercase with hyphens)
- **description**: When to use this agent
- **tools**: Optional list of specific Claude Code tools

Example:
```yaml
---
name: ast-scanner
description: AST scanning specialist for detecting Flutter keys
tools: Read, Glob, Grep, Bash
---
```

## Best Practices

1. **Let agents auto-select** - Claude Code's routing is usually optimal
2. **Be specific with requests** - Clear requirements help agent selection
3. **Trust the specialists** - Each agent is an expert in their domain
4. **Review agent suggestions** - Agents provide reasoning for their decisions
5. **Maintain agent focus** - Don't modify agents to handle unrelated tasks

## Maintenance

To update agents:
1. Edit the markdown file directly
2. Ensure YAML frontmatter is valid
3. Test agent invocation
4. Verify coordination with other agents

## Version

Current agent architecture version: **2.0.0**
- Migrated from YAML to Markdown format
- Removed all Python dependencies
- Optimized for flutter_keycheck project
- Production-ready with comprehensive coverage