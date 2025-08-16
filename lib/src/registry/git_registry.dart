// Shim for git registry - re-exports key registry
import 'key_registry_v3.dart' show GitKeyRegistry;
export 'key_registry_v3.dart' show GitKeyRegistry;

// Type alias for compatibility
typedef GitRegistry = GitKeyRegistry;
