/// Blind spot detection model
class BlindSpot {
  final String id;
  final String context;
  final String detector;
  final List<String> files;
  final String preview;

  BlindSpot({
    required this.id,
    required this.context,
    required this.detector,
    required this.files,
    required this.preview,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'context': context,
      'detector': detector,
      'files': files,
      'preview': preview,
    };
  }

  factory BlindSpot.fromMap(Map<String, dynamic> map) {
    return BlindSpot(
      id: map['id'] ?? '',
      context: map['context'] ?? '',
      detector: map['detector'] ?? '',
      files: List<String>.from(map['files'] ?? []),
      preview: map['preview'] ?? '',
    );
  }
}
