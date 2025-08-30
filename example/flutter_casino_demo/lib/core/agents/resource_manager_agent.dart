import 'dart:async';
import 'base_agent.dart';

/// Agent responsible for managing player resources (credits, bets, winnings)
class ResourceManagerAgent extends BaseAgentImpl {
  static const String _agentTypeId = 'ResourceManager';

  // Current player resources
  double _credits = 0.0;
  double _currentBet = 0.0;
  double _totalWinnings = 0.0;
  double _totalLosses = 0.0;
  int _gamesPlayed = 0;

  // Configuration
  double _minimumBet = 1.0;
  double _maximumBet = 100.0;
  double _initialCredits = 1000.0;

  // Stream controllers for real-time updates
  final StreamController<ResourceUpdate> _resourceUpdateController =
      StreamController<ResourceUpdate>.broadcast();

  @override
  String get agentType => _agentTypeId;

  /// Stream of resource updates for real-time UI updates
  Stream<ResourceUpdate> get resourceUpdates =>
      _resourceUpdateController.stream;

  /// Current player credits
  double get credits => _credits;

  /// Current bet amount
  double get currentBet => _currentBet;

  /// Total winnings across all games
  double get totalWinnings => _totalWinnings;

  /// Total losses across all games
  double get totalLosses => _totalLosses;

  /// Number of games played
  int get gamesPlayed => _gamesPlayed;

  /// Minimum allowed bet
  double get minimumBet => _minimumBet;

  /// Maximum allowed bet
  double get maximumBet => _maximumBet;

  /// Win/loss ratio
  double get winLossRatio =>
      _totalLosses == 0 ? _totalWinnings : _totalWinnings / _totalLosses;

  /// Net profit/loss
  double get netProfit => _totalWinnings - _totalLosses;

  @override
  Future<void> onInitialize() async {
    _credits = _initialCredits;
    _emitUpdate(ResourceUpdateType.creditsChanged, _credits);
  }

  @override
  Future<void> onDispose() async {
    await _resourceUpdateController.close();
  }

  /// Set initial credits (only during initialization)
  void setInitialCredits(double credits) {
    if (credits < 0) {
      throw AgentException('Initial credits cannot be negative',
          agentType: agentType, agentId: agentId);
    }
    _initialCredits = credits;
    if (status == AgentStatus.active) {
      _credits = credits;
      _emitUpdate(ResourceUpdateType.creditsChanged, _credits);
    }
  }

  /// Set betting limits
  void setBettingLimits({double? minimum, double? maximum}) {
    validateActive();

    if (minimum != null && minimum <= 0) {
      throw AgentException('Minimum bet must be positive',
          agentType: agentType, agentId: agentId);
    }

    if (maximum != null && maximum <= 0) {
      throw AgentException('Maximum bet must be positive',
          agentType: agentType, agentId: agentId);
    }

    if (minimum != null && maximum != null && minimum > maximum) {
      throw AgentException('Minimum bet cannot exceed maximum bet',
          agentType: agentType, agentId: agentId);
    }

    if (minimum != null) _minimumBet = minimum;
    if (maximum != null) _maximumBet = maximum;

    _emitUpdate(ResourceUpdateType.limitsChanged, {
      'minimum': _minimumBet,
      'maximum': _maximumBet,
    });
  }

  /// Validate and set current bet amount
  bool setBet(double amount) {
    validateActive();

    if (amount < _minimumBet || amount > _maximumBet) {
      return false; // Bet outside allowed range
    }

    if (amount > _credits) {
      return false; // Insufficient credits
    }

    _currentBet = amount;
    _emitUpdate(ResourceUpdateType.betChanged, amount);
    return true;
  }

  /// Process a bet and deduct from credits
  bool placeBet() {
    validateActive();

    if (_currentBet == 0) {
      throw AgentException('No bet amount set',
          agentType: agentType, agentId: agentId);
    }

    if (_currentBet > _credits) {
      return false; // Insufficient credits
    }

    _credits -= _currentBet;
    _totalLosses += _currentBet; // Track as potential loss
    _gamesPlayed++;

    _emitUpdate(ResourceUpdateType.betPlaced, {
      'betAmount': _currentBet,
      'remainingCredits': _credits,
      'gamesPlayed': _gamesPlayed,
    });

    return true;
  }

