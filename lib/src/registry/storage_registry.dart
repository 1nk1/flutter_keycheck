// Shim for storage registry - re-exports key registry
import 'key_registry_v3.dart' show PathKeyRegistry;
export 'key_registry_v3.dart' show PathKeyRegistry;

// Type alias for compatibility
typedef StorageRegistry = PathKeyRegistry;
