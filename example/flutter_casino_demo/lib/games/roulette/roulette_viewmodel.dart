import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'roulette_engine.dart';
import '../../core/agents/agents.dart';

/// Animation states for the roulette wheel
enum RouletteAnimationState {
  idle,
  spinning,
  slowing,
  stopped,
  celebrating,
}

/// View model for roulette game with MVVM architecture
class RouletteViewModel extends ChangeNotifier {
  final RouletteEngine _engine;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation and UI state
  RouletteAnimationState _animationState = RouletteAnimationState.idle;
  double _wheelRotation = 0.0;
  double _ballRotation = 0.0;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _animationsEnabled = true;

  // Game state
  RouletteSpinResult? _lastResult;
  int _selectedChipValue = 10;
  String _statusMessage = 'Place your bets!';
  bool _showBetHistory = false;
  bool _showSettings = false;
  bool _showStatistics = false;

  // Betting UI state
  Map<String, int> _chipCounts = {};

  RouletteViewModel({
    required RouletteEngine engine,
  }) : _engine = engine;

  // Getters for engine state
  int get balance => _engine.balance;
  List<RouletteBet> get currentBets => _engine.currentBets;
  List<RouletteSpinResult> get history => _engine.history;
  bool get isDemoMode => _engine.isDemoMode;
  bool get betsLocked => _engine.betsLocked;
  bool get hasBets => _engine.hasBets;
  int get totalBetAmount => _engine.totalBetAmount;
  Map<String, dynamic> get stats => _engine.getStats();
  RouletteConfig get config => _engine.config;
  List<RouletteNumber> get allNumbers => _engine.allNumbers;

  // UI state getters
  RouletteAnimationState get animationState => _animationState;
  double get wheelRotation => _wheelRotation;
  double get ballRotation => _ballRotation;
  RouletteSpinResult? get lastResult => _lastResult;
  int get selectedChipValue => _selectedChipValue;
  String get statusMessage => _statusMessage;
  bool get isSpinning => _animationState == RouletteAnimationState.spinning;
  bool get showBetHistory => _showBetHistory;
  bool get showSettings => _showSettings;
  bool get showStatistics => _showStatistics;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get animationsEnabled => _animationsEnabled;
  Map<String, int> get chipCounts => Map.unmodifiable(_chipCounts);

  /// Available chip values
  List<int> get chipValues => [1, 5, 10, 25, 50, 100, 500, 1000];

  /// Initialize the roulette game
  void initialize(int startingBalance, {bool demoMode = false}) {
    _engine.initialize(startingBalance, demoMode: demoMode);
    _selectedChipValue = chipValues.first;
    _updateStatusMessage();
    _resetChipCounts();
    notifyListeners();
  }

  /// Select chip value for betting
  void selectChipValue(int value) {
    if (chipValues.contains(value)) {
      _selectedChipValue = value;
      _updateStatusMessage();
      notifyListeners();
    }
  }

  /// Place a straight bet on a number
  void placeStraightBet(int number) {
    if (_canPlaceBet()) {
      if (_engine.placeStraightBet(number, _selectedChipValue)) {
        _updateChipCount('straight_$number', _selectedChipValue);
        _playSound('chip_place');
        _hapticFeedback();
        _updateStatusMessage();
        notifyListeners();
      }
    }
  }

  /// Place a split bet
  void placeSplitBet(int number1, int number2) {
    if (_canPlaceBet()) {
      if (_engine.placeSplitBet(number1, number2, _selectedChipValue)) {
        final key = 'split_${number1}_$number2';
        _updateChipCount(key, _selectedChipValue);
        _playSound('chip_place');
        _hapticFeedback();
        _updateStatusMessage();
        notifyListeners();
      }
    }
  }

  /// Place a street bet
  void placeStreetBet(int startNumber) {
    if (_canPlaceBet()) {
      if (_engine.placeStreetBet(startNumber, _selectedChipValue)) {
        _updateChipCount('street_$startNumber', _selectedChipValue);
        _playSound('chip_place');
        _hapticFeedback();
        _updateStatusMessage();
        notifyListeners();
      }
    }
  }

  /// Place a corner bet
  void placeCornerBet(int topLeftNumber) {
    if (_canPlaceBet()) {
      if (_engine.placeCornerBet(topLeftNumber, _selectedChipValue)) {
        _updateChipCount('corner_$topLeftNumber', _selectedChipValue);
        _playSound('chip_place');
        _hapticFeedback();
        _updateStatusMessage();
        notifyListeners();
      }
    }
  }

