import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors_v3.dart';
import 'package:flutter_keycheck/src/cache/dependency_cache.dart';
import 'package:path/path.dart' as path;

/// Package scanning scope
enum ScanScope {
  workspaceOnly('workspace-only'),
  depsOnly('deps-only'),
  all('all');

  final String value;
  const ScanScope(this.value);

  static ScanScope fromString(String value) {
    return ScanScope.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ScanScope.workspaceOnly,
    );
  }
}

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
  final bool includeExamples;
  final String? gitDiffBase;
  final ScanScope scope;
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
    this.includeExamples = true,
    this.gitDiffBase,
    this.scope = ScanScope.workspaceOnly,
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
      StringLiteralKeyDetector(),
    ];
  }

  /// Perform full AST scan with metrics
  Future<ScanResult> scan() async {
    final startTime = DateTime.now();

    // Ensure cache directory exists
    final cacheDir =
        Directory(path.join(projectPath, DependencyCache.cacheDir));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

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
      case ScanScope.depsOnly:
        return await _getDependencyFilesWithInfo();
      case ScanScope.all:
        final workspace = _getWorkspaceFilesWithInfo();
        final deps = await _getDependencyFilesWithInfo();
        return [...workspace, ...deps];
      case ScanScope.workspaceOnly:
        return _getWorkspaceFilesWithInfo();
    }
  }

  /// Get workspace files with info
  List<FileInfo> _getWorkspaceFilesWithInfo() {
    final files = <FileInfo>[];

    // Check if this is a package root (has pubspec.yaml)
    final pubspec = File(path.join(projectPath, 'pubspec.yaml'));

    // Determine which directories to scan
    final dirsToScan = <Directory>[];

    if (!pubspec.existsSync()) {
      // Not a package root - check if has local lib/
      final localLib = Directory(path.join(projectPath, 'lib'));
      if (localLib.existsSync()) {
        dirsToScan.add(localLib);
      }
    } else {
      // Standard package - scan lib/ and bin/
      final libDir = Directory(path.join(projectPath, 'lib'));
      if (libDir.existsSync()) {
        dirsToScan.add(libDir);
      }

      final binDir = Directory(path.join(projectPath, 'bin'));
      if (binDir.existsSync()) {
        dirsToScan.add(binDir);
      }

      // If includeTests is true, also scan test/
      if (includeTests) {
        final testDir = Directory(path.join(projectPath, 'test'));
        if (testDir.existsSync()) {
          dirsToScan.add(testDir);
        }
      }

      // Include example/ and examples/ directories if enabled
      if (includeExamples) {
        final exampleDir = Directory(path.join(projectPath, 'example'));
        if (exampleDir.existsSync()) {
          // Scan Flutter apps in example/
          for (final entity in exampleDir.listSync()) {
            if (entity is Directory) {
              final exampleLibDir = Directory(path.join(entity.path, 'lib'));
              if (exampleLibDir.existsSync()) {
                dirsToScan.add(exampleLibDir);
              }
              final exampleBinDir = Directory(path.join(entity.path, 'bin'));
              if (exampleBinDir.existsSync()) {
                dirsToScan.add(exampleBinDir);
              }
            }
          }
        }

        // Also check examples/ (plural)
        final examplesDir = Directory(path.join(projectPath, 'examples'));
        if (examplesDir.existsSync()) {
          for (final entity in examplesDir.listSync()) {
            if (entity is Directory) {
              final exampleLibDir = Directory(path.join(entity.path, 'lib'));
              if (exampleLibDir.existsSync()) {
                dirsToScan.add(exampleLibDir);
              }
              final exampleBinDir = Directory(path.join(entity.path, 'bin'));
              if (exampleBinDir.existsSync()) {
                dirsToScan.add(exampleBinDir);
              }
            }
          }
        }
      }
    }

    // Scan the determined directories
    for (final dir in dirsToScan) {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final relativePath = path.relative(entity.path, from: projectPath);

          // Skip excluded directories
          if (_isExcludedPath(entity.path)) continue;

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
    }

    return files;
  }

  /// Check if path should be excluded
  bool _isExcludedPath(String filePath) {
    // Exclude common directories that should never be scanned
    final excludePatterns = RegExp(r'/(\.dart_tool|build|\.git)/');
    return excludePatterns.hasMatch(filePath);
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

  /// Run pub deps to get dependency information (with caching)
  Future<void> _pubDepsJson() async {
    // Check if deps cache exists and is fresh (24h TTL)
    final cacheKey =
        'deps_json_${DateTime.now().toIso8601String().substring(0, 10)}';
    final cachedResult = await DependencyCache.loadCache(projectPath, cacheKey);

    if (cachedResult != null) {
      // Cache hit - deps already fetched within 24h
      return;
    }

    try {
      // Try flutter pub deps first, fallback to dart pub deps
      ProcessResult result;
      try {
        result = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      } on ProcessException {
        // Flutter not available, try dart
        result = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
      }

      // Cache the result if successful
      if (result.exitCode == 0) {
        await DependencyCache.saveCache(projectPath, cacheKey, {
          'timestamp': DateTime.now().toIso8601String(),
          'command': 'pub_get',
          'exitCode': result.exitCode,
        });
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
    // Try to use cache for package dependencies
    if (source == 'package' && packageInfo != null) {
      final cached = await _tryLoadFromCache(filePath, packageInfo);
      if (cached) {
        return; // Successfully loaded from cache
      }
    }

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

        // Save to cache if it's a package dependency
        if (source == 'package' && packageInfo != null) {
          // Extract only the keys from this file
          final fileKeys = <String, KeyUsage>{};
          for (final entry in visitor.keyUsages.entries) {
            // Check if this key has locations in this file
            if (entry.value.locations.any((loc) => loc.file == filePath)) {
              fileKeys[entry.key] = entry.value;
            }
          }
          await _saveToCache(filePath, packageInfo, analysis, fileKeys);
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

          // ENHANCED: Add regex-based key detection as fallback
          _extractKeysFromText(content, analysis);

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

  /// Extract keys from text using regex patterns (fallback when AST parsing fails)
  void _extractKeysFromText(String content, FileAnalysis analysis) {
    // Regex patterns for various key formats
    final patterns = [
      RegExp(r"const\s+ValueKey\s*\(\s*'([^']+)'"), // const ValueKey('key')
      RegExp(
          r"key:\s*const\s+ValueKey\s*\(\s*'([^']+)'"), // key: const ValueKey('key')
      RegExp(
          r"=\s*const\s+ValueKey\s*\(\s*'([^']+)'"), // = const ValueKey('key')
      RegExp(r"ValueKey\s*\(\s*'([^']+)'"), // ValueKey('key')
      RegExp(r"Key\s*\(\s*'([^']+)'"), // Key('key')
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final keyValue = match.group(1);
        if (keyValue != null && keyValue.isNotEmpty) {
          analysis.keysFound.add(keyValue);
          analysis.detectorHits['StringLiteral'] =
              (analysis.detectorHits['StringLiteral'] ?? 0) + 1;

          // Create a key usage for tracking
          final usage = keyUsages.putIfAbsent(
            keyValue,
            () => KeyUsage(
              id: keyValue,
              source: 'workspace',
            ),
          );

          // Add location info (approximate)
          final lineNumber =
              content.substring(0, match.start).split('\n').length;

          // Extract code context around the found key
          final lines = content.split('\n');
          final currentLineIndex = lineNumber - 1;
          final startLine = (currentLineIndex - 2).clamp(0, lines.length - 1);
          final endLine = (currentLineIndex + 2).clamp(0, lines.length - 1);

          final contextLines = <String>[];
          for (int i = startLine; i <= endLine; i++) {
            if (i < lines.length) {
              contextLines.add(lines[i]);
            }
          }
          final codeContext = contextLines.join('\n');

          usage.locations.add(KeyLocation(
            file: analysis.path,
            line: lineNumber,
            column: match.start - content.lastIndexOf('\n', match.start),
            detector: 'StringLiteral',
            context: codeContext,
          ));
        }
      }
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

  /// Try to load scan results from cache
  Future<bool> _tryLoadFromCache(String filePath, String packageInfo) async {
    try {
      final parts = packageInfo.split('@');
      if (parts.length != 2) return false;

      final packageName = parts[0];
      final packageVersion = parts[1];

      final cacheKey = DependencyCache.getCacheKey(
        packageName: packageName,
        packageVersion: packageVersion,
        detectorHash: DependencyCache.getDetectorHash(),
        sdkVersion: DependencyCache.getSdkVersion(),
      );

      final cached = await DependencyCache.loadCache(projectPath, cacheKey);
      if (cached == null) return false;

      // Check if this file is in the cache
      final fileKey = path.relative(filePath, from: projectPath);
      final fileData = cached[fileKey] as Map<String, dynamic>?;
      if (fileData == null) return false;

      // Restore analysis
      final analysis = FileAnalysis(
        path: filePath,
        relativePath: path.relative(filePath, from: projectPath),
      );

      // Restore metrics from cache
      analysis.widgetCount = fileData['widgetCount'] ?? 0;
      analysis.widgetsWithKeys = fileData['widgetsWithKeys'] ?? 0;
      analysis.nodesAnalyzed = fileData['nodesAnalyzed'] ?? 0;

      // Restore keys found
      final keysFound = fileData['keysFound'] as List?;
      if (keysFound != null) {
        for (final key in keysFound) {
          analysis.keysFound.add(key as String);
        }
      }

      // Store analysis
      fileAnalyses[filePath] = analysis;
      metrics.scannedFiles++;
      metrics.totalLines += (fileData['totalLines'] ?? 0) as int;
      metrics.analyzedNodes += analysis.nodesAnalyzed;

      // Restore key usages
      final usages = fileData['keyUsages'] as Map<String, dynamic>?;
      if (usages != null) {
        for (final entry in usages.entries) {
          final usageData = entry.value as Map<String, dynamic>;
          final usage = keyUsages.putIfAbsent(
            entry.key,
            () => KeyUsage(
              id: entry.key,
              source: usageData['source'] ?? 'package',
              package: packageInfo,
            ),
          );

          // Restore locations
          final locations = usageData['locations'] as List?;
          if (locations != null) {
            for (final locData in locations) {
              usage.locations
                  .add(KeyLocation.fromMap(locData as Map<String, dynamic>));
            }
          }

          // Restore handlers
          final handlers = usageData['handlers'] as List?;
          if (handlers != null) {
            for (final handlerData in handlers) {
              usage.handlers.add(
                  HandlerInfo.fromMap(handlerData as Map<String, dynamic>));
            }
          }

          // Restore tags
          final tags = usageData['tags'] as List?;
          if (tags != null) {
            usage.tags.addAll(tags.cast<String>());
          }
        }
      }

      return true;
    } catch (e) {
      // Cache load failed, continue with normal scan
      return false;
    }
  }

  /// Save scan results to cache
  Future<void> _saveToCache(
    String filePath,
    String packageInfo,
    FileAnalysis analysis,
    Map<String, KeyUsage> fileKeyUsages,
  ) async {
    try {
      final parts = packageInfo.split('@');
      if (parts.length != 2) return;

      final packageName = parts[0];
      final packageVersion = parts[1];

      final cacheKey = DependencyCache.getCacheKey(
        packageName: packageName,
        packageVersion: packageVersion,
        detectorHash: DependencyCache.getDetectorHash(),
        sdkVersion: DependencyCache.getSdkVersion(),
      );

      // Load existing cache or create new
      final existing =
          await DependencyCache.loadCache(projectPath, cacheKey) ?? {};

      // Add this file's data
      final fileKey = path.relative(filePath, from: projectPath);
      existing[fileKey] = {
        'widgetCount': analysis.widgetCount,
        'widgetsWithKeys': analysis.widgetsWithKeys,
        'nodesAnalyzed': analysis.nodesAnalyzed,
        'keysFound': analysis.keysFound.toList(),
        'totalLines': _countLines(File(filePath)),
        'keyUsages': fileKeyUsages.map((key, usage) => MapEntry(key, {
              'locations': usage.locations.map((loc) => loc.toMap()).toList(),
              'handlers': usage.handlers.map((h) => h.toMap()).toList(),
              'tags': usage.tags.toList(),
              'source': usage.source,
              'status': usage.status,
              'notes': usage.notes,
            })),
      };

      // Save cache
      await DependencyCache.saveCache(projectPath, cacheKey, existing);
    } catch (e) {
      // Cache save failed, ignore silently
    }
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

    // Also check for ValueKey/Key creation independently of widget context
    if (typeName == 'ValueKey' || typeName == 'Key') {
      for (final detector in detectors) {
        final result = detector.detectExpression(node);
        if (result != null) {
          _recordKey(result.key, node, detector, result);
          break;
        }
      }
    }

    // Call super to continue visiting children
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    analysis.nodesAnalyzed++;

    // Check if variable is initialized with a widget that has keys
    final initializer = node.initializer;
    if (initializer is InstanceCreationExpression) {
      final typeName = initializer.constructorName.type.toString();

      if (_isWidget(typeName)) {
        analysis.widgetCount++;
        analysis.widgetTypes.add(typeName);

        // Check for key parameter
        final keyArgs = initializer.argumentList.arguments
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
              _recordKey(result.key, initializer, detector, result);
              break;
            }
          }
        } else {
          analysis.uncoveredWidgetTypes.add(typeName);
        }
      }
      // ENHANCED: Check for direct Key/ValueKey assignments like "final Key? key = const ValueKey('...')"
      else if (typeName == 'ValueKey' || typeName == 'Key') {
        // Check if this variable is named 'key'
        if (node.name.lexeme == 'key') {
          // Extract key value using detectors
          for (final detector in detectors) {
            final result = detector.detectExpression(initializer);
            if (result != null) {
              _recordKey(result.key, initializer, detector, result);
              break;
            }
          }
        }
      }
    }

    super.visitVariableDeclaration(node);
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
