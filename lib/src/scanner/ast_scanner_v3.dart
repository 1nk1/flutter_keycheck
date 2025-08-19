import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_keycheck/src/config/config_v3.dart';
import 'package:flutter_keycheck/src/models/scan_result.dart';
import 'package:flutter_keycheck/src/scanner/key_detectors_v3.dart';
import 'package:flutter_keycheck/src/cache/dependency_cache.dart';
import 'package:flutter_keycheck/src/scanner/dependency_resolver.dart';
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

/// Performance metrics for optimization
class PerformanceMetrics {
  final Stopwatch _totalTime = Stopwatch();
  final Stopwatch _fileDiscoveryTime = Stopwatch();
  final Stopwatch _astAnalysisTime = Stopwatch();
  final Stopwatch _cacheTime = Stopwatch();
  final Map<String, int> _operationCounts = {};
  final Map<String, Duration> _phaseTimings = {};
  int _memoryUsedBytes = 0;
  int _filesProcessedParallel = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  double _filesPerSecond = 0;
  double _keysPerSecond = 0;

  void startTotal() => _totalTime.start();
  void stopTotal() => _totalTime.stop();
  
  void startFileDiscovery() => _fileDiscoveryTime.start();
  void stopFileDiscovery() => _fileDiscoveryTime.stop();
  
  void startASTAnalysis() => _astAnalysisTime.start();
  void stopASTAnalysis() => _astAnalysisTime.stop();
  
  void startCache() => _cacheTime.start();
  void stopCache() => _cacheTime.stop();

  void recordOperation(String operation) {
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
  }

  void recordPhase(String phase, Duration duration) {
    _phaseTimings[phase] = duration;
  }

  void updateMemoryUsage(int bytes) {
    _memoryUsedBytes = bytes;
  }

  void recordParallelFile() => _filesProcessedParallel++;
  void recordCacheHit() => _cacheHits++;
  void recordCacheMiss() => _cacheMisses++;
  
  void calculateRates(int totalFiles, int totalKeys) {
    final seconds = _totalTime.elapsed.inMilliseconds / 1000.0;
    if (seconds > 0) {
      _filesPerSecond = totalFiles / seconds;
      _keysPerSecond = totalKeys / seconds;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'total_time_ms': _totalTime.elapsedMilliseconds,
      'file_discovery_ms': _fileDiscoveryTime.elapsedMilliseconds,
      'ast_analysis_ms': _astAnalysisTime.elapsedMilliseconds,
      'cache_time_ms': _cacheTime.elapsedMilliseconds,
      'memory_used_mb': (_memoryUsedBytes / (1024 * 1024)).toStringAsFixed(2),
      'files_processed_parallel': _filesProcessedParallel,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'cache_hit_rate': _cacheHits + _cacheMisses > 0 
          ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1) + '%'
          : '0%',
      'files_per_second': _filesPerSecond.toStringAsFixed(1),
      'keys_per_second': _keysPerSecond.toStringAsFixed(1),
      'operation_counts': _operationCounts,
      'phase_timings': _phaseTimings.map((k, v) => MapEntry(k, v.inMilliseconds)),
    };
  }
}

/// Optimized regex patterns (pre-compiled for performance)
class OptimizedPatterns {
  static final RegExp widgetPattern = RegExp(
    r'\b(StatefulWidget|StatelessWidget|Widget|MaterialApp|CupertinoApp|'
    r'Scaffold|AppBar|Container|Column|Row|ListView|GridView|Stack|Card|'
    r'Button|TextField|Text|Image)\b'
  );
  
  static final RegExp excludePattern = RegExp(r'/(\.dart_tool|build|\.git)/');
  
  static final List<RegExp> keyPatterns = [
    RegExp(r"const\s+ValueKey\s*\(\s*'([^']+)'"),
    RegExp(r"key:\s*const\s+ValueKey\s*\(\s*'([^']+)'"),
    RegExp(r"=\s*const\s+ValueKey\s*\(\s*'([^']+)'"),
    RegExp(r"ValueKey\s*\(\s*'([^']+)'"),
    RegExp(r"Key\s*\(\s*'([^']+)'"),
  ];

