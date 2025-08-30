import 'dart:math';
import '../../core/agents/agents.dart';

/// Slot machine symbols with values and rarities
enum SlotSymbol {
  cherry('🍒', 2, 40),
  lemon('🍋', 3, 35),
  orange('🍊', 4, 30),
  plum('🍇', 5, 25),
  bell('🔔', 8, 15),
  bar('💰', 10, 12),
  seven('7️⃣', 15, 8),
  diamond('💎', 25, 5),
  crown('👑', 50, 3),
  jackpot('🎰', 100, 2);

  const SlotSymbol(this.emoji, this.multiplier, this.weight);

  final String emoji;
  final int multiplier;
  final int weight; // Higher weight = more common
}

/// Payline configuration for slot machine
class PayLine {
  final List<int> positions;
  final String name;

  const PayLine(this.positions, this.name);
}

/// Standard 5-reel, 3-row paylines
class StandardPayLines {
  static const List<PayLine> paylines = [
    // Horizontal lines
    PayLine([0, 1, 2, 3, 4], 'Top'),
    PayLine([5, 6, 7, 8, 9], 'Middle'),
    PayLine([10, 11, 12, 13, 14], 'Bottom'),

    // Diagonal lines
    PayLine([0, 6, 12, 8, 4], 'Diagonal Down'),
    PayLine([10, 6, 2, 8, 14], 'Diagonal Up'),

    // V and ^ patterns
    PayLine([0, 6, 7, 8, 4], 'V-Shape'),
    PayLine([10, 6, 7, 8, 14], '^-Shape'),

    // Zigzag patterns
    PayLine([5, 1, 7, 13, 9], 'Zigzag 1'),
    PayLine([5, 11, 7, 3, 9], 'Zigzag 2'),

    // W and M patterns
    PayLine([0, 11, 2, 13, 4], 'W-Pattern'),
    PayLine([10, 1, 12, 3, 14], 'M-Pattern'),
  ];
}

/// Result of a single slot machine spin
class SpinResult {
  final List<List<SlotSymbol>> reels;
  final List<WinLine> winLines;
  final int totalWin;
  final bool isJackpot;
  final bool isBigWin;
  final bool isFreeSpin;

  const SpinResult({
    required this.reels,
    required this.winLines,
    required this.totalWin,
    this.isJackpot = false,
    this.isBigWin = false,
    this.isFreeSpin = false,
  });

  bool get hasWin => totalWin > 0;

  double getWinMultiplier(int bet) => bet > 0 ? totalWin / bet : 0;
}

/// A winning line with symbols and payout
class WinLine {
  final PayLine payLine;
  final SlotSymbol symbol;
  final int count;
  final int payout;
  final List<int> positions;

  const WinLine({
    required this.payLine,
    required this.symbol,
    required this.count,
    required this.payout,
    required this.positions,
  });
}

/// Slot machine configuration
class SlotConfig {
  final int reelCount;
  final int rowCount;
  final List<PayLine> paylines;
  final double rtp; // Return to Player percentage
  final int minBet;
  final int maxBet;
  final Map<SlotSymbol, List<int>> reelStrips; // Symbol distribution per reel

  const SlotConfig({
    this.reelCount = 5,
    this.rowCount = 3,
    this.paylines = StandardPayLines.paylines,
    this.rtp = 0.96,
    this.minBet = 1,
    this.maxBet = 1000,
    required this.reelStrips,
  });

  /// Default classic slot configuration
  static SlotConfig get classic => SlotConfig(
        reelStrips: _generateClassicReelStrips(),
      );

  /// High volatility slot configuration
  static SlotConfig get highVolatility => SlotConfig(
        rtp: 0.94,
        reelStrips: _generateHighVolatilityReelStrips(),
      );

  /// Generate balanced reel strips for classic slots
  static Map<SlotSymbol, List<int>> _generateClassicReelStrips() {
    final Map<SlotSymbol, List<int>> strips = {};

    for (final symbol in SlotSymbol.values) {
      strips[symbol] = List.generate(5, (reelIndex) {
        // Adjust symbol frequency based on reel position
        final baseWeight = symbol.weight;
        final adjustedWeight = reelIndex == 2
            ? (baseWeight * 0.8)
                .round() // Middle reel has slightly lower frequency
            : baseWeight;
        return adjustedWeight;
      });
    }

    return strips;
  }

