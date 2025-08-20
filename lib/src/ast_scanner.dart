/// AST-based scanner for enhanced Flutter key detection
/// 
/// This module provides advanced scanning capabilities using the Dart analyzer
/// for more accurate and comprehensive key detection.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

/// Result of an AST scan operation
class AstScanResult {
  final Set<String> foundKeys;
  final Map<String, List<KeyLocation>> keyLocations;
  final List<String> scannedFiles;
  final Duration scanDuration;
  final Map<String, int> keyUsageCounts;

  AstScanResult({
    required this.foundKeys,
    required this.keyLocations,
    required this.scannedFiles,
    required this.scanDuration,
    required this.keyUsageCounts,
  });
}

/// Location of a key in source code
class KeyLocation {
  final String filePath;
  final int line;
  final int column;
  final String context;

  KeyLocation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.context,
  });
}

/// AST visitor for detecting Flutter keys
class KeyDetectorVisitor extends RecursiveAstVisitor<void> {
  final Set<String> foundKeys = {};
  final Map<String, List<KeyLocation>> keyLocations = {};
  final Map<String, int> keyUsageCounts = {};
  final String filePath;

  KeyDetectorVisitor(this.filePath);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Detect Key() constructors
    if (node.methodName.name == 'Key' || 
        node.methodName.name == 'ValueKey' ||
        node.methodName.name == 'ObjectKey' ||
        node.methodName.name == 'GlobalKey' ||
        node.methodName.name == 'UniqueKey') {
      _extractKeyFromNode(node);
    }

