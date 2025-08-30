import 'dart:math';
import '../../core/agents/agents.dart';

/// Roulette number with color and properties
class RouletteNumber {
  final int number;
  final RouletteColor color;
  final bool isEven;
  final bool isLow; // 1-18
  final int column; // 1, 2, or 3
  final int dozen; // 1, 2, or 3

  RouletteNumber(this.number)
      : color = _getColor(number),
        isEven = number > 0 && number % 2 == 0,
        isLow = number >= 1 && number <= 18,
        column = number == 0 ? 0 : ((number - 1) % 3) + 1,
        dozen = number == 0 ? 0 : ((number - 1) ~/ 12) + 1;

  bool get isOdd => number > 0 && !isEven;
  bool get isHigh => number >= 19 && number <= 36;

  static RouletteColor _getColor(int number) {
    if (number == 0) return RouletteColor.green;

    const redNumbers = [
      1,
      3,
      5,
      7,
      9,
      12,
      14,
      16,
      18,
      19,
      21,
      23,
      25,
      27,
      30,
      32,
      34,
      36
    ];
    return redNumbers.contains(number)
        ? RouletteColor.red
        : RouletteColor.black;
  }
}

/// Roulette number colors
enum RouletteColor {
  red,
  black,
  green,
}

/// Types of bets in roulette
enum BetType {
  // Inside bets
  straight(35, 'Straight Up'),
  split(17, 'Split'),
  street(11, 'Street'),
  corner(8, 'Corner'),
  sixLine(5, 'Six Line'),

  // Outside bets
  red(1, 'Red'),
  black(1, 'Black'),
  even(1, 'Even'),
  odd(1, 'Odd'),
  low(1, '1-18'),
  high(1, '19-36'),
  dozen1(2, '1st Dozen'),
  dozen2(2, '2nd Dozen'),
  dozen3(2, '3rd Dozen'),
  column1(2, '1st Column'),
  column2(2, '2nd Column'),
  column3(2, '3rd Column');

  const BetType(this.payout, this.name);

  final int payout;
  final String name;

  bool get isInside =>
      [straight, split, street, corner, sixLine].contains(this);
  bool get isOutside => !isInside;
}

/// Individual bet placed on the table
class RouletteBet {
  final BetType type;
  final List<int> numbers;
  final int amount;
  final String id;

  const RouletteBet({
    required this.type,
    required this.numbers,
    required this.amount,
    required this.id,
  });

  /// Check if this bet wins for the given number
  bool isWinner(int winningNumber) {
    return numbers.contains(winningNumber);
  }

  /// Calculate payout if this bet wins
  int calculatePayout() {
    return amount * type.payout;
  }
}

/// Result of a roulette spin
class RouletteSpinResult {
  final RouletteNumber winningNumber;
  final List<RouletteBet> winningBets;
  final List<RouletteBet> losingBets;
  final int totalWin;
  final int totalLoss;
  final double spinDuration;
  final DateTime timestamp;

  const RouletteSpinResult({
    required this.winningNumber,
    required this.winningBets,
    required this.losingBets,
    required this.totalWin,
    required this.totalLoss,
    required this.spinDuration,
    required this.timestamp,
  });

  int get netResult => totalWin - totalLoss;
  bool get hasWin => totalWin > 0;
}

/// Roulette game configuration
class RouletteConfig {
  final RouletteType type;
  final int minBet;
  final int maxBet;
  final int maxTotalBet;
  final Map<BetType, int> betLimits;
  final double houseEdge;

  const RouletteConfig({
    this.type = RouletteType.european,
    this.minBet = 1,
    this.maxBet = 1000,
    this.maxTotalBet = 5000,
    this.betLimits = const {},
    this.houseEdge = 0.027, // European roulette
  });

  /// European roulette (single zero)
  static const RouletteConfig european = RouletteConfig(
    type: RouletteType.european,
    houseEdge: 0.027,
  );

  /// American roulette (double zero)
  static const RouletteConfig american = RouletteConfig(
    type: RouletteType.american,
    houseEdge: 0.053,
  );

  /// High roller configuration
  static const RouletteConfig highRoller = RouletteConfig(
    type: RouletteType.european,
    minBet: 100,
    maxBet: 10000,
    maxTotalBet: 50000,
    houseEdge: 0.027,
  );
}

enum RouletteType {
  european,
  american,
}

/// Core roulette game engine
class RouletteEngine {
  final RouletteConfig config;
  final GameEngineAgent _gameEngine;
  final Random _random;

  // Game state
  int _balance = 0;
  List<RouletteBet> _currentBets = [];
  List<RouletteSpinResult> _history = [];
  int _totalSpins = 0;
  int _totalWins = 0;
  double _totalWagered = 0;
  double _totalWon = 0;

  // Demo mode
  bool _isDemoMode = true;
  bool _betsLocked = false;

  RouletteEngine({
    required this.config,
    required GameEngineAgent gameEngine,
    int? seed,
  })  : _gameEngine = gameEngine,
        _random = Random(seed);