  /// Generate reel strips for high volatility slots
  static Map<SlotSymbol, List<int>> _generateHighVolatilityReelStrips() {
    final Map<SlotSymbol, List<int>> strips = {};

    for (final symbol in SlotSymbol.values) {
      strips[symbol] = List.generate(5, (reelIndex) {
        final baseWeight = symbol.weight;
        // Reduce high-value symbol frequency for higher volatility
        final adjustedWeight =
            symbol.multiplier > 10 ? (baseWeight * 0.6).round() : baseWeight;
        return adjustedWeight;
      });
    }

    return strips;
  }
}

/// Core slot machine engine with game logic
class SlotsEngine {
  final SlotConfig config;
  final GameEngineAgent _gameEngine;
  final Random _random;

  // Game state
  int _balance = 0;
  int _currentBet = 10;
  int _totalSpins = 0;
  int _totalWins = 0;
  double _totalWagered = 0;
  double _totalWon = 0;
  List<SpinResult> _history = [];

  // Demo mode state
  bool _isDemoMode = true;
  bool _isAutoPlay = false;
  int _autoPlaySpins = 0;
  int _autoPlayRemaining = 0;

  SlotsEngine({
    required this.config,
    required GameEngineAgent gameEngine,
    int? seed,
  })  : _gameEngine = gameEngine,
        _random = Random(seed);

  // Getters
  int get balance => _balance;
  int get currentBet => _currentBet;
  int get totalSpins => _totalSpins;
  int get totalWins => _totalWins;
  double get totalWagered => _totalWagered;
  double get totalWon => _totalWon;
  double get winRate => _totalSpins > 0 ? (_totalWins / _totalSpins) * 100 : 0;
  double get actualRtp =>
      _totalWagered > 0 ? (_totalWon / _totalWagered) * 100 : 0;
  List<SpinResult> get history => List.unmodifiable(_history);
  bool get isDemoMode => _isDemoMode;
  bool get isAutoPlay => _isAutoPlay;
  int get autoPlayRemaining => _autoPlayRemaining;

  /// Initialize the engine with starting balance
  void initialize(int startingBalance, {bool demoMode = false}) {
    _balance = startingBalance;
    _isDemoMode = demoMode;
    _currentBet = config.minBet.clamp(config.minBet, _balance);
  }

  /// Set bet amount
  bool setBet(int amount) {
    if (amount < config.minBet || amount > config.maxBet) return false;
    if (!_isDemoMode && amount > _balance) return false;

    _currentBet = amount;
    return true;
  }

  /// Check if a spin is possible
  bool canSpin() {
    if (_isDemoMode) return true;
    return _balance >= _currentBet;
  }

  /// Perform a single spin
  Future<SpinResult> spin() async {
    if (!canSpin()) {
      throw Exception('Insufficient balance for spin');
    }

    // Deduct bet (except in demo mode)
    if (!_isDemoMode) {
      _balance -= _currentBet;
    }

    // Generate random reel results
    final reels = _generateReels();

    // Calculate wins
    final winLines = _calculateWins(reels);
    final totalWin = winLines.fold(0, (sum, line) => sum + line.payout);

    // Determine special wins
    final isJackpot = _isJackpotWin(winLines);
    final isBigWin = _isBigWin(totalWin);

    // Add winnings (including demo mode for consistency)
    if (totalWin > 0) {
      _balance += totalWin;
      _totalWins++;
    }

    // Update statistics
    _totalSpins++;
    _totalWagered += _currentBet;
    _totalWon += totalWin;

    final result = SpinResult(
      reels: reels,
      winLines: winLines,
      totalWin: totalWin,
      isJackpot: isJackpot,
      isBigWin: isBigWin,
    );

    // Add to history (keep last 100 spins)
    _history.add(result);
    if (_history.length > 100) {
      _history = _history.skip(_history.length - 100).toList();
    }

    // Handle auto play
    if (_isAutoPlay && _autoPlayRemaining > 0) {
      _autoPlayRemaining--;
      if (_autoPlayRemaining == 0) {
        stopAutoPlay();
      }
    }

    return result;
  }

  /// Start auto play mode
  void startAutoPlay(int spins) {
    if (spins <= 0) return;

    _isAutoPlay = true;
    _autoPlaySpins = spins;
    _autoPlayRemaining = spins;
  }