  /// Place an outside bet
  void placeOutsideBet(BetType betType) {
    if (_canPlaceBet() && betType.isOutside) {
      if (_engine.placeOutsideBet(betType, _selectedChipValue)) {
        _updateChipCount(betType.name, _selectedChipValue);
        _playSound('chip_place');
        _hapticFeedback();
        _updateStatusMessage();
        notifyListeners();
      }
    }
  }

  /// Remove a specific bet
  void removeBet(String betId) {
    final bet = currentBets.where((b) => b.id == betId).firstOrNull;
    if (bet != null && _engine.removeBet(betId)) {
      _removeChipCount(_getBetKey(bet), bet.amount);
      _playSound('chip_remove');
      _hapticFeedback();
      _updateStatusMessage();
      notifyListeners();
    }
  }

  /// Clear all bets
  void clearAllBets() {
    _engine.clearBets();
    _resetChipCounts();
    _playSound('chips_clear');
    _hapticFeedback();
    _updateStatusMessage();
    notifyListeners();
  }

  /// Repeat last bets
  void repeatLastBets() {
    if (_lastResult != null && !betsLocked) {
      final lastBets = [
        ..._lastResult!.winningBets,
        ..._lastResult!.losingBets
      ];

      for (final bet in lastBets) {
        if (_canPlaceBet()) {
          switch (bet.type) {
            case BetType.straight:
              _engine.placeStraightBet(bet.numbers.first, bet.amount);
              break;
            default:
              if (bet.type.isOutside) {
                _engine.placeOutsideBet(bet.type, bet.amount);
              }
          }
        }
      }

      _recalculateChipCounts();
      _playSound('chips_repeat');
      _hapticFeedback();
      _updateStatusMessage();
      notifyListeners();
    }
  }

  /// Spin the wheel
  Future<void> spin() async {
    if (!hasBets || isSpinning) return;

    try {
      _setAnimationState(RouletteAnimationState.spinning);
      _statusMessage = 'No more bets! Spinning...';
      notifyListeners();

      // Play spin sound
      if (_soundEnabled) {
        _playSound('wheel_spin');
      }

      // Start wheel animation
      if (_animationsEnabled) {
        await _animateWheelSpin();
      }

      // Perform the actual spin
      final result = await _engine.spin();
      _lastResult = result;

      // Stop wheel at winning number
      await _stopWheel(result.winningNumber.number);

      // Celebrate if there are wins
      if (result.hasWin) {
        await _celebrateWin(result);
      } else {
        _setAnimationState(RouletteAnimationState.stopped);
        _statusMessage = 'House wins. Place your bets!';
      }

      _resetChipCounts();
    } catch (e) {
      _setAnimationState(RouletteAnimationState.idle);
      _statusMessage = 'Error: ${e.toString()}';
      debugPrint('Spin error: $e');
    }

    notifyListeners();
  }

  /// Toggle bet history display
  void toggleBetHistory() {
    _showBetHistory = !_showBetHistory;
    notifyListeners();
  }

  /// Toggle settings display
  void toggleSettings() {
    _showSettings = !_showSettings;
    notifyListeners();
  }

  /// Toggle statistics display
  void toggleStatistics() {
    _showStatistics = !_showStatistics;
    notifyListeners();
  }

