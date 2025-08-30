import 'dart:async';
import 'agents.dart';

/// Orchestrator that coordinates all agents in the casino system
/// 
/// This class demonstrates how to properly initialize, coordinate, and manage
/// the lifecycle of all agents in the system. It provides a high-level interface
/// for the application to interact with the agent-based architecture.
class CasinoOrchestrator {
  // Agent instances
  late final ResourceManagerAgent _resourceManager;
  late final ContextManagerAgent _contextManager;
  late final ConfigManagerAgent _configManager;
  late final ReportGeneratorAgent _reportGenerator;
  late final GameEngineAgent _gameEngine;

  // Orchestrator state
  bool _isInitialized = false;
  final List<StreamSubscription> _subscriptions = [];

  /// Public getters for agents (read-only access)
  ResourceManagerAgent get resourceManager => _resourceManager;
  ContextManagerAgent get contextManager => _contextManager;
  ConfigManagerAgent get configManager => _configManager;
  ReportGeneratorAgent get reportGenerator => _reportGenerator;
  GameEngineAgent get gameEngine => _gameEngine;

  /// Check if orchestrator is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Initialize all agents and set up coordination
  Future<void> initialize() async {
    if (_isInitialized) {
      throw Exception('Orchestrator already initialized');
    }

    try {
      // Initialize all agents
      _resourceManager = ResourceManagerAgent();
      _contextManager = ContextManagerAgent();
      _configManager = ConfigManagerAgent();
      _reportGenerator = ReportGeneratorAgent();
      _gameEngine = GameEngineAgent();

      // Initialize agents in dependency order
      await _configManager.initialize();
      await _resourceManager.initialize();
      await _contextManager.initialize();
      await _reportGenerator.initialize();
      await _gameEngine.initialize();

      // Set up agent coordination
      await _setupAgentCoordination();

      _isInitialized = true;
    } catch (error) {
      // Clean up on initialization failure
      await _cleanup();
      rethrow;
    }
  }

