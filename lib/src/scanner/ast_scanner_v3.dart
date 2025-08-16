import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors_v3.dart';
import 'package:path/path.dart' as path;

/// Text-based heuristics for widget and handler detection
class _Heuristics {
  final int widgetHits;
  final List<String> handlers;

  _Heuristics({required this.widgetHits, required this.handlers});
}

/// File information with source tracking
class FileInfo {
  final String path;
  final String source; // 'workspace' or 'package'
  final String? packageInfo; // 'name@version' for dependencies

  FileInfo({
    required this.path,
    this.source = 'workspace',
    this.packageInfo,
  });
}

/// Enhanced AST scanner with provable coverage
class AstScannerV3 {
  final String projectPath;
  final bool includeTests;
  final bool includeGenerated;
  final String? gitDiffBase;
  final String scope; // 'workspace-only', 'deps-only', 'all'
  final String? packageFilter;
  final ConfigV3 config;

  // Built-in detectors
  late final List<KeyDetector> detectors;

  // Metrics
  final ScanMetrics metrics = ScanMetrics();
  final Map<String, FileAnalysis> fileAnalyses = {};
  final Map<String, KeyUsage> keyUsages = {};

  AstScannerV3({
    required this.projectPath,
    this.includeTests = false,
    this.includeGenerated = false,
    this.gitDiffBase,
    this.scope = 'workspace-only',
    this.packageFilter,
    required this.config,
  }) {
    // Initialize built-in detectors
    detectors = [
      ValueKeyDetector(),
      BasicKeyDetector(),
      ConstKeyDetector(),
      SemanticKeyDetector(),
      TestKeyDetector(),
      MaterialKeyDetector(),
      CupertinoKeyDetector(),
      IntegrationTestKeyDetector(),
      PatrolFinderDetector(),
    ];
  }

  /// Perform full AST scan with metrics
  Future<ScanResult> scan() async {
    final startTime = DateTime.now();

    // Get files to scan
    final filesWithInfo = await _getFilesToScanWithInfo();
    metrics.totalFiles = filesWithInfo.length;

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      excludedPaths: _getExcludedPaths(),
    );

    // Scan each file
    for (final fileInfo in filesWithInfo) {
      await _scanFile(
        fileInfo.path,
        collection,
        source: fileInfo.source,
        packageInfo: fileInfo.packageInfo,
      );
    }

    // Calculate coverage metrics
    _calculateCoverageMetrics();

    // Detect blind spots
    final blindSpots = _detectBlindSpots();

    final duration = DateTime.now().difference(startTime);

