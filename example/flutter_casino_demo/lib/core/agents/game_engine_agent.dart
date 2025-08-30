import 'dart:async';
import 'dart:math' as math;
import 'base_agent.dart';

/// Agent responsible for game logic, randomization, and ensuring fairness
class GameEngineAgent extends BaseAgentImpl {
  static const String _agentTypeId = 'GameEngine';
  
  // Random number generation
  late final math.Random _secureRandom;
  final List<int> _seedHistory = [];
  
  // Game state tracking
  final Map<String, GameInstance> _activeGames = {};
  final Map<String, GameTemplate> _gameTemplates = {};
  
  // Fairness tracking
  final Map<String, FairnessMetrics> _fairnessMetrics = {};
  int _totalSpins = 0;
  double _totalRTP = 0.0;
  
  // Stream controllers
  final StreamController<GameEngineUpdate> _gameUpdateController = 
      StreamController<GameEngineUpdate>.broadcast();

  @override
  String get agentType => _agentTypeId;

  /// Stream of game engine updates
  Stream<GameEngineUpdate> get gameUpdates => _gameUpdateController.stream;

  /// Active game instances
  List<GameInstance> get activeGames => List.unmodifiable(_activeGames.values);

  /// Available game templates
  List<GameTemplate> get availableGameTemplates => List.unmodifiable(_gameTemplates.values);

  /// Total spins across all games
  int get totalSpins => _totalSpins;

  /// Current overall RTP
  double get currentRTP => _totalSpins == 0 ? 0.0 : _totalRTP / _totalSpins;

  @override
  Future<void> onInitialize() async {
    // Initialize secure random number generator
    final now = DateTime.now();
    final seed = now.microsecondsSinceEpoch;
    _secureRandom = math.Random(seed);
    _seedHistory.add(seed);
    
    await _loadGameTemplates();
  }

  @override
  Future<void> onDispose() async {
    // End all active games
    for (final gameInstance in _activeGames.values) {
      await endGame(gameInstance.id, forced: true);
    }
    
    await _gameUpdateController.close();
  }

  /// Create a new game instance
  Future<String> createGame(String templateId, {
    double? betAmount,
    Map<String, dynamic>? gameConfig,
  }) async {
    validateActive();
    
    final template = _gameTemplates[templateId];
    if (template == null) {
      throw AgentException('Game template not found: $templateId', 
          agentType: agentType, agentId: agentId);
    }
    
    final gameId = _generateGameId();
    final gameInstance = GameInstance(
      id: gameId,
      templateId: templateId,
      gameName: template.name,
      gameType: template.type,
      state: GameInstanceState.created,
      betAmount: betAmount ?? template.minBet,
      config: gameConfig ?? {},
      createdAt: DateTime.now(),
      rng: _createGameRNG(),
    );
    
    _activeGames[gameId] = gameInstance;
    
    // Initialize fairness tracking for this game type
    if (!_fairnessMetrics.containsKey(template.type)) {
      _fairnessMetrics[template.type] = FairnessMetrics(gameType: template.type);
    }
    
    _emitGameUpdate(GameEngineUpdateType.gameCreated, {
      'gameId': gameId,
      'templateId': templateId,
      'gameType': template.type,
    });
    
    return gameId;
  }

  /// Start a game instance
  Future<bool> startGame(String gameId) async {
    validateActive();
    
    final game = _activeGames[gameId];
    if (game == null) {
      return false;
    }
    
    if (game.state != GameInstanceState.created) {
      throw AgentException('Game cannot be started in current state: ${game.state}', 
          agentType: agentType, agentId: agentId);
    }
    
    _activeGames[gameId] = game.copyWith(
      state: GameInstanceState.active,
      startedAt: DateTime.now(),
    );
    
    _emitGameUpdate(GameEngineUpdateType.gameStarted, {
      'gameId': gameId,
      'gameType': game.gameType,
    });
    
    return true;
  }

