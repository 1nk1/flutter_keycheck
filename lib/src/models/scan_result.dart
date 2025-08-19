import 'dart:convert';

/// Complete scan result with metrics and coverage
class ScanResult {
  final ScanMetrics metrics;
  final Map<String, FileAnalysis> fileAnalyses;
  final Map<String, KeyUsage> keyUsages;
  final List<BlindSpot> blindSpots;
  final Duration duration;

  ScanResult({
    required this.metrics,
    required this.fileAnalyses,
    required this.keyUsages,
    required this.blindSpots,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    // Aggregate keys from all file analyses
    final aggregatedKeys = <Map<String, dynamic>>[];
    for (final entry in fileAnalyses.entries) {
      final fa = entry.value;
      for (final keyName in fa.keysFound) {
        // Try to find location info from keyUsages
        final usage = keyUsages[keyName];
        KeyLocation? location;
        if (usage != null && usage.locations.isNotEmpty) {
          try {
            location = usage.locations.firstWhere(
              (loc) => loc.file == fa.relativePath,
            );
          } catch (_) {
            // No matching location found
          }
        }

        aggregatedKeys.add({
          'key': keyName,
          'file': fa.relativePath,
          if (location != null && location.line > 0) 'line': location.line,
          if (usage?.source != null) 'source': usage!.source,
          if (usage?.package != null) 'package': usage!.package,
        });
      }
    }

    return {
      'schemaVersion': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'keys': aggregatedKeys, // critical for tests
      'metrics': metrics.toMap(),
      'file_analyses': fileAnalyses.map((k, v) => MapEntry(k, v.toMap())),
      'key_usages': keyUsages.map((k, v) => MapEntry(k, v.toMap())),
      'blind_spots': blindSpots.map((e) => e.toMap()).toList(),
      'duration_ms': duration.inMilliseconds,
    };
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      metrics: ScanMetrics.fromMap(map['metrics']),
      fileAnalyses: Map<String, FileAnalysis>.from(
        (map['file_analyses'] as Map).map(
          (k, v) => MapEntry(k, FileAnalysis.fromMap(v)),
        ),
      ),
      keyUsages: Map<String, KeyUsage>.from(
        (map['key_usages'] as Map).map(
          (k, v) => MapEntry(k, KeyUsage.fromMap(v)),
        ),
      ),
      blindSpots: List<BlindSpot>.from(
        (map['blind_spots'] as List).map((x) => BlindSpot.fromMap(x)),
      ),
      duration: Duration(milliseconds: map['duration_ms']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ScanResult.fromJson(String source) =>
      ScanResult.fromMap(json.decode(source));
}

/// Scan metrics with coverage information
class ScanMetrics {
  int totalFiles = 0;
  int scannedFiles = 0;
  int totalLines = 0;
  int analyzedNodes = 0;
  double fileCoverage = 0;
  double widgetCoverage = 0;
  double handlerCoverage = 0;
  Map<String, int> detectorHits = {};
  List<ScanError> errors = [];
  bool incrementalScan = false;
  String? incrementalBase;
  Map<String, dynamic>? dependencyTree;
  
  // Performance optimization metrics
  int parallelFilesProcessed = 0;
  int cacheHits = 0;
  int cacheMisses = 0;
  int largeFilesProcessed = 0;
  double avgFileSizeKB = 0;
  Duration totalScanTime = Duration.zero;

  // Default constructor
  ScanMetrics();

  Map<String, dynamic> toMap() {
    return {
      'total_files': totalFiles,
      'scanned_files': scannedFiles,
      'total_lines': totalLines,
      'analyzed_nodes': analyzedNodes,
      'file_coverage': fileCoverage,
      'widget_coverage': widgetCoverage,
      'handler_coverage': handlerCoverage,
      'detector_hits': detectorHits,
      'errors': errors.map((e) => e.toMap()).toList(),
      'incremental_scan': incrementalScan,
      'incremental_base': incrementalBase,
      'parallel_files_processed': parallelFilesProcessed,
      'cache_hits': cacheHits,
      'cache_misses': cacheMisses,
      'cache_hit_rate': cacheHits + cacheMisses > 0 
          ? '${(cacheHits / (cacheHits + cacheMisses) * 100).toStringAsFixed(1)}%'
          : '0%',
      'large_files_processed': largeFilesProcessed,
      'avg_file_size_kb': avgFileSizeKB.toStringAsFixed(1),
      'total_scan_time_ms': totalScanTime.inMilliseconds,
      if (dependencyTree != null) 'dependency_tree': dependencyTree,
    };
  }

  factory ScanMetrics.fromMap(Map<String, dynamic> map) {
    final metrics = ScanMetrics();
    metrics.totalFiles = map['total_files'] ?? 0;
    metrics.scannedFiles = map['scanned_files'] ?? 0;
    metrics.totalLines = map['total_lines'] ?? 0;
    metrics.analyzedNodes = map['analyzed_nodes'] ?? 0;
    metrics.fileCoverage = (map['file_coverage'] ?? 0).toDouble();
    metrics.widgetCoverage = (map['widget_coverage'] ?? 0).toDouble();
    metrics.handlerCoverage = (map['handler_coverage'] ?? 0).toDouble();
    metrics.detectorHits = Map<String, int>.from(map['detector_hits'] ?? {});
    metrics.errors = List<ScanError>.from(
      (map['errors'] ?? []).map((x) => ScanError.fromMap(x)),
    );
    metrics.incrementalScan = map['incremental_scan'] ?? false;
    metrics.incrementalBase = map['incremental_base'];
    metrics.parallelFilesProcessed = map['parallel_files_processed'] ?? 0;
    metrics.cacheHits = map['cache_hits'] ?? 0;
    metrics.cacheMisses = map['cache_misses'] ?? 0;
    metrics.largeFilesProcessed = map['large_files_processed'] ?? 0;
    metrics.avgFileSizeKB = (map['avg_file_size_kb'] ?? 0).toDouble();
    metrics.totalScanTime = Duration(milliseconds: map['total_scan_time_ms'] ?? 0);
    metrics.dependencyTree = map['dependency_tree'];
    return metrics;
  }
}

/// File-level analysis
class FileAnalysis {
  final String path;
  final String relativePath;
  final Set<String> keysFound = {};
  final Set<String> widgetTypes = {};
  final Set<String> uncoveredWidgetTypes = {};
  final List<String> functions = [];
  final List<String> methods = [];
  final Map<String, int> detectorHits = {};
  int nodesAnalyzed = 0;
  int widgetCount = 0;
  int widgetsWithKeys = 0;

  FileAnalysis({
    required this.path,
    required this.relativePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'relative_path': relativePath,
      'keys_found': keysFound.toList(),
      'widget_types': widgetTypes.toList(),
      'uncovered_widget_types': uncoveredWidgetTypes.toList(),
      'functions': functions,
      'methods': methods,
      'detector_hits': detectorHits,
      'nodes_analyzed': nodesAnalyzed,
      'widget_count': widgetCount,
      'widgets_with_keys': widgetsWithKeys,
    };
  }

  factory FileAnalysis.fromMap(Map<String, dynamic> map) {
    final analysis = FileAnalysis(
      path: map['path'],
      relativePath: map['relative_path'],
    );
    analysis.keysFound.addAll(List<String>.from(map['keys_found'] ?? []));
    analysis.widgetTypes.addAll(List<String>.from(map['widget_types'] ?? []));
    analysis.uncoveredWidgetTypes
        .addAll(List<String>.from(map['uncovered_widget_types'] ?? []));
    analysis.functions.addAll(List<String>.from(map['functions'] ?? []));
    analysis.methods.addAll(List<String>.from(map['methods'] ?? []));
    analysis.detectorHits
        .addAll(Map<String, int>.from(map['detector_hits'] ?? {}));
    analysis.nodesAnalyzed = map['nodes_analyzed'] ?? 0;
    analysis.widgetCount = map['widget_count'] ?? 0;
    analysis.widgetsWithKeys = map['widgets_with_keys'] ?? 0;
    return analysis;
  }
}

/// Key usage information
class KeyUsage {
  final String id;
  final List<KeyLocation> locations = [];
  final List<HandlerInfo> handlers = [];
  final Set<String> tags = {};
  String status = 'active';
  String? notes;
  String source = 'workspace'; // 'workspace' or 'package'
  String? package; // 'name@version' for deps

  KeyUsage({required this.id, this.source = 'workspace', this.package});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locations': locations.map((e) => e.toMap()).toList(),
      'handlers': handlers.map((e) => e.toMap()).toList(),
      'tags': tags.toList(),
      'status': status,
      'notes': notes,
      'source': source,
      'package': package,
    };
  }

  factory KeyUsage.fromMap(Map<String, dynamic> map) {
    final usage = KeyUsage(
      id: map['id'],
      source: map['source'] ?? 'workspace',
      package: map['package'],
    );
    usage.locations.addAll(
      (map['locations'] ?? []).map<KeyLocation>((x) => KeyLocation.fromMap(x)),
    );
    usage.handlers.addAll(
      (map['handlers'] ?? []).map<HandlerInfo>((x) => HandlerInfo.fromMap(x)),
    );
    usage.tags.addAll(List<String>.from(map['tags'] ?? []));
    usage.status = map['status'] ?? 'active';
    usage.notes = map['notes'];
    return usage;
  }
}

/// Key location in code
class KeyLocation {
  final String file;
  final int line;
  final int column;
  final String detector;
  final String context;

