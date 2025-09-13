# Flutter KeyCheck Product Overview

Flutter KeyCheck is an enterprise-grade Flutter widget key analyzer that provides comprehensive static analysis of Flutter applications to ensure proper key coverage for UI automation and testing.

## Core Purpose

- **Static Analysis Tool**: Analyzes Flutter codebases to identify which widgets have keys and which don't
- **QA Automation Support**: Helps QA teams ensure critical UI elements are properly keyed for automated testing
- **CI/CD Integration**: Provides quality gates and validation for continuous integration pipelines
- **Enterprise Reporting**: Generates premium HTML reports with glassmorphism UI and advanced analytics

## Key Features

- **AST-Based Analysis**: Uses Dart analyzer for deep code inspection
- **Multiple Report Formats**: HTML (premium), CI/CD terminal output, JSON, Markdown, JUnit XML
- **Key Pattern Detection**: Supports modern KeyConstants patterns and traditional string-based keys
- **Quality Gates**: Coverage thresholds, blind spot detection, performance validation
- **Package Support**: Handles Flutter packages with example/ folders automatically
- **Caching System**: Performance optimization with dependency and scan caching

## Target Users

- **QA Automation Engineers**: Generate baseline keys, track critical UI elements
- **Flutter Development Teams**: Ensure consistent key naming and maintainability
- **DevOps Engineers**: Implement quality gates and automated validation
- **Package Maintainers**: Validate example apps and documentation accuracy

## Version Strategy

- **v3.x**: Current major version with breaking changes, subcommand CLI, deterministic exit codes
- **v2.x**: Legacy version with traditional CLI interface, still supported
- Migration path available with comprehensive documentation