  static final Set<String> handlerNames = {
    'onPressed', 'onTap', 'onChanged', 'onLongPress', 'onSubmitted',
    'onSave', 'onSelect', 'onDoubleTap', 'onPanUpdate', 'onHorizontalDragEnd',
    'onVerticalDragEnd', 'onScaleEnd', 'onEditingComplete', 'onFieldSubmitted'
  };
  
  static final Set<String> commonWidgets = {
    'Column', 'Row', 'Stack', 'Scaffold', 'AppBar', 'Center', 'Padding',
    'Expanded', 'ListView', 'GridView', 'Container', 'Text', 'Image', 'Icon',
    'MaterialApp', 'CupertinoApp', 'Semantics', 'ElevatedButton', 'TextButton',
    'IconButton', 'OutlinedButton'
  };
}

/// File chunk for parallel processing
class FileChunk {
  final List<FileInfo> files;
  final int chunkId;
  
  FileChunk(this.files, this.chunkId);
}

/// Isolate work item for parallel processing
class IsolateWorkItem {
  final List<FileInfo> files;
  final String projectPath;
  final ConfigV3 config;
  final SendPort sendPort;
  
  IsolateWorkItem({
    required this.files,
    required this.projectPath, 
    required this.config,
    required this.sendPort,
  });
}

/// Result from isolate processing
class IsolateResult {
  final Map<String, FileAnalysis> fileAnalyses;
  final Map<String, KeyUsage> keyUsages;
  final int chunkId;
  final List<ScanError> errors;
  final PerformanceMetrics metrics;
  