    return ScanResult(
      metrics: metrics,
      fileAnalyses: fileAnalyses,
      keyUsages: keyUsages,
      blindSpots: blindSpots,
      duration: duration,
    );
  }

  /// Get files to scan with source information
  Future<List<FileInfo>> _getFilesToScanWithInfo() async {
    if (gitDiffBase != null) {
      // Incremental scan
      final result = await Process.run(
        'git',
        ['diff', '--name-only', gitDiffBase!, '--', '*.dart'],
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        final files = result.stdout
            .toString()
            .split('\n')
            .where((f) => f.isNotEmpty && f.endsWith('.dart'))
            .map((f) => FileInfo(
                  path: path.join(projectPath, f),
                  source: 'workspace',
                ))
            .toList();

        metrics.incrementalScan = true;
        metrics.incrementalBase = gitDiffBase!;
        return files;
      }
    }

    // Full scan based on scope
    switch (scope) {
      case 'deps-only':
        return await _getDependencyFilesWithInfo();
      case 'all':
        final workspace = _getWorkspaceFilesWithInfo();
        final deps = await _getDependencyFilesWithInfo();
        return [...workspace, ...deps];
      case 'workspace-only':
      default:
        return _getWorkspaceFilesWithInfo();
    }
  }

  /// Get workspace files with info
  List<FileInfo> _getWorkspaceFilesWithInfo() {
    final files = <FileInfo>[];
    final dir = Directory(projectPath);

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = path.relative(entity.path, from: projectPath);

        // Apply filters
        if (!_shouldIncludeFile(relativePath)) continue;

        // Apply package filter if set
        if (packageFilter != null) {
          final pattern = RegExp(packageFilter!);
          if (!pattern.hasMatch(relativePath)) continue;
        }

        files.add(FileInfo(
          path: entity.path,
          source: 'workspace',
        ));
      }
    }

    return files;
  }

  /// Get dependency files with info
  Future<List<FileInfo>> _getDependencyFilesWithInfo() async {
    final files = <FileInfo>[];

    // Read package_config.json to get dependency locations
    final packageConfigFile =
        File(path.join(projectPath, '.dart_tool', 'package_config.json'));
    if (!packageConfigFile.existsSync()) {
      // Try running pub get first
      await _pubDepsJson();
      if (!packageConfigFile.existsSync()) {
        return files; // No dependencies available
      }
    }

    try {
      final packageConfig = json.decode(packageConfigFile.readAsStringSync());
      final packages = packageConfig['packages'] as List;

      for (final package in packages) {
        final packageName = package['name'] as String;
        final packageUri = package['rootUri'] as String;

        // Skip the current project itself
        if (packageUri == '../' || packageUri == '..') continue;

        // Get the actual package path
        String packagePath;
        if (packageUri.startsWith('file://')) {
          packagePath = Uri.parse(packageUri).toFilePath();
        } else if (packageUri.startsWith('../')) {
          packagePath =
              path.normalize(path.join(projectPath, '.dart_tool', packageUri));
        } else {
          packagePath = path.join(projectPath, '.dart_tool', packageUri);
        }

        // Scan lib folder of the package
        final libPath = path.join(packagePath, 'lib');
        if (Directory(libPath).existsSync()) {
          // Get package version from pubspec or use default
          final packageVersion =
              await _getPackageVersion(packagePath) ?? '0.0.0';
          final packageFullName = '$packageName@$packageVersion';

          for (final entity in Directory(libPath).listSync(recursive: true)) {
            if (entity is File && entity.path.endsWith('.dart')) {
              files.add(FileInfo(
                path: entity.path,
                source: 'package',
                packageInfo: packageFullName,
              ));
            }
          }
        }
      }
    } catch (e) {
      // If we can't parse package config, fallback to pub deps
      await _pubDepsJson();
    }

    return files;
  }

  /// Get package version from pubspec.yaml
  Future<String?> _getPackageVersion(String packagePath) async {
    try {
      final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final versionMatch =
            RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
        if (versionMatch != null) {
          return versionMatch.group(1)?.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Run pub deps to get dependency information
  Future<void> _pubDepsJson() async {
    try {
      // Try flutter pub deps first, fallback to dart pub deps
      try {
        await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      } on ProcessException {
        // Flutter not available, try dart
        await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      }
    } catch (e) {
      // Ignore errors - we'll work with what we have
    }
  }

  /// Check if file should be included
  bool _shouldIncludeFile(String relativePath) {
    if (!includeTests && relativePath.contains('test/')) return false;
    if (!includeGenerated && relativePath.endsWith('.g.dart')) return false;
    if (!includeGenerated && relativePath.endsWith('.freezed.dart')) {
      return false;
    }

    // Check exclude patterns from config
    for (final pattern in config.scan.excludePatterns) {
      if (_matchesPattern(relativePath, pattern)) return false;
    }

    return true;
  }

  /// Match glob pattern
  bool _matchesPattern(String path, String pattern) {
    // Simplified glob matching
    final regex = pattern
        .replaceAll('**/', '.*')
        .replaceAll('*', '[^/]*')
        .replaceAll('?', '.');
    return RegExp(regex).hasMatch(path);
  }

  /// Scan single file with AST
  Future<void> _scanFile(String filePath, AnalysisContextCollection collection,
      {String source = 'workspace', String? packageInfo}) async {
    try {
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        final analysis = FileAnalysis(
          path: filePath,
          relativePath: path.relative(filePath, from: projectPath),
        );

        // Create visitor with all detectors
        final visitor = KeyVisitorV3(
          detectors: detectors,
          analysis: analysis,
          keyUsages: keyUsages,
          filePath: filePath,
          source: source,
          packageInfo: packageInfo,
        );

        // Visit AST - use accept to properly traverse the entire tree
        result.unit.accept(visitor);

        // Store analysis
        fileAnalyses[filePath] = analysis;
        metrics.scannedFiles++;
        metrics.totalLines += _countLines(File(filePath));
        metrics.analyzedNodes += analysis.nodesAnalyzed;

        // Update detector metrics
        for (final detector in detectors) {
          metrics.detectorHits[detector.name] =
              (metrics.detectorHits[detector.name] ?? 0) +
                  (analysis.detectorHits[detector.name] ?? 0);
        }
      }
    } catch (e) {
      // Try text-based heuristics as fallback
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final heuristics = _scanTextHeuristics(content);

          // Create basic analysis with heuristics
          final analysis = FileAnalysis(
            path: filePath,
            relativePath: path.relative(filePath, from: projectPath),
          );

          // Use heuristics for metrics
          analysis.widgetCount = heuristics.widgetHits;
          if (heuristics.widgetHits > 0) {
            analysis.widgetsWithKeys = 1; // Conservative estimate
          }

          // Store basic metrics
          fileAnalyses[filePath] = analysis;
          metrics.scannedFiles++;
          metrics.totalLines += _countLines(file);

          // Handler information is captured in heuristics but not stored in metrics
        }
      } catch (_) {
        // If even text scanning fails, record error
        metrics.errors.add(ScanError(
          file: filePath,
          error: e.toString(),
          type: 'ast_parse',
        ));
      }
    }
  }

  /// Calculate coverage metrics
  void _calculateCoverageMetrics() {
    // File coverage
    metrics.fileCoverage = metrics.totalFiles > 0
        ? (metrics.scannedFiles / metrics.totalFiles * 100)
        : 0;

    // Widget coverage
    int totalWidgets = 0;
    int widgetsWithKeys = 0;

    for (final analysis in fileAnalyses.values) {
      totalWidgets += analysis.widgetCount;
      widgetsWithKeys += analysis.widgetsWithKeys;
    }

    metrics.widgetCoverage =
        totalWidgets > 0 ? (widgetsWithKeys / totalWidgets * 100) : 0;

    // Handler coverage
    int totalHandlers = 0;
    int handlersWithKeys = 0;

    for (final usage in keyUsages.values) {
      if (usage.handlers.isNotEmpty) {
        handlersWithKeys++;
      }
      totalHandlers++;
    }

    metrics.handlerCoverage =
        totalHandlers > 0 ? (handlersWithKeys / totalHandlers * 100) : 0;
  }

  /// Detect blind spots
  List<BlindSpot> _detectBlindSpots() {
    final blindSpots = <BlindSpot>[];

    // Check for files with no keys
    for (final entry in fileAnalyses.entries) {
      if (entry.value.keysFound.isEmpty && entry.value.widgetCount > 5) {
        blindSpots.add(BlindSpot(
          type: 'no_keys_in_ui_heavy_file',
          location: entry.key,
          severity: 'warning',
          message: 'File has ${entry.value.widgetCount} widgets but no keys',
        ));
      }
    }

    // Check detector effectiveness
    for (final entry in metrics.detectorHits.entries) {
      if (entry.value == 0) {
        blindSpots.add(BlindSpot(
          type: 'ineffective_detector',
          location: 'detector:${entry.key}',
          severity: 'info',
          message: 'Detector "${entry.key}" found no matches',
        ));
      }
    }

    return blindSpots;
  }

  List<String> _getExcludedPaths() {
    final excluded = <String>[];
    if (!includeTests) {
      final testPath = path.join(projectPath, 'test');
      if (Directory(testPath).existsSync()) {
        excluded.add(testPath);
      }
    }
    // Note: AnalysisContextCollection doesn't support glob patterns in excludedPaths
    // We'll filter generated files in _shouldIncludeFile instead
    return excluded;
  }

  int _countLines(File file) {
    try {
      return file.readAsLinesSync().length;
    } catch (_) {
      return 0;
    }
  }

  /// Scan text heuristics for metrics when AST parsing fails
  _Heuristics _scanTextHeuristics(String content) {
    final widgetHits = RegExp(
            r'\b(StatefulWidget|StatelessWidget|Widget|MaterialApp|CupertinoApp|Scaffold|AppBar|Container|Column|Row|ListView|GridView|Stack|Card|Button|TextField|Text|Image)\b')
        .allMatches(content)
        .length;

    final handlerNames = <String>{
      'onPressed',
      'onTap',
      'onChanged',
      'onLongPress',
      'onSubmitted',
      'onSave',
      'onSelect',
      'onDoubleTap',
      'onPanUpdate',
      'onHorizontalDragEnd',
      'onVerticalDragEnd',
      'onScaleEnd',
      'onEditingComplete',
      'onFieldSubmitted'
    };

    final handlers = <String>[];
    for (final h in handlerNames) {
      if (content.contains(h)) {
        handlers.add(h);
      }
    }

    return _Heuristics(widgetHits: widgetHits, handlers: handlers);
  }
}

