/// Base agent interface defining common behavior for all agents in the casino system
abstract class BaseAgent {
  /// Unique identifier for this agent instance
  String get agentId;

  /// Agent type for logging and debugging
  String get agentType;

  /// Initialize the agent with required dependencies
  Future<void> initialize();

  /// Dispose of resources when agent is no longer needed
  Future<void> dispose();

  /// Check if the agent is currently active and ready to process requests
  bool get isActive;

  /// Get current status of the agent
  AgentStatus get status;

  /// Handle errors that occur during agent operations
  void handleError(Object error, StackTrace stackTrace);

  /// Get agent metadata for monitoring and diagnostics
  Map<String, dynamic> getMetadata();
}

/// Status enumeration for agent lifecycle
enum AgentStatus {
  /// Agent is not yet initialized
  uninitialized,

  /// Agent is initializing
  initializing,

  /// Agent is active and ready to process requests
  active,

  /// Agent is temporarily suspended
  suspended,

  /// Agent encountered an error
  error,

  /// Agent is disposing resources
  disposing,

  /// Agent has been disposed
  disposed,
}

/// Base implementation providing common functionality
abstract class BaseAgentImpl implements BaseAgent {
  late final String _agentId;
  AgentStatus _status = AgentStatus.uninitialized;
  final List<String> _errors = [];

  BaseAgentImpl() {
    _agentId = '${agentType}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  String get agentId => _agentId;

  @override
  AgentStatus get status => _status;

  @override
  bool get isActive => _status == AgentStatus.active;

  @override
  Future<void> initialize() async {
    if (_status != AgentStatus.uninitialized) {
      throw AgentException(
          'Agent is already initialized or in invalid state: $_status');
    }

    _status = AgentStatus.initializing;

    try {
      await onInitialize();
      _status = AgentStatus.active;
    } catch (error, stackTrace) {
      _status = AgentStatus.error;
      handleError(error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    if (_status == AgentStatus.disposed || _status == AgentStatus.disposing) {
      return;
    }

    _status = AgentStatus.disposing;

    try {
      await onDispose();
    } catch (error, stackTrace) {
      handleError(error, stackTrace);
    } finally {
      _status = AgentStatus.disposed;
    }
  }

  @override
  void handleError(Object error, StackTrace stackTrace) {
    final errorMessage = 'Agent $agentType ($agentId) error: $error';
    _errors.add(errorMessage);

    // Log error (in a real app, this would use a proper logging system)
    print('ERROR: $errorMessage');
    print('Stack trace: $stackTrace');
  }

  @override
  Map<String, dynamic> getMetadata() {
    return {
      'agentId': agentId,
      'agentType': agentType,
      'status': status.name,
      'isActive': isActive,
      'errors': List.unmodifiable(_errors),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Protected method for subclasses to implement initialization logic
  Future<void> onInitialize();

  /// Protected method for subclasses to implement disposal logic
  Future<void> onDispose();

  /// Suspend the agent (can be resumed)
  void suspend() {
    if (_status == AgentStatus.active) {
      _status = AgentStatus.suspended;
    }
  }

  /// Resume a suspended agent
  void resume() {
    if (_status == AgentStatus.suspended) {
      _status = AgentStatus.active;
    }
  }

  /// Validate that the agent is in active state before processing
  void validateActive() {
    if (!isActive) {
      throw AgentException('Agent is not active. Current status: $_status');
    }
  }
}

/// Exception thrown by agents during operations
class AgentException implements Exception {
  final String message;
  final String? agentType;
  final String? agentId;

  const AgentException(this.message, {this.agentType, this.agentId});

  @override
  String toString() {
    if (agentType != null && agentId != null) {
      return 'AgentException in $agentType ($agentId): $message';
    }
    return 'AgentException: $message';
  }
}