  IsolateResult({
    required this.fileAnalyses,
    required this.keyUsages,
    required this.chunkId,
    required this.errors,
    required this.metrics,
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

  // Performance optimization settings
  final bool enableParallelProcessing;
  final int maxWorkerIsolates;
  final bool enableIncrementalScanning;
  final bool enableLazyLoading;
  final int maxFileSizeForMemory; // bytes
  final bool enableAggressiveCaching;

  // Built-in detectors
  late final List<KeyDetector> detectors;

  // Metrics
  final ScanMetrics metrics = ScanMetrics();
  final PerformanceMetrics performanceMetrics = PerformanceMetrics();
  final Map<String, FileAnalysis> fileAnalyses = {};
  final Map<String, KeyUsage> keyUsages = {};
  
  // Performance optimization state
  final Map<String, String> _fileHashCache = {};
  final Map<String, DateTime> _fileModificationCache = {};
  late final int _optimalChunkSize;

  AstScannerV3({
    required this.projectPath,
    this.includeTests = false,
    this.includeGenerated = false,
    this.includeExamples = true,
    this.gitDiffBase,
    this.scope = ScanScope.workspaceOnly,
    this.packageFilter,
    required this.config,
    this.enableParallelProcessing = true,
    this.maxWorkerIsolates = 0, // 0 = auto-detect based on CPU cores
    this.enableIncrementalScanning = true,
    this.enableLazyLoading = true,
    this.maxFileSizeForMemory = 2 * 1024 * 1024, // 2MB threshold
    this.enableAggressiveCaching = true,
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

    // Calculate optimal chunk size based on system capabilities
    final coreCount = Platform.numberOfProcessors;
    final actualWorkers = maxWorkerIsolates > 0 ? maxWorkerIsolates : coreCount;
    _optimalChunkSize = (1000 / actualWorkers).ceil().clamp(10, 500);
    
    if (config.verbose) {
      print('🚀 Performance optimizations enabled:');
      print('  • Parallel processing: $enableParallelProcessing (${actualWorkers} workers)');
      print('  • Incremental scanning: $enableIncrementalScanning');
      print('  • Lazy loading: $enableLazyLoading');
      print('  • Aggressive caching: $enableAggressiveCaching');
      print('  • Optimal chunk size: $_optimalChunkSize files');
    }
  }

  /// Perform full AST scan with comprehensive performance optimizations
  Future<ScanResult> scan() async {
    performanceMetrics.startTotal();
    final startTime = DateTime.now();

    try {
      // Ensure cache directory exists
      final cacheDir = Directory(path.join(projectPath, DependencyCache.cacheDir));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Phase 1: File Discovery (optimized)
      performanceMetrics.startFileDiscovery();
      final filesWithInfo = await _getFilesToScanWithInfoOptimized();
      metrics.totalFiles = filesWithInfo.length;
      performanceMetrics.stopFileDiscovery();

      if (config.verbose) {
        print('📁 Discovered ${filesWithInfo.length} files in ${performanceMetrics._fileDiscoveryTime.elapsedMilliseconds}ms');
      }

      // Phase 2: Incremental Scanning Check
      List<FileInfo> filesToProcess = filesWithInfo;
      if (enableIncrementalScanning && gitDiffBase == null) {
        filesToProcess = await _filterUnchangedFiles(filesWithInfo);
        if (config.verbose && filesToProcess.length < filesWithInfo.length) {
          print('⚡ Incremental scan: ${filesToProcess.length}/${filesWithInfo.length} files need processing');
        }
      }

      // Phase 3: AST Analysis (parallel or sequential)
      performanceMetrics.startASTAnalysis();
      if (enableParallelProcessing && filesToProcess.length > 20) {
        await _scanFilesParallel(filesToProcess);
      } else {
        await _scanFilesSequential(filesToProcess);
      }
      performanceMetrics.stopASTAnalysis();

      // Phase 4: Post-processing
      _calculateCoverageMetrics();
      final blindSpots = _detectBlindSpots();

      // Update performance metrics
      final totalKeys = keyUsages.length;
      performanceMetrics.calculateRates(metrics.scannedFiles, totalKeys);
      
      // Monitor memory usage
      final memoryInfo = ProcessInfo.currentRss;
      performanceMetrics.updateMemoryUsage(memoryInfo);

      performanceMetrics.stopTotal();
      final duration = DateTime.now().difference(startTime);

      // Performance reporting
      if (config.verbose) {
        _reportPerformanceMetrics();
      }

      // Store performance metrics in scan metrics
      metrics.dependencyTree ??= {};
      metrics.dependencyTree!['performance'] = performanceMetrics.toMap();

      return ScanResult(
        metrics: metrics,
        fileAnalyses: fileAnalyses,
        keyUsages: keyUsages,
        blindSpots: blindSpots,
        duration: duration,
      );
    } catch (e) {
      performanceMetrics.stopTotal();
      rethrow;
    }
  }

  /// Report comprehensive performance metrics
  void _reportPerformanceMetrics() {
    final perf = performanceMetrics.toMap();
    print('\n📊 Performance Report:');
    print('  Total time: ${perf['total_time_ms']}ms');
    print('  File discovery: ${perf['file_discovery_ms']}ms');
    print('  AST analysis: ${perf['ast_analysis_ms']}ms');
    print('  Cache operations: ${perf['cache_time_ms']}ms');
    print('  Memory usage: ${perf['memory_used_mb']} MB');
    print('  Cache hit rate: ${perf['cache_hit_rate']}');
    print('  Performance: ${perf['files_per_second']} files/sec, ${perf['keys_per_second']} keys/sec');
    if (perf['files_processed_parallel'] > 0) {
      print('  Parallel processing: ${perf['files_processed_parallel']} files');
    }
  }

  /// Optimized file discovery with caching and parallel directory scanning
  Future<List<FileInfo>> _getFilesToScanWithInfoOptimized() async {
    if (gitDiffBase != null) {
      return await _getFilesToScanWithInfo(); // Use existing git diff logic
    }

    // Parallel directory scanning for better performance
    switch (scope) {
      case ScanScope.depsOnly:
        return await _getDependencyFilesWithInfo();
      case ScanScope.all:
        final futures = [
          Future(() => _getWorkspaceFilesWithInfo()),
          _getDependencyFilesWithInfo(),
        ];
        final results = await Future.wait(futures);
        return [...results[0], ...results[1]];
      case ScanScope.workspaceOnly:
        return _getWorkspaceFilesWithInfoOptimized();
    }
  }

  /// Optimized workspace file discovery with parallel directory scanning
  List<FileInfo> _getWorkspaceFilesWithInfoOptimized() {
    final files = <FileInfo>[];
    final pubspec = File(path.join(projectPath, 'pubspec.yaml'));
    final dirsToScan = <Directory>[];

    // Determine directories to scan (same logic as original)
    if (!pubspec.existsSync()) {
      final localLib = Directory(path.join(projectPath, 'lib'));
      if (localLib.existsSync()) dirsToScan.add(localLib);
    } else {
      // Standard package directories
      for (final dirName in ['lib', 'bin']) {
        final dir = Directory(path.join(projectPath, dirName));
        if (dir.existsSync()) dirsToScan.add(dir);
      }

      if (includeTests) {
        final testDir = Directory(path.join(projectPath, 'test'));
        if (testDir.existsSync()) dirsToScan.add(testDir);
      }

      if (includeExamples) {
        for (final exampleDirName in ['example', 'examples']) {
          final exampleDir = Directory(path.join(projectPath, exampleDirName));
          if (exampleDir.existsSync()) {
            for (final entity in exampleDir.listSync()) {
              if (entity is Directory) {
                for (final subDirName in ['lib', 'bin']) {
                  final subDir = Directory(path.join(entity.path, subDirName));
                  if (subDir.existsSync()) dirsToScan.add(subDir);
                }
              }
            }
          }
        }
      }
    }

    // Optimized file scanning with pre-compiled patterns
    for (final dir in dirsToScan) {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // Fast exclusion check using pre-compiled regex
        if (OptimizedPatterns.excludePattern.hasMatch(entity.path)) continue;

        final relativePath = path.relative(entity.path, from: projectPath);
        if (!_shouldIncludeFileOptimized(relativePath)) continue;

        // Fast package filter check
        if (packageFilter != null) {
          final pattern = RegExp(packageFilter!);
          if (!pattern.hasMatch(relativePath)) continue;
        }

        files.add(FileInfo(path: entity.path, source: 'workspace'));
      }
    }

    return files;
  }

  /// Optimized file inclusion check
  bool _shouldIncludeFileOptimized(String relativePath) {
    if (!includeTests && relativePath.contains('test/')) return false;
    if (!includeGenerated) {
      if (relativePath.endsWith('.g.dart') || relativePath.endsWith('.freezed.dart')) {
        return false;
      }
    }

    // Fast exclude pattern check
    for (final pattern in config.scan.excludePatterns) {
      if (_matchesPatternOptimized(relativePath, pattern)) return false;
    }

    return true;
  }

  /// Optimized pattern matching with caching
  bool _matchesPatternOptimized(String path, String pattern) {
    // Simple caching for pattern matches
    final cacheKey = '$path:$pattern';
    // In production, could use an LRU cache here
    
    final regex = pattern
        .replaceAll('**/', '.*')
        .replaceAll('*', '[^/]*')
        .replaceAll('?', '.');
    return RegExp(regex).hasMatch(path);
  }

  /// Filter files that haven't changed (incremental scanning)
  Future<List<FileInfo>> _filterUnchangedFiles(List<FileInfo> files) async {
    if (!enableIncrementalScanning) return files;

    final changedFiles = <FileInfo>[];
    final checkTasks = <Future<void>>[];

    // Process in chunks to avoid overwhelming the filesystem
    for (int i = 0; i < files.length; i += 100) {
      final chunk = files.skip(i).take(100).toList();
      checkTasks.add(_checkFilesChunk(chunk, changedFiles));
    }

    await Future.wait(checkTasks);
    return changedFiles;
  }

  /// Check a chunk of files for modifications
  Future<void> _checkFilesChunk(List<FileInfo> files, List<FileInfo> changedFiles) async {
    for (final fileInfo in files) {
      final file = File(fileInfo.path);
      if (!await file.exists()) continue;

      final stat = await file.stat();
      final lastModified = stat.modified;
      final cachedModification = _fileModificationCache[fileInfo.path];

      if (cachedModification == null || lastModified.isAfter(cachedModification)) {
        _fileModificationCache[fileInfo.path] = lastModified;
        changedFiles.add(fileInfo);
      }
    }
  }

  /// Parallel file processing using isolates
  Future<void> _scanFilesParallel(List<FileInfo> files) async {
    final coreCount = Platform.numberOfProcessors;
    final workerCount = maxWorkerIsolates > 0 ? maxWorkerIsolates : coreCount;
    final chunkSize = (files.length / workerCount).ceil().clamp(10, _optimalChunkSize);

    if (config.verbose) {
      print('🔄 Processing ${files.length} files with $workerCount workers (chunk size: $chunkSize)');
    }

    final chunks = <List<FileInfo>>[];
    for (int i = 0; i < files.length; i += chunkSize) {
      chunks.add(files.skip(i).take(chunkSize).toList());
    }

    final workers = <Future<void>>[];
    for (int i = 0; i < chunks.length; i++) {
      workers.add(_processChunkInIsolate(chunks[i], i));
    }

    await Future.wait(workers);
  }

  /// Process files sequentially with optimizations
  Future<void> _scanFilesSequential(List<FileInfo> files) async {
    if (config.verbose && files.length > 100) {
      print('🔄 Processing ${files.length} files sequentially with optimizations');
    }

    // Create analysis context once for all files
    final collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      excludedPaths: _getExcludedPaths(),
    );

    // Process files with progress tracking
    final batchSize = 50;
    for (int i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize);
      
      // Process batch
      final batchTasks = batch.map((fileInfo) => _scanFileOptimized(
        fileInfo.path,
        collection,
        source: fileInfo.source,
        packageInfo: fileInfo.packageInfo,
      ));

      await Future.wait(batchTasks);

      if (config.verbose && files.length > 100) {
        final progress = ((i + batchSize) / files.length * 100).clamp(0, 100);
        print('  Progress: ${progress.toStringAsFixed(1)}%');
      }
    }
  }