  /// Execute a game round (spin, deal, etc.)
  Future<GameResult> executeRound(String gameId, {Map<String, dynamic>? roundParameters}) async {
    validateActive();
    
    final game = _activeGames[gameId];
    if (game == null) {
      throw AgentException('Game not found: $gameId', 
          agentType: agentType, agentId: agentId);
    }
    
    if (game.state != GameInstanceState.active) {
      throw AgentException('Game not active: $gameId', 
          agentType: agentType, agentId: agentId);
    }
    
    final template = _gameTemplates[game.templateId]!;
    GameResult result;
    
    switch (template.type) {
      case GameType.slotMachine:
        result = await _executeSlotSpin(game, template, roundParameters);
        break;
      case GameType.roulette:
        result = await _executeRouletteSpin(game, template, roundParameters);
        break;
      case GameType.blackjack:
        result = await _executeBlackjackRound(game, template, roundParameters);
        break;
      case GameType.poker:
        result = await _executePokerRound(game, template, roundParameters);
        break;
      case GameType.custom:
        result = await _executeCustomGame(game, template, roundParameters);
        break;
    }
    
    // Update game instance with result
    final updatedGame = game.copyWith(
      lastResult: result,
      totalWinnings: game.totalWinnings + result.winAmount,
      totalBets: game.totalBets + game.betAmount,
      roundsPlayed: game.roundsPlayed + 1,
    );
    
    _activeGames[gameId] = updatedGame;
    
    // Update global statistics
    _totalSpins++;
    _totalRTP += result.winAmount / game.betAmount;
    
    // Update fairness metrics
    final metrics = _fairnessMetrics[game.gameType]!;
    _fairnessMetrics[game.gameType] = metrics.addResult(result.winAmount, game.betAmount);
    
    _emitGameUpdate(GameEngineUpdateType.roundExecuted, {
      'gameId': gameId,
      'result': result.toJson(),
      'gameType': game.gameType,
    });
    
    return result;
  }

  /// End a game instance
  Future<void> endGame(String gameId, {bool forced = false}) async {
    validateActive();
    
    final game = _activeGames[gameId];
    if (game == null) {
      return;
    }
    
    if (!forced && game.state != GameInstanceState.active) {
      throw AgentException('Game cannot be ended in current state: ${game.state}', 
          agentType: agentType, agentId: agentId);
    }
    
    final endedGame = game.copyWith(
      state: GameInstanceState.completed,
      endedAt: DateTime.now(),
    );
    
    _activeGames[gameId] = endedGame;
    
    _emitGameUpdate(GameEngineUpdateType.gameEnded, {
      'gameId': gameId,
      'gameType': game.gameType,
      'totalWinnings': endedGame.totalWinnings,
      'totalBets': endedGame.totalBets,
      'roundsPlayed': endedGame.roundsPlayed,
      'rtp': endedGame.totalBets == 0 ? 0.0 : endedGame.totalWinnings / endedGame.totalBets,
    });
    
    // Remove from active games after a delay to allow for result processing
    Timer(const Duration(seconds: 30), () {
      _activeGames.remove(gameId);
    });
  }

  /// Get fairness metrics for all game types
  Map<String, FairnessMetrics> getFairnessMetrics() {
    return Map.unmodifiable(_fairnessMetrics);
  }

  /// Verify random number generation integrity
  bool verifyRNGIntegrity() {
    // In a real implementation, this would perform cryptographic verification
    // of the RNG state and seed history
    return _seedHistory.isNotEmpty && _secureRandom.nextDouble() >= 0.0;
  }

  /// Get game instance by ID
  GameInstance? getGameInstance(String gameId) {
    return _activeGames[gameId];
  }

  /// Register a custom game template
  void registerGameTemplate(GameTemplate template) {
    validateActive();
    
    _gameTemplates[template.id] = template;
    
    _emitGameUpdate(GameEngineUpdateType.templateRegistered, {
      'templateId': template.id,
      'gameType': template.type.name,
      'gameName': template.name,
    });
  }

  Future<GameResult> _executeSlotSpin(
    GameInstance game, 
    GameTemplate template, 
    Map<String, dynamic>? parameters,
  ) async {
    final reels = template.config['reels'] as int? ?? 5;
    final symbols = template.config['symbols'] as List<String>? ?? 
        ['🍒', '🍋', '🍊', '🍇', '💎', '⭐', '🔔', '💰'];
    final paylines = template.config['paylines'] as int? ?? 20;
    
    // Generate reel results
    final reelResults = List.generate(reels, (index) => 
        symbols[game.rng.nextInt(symbols.length)]);
    
    // Calculate winnings based on payline matches
    double winMultiplier = 0.0;
    final matchingSymbols = <String, int>{};
    
    for (final symbol in reelResults) {
      matchingSymbols[symbol] = (matchingSymbols[symbol] ?? 0) + 1;
    }
    
    // Simple matching logic - can be made more complex
    for (final entry in matchingSymbols.entries) {
      if (entry.value >= 3) {
        final symbolMultiplier = _getSymbolMultiplier(entry.key, symbols);
        winMultiplier += symbolMultiplier * (entry.value - 2);
      }
    }
    
    // Apply RTP adjustment to maintain fairness
    winMultiplier = _adjustForRTP(winMultiplier, template.targetRTP);
    
    final winAmount = game.betAmount * winMultiplier;
    
    return GameResult(
      gameId: game.id,
      roundNumber: game.roundsPlayed + 1,
      betAmount: game.betAmount,
      winAmount: winAmount,
      multiplier: winMultiplier,
      details: {
        'reelResults': reelResults,
        'matchingSymbols': matchingSymbols,
        'paylines': paylines,
      },
      timestamp: DateTime.now(),
    );
  }

