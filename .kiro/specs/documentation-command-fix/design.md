# Design Document

## Overview

This design addresses the documentation inconsistency where the non-existent `ci-validate` command is referenced instead of the correct `validate` command. The solution involves a systematic search and replace operation across all documentation files, with careful attention to context preservation and verification.

## Architecture

### Search and Replace Strategy
The fix will use a multi-phase approach:
1. **Discovery Phase**: Comprehensive search to identify all instances of "ci-validate"
2. **Analysis Phase**: Review each instance for context and replacement appropriateness
3. **Replacement Phase**: Systematic replacement with "validate"
4. **Verification Phase**: Confirm all replacements are contextually correct

### File Scope
Target file types and locations:
- **Documentation Files**: README.md, CHANGELOG.md, MIGRATION_v3.md
- **Documentation Directory**: All files in docs/ and subdirectories
- **Example Files**: Files in example/ directory
- **Configuration Files**: CI/CD configs, GitHub workflows
- **Markdown Files**: All .md files throughout the project

## Components and Interfaces

### Search Patterns
Primary search patterns to identify:
- `ci-validate` - Direct command references
- `flutter_keycheck ci-validate` - Full command invocations
- `dart run flutter_keycheck:flutter_keycheck ci-validate` - Dart execution examples
- Code blocks containing ci-validate commands
- Inline code references to ci-validate

### Replacement Patterns
Corresponding replacements:
- `ci-validate` → `validate`
- `flutter_keycheck ci-validate` → `flutter_keycheck validate`
- `dart run flutter_keycheck:flutter_keycheck ci-validate` → `dart run flutter_keycheck:flutter_keycheck validate`

### Context Preservation
Maintain formatting and structure:
- Preserve markdown code block formatting
- Maintain CLI argument structure
- Keep surrounding text context intact
- Preserve indentation and spacing

## Data Models

### Search Result Structure
For each found instance:
- **File Path**: Location of the file containing the reference
- **Line Number**: Specific line where reference occurs
- **Context**: Surrounding text for verification
- **Match Type**: Type of reference (direct command, full invocation, etc.)

### Replacement Record
For tracking changes:
- **File Path**: File that was modified
- **Original Text**: Text before replacement
- **New Text**: Text after replacement
- **Line Number**: Location of change
- **Verification Status**: Whether replacement was contextually appropriate

## Error Handling

### False Positive Prevention
- Review each match for context appropriateness
- Avoid replacing instances that might be historical references or comparisons
- Preserve any intentional documentation about command name changes

### File Safety
- Create backups before making changes
- Verify file integrity after replacements
- Ensure no unintended formatting changes occur

### Verification Checks
- Confirm zero remaining "ci-validate" references after completion
- Validate that replaced commands are syntactically correct
- Check that documentation flow remains logical

## Testing Strategy

### Pre-Replacement Testing
- Comprehensive search to catalog all instances
- Context analysis for each found reference
- Identification of any edge cases or special contexts

### Post-Replacement Testing
- Verification search to confirm no remaining "ci-validate" references
- Spot-check replaced content for contextual accuracy
- Review of modified files for formatting integrity

### Documentation Validation
- Test example commands to ensure they work correctly
- Verify CLI help output matches documented commands
- Check that all command references are consistent throughout project

## Implementation Approach

### Phase 1: Discovery and Analysis
1. Perform comprehensive search across all target file types
2. Catalog all instances with context information
3. Analyze each instance for replacement appropriateness
4. Identify any special cases or edge conditions

### Phase 2: Systematic Replacement
1. Process files in logical order (README first, then docs/, then examples)
2. Make replacements while preserving formatting and context
3. Track all changes for verification
4. Handle any special cases identified in Phase 1

### Phase 3: Verification and Quality Assurance
1. Perform verification search to confirm complete replacement
2. Review modified files for contextual accuracy
3. Test example commands to ensure functionality
4. Validate overall documentation consistency

### Phase 4: Documentation and Tracking
1. Document all changes made
2. Create summary of files modified
3. Prepare commit message with clear description
4. Ensure changes are ready for review and integration