  /// Process winnings and add to credits
  void processWinnings(double winAmount) {
    validateActive();

    if (winAmount < 0) {
      throw AgentException('Win amount cannot be negative',
          agentType: agentType, agentId: agentId);
    }

    _credits += winAmount;

    // Adjust accounting: remove the bet from losses and add net win to winnings
    _totalLosses -= _currentBet;
    _totalWinnings += winAmount;

    _emitUpdate(ResourceUpdateType.winningsProcessed, {
      'winAmount': winAmount,
      'totalWinnings': _totalWinnings,
      'credits': _credits,
      'netProfit': netProfit,
    });

    _currentBet = 0.0; // Reset bet after processing
  }

  /// Add credits to player account (bonus, purchase, etc.)
  void addCredits(double amount, {String reason = 'Credit addition'}) {
    validateActive();

    if (amount <= 0) {
      throw AgentException('Credit amount must be positive',
          agentType: agentType, agentId: agentId);
    }

    _credits += amount;

    _emitUpdate(ResourceUpdateType.creditsAdded, {
      'amount': amount,
      'credits': _credits,
      'reason': reason,
    });
  }

  /// Check if player can afford a specific bet
  bool canAffordBet(double betAmount) {
    return betAmount >= _minimumBet &&
        betAmount <= _maximumBet &&
        betAmount <= _credits;
  }

  /// Check if player is eligible to play (has enough credits for minimum bet)
  bool canPlay() {
    return _credits >= _minimumBet;
  }

  /// Get suggested bet amount based on current credits
  double getSuggestedBet() {
    final affordableBets = [
      _minimumBet,
      _credits * 0.01, // 1% of credits
      _credits * 0.05, // 5% of credits
      _credits * 0.10, // 10% of credits
    ];

    // Find the largest affordable bet that doesn't exceed maximum
    double suggested = _minimumBet;
    for (final bet in affordableBets) {
      if (bet <= _credits && bet <= _maximumBet && bet >= _minimumBet) {
        suggested = bet;
      }
    }

    return suggested;
  }

  /// Reset all statistics while keeping current credits
  void resetStatistics() {
    validateActive();

    _totalWinnings = 0.0;
    _totalLosses = 0.0;
    _gamesPlayed = 0;

    _emitUpdate(ResourceUpdateType.statisticsReset, {
      'credits': _credits,
    });
  }

  /// Get comprehensive resource summary
  ResourceSummary getResourceSummary() {
    return ResourceSummary(
      credits: _credits,
      currentBet: _currentBet,
      totalWinnings: _totalWinnings,
      totalLosses: _totalLosses,
      gamesPlayed: _gamesPlayed,
      minimumBet: _minimumBet,
      maximumBet: _maximumBet,
      winLossRatio: winLossRatio,
      netProfit: netProfit,
      canPlay: canPlay(),
    );
  }

  void _emitUpdate(ResourceUpdateType type, dynamic data) {
    if (!_resourceUpdateController.isClosed) {
      _resourceUpdateController.add(ResourceUpdate(
        type: type,
        data: data,
        timestamp: DateTime.now(),
        agentId: agentId,
      ));
    }
  }
}

/// Types of resource updates that can be emitted
enum ResourceUpdateType {
  creditsChanged,
  betChanged,
  betPlaced,
  winningsProcessed,
  creditsAdded,
  limitsChanged,
  statisticsReset,
}

/// Resource update event
class ResourceUpdate {
  final ResourceUpdateType type;
  final dynamic data;
  final DateTime timestamp;
  final String agentId;

  const ResourceUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.agentId,
  });

  @override
  String toString() {
    return 'ResourceUpdate(type: $type, data: $data, timestamp: $timestamp)';
  }
}

/// Comprehensive resource summary
class ResourceSummary {
  final double credits;
  final double currentBet;
  final double totalWinnings;
  final double totalLosses;
  final int gamesPlayed;
  final double minimumBet;
  final double maximumBet;
  final double winLossRatio;
  final double netProfit;
  final bool canPlay;

  const ResourceSummary({
    required this.credits,
    required this.currentBet,
    required this.totalWinnings,
    required this.totalLosses,
    required this.gamesPlayed,
    required this.minimumBet,
    required this.maximumBet,
    required this.winLossRatio,
    required this.netProfit,
    required this.canPlay,
  });

  Map<String, dynamic> toJson() {
    return {
      'credits': credits,
      'currentBet': currentBet,
      'totalWinnings': totalWinnings,
      'totalLosses': totalLosses,
      'gamesPlayed': gamesPlayed,
      'minimumBet': minimumBet,
      'maximumBet': maximumBet,
      'winLossRatio': winLossRatio,
      'netProfit': netProfit,
      'canPlay': canPlay,
    };
  }

  @override
  String toString() {
    return 'ResourceSummary(credits: $credits, currentBet: $currentBet, '
        'games: $gamesPlayed, netProfit: $netProfit)';
  }
}