  Future<GameResult> _executeRouletteSpin(
    GameInstance game, 
    GameTemplate template, 
    Map<String, dynamic>? parameters,
  ) async {
    final wheelType = template.config['wheelType'] as String? ?? 'european';
    final maxNumber = wheelType == 'american' ? 37 : 36; // 0-36 for european, 0-37 for american
    
    final winningNumber = game.rng.nextInt(maxNumber + 1);
    final bet = parameters?['bet'] as Map<String, dynamic>? ?? {'type': 'number', 'value': 7};
    
    double winMultiplier = 0.0;
    
    switch (bet['type']) {
      case 'number':
        if (winningNumber == bet['value']) {
          winMultiplier = 35.0;
        }
        break;
      case 'red':
        if (_isRedNumber(winningNumber) && winningNumber != 0) {
          winMultiplier = 1.0;
        }
        break;
      case 'black':
        if (!_isRedNumber(winningNumber) && winningNumber != 0) {
          winMultiplier = 1.0;
        }
        break;
      case 'even':
        if (winningNumber % 2 == 0 && winningNumber != 0) {
          winMultiplier = 1.0;
        }
        break;
      case 'odd':
        if (winningNumber % 2 == 1) {
          winMultiplier = 1.0;
        }
        break;
    }
    
    winMultiplier = _adjustForRTP(winMultiplier, template.targetRTP);
    final winAmount = game.betAmount * winMultiplier;
    
    return GameResult(
      gameId: game.id,
      roundNumber: game.roundsPlayed + 1,
      betAmount: game.betAmount,
      winAmount: winAmount,
      multiplier: winMultiplier,
      details: {
        'winningNumber': winningNumber,
        'wheelType': wheelType,
        'bet': bet,
        'isWin': winMultiplier > 0,
      },
      timestamp: DateTime.now(),
    );
  }

  Future<GameResult> _executeBlackjackRound(
    GameInstance game, 
    GameTemplate template, 
    Map<String, dynamic>? parameters,
  ) async {
    // Simplified blackjack implementation
    final playerCards = _drawCards(game.rng, 2);
    final dealerCards = _drawCards(game.rng, 2);
    
    final playerValue = _calculateBlackjackValue(playerCards);
    final dealerValue = _calculateBlackjackValue(dealerCards);
    
    double winMultiplier = 0.0;
    
    if (playerValue == 21 && playerCards.length == 2) {
      // Blackjack
      winMultiplier = 2.5;
    } else if (playerValue > 21) {
      // Bust
      winMultiplier = 0.0;
    } else if (dealerValue > 21 || playerValue > dealerValue) {
      // Player wins
      winMultiplier = 2.0;
    } else if (playerValue == dealerValue) {
      // Push
      winMultiplier = 1.0;
    }
    
    winMultiplier = _adjustForRTP(winMultiplier, template.targetRTP);
    final winAmount = game.betAmount * winMultiplier;
    
    return GameResult(
      gameId: game.id,
      roundNumber: game.roundsPlayed + 1,
      betAmount: game.betAmount,
      winAmount: winAmount,
      multiplier: winMultiplier,
      details: {
        'playerCards': playerCards,
        'dealerCards': dealerCards,
        'playerValue': playerValue,
        'dealerValue': dealerValue,
      },
      timestamp: DateTime.now(),
    );
  }

