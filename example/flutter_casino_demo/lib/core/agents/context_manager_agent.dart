import 'dart:async';
import 'dart:convert';
import 'base_agent.dart';

/// Agent responsible for managing session state and game context
class ContextManagerAgent extends BaseAgentImpl {
  static const String _agentTypeId = 'ContextManager';
  
  // Session state
  String? _sessionId;
  DateTime? _sessionStartTime;
  SessionState _sessionState = SessionState.idle;
  GameState _gameState = GameState.waiting;
  
  // Game context
  String? _currentGameType;
  Map<String, dynamic> _gameContext = {};
  List<GameAction> _actionHistory = [];
  
  // Session data
  Map<String, dynamic> _sessionData = {};
  final Map<String, dynamic> _preferences = {};
  
  // Stream controllers
  final StreamController<ContextUpdate> _contextUpdateController = 
      StreamController<ContextUpdate>.broadcast();
  final StreamController<GameAction> _actionHistoryController = 
      StreamController<GameAction>.broadcast();

  @override
  String get agentType => _agentTypeId;

  /// Stream of context updates
  Stream<ContextUpdate> get contextUpdates => _contextUpdateController.stream;

  /// Stream of game actions for history tracking
  Stream<GameAction> get actionHistory => _actionHistoryController.stream;

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Current session state
  SessionState get sessionState => _sessionState;

  /// Current game state
  GameState get gameState => _gameState;

  /// Current game type
  String? get currentGameType => _currentGameType;

  /// Session duration
  Duration? get sessionDuration {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Number of actions in current session
  int get actionCount => _actionHistory.length;

  @override
  Future<void> onInitialize() async {
    _sessionData.clear();
    _gameContext.clear();
    _actionHistory.clear();
  }

  @override
  Future<void> onDispose() async {
    await endSession();
    await _contextUpdateController.close();
    await _actionHistoryController.close();
  }

  /// Start a new session
  Future<String> startSession({String? userId, Map<String, dynamic>? initialData}) async {
    validateActive();
    
    if (_sessionState != SessionState.idle) {
      throw AgentException('Cannot start session in current state: $_sessionState', 
          agentType: agentType, agentId: agentId);
    }
    
    _sessionId = _generateSessionId();
    _sessionStartTime = DateTime.now();
    _sessionState = SessionState.active;
    _gameState = GameState.waiting;
    
    _sessionData = {
      'sessionId': _sessionId,
      'startTime': _sessionStartTime!.toIso8601String(),
      'userId': userId,
      ...?initialData,
    };
    
    _actionHistory.clear();
    
    _emitContextUpdate(ContextUpdateType.sessionStarted, {
      'sessionId': _sessionId,
      'startTime': _sessionStartTime,
      'userId': userId,
    });
    
    return _sessionId!;
  }

  /// End current session
  Future<void> endSession() async {
    if (_sessionState == SessionState.idle) return;
    
    _sessionState = SessionState.ending;
    
    // Save final session data
    if (_sessionStartTime != null) {
      _sessionData['endTime'] = DateTime.now().toIso8601String();
      _sessionData['duration'] = sessionDuration!.inMilliseconds;
      _sessionData['actionCount'] = _actionHistory.length;
    }
    
    _emitContextUpdate(ContextUpdateType.sessionEnded, {
      'sessionId': _sessionId,
      'duration': sessionDuration,
      'actionCount': _actionHistory.length,
    });
    
    // Reset state
    _sessionId = null;
    _sessionStartTime = null;
    _sessionState = SessionState.idle;
    _gameState = GameState.waiting;
    _currentGameType = null;
    _gameContext.clear();
  }

  /// Start a new game within the session
  void startGame(String gameType, {Map<String, dynamic>? gameConfig}) {
    validateActive();
    
    if (_sessionState != SessionState.active) {
      throw AgentException('Cannot start game outside active session', 
          agentType: agentType, agentId: agentId);
    }
    
    if (_gameState == GameState.playing) {
      throw AgentException('Game already in progress', 
          agentType: agentType, agentId: agentId);
    }
    
    _currentGameType = gameType;
    _gameState = GameState.playing;
    _gameContext = {
      'gameType': gameType,
      'startTime': DateTime.now().toIso8601String(),
      ...?gameConfig,
    };
    
    _recordAction(GameActionType.gameStarted, {
      'gameType': gameType,
      'config': gameConfig,
    });
    
    _emitContextUpdate(ContextUpdateType.gameStarted, {
      'gameType': gameType,
      'config': gameConfig,
    });
  }

  /// End current game
  void endGame({Map<String, dynamic>? gameResults}) {
    validateActive();
    
    if (_gameState != GameState.playing) {
      throw AgentException('No game in progress to end', 
          agentType: agentType, agentId: agentId);
    }
    
    _gameContext['endTime'] = DateTime.now().toIso8601String();
    if (gameResults != null) {
      _gameContext['results'] = gameResults;
    }
    
    _recordAction(GameActionType.gameEnded, {
      'gameType': _currentGameType,
      'results': gameResults,
    });
    
    _emitContextUpdate(ContextUpdateType.gameEnded, {
      'gameType': _currentGameType,
      'results': gameResults,
    });
    
    _gameState = GameState.waiting;
    _currentGameType = null;
    _gameContext.clear();
  }

  /// Record a game action
  void recordAction(GameActionType actionType, {Map<String, dynamic>? actionData}) {
    validateActive();
    _recordAction(actionType, actionData);
  }

  /// Set game context data
  void setGameContext(String key, dynamic value) {
    validateActive();
    
    _gameContext[key] = value;
    _emitContextUpdate(ContextUpdateType.gameContextChanged, {
      'key': key,
      'value': value,
    });
  }

  /// Get game context data
  T? getGameContext<T>(String key) {
    final value = _gameContext[key];
    return value is T ? value : null;
  }

  /// Set session data
  void setSessionData(String key, dynamic value) {
    validateActive();
    
    _sessionData[key] = value;
    _emitContextUpdate(ContextUpdateType.sessionDataChanged, {
      'key': key,
      'value': value,
    });
  }

  /// Get session data
  T? getSessionData<T>(String key) {
    final value = _sessionData[key];
    return value is T ? value : null;
  }

  /// Set user preference
  void setPreference(String key, dynamic value) {
    validateActive();
    
    _preferences[key] = value;
    _emitContextUpdate(ContextUpdateType.preferencesChanged, {
      'key': key,
      'value': value,
    });
  }

  /// Get user preference
  T? getPreference<T>(String key) {
    final value = _preferences[key];
    return value is T ? value : null;
  }

  /// Get action history filtered by type
  List<GameAction> getActionHistory({GameActionType? filterType}) {
    if (filterType == null) {
      return List.unmodifiable(_actionHistory);
    }
    return _actionHistory.where((action) => action.type == filterType).toList();
  }

  /// Get session summary
  SessionSummary getSessionSummary() {
    return SessionSummary(
      sessionId: _sessionId,
      sessionState: _sessionState,
      gameState: _gameState,
      currentGameType: _currentGameType,
      sessionDuration: sessionDuration,
      actionCount: _actionHistory.length,
      sessionStartTime: _sessionStartTime,
      gameContext: Map.unmodifiable(_gameContext),
      sessionData: Map.unmodifiable(_sessionData),
      preferences: Map.unmodifiable(_preferences),
    );
  }

  /// Export session data as JSON
  String exportSessionData() {
    final data = {
      'sessionId': _sessionId,
      'sessionState': _sessionState.name,
      'gameState': _gameState.name,
      'currentGameType': _currentGameType,
      'sessionData': _sessionData,
      'gameContext': _gameContext,
      'preferences': _preferences,
      'actionHistory': _actionHistory.map((action) => action.toJson()).toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
    
    return jsonEncode(data);
  }

  void _recordAction(GameActionType actionType, Map<String, dynamic>? actionData) {
    final action = GameAction(
      id: _generateActionId(),
      type: actionType,
      timestamp: DateTime.now(),
      sessionId: _sessionId,
      gameType: _currentGameType,
      data: actionData ?? {},
    );
    
    _actionHistory.add(action);
    
    if (!_actionHistoryController.isClosed) {
      _actionHistoryController.add(action);
    }
  }

  void _emitContextUpdate(ContextUpdateType type, Map<String, dynamic> data) {
    if (!_contextUpdateController.isClosed) {
      _contextUpdateController.add(ContextUpdate(
        type: type,
        data: data,
        timestamp: DateTime.now(),
        agentId: agentId,
        sessionId: _sessionId,
      ));
    }
  }

  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${hashCode.abs()}';
  }

  String _generateActionId() {
    return 'action_${DateTime.now().millisecondsSinceEpoch}_${_actionHistory.length}';
  }
}

/// Session states
enum SessionState {
  idle,
  active,
  paused,
  ending,
}

/// Game states
enum GameState {
  waiting,
  playing,
  paused,
  completed,
}

/// Types of context updates
enum ContextUpdateType {
  sessionStarted,
  sessionEnded,
  sessionDataChanged,
  gameStarted,
  gameEnded,
  gameContextChanged,
  preferencesChanged,
}

/// Types of game actions
enum GameActionType {
  gameStarted,
  gameEnded,
  betPlaced,
  spinExecuted,
  winProcessed,
  bonusTriggered,
  settingsChanged,
  pauseRequested,
  resumeRequested,
  custom,
}

/// Context update event
class ContextUpdate {
  final ContextUpdateType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String agentId;
  final String? sessionId;