  // Getters
  int get balance => _balance;
  List<RouletteBet> get currentBets => List.unmodifiable(_currentBets);
  List<RouletteSpinResult> get history => List.unmodifiable(_history);
  int get totalSpins => _totalSpins;
  int get totalWins => _totalWins;
  double get totalWagered => _totalWagered;
  double get totalWon => _totalWon;
  double get winRate => _totalSpins > 0 ? (_totalWins / _totalSpins) * 100 : 0;
  double get actualRtp =>
      _totalWagered > 0 ? (_totalWon / _totalWagered) * 100 : 0;
  bool get isDemoMode => _isDemoMode;
  bool get betsLocked => _betsLocked;
  bool get hasBets => _currentBets.isNotEmpty;
  int get totalBetAmount =>
      _currentBets.fold(0, (sum, bet) => sum + bet.amount);

  /// All roulette numbers (0-36 for European, 0-37 for American)
  List<RouletteNumber> get allNumbers {
    final numbers = List.generate(37, (i) => RouletteNumber(i));
    if (config.type == RouletteType.american) {
      numbers.add(RouletteNumber(37)); // 00 in American roulette
    }
    return numbers;
  }

  /// Initialize the engine
  void initialize(int startingBalance, {bool demoMode = false}) {
    _balance = startingBalance;
    _isDemoMode = demoMode;
    _currentBets.clear();
    _betsLocked = false;
  }

  /// Place a straight bet on a single number
  bool placeStraightBet(int number, int amount) {
    if (!_canPlaceBet(amount) || number < 0 || number > 36) return false;

    final bet = RouletteBet(
      type: BetType.straight,
      numbers: [number],
      amount: amount,
      id: _generateBetId(),
    );

    return _addBet(bet);
  }

  /// Place a split bet on two adjacent numbers
  bool placeSplitBet(int number1, int number2, int amount) {
    if (!_canPlaceBet(amount) || !_isValidSplit(number1, number2)) return false;

    final bet = RouletteBet(
      type: BetType.split,
      numbers: [number1, number2],
      amount: amount,
      id: _generateBetId(),
    );

    return _addBet(bet);
  }

  /// Place a street bet (row of 3 numbers)
  bool placeStreetBet(int startNumber, int amount) {
    if (!_canPlaceBet(amount) || !_isValidStreet(startNumber)) return false;

    final numbers = [startNumber, startNumber + 1, startNumber + 2];
    final bet = RouletteBet(
      type: BetType.street,
      numbers: numbers,
      amount: amount,
      id: _generateBetId(),
    );

    return _addBet(bet);
  }

  /// Place a corner bet (4 numbers)
  bool placeCornerBet(int topLeftNumber, int amount) {
    if (!_canPlaceBet(amount) || !_isValidCorner(topLeftNumber)) return false;

    final numbers = [
      topLeftNumber,
      topLeftNumber + 1,
      topLeftNumber + 3,
      topLeftNumber + 4,
    ];

    final bet = RouletteBet(
      type: BetType.corner,
      numbers: numbers,
      amount: amount,
      id: _generateBetId(),
    );

    return _addBet(bet);
  }

  /// Place an outside bet (red, black, even, odd, etc.)
  bool placeOutsideBet(BetType betType, int amount) {
    if (!_canPlaceBet(amount) || betType.isInside) return false;

    final numbers = _getOutsideBetNumbers(betType);
    final bet = RouletteBet(
      type: betType,
      numbers: numbers,
      amount: amount,
      id: _generateBetId(),
    );

    return _addBet(bet);
  }

  /// Remove a specific bet
  bool removeBet(String betId) {
    if (_betsLocked) return false;

    final betIndex = _currentBets.indexWhere((bet) => bet.id == betId);
    if (betIndex == -1) return false;

    final bet = _currentBets[betIndex];
    if (!_isDemoMode) {
      _balance += bet.amount;
    }

    _currentBets.removeAt(betIndex);
    return true;
  }

  /// Clear all bets
  void clearBets() {
    if (_betsLocked) return;

    if (!_isDemoMode) {
      final totalAmount = _currentBets.fold(0, (sum, bet) => sum + bet.amount);
      _balance += totalAmount;
    }

    _currentBets.clear();
  }

  /// Lock bets (no more changes allowed)
  void lockBets() {
    _betsLocked = true;
  }