  KeyLocation({
    required this.file,
    required this.line,
    required this.column,
    required this.detector,
    required this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'file': file,
      'line': line,
      'column': column,
      'detector': detector,
      'context': context,
    };
  }

  factory KeyLocation.fromMap(Map<String, dynamic> map) {
    return KeyLocation(
      file: map['file'],
      line: map['line'],
      column: map['column'],
      detector: map['detector'],
      context: map['context'],
    );
  }
}

/// Handler information for actions
class HandlerInfo {
  final String type;
  final String? method;
  final String file;
  final int line;

  HandlerInfo({
    required this.type,
    this.method,
    required this.file,
    required this.line,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'method': method,
      'file': file,
      'line': line,
    };
  }

  factory HandlerInfo.fromMap(Map<String, dynamic> map) {
    return HandlerInfo(
      type: map['type'],
      method: map['method'],
      file: map['file'],
      line: map['line'],
    );
  }
}

/// Blind spot in scanning
class BlindSpot {
  final String type;
  final String location;
  final String severity;
  final String message;

  BlindSpot({
    required this.type,
    required this.location,
    required this.severity,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'location': location,
      'severity': severity,
      'message': message,
    };
  }

  factory BlindSpot.fromMap(Map<String, dynamic> map) {
    return BlindSpot(
      type: map['type'],
      location: map['location'],
      severity: map['severity'],
      message: map['message'],
    );
  }
}

/// Scan error
class ScanError {
  final String file;
  final String error;
  final String type;

  ScanError({
    required this.file,
    required this.error,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'file': file,
      'error': error,
      'type': type,
    };
  }

  factory ScanError.fromMap(Map<String, dynamic> map) {
    return ScanError(
      file: map['file'],
      error: map['error'],
      type: map['type'],
    );
  }
}

/// Scan snapshot with metadata
class ScanSnapshot {
  final DateTime timestamp;
  final String projectPath;
  final ScanResult scanResult;

  ScanSnapshot({
    required this.timestamp,
    required this.projectPath,
    required this.scanResult,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'project_path': projectPath,
      'scan_result': scanResult.toMap(),
      'schema_version': '1.0',
    };
  }

  factory ScanSnapshot.fromMap(Map<String, dynamic> map) {
    return ScanSnapshot(
      timestamp: DateTime.parse(map['timestamp']),
      projectPath: map['project_path'],
      scanResult: ScanResult.fromMap(map['scan_result']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ScanSnapshot.fromJson(String source) =>
      ScanSnapshot.fromMap(json.decode(source));
}