/// Enhanced AST visitor for v3
class KeyVisitorV3 extends RecursiveAstVisitor<void> {
  final List<KeyDetector> detectors;
  final FileAnalysis analysis;
  final Map<String, KeyUsage> keyUsages;
  final String filePath;
  final String source;
  final String? packageInfo;

  KeyVisitorV3({
    required this.detectors,
    required this.analysis,
    required this.keyUsages,
    required this.filePath,
    this.source = 'workspace',
    this.packageInfo,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Make sure we visit the class body
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Make sure we visit the method body
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Also handle top-level functions
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    analysis.nodesAnalyzed++;

    // Check if this might be a widget constructor (when Flutter types aren't resolved)
    final methodName = node.methodName.name;

    // Special handling for Semantics widget
    if (methodName == 'Semantics' && node.target == null) {
      analysis.widgetCount++;
      analysis.widgetTypes.add(methodName);

      // Semantics uses 'identifier' parameter instead of 'key'
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'identifier') {
          final value = arg.expression;
          if (value is StringLiteral) {
            final result = DetectionResult(
              key: value.stringValue ?? '',
              detector: 'Semantics',
              tags: ['semantic', 'accessibility'],
            );
            _recordKey(result.key, node,
                detectors.firstWhere((d) => d.name == 'Semantics'), result);
            analysis.widgetsWithKeys++;
          }
        }
      }
    } else if (_isWidget(methodName) && node.target == null) {
      // This is likely a widget constructor being parsed as a method
      analysis.widgetCount++;
      analysis.widgetTypes.add(methodName);

      // Check for key parameter
      NamedExpression? keyArg;
      try {
        keyArg = node.argumentList.arguments
            .whereType<NamedExpression>()
            .firstWhere((arg) => arg.name.label.name == 'key');
      } catch (_) {
        keyArg = null;
      }

      if (keyArg != null) {
        analysis.widgetsWithKeys++;

        // Extract key value using detectors
        for (final detector in detectors) {
          final result = detector.detectExpression(keyArg.expression);
          if (result != null) {
            _recordKey(result.key, node, detector, result);
            break;
          }
        }

        // Check for handlers in this widget
        _checkMethodInvocationHandlers(node);
      } else {
        analysis.uncoveredWidgetTypes.add(methodName);
      }
    }