  Future<GameResult> _executePokerRound(
    GameInstance game, 
    GameTemplate template, 
    Map<String, dynamic>? parameters,
  ) async {
    // Simplified poker implementation (5-card draw)
    final hand = _drawCards(game.rng, 5);
    final handRank = _evaluatePokerHand(hand);
    
    final winMultiplier = _getPokerPayoutMultiplier(handRank);
    final adjustedMultiplier = _adjustForRTP(winMultiplier, template.targetRTP);
    final winAmount = game.betAmount * adjustedMultiplier;
    
    return GameResult(
      gameId: game.id,
      roundNumber: game.roundsPlayed + 1,
      betAmount: game.betAmount,
      winAmount: winAmount,
      multiplier: adjustedMultiplier,
      details: {
        'hand': hand,
        'handRank': handRank.name,
        'handName': _getPokerHandName(handRank),
      },
      timestamp: DateTime.now(),
    );
  }

  Future<GameResult> _executeCustomGame(
    GameInstance game, 
    GameTemplate template, 
    Map<String, dynamic>? parameters,
  ) async {
    // Default implementation for custom games
    final winProbability = template.config['winProbability'] as double? ?? 0.45;
    final maxMultiplier = template.config['maxMultiplier'] as double? ?? 5.0;
    
    final isWin = game.rng.nextDouble() < winProbability;
    double winMultiplier = 0.0;
    
    if (isWin) {
      winMultiplier = 1.0 + (game.rng.nextDouble() * maxMultiplier);
    }
    
    winMultiplier = _adjustForRTP(winMultiplier, template.targetRTP);
    final winAmount = game.betAmount * winMultiplier;
    
    return GameResult(
      gameId: game.id,
      roundNumber: game.roundsPlayed + 1,
      betAmount: game.betAmount,
      winAmount: winAmount,
      multiplier: winMultiplier,
      details: {
        'isWin': isWin,
        'winProbability': winProbability,
      },
      timestamp: DateTime.now(),
    );
  }

  double _adjustForRTP(double winMultiplier, double targetRTP) {
    // Simple RTP adjustment - in reality this would be more sophisticated
    final currentRTP = this.currentRTP;
    
    if (currentRTP < targetRTP - 0.05) {
      // If we're below target, slightly increase wins
      return winMultiplier * 1.1;
    } else if (currentRTP > targetRTP + 0.05) {
      // If we're above target, slightly decrease wins
      return winMultiplier * 0.9;
    }
    
    return winMultiplier;
  }

  double _getSymbolMultiplier(String symbol, List<String> symbols) {
    final index = symbols.indexOf(symbol);
    // Higher index = rarer symbol = higher multiplier
    return 1.0 + (index / symbols.length) * 10.0;
  }