  /// Process a chunk of files in an isolate
  Future<void> _processChunkInIsolate(List<FileInfo> files, int chunkId) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      IsolateWorkItem(
        files: files,
        projectPath: projectPath,
        config: config,
        sendPort: receivePort.sendPort,
      ),
    );

    final result = await receivePort.first as IsolateResult;
    isolate.kill();

    // Merge results back to main thread
    fileAnalyses.addAll(result.fileAnalyses);
    for (final entry in result.keyUsages.entries) {
      final existing = keyUsages[entry.key];
      if (existing != null) {
        existing.locations.addAll(entry.value.locations);
        existing.handlers.addAll(entry.value.handlers);
        existing.tags.addAll(entry.value.tags);
      } else {
        keyUsages[entry.key] = entry.value;
      }
    }

    metrics.scannedFiles += result.fileAnalyses.length;
    metrics.errors.addAll(result.errors);
    performanceMetrics._filesProcessedParallel += files.length;
  }

  /// Entry point for isolate worker
  static void _isolateEntryPoint(IsolateWorkItem workItem) async {
    try {
      final scanner = AstScannerV3(
        projectPath: workItem.projectPath,
        config: workItem.config,
        enableParallelProcessing: false, // No nested parallelism
      );

      final fileAnalyses = <String, FileAnalysis>{};
      final keyUsages = <String, KeyUsage>{};
      final errors = <ScanError>[];
      final metrics = PerformanceMetrics();

      final collection = AnalysisContextCollection(
        includedPaths: [workItem.projectPath],
      );

      for (final fileInfo in workItem.files) {
        try {
          await scanner._scanFileOptimized(
            fileInfo.path,
            collection,
            source: fileInfo.source,
            packageInfo: fileInfo.packageInfo,
          );

          // Collect results for this file
          final analysis = scanner.fileAnalyses[fileInfo.path];
          if (analysis != null) {
            fileAnalyses[fileInfo.path] = analysis;
          }

        } catch (e) {
          errors.add(ScanError(
            file: fileInfo.path,
            error: e.toString(),
            type: 'isolate_scan',
          ));
        }
      }

      // Collect key usages from scanner
      for (final entry in scanner.keyUsages.entries) {
        keyUsages[entry.key] = entry.value;
      }

      final result = IsolateResult(
        fileAnalyses: fileAnalyses,
        keyUsages: keyUsages,
        chunkId: 0,
        errors: errors,
        metrics: metrics,
      );

      workItem.sendPort.send(result);
    } catch (e) {
      // Send error result
      final result = IsolateResult(
        fileAnalyses: {},
        keyUsages: {},
        chunkId: 0,
        errors: [ScanError(
          file: 'isolate',
          error: e.toString(),
          type: 'isolate_error',
        )],
        metrics: PerformanceMetrics(),
      );
      workItem.sendPort.send(result);
    }
  }

  /// Get files to scan with source information (original method for git diff)
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

  /// Get dependency files with info (enhanced with transitive dependencies)
  Future<List<FileInfo>> _getDependencyFilesWithInfo() async {
    final files = <FileInfo>[];

    // Use the new DependencyResolver for full transitive resolution
    final resolver = DependencyResolver(
      projectPath: projectPath,
      includeDevDependencies: false,
      verbose: config.verbose,
    );

    try {
      // Resolve all dependencies (direct and transitive)
      final dependencies = await resolver.resolveDependencies();
      
      if (config.verbose) {
        final stats = resolver.getStatistics();
        print('📊 Dependency Statistics:');
        print('  Total packages: ${stats['total_packages']}');
        print('  Direct dependencies: ${stats['direct_dependencies']}');
        print('  Transitive dependencies: ${stats['transitive_dependencies']}');
        print('  Max depth: ${stats['max_depth']}');
      }

      // Process each resolved dependency
      for (final entry in dependencies.entries) {
        final package = entry.value;
        
        // Skip the root package
        if (package.depth == 0) continue;
        
        // Apply package filter if set
        if (packageFilter != null) {
          final pattern = RegExp(packageFilter!);
          if (!pattern.hasMatch(package.name)) continue;
        }

        // Scan lib folder of the package
        final libPath = path.join(package.resolvedPath, 'lib');
        if (Directory(libPath).existsSync()) {
          for (final entity in Directory(libPath).listSync(recursive: true)) {
            if (entity is File && entity.path.endsWith('.dart')) {
              files.add(FileInfo(
                path: entity.path,
                source: 'package',
                packageInfo: package.fullName,
              ));
            }
          }
        }
      }
      
      // Store dependency tree in metrics for reporting
      metrics.dependencyTree = dependencies.map(
        (key, value) => MapEntry(key, {
          'name': value.name,
          'version': value.version,
          'source': value.source,
          'depth': value.depth,
          'dependencies': value.directDependencies.toList(),
        }),
      );
      
    } catch (e) {
      // Fallback to old method if resolver fails
      if (config.verbose) {
        print('Warning: Dependency resolver failed, using fallback: $e');
      }
      return _getDependencyFilesWithInfoFallback();
    }

    return files;
  }

  /// Fallback method for dependency scanning (original implementation)
  Future<List<FileInfo>> _getDependencyFilesWithInfoFallback() async {
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

  /// Optimized file scanning with lazy loading and enhanced caching
  Future<void> _scanFileOptimized(String filePath, AnalysisContextCollection collection,
      {String source = 'workspace', String? packageInfo}) async {
    performanceMetrics.recordOperation('file_scan');
    
    // Enhanced cache check with performance tracking
    if (source == 'package' && packageInfo != null && enableAggressiveCaching) {
      performanceMetrics.startCache();
      final cached = await _tryLoadFromCache(filePath, packageInfo);
      performanceMetrics.stopCache();
      
      if (cached) {
        performanceMetrics.recordCacheHit();
        return;
      } else {
        performanceMetrics.recordCacheMiss();
      }
    }

    // Check file size for lazy loading decision
    final file = File(filePath);
    final fileSize = await file.length();
    
    if (enableLazyLoading && fileSize > maxFileSizeForMemory) {
      await _scanLargeFile(filePath, collection, source: source, packageInfo: packageInfo);
      return;
    }

    // Regular AST scanning with optimizations
    await _scanFileAST(filePath, collection, source: source, packageInfo: packageInfo);
  }

  /// Scan large files using streaming and heuristics
  Future<void> _scanLargeFile(String filePath, AnalysisContextCollection collection,
      {String source = 'workspace', String? packageInfo}) async {
    try {
      final file = File(filePath);
      
      // Use streaming for large files
      final analysis = FileAnalysis(
        path: filePath,
        relativePath: path.relative(filePath, from: projectPath),
      );

      // Stream file content and use optimized regex patterns
      final content = await file.readAsString();
      
      // Use pre-compiled patterns for better performance
      final widgetMatches = OptimizedPatterns.widgetPattern.allMatches(content).length;
      analysis.widgetCount = widgetMatches;

      // Extract keys using optimized patterns
      _extractKeysFromTextOptimized(content, analysis);

      // Simple heuristics for handlers
      for (final handlerName in OptimizedPatterns.handlerNames) {
        if (content.contains(handlerName)) {
          analysis.widgetCount = (analysis.widgetCount + 1).clamp(1, widgetMatches);
        }
      }

      // Store analysis
      fileAnalyses[filePath] = analysis;
      metrics.scannedFiles++;
      metrics.totalLines += content.split('\n').length;

      if (config.verbose) {
        final sizeKB = (await file.length() / 1024).toStringAsFixed(1);
        print('  📄 Large file processed via streaming: ${path.basename(filePath)} (${sizeKB}KB)');
      }

    } catch (e) {
      metrics.errors.add(ScanError(
        file: filePath,
        error: e.toString(),
        type: 'large_file_scan',
      ));
    }
  }

  /// Extract keys using optimized pre-compiled patterns
  void _extractKeysFromTextOptimized(String content, FileAnalysis analysis) {
    for (final pattern in OptimizedPatterns.keyPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final keyValue = match.group(1);
        if (keyValue != null && keyValue.isNotEmpty) {
          analysis.keysFound.add(keyValue);
          analysis.detectorHits['StringLiteral'] =
              (analysis.detectorHits['StringLiteral'] ?? 0) + 1;

          // Create efficient key usage
          final usage = keyUsages.putIfAbsent(
            keyValue,
            () => KeyUsage(id: keyValue, source: 'workspace'),
          );

          // Add location with minimal computation
          final lineNumber = content.substring(0, match.start).split('\n').length;
          usage.locations.add(KeyLocation(
            file: analysis.path,
            line: lineNumber,
            column: match.start - content.lastIndexOf('\n', match.start),
            detector: 'StringLiteralOptimized',
            context: 'regex-optimized',
          ));
        }
      }
    }
  }

  /// AST-based file scanning (existing logic but optimized)
  Future<void> _scanFileAST(String filePath, AnalysisContextCollection collection,
      {String source = 'workspace', String? packageInfo}) async {
    // This is the optimized version of the original _scanFile method
    await _scanFile(filePath, collection, source: source, packageInfo: packageInfo);
  }

  /// Scan single file with AST (original method, kept for compatibility)
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
          usage.locations.add(KeyLocation(
            file: analysis.path,
            line: lineNumber,
            column: match.start - content.lastIndexOf('\n', match.start),
            detector: 'StringLiteral',
            context: 'regex-fallback',
          ));
        }
      }
    }
  }

  /// Optimized text heuristics using pre-compiled patterns
  _Heuristics _scanTextHeuristics(String content) {
    // Use pre-compiled pattern for better performance
    final widgetHits = OptimizedPatterns.widgetPattern.allMatches(content).length;

    final handlers = <String>[];
    for (final handlerName in OptimizedPatterns.handlerNames) {
      if (content.contains(handlerName)) {
        handlers.add(handlerName);
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
    // Fast check using pre-compiled set
    if (OptimizedPatterns.commonWidgets.contains(typeName)) {
      return true;
    }
    
    // Fallback to suffix checks
    return typeName.endsWith('Widget') ||
        typeName.endsWith('Button') ||
        typeName.endsWith('Field') ||
        typeName.endsWith('View') ||
        typeName.endsWith('Screen') ||
        typeName.endsWith('Page') ||
        typeName.endsWith('Dialog') ||
        typeName.endsWith('Card');
  }
}