  const ContextUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.agentId,
    this.sessionId,
  });

  @override
  String toString() {
    return 'ContextUpdate(type: $type, sessionId: $sessionId, timestamp: $timestamp)';
  }
}

/// Game action record
class GameAction {
  final String id;
  final GameActionType type;
  final DateTime timestamp;
  final String? sessionId;
  final String? gameType;
  final Map<String, dynamic> data;

  const GameAction({
    required this.id,
    required this.type,
    required this.timestamp,
    this.sessionId,
    this.gameType,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'gameType': gameType,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'GameAction(id: $id, type: $type, gameType: $gameType, timestamp: $timestamp)';
  }
}

/// Session summary
class SessionSummary {
  final String? sessionId;
  final SessionState sessionState;
  final GameState gameState;
  final String? currentGameType;
  final Duration? sessionDuration;
  final int actionCount;
  final DateTime? sessionStartTime;
  final Map<String, dynamic> gameContext;
  final Map<String, dynamic> sessionData;
  final Map<String, dynamic> preferences;

  const SessionSummary({
    this.sessionId,
    required this.sessionState,
    required this.gameState,
    this.currentGameType,
    this.sessionDuration,
    required this.actionCount,
    this.sessionStartTime,
    required this.gameContext,
    required this.sessionData,
    required this.preferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionState': sessionState.name,
      'gameState': gameState.name,
      'currentGameType': currentGameType,
      'sessionDuration': sessionDuration?.inMilliseconds,
      'actionCount': actionCount,
      'sessionStartTime': sessionStartTime?.toIso8601String(),
      'gameContext': gameContext,
      'sessionData': sessionData,
      'preferences': preferences,
    };
  }

  @override
  String toString() {
    return 'SessionSummary(sessionId: $sessionId, state: $sessionState, '
           'duration: $sessionDuration, actions: $actionCount)';
  }
}