  /// Update sound setting
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    notifyListeners();
  }

  /// Update haptics setting
  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    notifyListeners();
  }

  /// Update animations setting
  void setAnimationsEnabled(bool enabled) {
    _animationsEnabled = enabled;
    notifyListeners();
  }

  /// Reset game statistics
  void resetStats() {
    _engine.resetStats();
    _lastResult = null;
    _resetChipCounts();
    _updateStatusMessage();
    notifyListeners();
  }

  /// Get chip count for a specific bet position
  int getChipCountAt(String position) {
    return _chipCounts[position] ?? 0;
  }

  /// Get bet amount for a specific position
  int getBetAmountAt(String position) {
    return currentBets
        .where((bet) => _getBetKey(bet) == position)
        .fold(0, (sum, bet) => sum + bet.amount);
  }

  /// Check if a position has bets
  bool hasChipsAt(String position) {
    return getChipCountAt(position) > 0;
  }

  /// Get the color of a roulette number
  RouletteColor getNumberColor(int number) {
    return RouletteNumber(number).color;
  }

  /// Get recent winning numbers
  List<int> getRecentNumbers({int count = 10}) {
    return _engine.getRecentNumbers(count: count).map((n) => n.number).toList();
  }

  /// Get hot numbers
  List<MapEntry<int, int>> getHotNumbers() {
    return _engine.getHotNumbers();
  }

  /// Get cold numbers
  List<MapEntry<int, int>> getColdNumbers() {
    return _engine.getColdNumbers();
  }

  // Private methods

  bool _canPlaceBet() {
    return !betsLocked && !isSpinning;
  }

  void _updateChipCount(String key, int amount) {
    _chipCounts[key] = (_chipCounts[key] ?? 0) + amount;
  }

  void _removeChipCount(String key, int amount) {
    final currentCount = _chipCounts[key] ?? 0;
    final newCount = currentCount - amount;

    if (newCount <= 0) {
      _chipCounts.remove(key);
    } else {
      _chipCounts[key] = newCount;
    }
  }

  void _resetChipCounts() {
    _chipCounts.clear();
  }

  void _recalculateChipCounts() {
    _resetChipCounts();
    for (final bet in currentBets) {
      _updateChipCount(_getBetKey(bet), bet.amount);
    }
  }

  String _getBetKey(RouletteBet bet) {
    switch (bet.type) {
      case BetType.straight:
        return 'straight_${bet.numbers.first}';
      case BetType.split:
        return 'split_${bet.numbers.first}_${bet.numbers.last}';
      case BetType.street:
        return 'street_${bet.numbers.first}';
      case BetType.corner:
        return 'corner_${bet.numbers.first}';
      default:
        return bet.type.name;
    }
  }

  void _setAnimationState(RouletteAnimationState state) {
    _animationState = state;
  }

  Future<void> _animateWheelSpin() async {
    const duration = Duration(seconds: 3);
    const rotations = 10; // Number of full rotations

    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < duration) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = elapsed / duration.inMilliseconds;

      _wheelRotation = (rotations * 360 * progress) % 360;
      _ballRotation = -(rotations * 360 * progress * 1.5) %
          360; // Ball moves opposite direction

      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 16)); // ~60 FPS
    }
  }

  Future<void> _stopWheel(int winningNumber) async {
    _setAnimationState(RouletteAnimationState.slowing);

    // Calculate the angle for the winning number
    final numberAngle = _calculateNumberAngle(winningNumber);

    // Animate to the final position
    const duration = Duration(milliseconds: 1500);
    final startRotation = _wheelRotation;
    final targetRotation = numberAngle;
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < duration) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = elapsed / duration.inMilliseconds;
      final easedProgress = _easeOut(progress);

      _wheelRotation =
          startRotation + (targetRotation - startRotation) * easedProgress;
      _ballRotation = _wheelRotation; // Ball settles on winning number

      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 16));
    }

    _wheelRotation = targetRotation;
    _ballRotation = targetRotation;
    _setAnimationState(RouletteAnimationState.stopped);

    if (_soundEnabled) {
      _playSound('ball_settle');
    }

    if (_hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }

    notifyListeners();
  }

  Future<void> _celebrateWin(RouletteSpinResult result) async {
    _setAnimationState(RouletteAnimationState.celebrating);

    if (result.totalWin > result.totalLoss * 5) {
      _statusMessage = '🎉 BIG WIN! You won \$${result.totalWin}!';
      if (_soundEnabled) _playSound('big_win');
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    } else {
      _statusMessage = '🎊 You won \$${result.totalWin}!';
      if (_soundEnabled) _playSound('win');
      if (_hapticsEnabled) HapticFeedback.lightImpact();
    }

    // Flash winning number for a moment
    await Future.delayed(const Duration(seconds: 2));

    _setAnimationState(RouletteAnimationState.idle);
    _statusMessage = 'Place your bets!';
  }

  double _calculateNumberAngle(int number) {
    // European roulette wheel layout (0-36)
    final wheelLayout = [
      0,
      32,
      15,
      19,
      4,
      21,
      2,
      25,
      17,
      34,
      6,
      27,
      13,
      36,
      11,
      30,
      8,
      23,
      10,
      5,
      24,
      16,
      33,
      1,
      20,
      14,
      31,
      9,
      22,
      18,
      29,
      7,
      28,
      12,
      35,
      3,
      26
    ];

    final index = wheelLayout.indexOf(number);
    return (index * (360 / wheelLayout.length)) % 360;
  }

  double _easeOut(double t) {
    return 1 - pow(1 - t, 3);
  }

  /// Placeholder for pow function (dart:math would normally be imported)
  double pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  Future<void> _playSound(String soundName) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource('sounds/roulette_$soundName.mp3'));
    } catch (e) {
      debugPrint('Failed to play sound $soundName: $e');
    }
  }

  void _hapticFeedback() {
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _updateStatusMessage() {
    if (isSpinning) {
      _statusMessage = 'Spinning...';
    } else if (betsLocked) {
      _statusMessage = 'No more bets!';
    } else if (hasBets) {
      _statusMessage = 'Total bet: \$${totalBetAmount} - Spin to play!';
    } else {
      _statusMessage = 'Place your bets!';
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