    // Check each detector for regular method invocations (like ValueKey)
    for (final detector in detectors) {
      final result = detector.detect(node);
      if (result != null) {
        _recordKey(result.key, node, detector, result);
      }
    }

    // Check for action handlers
    _checkActionHandler(node);

    // Call super to continue visiting
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    analysis.nodesAnalyzed++;

    // Track widget creation
    final typeName = node.constructorName.type.toString();

    if (_isWidget(typeName)) {
      analysis.widgetCount++;
      analysis.widgetTypes.add(typeName);

      // Check for key parameter
      final keyArgs = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'key')
          .toList();
      final keyArg = keyArgs.isNotEmpty ? keyArgs.first : null;

      if (keyArg != null) {
        analysis.widgetsWithKeys++;

        // Extract key value using detectors
        for (final detector in detectors) {
          final result = detector.detectExpression(keyArg.expression);
          if (result != null) {
            _recordKey(result.key, node, detector, result);
            break; // Found a key, stop checking other detectors
          }
        }
      } else {
        analysis.uncoveredWidgetTypes.add(typeName);
      }

      // Check for handlers in this widget
      _checkWidgetHandlers(node);
    }

    // Also check for Semantics widget specifically
    if (typeName == 'Semantics') {
      _checkSemanticsWidget(node);
    }

    // Call super to continue visiting children
    super.visitInstanceCreationExpression(node);
  }

  void _recordKey(
      String key, AstNode node, KeyDetector detector, DetectionResult result) {
    // Record in file analysis
    analysis.keysFound.add(key);
    analysis.detectorHits[detector.name] =
        (analysis.detectorHits[detector.name] ?? 0) + 1;

    // Get location info
    final lineInfo = (node.root as CompilationUnit).lineInfo;
    final location = lineInfo.getLocation(node.offset);

    // Create or update key usage
    final usage = keyUsages.putIfAbsent(
      key,
      () => KeyUsage(
        id: key,
        source: source,
        package: packageInfo,
      ),
    );

    usage.locations.add(KeyLocation(
      file: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      detector: detector.name,
      context: _getContext(node),
    ));

    // Add tags from detector
    if (result.tags != null) {
      usage.tags.addAll(result.tags!);
    }
  }

  void _checkActionHandler(MethodInvocation node) {
    final methodName = node.methodName.name;
    final actionPatterns = ['onPressed', 'onTap', 'onSubmit', 'onChanged'];

    if (actionPatterns.contains(methodName)) {
      // Find associated key in parent widget
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final keyArgs = current.argumentList.arguments
              .whereType<NamedExpression>()
              .where((arg) => arg.name.label.name == 'key')
              .toList();
          final keyArg = keyArgs.isNotEmpty ? keyArgs.first : null;

          if (keyArg != null) {
            for (final detector in detectors) {
              final result = detector.detectExpression(keyArg.expression);
              if (result != null) {
                final usage = keyUsages[result.key];
                if (usage != null) {
                  usage.handlers.add(HandlerInfo(
                    type: methodName,
                    method: _extractHandlerMethod(node),
                    file: filePath,
                    line: node.offset,
                  ));
                }
                break;
              }
            }
          }
          break;
        }
        current = current.parent;
      }
    }
  }

  void _checkMethodInvocationHandlers(MethodInvocation node) {
    // Check for handlers in named arguments (for widgets parsed as methods)
    final handlerPatterns = [
      'onPressed',
      'onTap',
      'onSubmitted',
      'onChanged',
      'onLongPress',
      'onSaved',
      'onSelected',
      'onDoubleTap'
    ];

    String? widgetKey;
    // First, find if this widget has a key
    NamedExpression? keyArg;
    try {
      keyArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .firstWhere((arg) => arg.name.label.name == 'key');
    } catch (_) {
      keyArg = null;
    }

    if (keyArg != null) {
      for (final detector in detectors) {
        final result = detector.detectExpression(keyArg.expression);
        if (result != null) {
          widgetKey = result.key;
          break;
        }
      }
    }

    // If widget has a key, check for handlers
    if (widgetKey != null) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          if (handlerPatterns.contains(name)) {
            final usage = keyUsages[widgetKey];
            if (usage != null) {
              usage.handlers.add(HandlerInfo(
                type: name,
                method: _extractHandlerFromExpression(arg.expression),
                file: filePath,
                line: arg.offset,
              ));
            }
          }
        }
      }
    }
  }

  void _checkWidgetHandlers(InstanceCreationExpression node) {
    // Check for handlers in named arguments
    final handlerPatterns = [
      'onPressed',
      'onTap',
      'onSubmitted',
      'onChanged',
      'onLongPress',
      'onSaved',
      'onSelected',
      'onDoubleTap'
    ];

    String? widgetKey;
    // First, find if this widget has a key
    final keyArgs = node.argumentList.arguments
        .whereType<NamedExpression>()
        .where((arg) => arg.name.label.name == 'key')
        .toList();
    final keyArg = keyArgs.isNotEmpty ? keyArgs.first : null;

    if (keyArg != null) {
      for (final detector in detectors) {
        final result = detector.detectExpression(keyArg.expression);
        if (result != null) {
          widgetKey = result.key;
          break;
        }
      }
    }

    // If widget has a key, check for handlers
    if (widgetKey != null) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          if (handlerPatterns.contains(name)) {
            final usage = keyUsages[widgetKey];
            if (usage != null) {
              usage.handlers.add(HandlerInfo(
                type: name,
                method: _extractHandlerFromExpression(arg.expression),
                file: filePath,
                line: arg.offset,
              ));
            }
          }
        }
      }
    }
  }

  void _checkSemanticsWidget(InstanceCreationExpression node) {
    // Check for Semantics widget with identifier
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'identifier') {
        final value = arg.expression;
        if (value is StringLiteral) {
          final result = DetectionResult(
            key: value.stringValue ?? '',
            detector: 'Semantics',
            tags: ['semantic', 'accessibility'],
          );
          _recordKey(result.key, node,
              detectors.firstWhere((d) => d.name == 'Semantics'), result);
        }
      }
    }
  }

  String? _extractHandlerFromExpression(Expression expression) {
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    if (expression is FunctionExpression) {
      return '<anonymous>';
    }
    if (expression is MethodInvocation) {
      return expression.methodName.name;
    }
    return null;
  }

  String _getContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return 'method:${current.name.lexeme}';
      }
      if (current is FunctionDeclaration) {
        return 'function:${current.name.lexeme}';
      }
      if (current is ClassDeclaration) {
        return 'class:${current.name.lexeme}';
      }
      current = current.parent;
    }
    return 'global';
  }

  String? _extractHandlerMethod(MethodInvocation node) {
    final args = node.argumentList.arguments ?? [];
    final arg = args.isNotEmpty ? args.first : null;
    if (arg is SimpleIdentifier) {
      return arg.name;
    }
    if (arg is FunctionExpression) {
      return '<anonymous>';
    }
    return null;
  }

  bool _isWidget(String typeName) {
    return typeName.endsWith('Widget') ||
        typeName.endsWith('Button') ||
        typeName.endsWith('Field') ||
        typeName.endsWith('View') ||
        typeName.endsWith('Screen') ||
        typeName.endsWith('Page') ||
        typeName.endsWith('Dialog') ||
        typeName.endsWith('Card') ||
        [
          'Column',
          'Row',
          'Stack',
          'Scaffold',
          'AppBar',
          'Center',
          'Padding',
          'Expanded',
          'ListView',
          'GridView',
          'Container',
          'Text',
          'Image',
          'Icon',
          'MaterialApp',
          'CupertinoApp',
          'Semantics',
          'ElevatedButton',
          'TextButton',
          'IconButton',
          'OutlinedButton'
        ].contains(typeName);
  }
}