    // Detect find.byKey() patterns
    if (node.methodName.name == 'byKey' || node.methodName.name == 'byValueKey') {
      final target = node.target;
      if (target is Identifier && target.name == 'find') {
        _extractKeyFromNode(node);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name;
    
    // Check for Key constructors
    if (typeName is NamedType) {
      final name = typeName.name2.lexeme;
      if (name == 'Key' || 
          name == 'ValueKey' || 
          name == 'ObjectKey' ||
          name == 'GlobalKey' ||
          name == 'UniqueKey') {
        _extractKeyFromNode(node);
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  void _extractKeyFromNode(AstNode node) {
    String? keyValue;
    
    // Extract the key value from the arguments
    if (node is MethodInvocation) {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        keyValue = _extractStringValue(args.first);
      }
    } else if (node is InstanceCreationExpression) {
      final args = node.argumentList?.arguments;
      if (args != null && args.isNotEmpty) {
        keyValue = _extractStringValue(args.first);
      }
    }

    if (keyValue != null) {
      foundKeys.add(keyValue);
      
      // Track location
      final lineInfo = node.root.lineInfo;
      final location = lineInfo.getLocation(node.offset);
      
      keyLocations.putIfAbsent(keyValue, () => []).add(
        KeyLocation(
          filePath: filePath,
          line: location.lineNumber,
          column: location.columnNumber,
          context: node.toSource(),
        ),
      );

      // Track usage count
      keyUsageCounts[keyValue] = (keyUsageCounts[keyValue] ?? 0) + 1;
    }
  }

  String? _extractStringValue(Expression expr) {
    if (expr is StringLiteral) {
      return expr.stringValue;
    } else if (expr is SimpleIdentifier) {
      // For constants, return the identifier name
      // The actual resolution would need more context
      return expr.name;
    } else if (expr is PrefixedIdentifier) {
      // For KeyConstants.someKey patterns
      return '${expr.prefix.name}.${expr.identifier.name}';
    }
    return null;
  }
}

/// Enhanced AST scanner for Flutter projects
class AstScanner {
  final String projectPath;
  final bool includeTests;
  final bool includeExamples;
  final List<String>? includeOnly;
  final List<String>? exclude;
  final bool verbose;

  AstScanner({
    required this.projectPath,
    this.includeTests = false,
    this.includeExamples = true,
    this.includeOnly,
    this.exclude,
    this.verbose = false,
  });

  /// Perform AST-based scanning
  Future<AstScanResult> scan() async {
    final startTime = DateTime.now();
    final foundKeys = <String>{};
    final keyLocations = <String, List<KeyLocation>>{};
    final keyUsageCounts = <String, int>{};
    final scannedFiles = <String>[];

    // Get files to scan
    final files = await _getFilesToScan();
    
    if (verbose) {
      print('🔍 Scanning ${files.length} files with AST analyzer...');
    }

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      excludedPaths: _getExcludedPaths(),
    );

    // Scan each file
    for (final filePath in files) {
      try {
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedUnit(filePath);
        
        if (result is ResolvedUnitResult) {
          final visitor = KeyDetectorVisitor(filePath);
          result.unit.accept(visitor);
          
          // Merge results
          foundKeys.addAll(visitor.foundKeys);
          visitor.keyLocations.forEach((key, locations) {
            keyLocations.putIfAbsent(key, () => []).addAll(locations);
          });
          visitor.keyUsageCounts.forEach((key, count) {
            keyUsageCounts[key] = (keyUsageCounts[key] ?? 0) + count;
          });
          
          scannedFiles.add(filePath);
          
          if (verbose && visitor.foundKeys.isNotEmpty) {
            print('  📄 ${path.relative(filePath, from: projectPath)}: ${visitor.foundKeys.length} keys');
          }
        }
      } catch (e) {
        if (verbose) {
          print('  ⚠️ Error scanning ${path.relative(filePath, from: projectPath)}: $e');
        }
      }
    }

    final duration = DateTime.now().difference(startTime);
    
    if (verbose) {
      print('✅ AST scan complete in ${duration.inMilliseconds}ms');
      print('   Found ${foundKeys.length} unique keys across ${scannedFiles.length} files');
    }

    return AstScanResult(
      foundKeys: foundKeys,
      keyLocations: keyLocations,
      scannedFiles: scannedFiles,
      scanDuration: duration,
      keyUsageCounts: keyUsageCounts,
    );
  }

  /// Get list of files to scan
  Future<List<String>> _getFilesToScan() async {
    final files = <String>[];
    final dirsToScan = <Directory>[];

    // Always scan lib/
    final libDir = Directory(path.join(projectPath, 'lib'));
    if (libDir.existsSync()) {
      dirsToScan.add(libDir);
    }

    // Optionally scan test/
    if (includeTests) {
      final testDir = Directory(path.join(projectPath, 'test'));
      if (testDir.existsSync()) {
        dirsToScan.add(testDir);
      }
      
      final integrationTestDir = Directory(path.join(projectPath, 'integration_test'));
      if (integrationTestDir.existsSync()) {
        dirsToScan.add(integrationTestDir);
      }
    }

    // Optionally scan example/
    if (includeExamples) {
      final exampleDir = Directory(path.join(projectPath, 'example'));
      if (exampleDir.existsSync()) {
        final exampleLibDir = Directory(path.join(exampleDir.path, 'lib'));
        if (exampleLibDir.existsSync()) {
          dirsToScan.add(exampleLibDir);
        }
      }
    }

    // Collect all Dart files
    for (final dir in dirsToScan) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          if (_shouldIncludeFile(entity.path)) {
            files.add(entity.path);
          }
        }
      }
    }

    return files;
  }

  /// Check if file should be included based on filters
  bool _shouldIncludeFile(String filePath) {
    final relativePath = path.relative(filePath, from: projectPath);
    
    // Check exclude patterns
    if (exclude != null) {
      for (final pattern in exclude!) {
        if (RegExp(pattern).hasMatch(relativePath)) {
          return false;
        }
      }
    }

    // Check include-only patterns
    if (includeOnly != null && includeOnly!.isNotEmpty) {
      for (final pattern in includeOnly!) {
        if (RegExp(pattern).hasMatch(relativePath)) {
          return true;
        }
      }
      return false; // If include-only is specified, exclude by default
    }

    return true;
  }

  /// Get paths to exclude from analysis
  List<String> _getExcludedPaths() {
    return [
      path.join(projectPath, '.dart_tool'),
      path.join(projectPath, 'build'),
      path.join(projectPath, '.git'),
    ];
  }
}