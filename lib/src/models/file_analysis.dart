/// File analysis result model
class FileAnalysis {
  final String path;
  final String absolutePath;
  final int keysFound;
  final List<String> parseErrors;
  final Duration scanDuration;

  FileAnalysis({
    required this.path,
    required this.absolutePath,
    required this.keysFound,
    required this.parseErrors,
    required this.scanDuration,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'absolutePath': absolutePath,
      'keysFound': keysFound,
      'parseErrors': parseErrors,
      'scanDuration': scanDuration.inMilliseconds,
    };
  }

  factory FileAnalysis.fromMap(Map<String, dynamic> map) {
    return FileAnalysis(
      path: map['path'] ?? '',
      absolutePath: map['absolutePath'] ?? '',
      keysFound: map['keysFound'] ?? 0,
      parseErrors: List<String>.from(map['parseErrors'] ?? []),
      scanDuration: Duration(milliseconds: map['scanDuration'] ?? 0),
    );
  }
}
