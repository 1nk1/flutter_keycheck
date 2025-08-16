// Shim for package registry - re-exports key registry
import 'key_registry_v3.dart' show PackageKeyRegistry;
export 'key_registry_v3.dart' show PackageKeyRegistry;

// Type alias for compatibility
typedef PackageRegistry = PackageKeyRegistry;