  /// Dispose of all agents and clean up resources
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    await _cleanup();
    _isInitialized = false;
  }

  /// Start a new gaming session
  Future<CasinoSession> startSession({
    String? playerId,
    String? playerName,
    double? initialCredits,
  }) async {
    _validateInitialized();

    // Load or create player profile
    String profileId;
    if (playerId != null) {
      final loaded = await _configManager.loadPlayerProfile(playerId);
      if (!loaded) {
        throw AgentException('Player profile not found: $playerId');
      }
      profileId = playerId;
    } else {
      profileId = await _configManager.createPlayerProfile(
        displayName: playerName ?? 'Guest Player',
      );
      await _configManager.loadPlayerProfile(profileId);
    }

    // Set initial credits if provided
    if (initialCredits != null) {
      _resourceManager.setInitialCredits(initialCredits);
    }

    // Start context session
    final sessionId = await _contextManager.startSession(
      userId: profileId,
      initialData: {
        'playerName': playerName ?? 'Guest Player',
        'startCredits': _resourceManager.credits,
      },
    );

    return CasinoSession(
      sessionId: sessionId,
      profileId: profileId,
      orchestrator: this,
    );
  }

  /// Play a game round
  Future<GameRoundResult> playRound({
    required String gameType,
    required double betAmount,
    Map<String, dynamic>? gameParameters,
  }) async {
    _validateInitialized();

    // Validate bet amount
    if (!_resourceManager.setBet(betAmount)) {
      throw AgentException('Invalid bet amount: $betAmount');
    }

    // Place bet
    if (!_resourceManager.placeBet()) {
      throw AgentException('Insufficient credits for bet');
    }

    // Record game start
    _contextManager.startGame(gameType, gameConfig: gameParameters);

    try {
      // Create and execute game
      final gameId = await _gameEngine.createGame(
        _getGameTemplateId(gameType),
        betAmount: betAmount,
        gameConfig: gameParameters,
      );

      await _gameEngine.startGame(gameId);
      final gameResult = await _gameEngine.executeRound(gameId, roundParameters: gameParameters);

      // Process winnings if any
      if (gameResult.winAmount > 0) {
        _resourceManager.processWinnings(gameResult.winAmount);
      }

      // Record game completion
      _contextManager.endGame(gameResults: {
        'winAmount': gameResult.winAmount,
        'multiplier': gameResult.multiplier,
        'isWin': gameResult.isWin,
      });

      // End game instance
      await _gameEngine.endGame(gameId);

      // Record action
      _contextManager.recordAction(
        gameResult.isWin ? GameActionType.winProcessed : GameActionType.spinExecuted,
        actionData: gameResult.toJson(),
      );

      return GameRoundResult(
        gameResult: gameResult,
        newBalance: _resourceManager.credits,
        sessionStats: _contextManager.getSessionSummary(),
      );
    } catch (error) {
      // End game on error
      _contextManager.endGame(gameResults: {'error': error.toString()});
      rethrow;
    }
  }

  /// Generate a comprehensive session report
  Future<String> generateSessionReport({
    DateTime? startDate,
    DateTime? endDate,
    String templateId = 'session_summary',
  }) async {
    _validateInitialized();

    // Add current session data to report generator
    if (_contextManager.sessionId != null) {
      final sessionSummary = _contextManager.getSessionSummary();
      final resourceSummary = _resourceManager.getResourceSummary();

      final gameSession = GameSession(
        sessionId: sessionSummary.sessionId!,
        gameType: sessionSummary.currentGameType ?? 'mixed',
        startTime: sessionSummary.sessionStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        gamesPlayed: sessionSummary.actionCount,
        totalBets: resourceSummary.totalLosses, // Represents total amount bet
        totalWinnings: resourceSummary.totalWinnings,
        netResult: resourceSummary.netProfit,
        largestWin: 0.0, // Would need to track this separately
        largestLoss: 0.0, // Would need to track this separately
      );

      _reportGenerator.addGameSession(gameSession);
    }

    final reportId = await _reportGenerator.generateReport(
      templateId,
      startDate: startDate,
      endDate: endDate,
    );

    return _reportGenerator.exportReportAsJson(reportId);
  }

  /// Get real-time casino statistics
  CasinoStatistics getRealTimeStatistics() {
    _validateInitialized();

    return CasinoStatistics(
      resourceSummary: _resourceManager.getResourceSummary(),
      sessionSummary: _contextManager.getSessionSummary(),
      reportStats: _reportGenerator.getRealTimeStatistics(),
      fairnessMetrics: _gameEngine.getFairnessMetrics(),
    );
  }

  /// Set up coordination between agents
  Future<void> _setupAgentCoordination() async {
    // Resource manager updates → Context manager
    _subscriptions.add(
      _resourceManager.resourceUpdates.listen((update) {
        _contextManager.setSessionData('lastResourceUpdate', update.toJson());
      }),
    );

    // Context manager updates → Report generator
    _subscriptions.add(
      _contextManager.contextUpdates.listen((update) {
        if (update.type == ContextUpdateType.gameEnded) {
          // Could trigger automatic report updates here
        }
      }),
    );

    // Game engine updates → Context manager
    _subscriptions.add(
      _gameEngine.gameUpdates.listen((update) {
        if (update.type == GameEngineUpdateType.roundExecuted) {
          _contextManager.setGameContext('lastGameUpdate', update.toJson());
        }
      }),
    );

    // Configuration updates → All agents
    _subscriptions.add(
      _configManager.configUpdates.listen((update) {
        if (update.type == ConfigUpdateType.globalSettingChanged) {
          // Propagate configuration changes to other agents as needed
        }
      }),
    );
  }

  String _getGameTemplateId(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'slots':
      case 'slot':
        return 'classic_slots';
      case 'roulette':
        return 'european_roulette';
      case 'blackjack':
        return 'blackjack_classic';
      default:
        return 'classic_slots'; // Default fallback
    }
  }

  void _validateInitialized() {
    if (!_isInitialized) {
      throw Exception('Orchestrator not initialized');
    }
  }

  Future<void> _cleanup() async {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Dispose agents in reverse order of initialization
    final agents = [
      _gameEngine,
      _reportGenerator,
      _contextManager,
      _resourceManager,
      _configManager,
    ];

    for (final agent in agents) {
      try {
        if (agent.isActive) {
          await agent.dispose();
        }
      } catch (error) {
        // Log error but continue cleanup
        print('Error disposing agent ${agent.agentType}: $error');
      }
    }
  }
}

/// Represents an active casino session
class CasinoSession {
  final String sessionId;
  final String profileId;
  final CasinoOrchestrator orchestrator;

  const CasinoSession({
    required this.sessionId,
    required this.profileId,
    required this.orchestrator,
  });

  /// End the current session
  Future<void> endSession() async {
    await orchestrator.contextManager.endSession();
  }

  /// Get current session statistics
  CasinoStatistics getStatistics() {
    return orchestrator.getRealTimeStatistics();
  }
}

/// Result of a game round
class GameRoundResult {
  final GameResult gameResult;
  final double newBalance;
  final SessionSummary sessionStats;

  const GameRoundResult({
    required this.gameResult,
    required this.newBalance,
    required this.sessionStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameResult': gameResult.toJson(),
      'newBalance': newBalance,
      'sessionStats': sessionStats.toJson(),
    };
  }
}

/// Comprehensive casino statistics
class CasinoStatistics {
  final ResourceSummary resourceSummary;
  final SessionSummary sessionSummary;
  final Map<String, dynamic> reportStats;
  final Map<String, FairnessMetrics> fairnessMetrics;

  const CasinoStatistics({
    required this.resourceSummary,
    required this.sessionSummary,
    required this.reportStats,
    required this.fairnessMetrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'resources': resourceSummary.toJson(),
      'session': sessionSummary.toJson(),
      'statistics': reportStats,
      'fairness': fairnessMetrics.map((k, v) => MapEntry(k, v.toJson())),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Extension methods for easy JSON serialization
extension ResourceUpdateJson on ResourceUpdate {
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'agentId': agentId,
    };
  }
}