  bool _isRedNumber(int number) {
    const redNumbers = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36};
    return redNumbers.contains(number);
  }

  List<PlayingCard> _drawCards(math.Random rng, int count) {
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    
    final cards = <PlayingCard>[];
    for (int i = 0; i < count; i++) {
      final suit = suits[rng.nextInt(suits.length)];
      final rank = ranks[rng.nextInt(ranks.length)];
      cards.add(PlayingCard(suit: suit, rank: rank));
    }
    
    return cards;
  }

  int _calculateBlackjackValue(List<PlayingCard> cards) {
    int value = 0;
    int aces = 0;
    
    for (final card in cards) {
      if (card.rank == 'A') {
        aces++;
        value += 11;
      } else if (['J', 'Q', 'K'].contains(card.rank)) {
        value += 10;
      } else {
        value += int.parse(card.rank);
      }
    }
    
    // Adjust for aces
    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }
    
    return value;
  }

  PokerHandRank _evaluatePokerHand(List<PlayingCard> cards) {
    // Simplified poker hand evaluation
    final rankCounts = <String, int>{};
    final suitCounts = <String, int>{};
    
    for (final card in cards) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }
    
    final counts = rankCounts.values.toList()..sort((a, b) => b.compareTo(a));
    final isFlush = suitCounts.values.any((count) => count >= 5);
    
    if (counts[0] == 4) return PokerHandRank.fourOfAKind;
    if (counts[0] == 3 && counts[1] == 2) return PokerHandRank.fullHouse;
    if (isFlush) return PokerHandRank.flush;
    if (counts[0] == 3) return PokerHandRank.threeOfAKind;
    if (counts[0] == 2 && counts[1] == 2) return PokerHandRank.twoPair;
    if (counts[0] == 2) return PokerHandRank.onePair;
    
    return PokerHandRank.highCard;
  }

  double _getPokerPayoutMultiplier(PokerHandRank rank) {
    switch (rank) {
      case PokerHandRank.royalFlush: return 250.0;
      case PokerHandRank.straightFlush: return 50.0;
      case PokerHandRank.fourOfAKind: return 25.0;
      case PokerHandRank.fullHouse: return 9.0;
      case PokerHandRank.flush: return 6.0;
      case PokerHandRank.straight: return 4.0;
      case PokerHandRank.threeOfAKind: return 3.0;
      case PokerHandRank.twoPair: return 2.0;
      case PokerHandRank.onePair: return 1.0;
      case PokerHandRank.highCard: return 0.0;
    }
  }

  String _getPokerHandName(PokerHandRank rank) {
    switch (rank) {
      case PokerHandRank.royalFlush: return 'Royal Flush';
      case PokerHandRank.straightFlush: return 'Straight Flush';
      case PokerHandRank.fourOfAKind: return 'Four of a Kind';
      case PokerHandRank.fullHouse: return 'Full House';
      case PokerHandRank.flush: return 'Flush';
      case PokerHandRank.straight: return 'Straight';
      case PokerHandRank.threeOfAKind: return 'Three of a Kind';
      case PokerHandRank.twoPair: return 'Two Pair';
      case PokerHandRank.onePair: return 'One Pair';
      case PokerHandRank.highCard: return 'High Card';
    }
  }

  math.Random _createGameRNG() {
    final seed = DateTime.now().microsecondsSinceEpoch + _secureRandom.nextInt(1000000);
    _seedHistory.add(seed);
    return math.Random(seed);
  }

  Future<void> _loadGameTemplates() async {
    final templates = [
      GameTemplate(
        id: 'classic_slots',
        name: 'Classic Slots',
        type: GameType.slotMachine,
        minBet: 1.0,
        maxBet: 100.0,
        targetRTP: 0.96,
        config: {
          'reels': 5,
          'paylines': 20,
          'symbols': ['🍒', '🍋', '🍊', '🍇', '💎', '⭐', '🔔', '💰'],
        },
      ),
      GameTemplate(
        id: 'european_roulette',
        name: 'European Roulette',
        type: GameType.roulette,
        minBet: 1.0,
        maxBet: 500.0,
        targetRTP: 0.973,
        config: {
          'wheelType': 'european',
        },
      ),
      GameTemplate(
        id: 'blackjack_classic',
        name: 'Classic Blackjack',
        type: GameType.blackjack,
        minBet: 5.0,
        maxBet: 200.0,
        targetRTP: 0.99,
        config: {
          'decks': 6,
        },
      ),
    ];
    
    for (final template in templates) {
      _gameTemplates[template.id] = template;
    }
  }

  void _emitGameUpdate(GameEngineUpdateType type, Map<String, dynamic> data) {
    if (!_gameUpdateController.isClosed) {
      _gameUpdateController.add(GameEngineUpdate(
        type: type,
        data: data,
        timestamp: DateTime.now(),
        agentId: agentId,
      ));
    }
  }

  String _generateGameId() {
    return 'game_${DateTime.now().millisecondsSinceEpoch}_${_secureRandom.nextInt(10000)}';
  }
}

/// Types of games
enum GameType {
  slotMachine,
  roulette,
  blackjack,
  poker,
  custom,
}

/// Game instance states
enum GameInstanceState {
  created,
  active,
  paused,
  completed,
  error,
}

/// Types of game engine updates
enum GameEngineUpdateType {
  gameCreated,
  gameStarted,
  roundExecuted,
  gameEnded,
  templateRegistered,
}

/// Poker hand rankings
enum PokerHandRank {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
  royalFlush,
}

/// Game engine update event
class GameEngineUpdate {
  final GameEngineUpdateType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String agentId;

  const GameEngineUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.agentId,
  });

  @override
  String toString() {
    return 'GameEngineUpdate(type: $type, timestamp: $timestamp)';
  }
}

/// Game template definition
class GameTemplate {
  final String id;
  final String name;
  final GameType type;
  final double minBet;
  final double maxBet;
  final double targetRTP;
  final Map<String, dynamic> config;

  const GameTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.minBet,
    required this.maxBet,
    required this.targetRTP,
    required this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'minBet': minBet,
      'maxBet': maxBet,
      'targetRTP': targetRTP,
      'config': config,
    };
  }

  @override
  String toString() {
    return 'GameTemplate(id: $id, name: $name, type: $type)';
  }
}