  /// Stop auto play mode
  void stopAutoPlay() {
    _isAutoPlay = false;
    _autoPlaySpins = 0;
    _autoPlayRemaining = 0;
  }

  /// Reset game statistics
  void resetStats() {
    _totalSpins = 0;
    _totalWins = 0;
    _totalWagered = 0;
    _totalWon = 0;
    _history.clear();
  }

  /// Generate random symbols for all reels
  List<List<SlotSymbol>> _generateReels() {
    final reels = <List<SlotSymbol>>[];

    for (int reelIndex = 0; reelIndex < config.reelCount; reelIndex++) {
      final reel = <SlotSymbol>[];

      for (int row = 0; row < config.rowCount; row++) {
        reel.add(_generateSymbolForReel(reelIndex));
      }

      reels.add(reel);
    }

    return reels;
  }

  /// Generate a single symbol for a specific reel
  SlotSymbol _generateSymbolForReel(int reelIndex) {
    // Create weighted list of symbols based on reel configuration
    final weightedSymbols = <SlotSymbol>[];

    for (final symbol in SlotSymbol.values) {
      final weight = config.reelStrips[symbol]?[reelIndex] ?? symbol.weight;
      for (int i = 0; i < weight; i++) {
        weightedSymbols.add(symbol);
      }
    }

    return weightedSymbols[_random.nextInt(weightedSymbols.length)];
  }

  /// Calculate winning lines from reel results
  List<WinLine> _calculateWins(List<List<SlotSymbol>> reels) {
    final winLines = <WinLine>[];

    // Convert reels to flat grid for easier payline checking
    final grid = <SlotSymbol>[];
    for (int row = 0; row < config.rowCount; row++) {
      for (int reel = 0; reel < config.reelCount; reel++) {
        grid.add(reels[reel][row]);
      }
    }

    // Check each payline
    for (final payLine in config.paylines) {
      final lineSymbols = payLine.positions.map((pos) => grid[pos]).toList();
      final winLine = _checkPaylineWin(payLine, lineSymbols);

      if (winLine != null) {
        winLines.add(winLine);
      }
    }

    return winLines;
  }

  /// Check if a payline has a winning combination
  WinLine? _checkPaylineWin(PayLine payLine, List<SlotSymbol> symbols) {
    if (symbols.isEmpty) return null;

    final firstSymbol = symbols[0];
    int matchCount = 1;

    // Count consecutive matching symbols from left to right
    for (int i = 1; i < symbols.length; i++) {
      if (symbols[i] == firstSymbol) {
        matchCount++;
      } else {
        break;
      }
    }

    // Need at least 3 matching symbols for a win
    if (matchCount < 3) return null;

    // Calculate payout
    final basePayout = firstSymbol.multiplier * _currentBet;
    final multiplier = _getMatchMultiplier(matchCount);
    final payout = (basePayout * multiplier).round();

    return WinLine(
      payLine: payLine,
      symbol: firstSymbol,
      count: matchCount,
      payout: payout,
      positions: payLine.positions.take(matchCount).toList(),
    );
  }

  /// Get multiplier based on number of matching symbols
  double _getMatchMultiplier(int matchCount) {
    switch (matchCount) {
      case 3:
        return 1.0;
      case 4:
        return 2.5;
      case 5:
        return 5.0;
      default:
        return 1.0;
    }
  }

  /// Check if the spin result contains a jackpot
  bool _isJackpotWin(List<WinLine> winLines) {
    return winLines
        .any((line) => line.symbol == SlotSymbol.jackpot && line.count >= 3);
  }

  /// Check if the win is considered a "big win"
  bool _isBigWin(int totalWin) {
    return totalWin >= _currentBet * 10; // 10x bet or more
  }

  /// Get game statistics summary
  Map<String, dynamic> getStats() {
    return {
      'totalSpins': _totalSpins,
      'totalWins': _totalWins,
      'winRate': winRate,
      'totalWagered': _totalWagered,
      'totalWon': _totalWon,
      'actualRtp': actualRtp,
      'balance': _balance,
      'currentBet': _currentBet,
      'bigWins': _history.where((result) => result.isBigWin).length,
      'jackpots': _history.where((result) => result.isJackpot).length,
      'bestWin': _history.isNotEmpty
          ? _history.map((r) => r.totalWin).reduce((a, b) => a > b ? a : b)
          : 0,
    };
  }
}
