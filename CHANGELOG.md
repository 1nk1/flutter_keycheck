# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Enhanced development environment integration with MCP (Model Context Protocol) servers
- Improved AI-assisted development workflow support

### Fixed
- Fixed HTML rendering bug in Premium Dashboard Reporter's "Key Locations" modal window where CODE CONTEXT sections displayed raw HTML/CSS tags instead of clean Dart code. The modal now properly renders Dart code snippets with HTML entity escaping, ensuring safe display of code containing HTML-like syntax (generics, comparisons, etc.).

## [3.2.0] - 2024-12-14

### Added
- Dart 3.24.5 and analyzer 5.3.x compatibility
- Premium Dashboard Reporter implementation
- Enhanced key validation and reporting capabilities
- New scan command options:
  - `--include-generated` - Include generated files (.g.dart, .freezed.dart)
  - `--include-examples` - Scan example/* packages as part of workspace
  - `--since <commit>` - Incremental scan since git commit/branch
  - `--filter <pattern>` - Filter packages by pattern (for monorepo)
  - `--light-html` - Generate lightweight HTML report without heavy effects
- Enhanced configuration structure with v3 schema
- Improved CLI help and documentation

### Changed
- Updated dependencies for latest Dart SDK compatibility
- Improved analyzer integration
- Enhanced configuration file structure with separate sections for registry, scan, policies, and report settings
- Updated documentation to reflect current CLI structure and options

### Fixed
- Analyzer compatibility issues with latest Dart SDK versions
- HTML rendering bug in Premium Dashboard Reporter's "Key Locations" modal window