  /// Spin the wheel
  Future<RouletteSpinResult> spin() async {
    if (!hasBets) {
      throw Exception('No bets placed');
    }

    lockBets();

    final startTime = DateTime.now();

    // Generate winning number
    final maxNumber = config.type == RouletteType.american ? 38 : 37;
    final winningNumberValue = _random.nextInt(maxNumber);
    final winningNumber = RouletteNumber(winningNumberValue);

    // Determine winning and losing bets
    final winningBets = <RouletteBet>[];
    final losingBets = <RouletteBet>[];
    int totalWin = 0;
    int totalLoss = 0;

    for (final bet in _currentBets) {
      if (bet.isWinner(winningNumber.number)) {
        winningBets.add(bet);
        totalWin += bet.calculatePayout() + bet.amount; // Include original bet
      } else {
        losingBets.add(bet);
        totalLoss += bet.amount;
      }
    }

    // Update balance
    if (!_isDemoMode) {
      _balance += totalWin;
    }

    // Update statistics
    _totalSpins++;
    if (totalWin > 0) {
      _totalWins++;
    }
    _totalWagered += totalLoss +
        (totalWin > 0
            ? winningBets.fold(0, (sum, bet) => sum + bet.amount)
            : 0);
    _totalWon += totalWin;

    final spinDuration =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    final result = RouletteSpinResult(
      winningNumber: winningNumber,
      winningBets: winningBets,
      losingBets: losingBets,
      totalWin: totalWin,
      totalLoss: totalLoss,
      spinDuration: spinDuration,
      timestamp: DateTime.now(),
    );

    // Add to history (keep last 100 spins)
    _history.add(result);
    if (_history.length > 100) {
      _history = _history.skip(_history.length - 100).toList();
    }

    // Reset for next round
    _currentBets.clear();
    _betsLocked = false;

    return result;
  }

  /// Get recent numbers for display
  List<RouletteNumber> getRecentNumbers({int count = 10}) {
    return _history.take(count).map((result) => result.winningNumber).toList();
  }

  /// Get hot numbers (most frequent)
  List<MapEntry<int, int>> getHotNumbers({int count = 5}) {
    final numberCount = <int, int>{};

    for (final result in _history) {
      final number = result.winningNumber.number;
      numberCount[number] = (numberCount[number] ?? 0) + 1;
    }

    final sorted = numberCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(count).toList();
  }

  /// Get cold numbers (least frequent)
  List<MapEntry<int, int>> getColdNumbers({int count = 5}) {
    final numberCount = <int, int>{};

    // Initialize all numbers with 0
    for (int i = 0; i <= 36; i++) {
      numberCount[i] = 0;
    }

    // Count occurrences
    for (final result in _history) {
      final number = result.winningNumber.number;
      numberCount[number] = numberCount[number]! + 1;
    }

    final sorted = numberCount.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sorted.take(count).toList();
  }

  /// Reset game statistics
  void resetStats() {
    _totalSpins = 0;
    _totalWins = 0;
    _totalWagered = 0;
    _totalWon = 0;
    _history.clear();
  }

  // Helper methods

  bool _canPlaceBet(int amount) {
    if (_betsLocked) return false;
    if (amount < config.minBet || amount > config.maxBet) return false;
    if (totalBetAmount + amount > config.maxTotalBet) return false;
    if (!_isDemoMode && amount > _balance) return false;

    return true;
  }

  bool _addBet(RouletteBet bet) {
    if (!_canPlaceBet(bet.amount)) return false;

    // Deduct from balance (except in demo mode)
    if (!_isDemoMode) {
      _balance -= bet.amount;
    }

    _currentBets.add(bet);
    return true;
  }

  String _generateBetId() {
    return 'bet_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
  }

  bool _isValidSplit(int num1, int num2) {
    if (num1 == num2) return false;
    if (num1 < 0 || num1 > 36 || num2 < 0 || num2 > 36) return false;

    // Check if numbers are adjacent horizontally or vertically
    final diff = (num1 - num2).abs();
    return diff == 1 || diff == 3;
  }

  bool _isValidStreet(int startNumber) {
    return startNumber >= 1 && startNumber <= 34 && (startNumber - 1) % 3 == 0;
  }

  bool _isValidCorner(int topLeftNumber) {
    if (topLeftNumber < 1 || topLeftNumber > 32) return false;
    return (topLeftNumber - 1) % 3 != 2; // Not in rightmost column
  }

  List<int> _getOutsideBetNumbers(BetType betType) {
    switch (betType) {
      case BetType.red:
        return [
          1,
          3,
          5,
          7,
          9,
          12,
          14,
          16,
          18,
          19,
          21,
          23,
          25,
          27,
          30,
          32,
          34,
          36
        ];
      case BetType.black:
        return [
          2,
          4,
          6,
          8,
          10,
          11,
          13,
          15,
          17,
          20,
          22,
          24,
          26,
          28,
          29,
          31,
          33,
          35
        ];
      case BetType.even:
        return List.generate(18, (i) => (i + 1) * 2);
      case BetType.odd:
        return List.generate(18, (i) => (i * 2) + 1);
      case BetType.low:
        return List.generate(18, (i) => i + 1);
      case BetType.high:
        return List.generate(18, (i) => i + 19);
      case BetType.dozen1:
        return List.generate(12, (i) => i + 1);
      case BetType.dozen2:
        return List.generate(12, (i) => i + 13);
      case BetType.dozen3:
        return List.generate(12, (i) => i + 25);
      case BetType.column1:
        return [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];
      case BetType.column2:
        return [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
      case BetType.column3:
        return [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];
      default:
        return [];
    }
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
      'currentBetAmount': totalBetAmount,
      'recentNumbers': getRecentNumbers().map((n) => n.number).toList(),
      'hotNumbers': getHotNumbers()
          .map((e) => {'number': e.key, 'count': e.value})
          .toList(),
      'coldNumbers': getColdNumbers()
          .map((e) => {'number': e.key, 'count': e.value})
          .toList(),
    };
  }
}