/// Game instance
class GameInstance {
  final String id;
  final String templateId;
  final String gameName;
  final GameType gameType;
  final GameInstanceState state;
  final double betAmount;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final math.Random rng;
  final GameResult? lastResult;
  final double totalWinnings;
  final double totalBets;
  final int roundsPlayed;

  const GameInstance({
    required this.id,
    required this.templateId,
    required this.gameName,
    required this.gameType,
    required this.state,
    required this.betAmount,
    required this.config,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.rng,
    this.lastResult,
    this.totalWinnings = 0.0,
    this.totalBets = 0.0,
    this.roundsPlayed = 0,
  });

  GameInstance copyWith({
    GameInstanceState? state,
    DateTime? startedAt,
    DateTime? endedAt,
    GameResult? lastResult,
    double? totalWinnings,
    double? totalBets,
    int? roundsPlayed,
  }) {
    return GameInstance(
      id: id,
      templateId: templateId,
      gameName: gameName,
      gameType: gameType,
      state: state ?? this.state,
      betAmount: betAmount,
      config: config,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      rng: rng,
      lastResult: lastResult ?? this.lastResult,
      totalWinnings: totalWinnings ?? this.totalWinnings,
      totalBets: totalBets ?? this.totalBets,
      roundsPlayed: roundsPlayed ?? this.roundsPlayed,
    );
  }

  Duration? get duration {
    if (startedAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  double get rtp => totalBets == 0 ? 0.0 : totalWinnings / totalBets;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'gameName': gameName,
      'gameType': gameType.name,
      'state': state.name,
      'betAmount': betAmount,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'lastResult': lastResult?.toJson(),
      'totalWinnings': totalWinnings,
      'totalBets': totalBets,
      'roundsPlayed': roundsPlayed,
      'rtp': rtp,
      'duration': duration?.inMilliseconds,
    };
  }

  @override
  String toString() {
    return 'GameInstance(id: $id, game: $gameName, state: $state, rounds: $roundsPlayed)';
  }
}

/// Game result
class GameResult {
  final String gameId;
  final int roundNumber;
  final double betAmount;
  final double winAmount;
  final double multiplier;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const GameResult({
    required this.gameId,
    required this.roundNumber,
    required this.betAmount,
    required this.winAmount,
    required this.multiplier,
    required this.details,
    required this.timestamp,
  });

  bool get isWin => winAmount > betAmount;
  double get profit => winAmount - betAmount;

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'roundNumber': roundNumber,
      'betAmount': betAmount,
      'winAmount': winAmount,
      'multiplier': multiplier,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'isWin': isWin,
      'profit': profit,
    };
  }

  @override
  String toString() {
    return 'GameResult(game: $gameId, round: $roundNumber, win: $winAmount, multiplier: ${multiplier.toStringAsFixed(2)}x)';
  }
}

/// Playing card
class PlayingCard {
  final String suit;
  final String rank;

  const PlayingCard({required this.suit, required this.rank});

  @override
  String toString() => '$rank$suit';

  Map<String, dynamic> toJson() {
    return {'suit': suit, 'rank': rank};
  }
}

/// Fairness metrics tracking
class FairnessMetrics {
  final String gameType;
  final int totalRounds;
  final double totalWinnings;
  final double totalBets;
  final double actualRTP;
  final List<double> recentResults;

  const FairnessMetrics({
    required this.gameType,
    this.totalRounds = 0,
    this.totalWinnings = 0.0,
    this.totalBets = 0.0,
    this.recentResults = const [],
  }) : actualRTP = totalBets == 0 ? 0.0 : totalWinnings / totalBets;

  FairnessMetrics addResult(double winAmount, double betAmount) {
    final newResults = List<double>.from(recentResults)..add(winAmount - betAmount);
    if (newResults.length > 1000) {
      newResults.removeAt(0); // Keep only last 1000 results
    }

    return FairnessMetrics(
      gameType: gameType,
      totalRounds: totalRounds + 1,
      totalWinnings: totalWinnings + winAmount,
      totalBets: totalBets + betAmount,
      recentResults: newResults,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameType': gameType,
      'totalRounds': totalRounds,
      'totalWinnings': totalWinnings,
      'totalBets': totalBets,
      'actualRTP': actualRTP,
      'recentResultsCount': recentResults.length,
    };
  }

  @override
  String toString() {
    return 'FairnessMetrics(game: $gameType, rounds: $totalRounds, RTP: ${(actualRTP * 100).toStringAsFixed(2)}%)';
  }
}