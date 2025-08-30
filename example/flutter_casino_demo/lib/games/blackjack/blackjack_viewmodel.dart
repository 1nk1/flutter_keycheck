import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'blackjack_engine.dart';
import '../../core/agents/agents.dart';

/// Animation states for blackjack game
enum BlackjackAnimationState {
  idle,
  dealing,
  cardFlip,
  celebrating,
  gameOver,
}

/// View model for blackjack game with MVVM architecture
class BlackjackViewModel extends ChangeNotifier {
  final BlackjackEngine _engine;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Animation and UI state
  BlackjackAnimationState _animationState = BlackjackAnimationState.idle;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _animationsEnabled = true;

  // Game state
  BlackjackGameResult? _lastResult;
  int _selectedBet = 25;
  String _statusMessage = 'Place your bet to start!';
  bool _showBasicStrategy = false;
  bool _showSettings = false;
  bool _showGameHistory = false;
  bool _autoPlayBasicStrategy = false;

  // Card dealing animation
  int _dealingCardIndex = 0;
  bool _isDealingCards = false;

  BlackjackViewModel({
    required BlackjackEngine engine,
  }) : _engine = engine;

  // Getters for engine state
  int get balance => _engine.balance;
  BlackjackHand get dealerHand => _engine.dealerHand;
  List<BlackjackHand> get playerHands => _engine.playerHands;
  List<int> get handBets => _engine.handBets;
  int get currentHandIndex => _engine.currentHandIndex;
  BlackjackHand get currentHand => _engine.currentHand;
  int get currentBet => _engine.currentBet;
  bool get gameInProgress => _engine.gameInProgress;
  bool get dealerTurn => _engine.dealerTurn;
  bool get isDemoMode => _engine.isDemoMode;
  BlackjackConfig get config => _engine.config;
  Map<String, dynamic> get stats => _engine.getStats();
  List<BlackjackGameResult> get history => _engine.history;
  List<BlackjackAction> get availableActions => _engine.getAvailableActions();
  BlackjackAction get basicStrategyAction => _engine.getBasicStrategyAction();

  // UI state getters
  BlackjackAnimationState get animationState => _animationState;
  BlackjackGameResult? get lastResult => _lastResult;
  int get selectedBet => _selectedBet;
  String get statusMessage => _statusMessage;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get animationsEnabled => _animationsEnabled;
  bool get showBasicStrategy => _showBasicStrategy;
  bool get showSettings => _showSettings;
  bool get showGameHistory => _showGameHistory;
  bool get autoPlayBasicStrategy => _autoPlayBasicStrategy;
  bool get isDealingCards => _isDealingCards;

  /// Available bet amounts
  List<int> get betAmounts => [5, 10, 25, 50, 100, 250, 500, 1000];

  /// Initialize the blackjack game
  void initialize(int startingBalance, {bool demoMode = false}) {
    _engine.initialize(startingBalance, demoMode: demoMode);
    _selectedBet = betAmounts.where((bet) => bet <= balance).first;
    _updateStatusMessage();
    notifyListeners();
  }

  /// Set bet amount
  void setBet(int amount) {
    if (betAmounts.contains(amount) && (isDemoMode || amount <= balance)) {
      _selectedBet = amount;
      _updateStatusMessage();
      notifyListeners();
    }
  }

  /// Start a new game
  Future<void> startNewGame() async {
    if (gameInProgress) return;

    if (_engine.startNewGame(_selectedBet)) {
      _setAnimationState(BlackjackAnimationState.dealing);
      _statusMessage = 'Dealing cards...';

      if (_animationsEnabled) {
        await _animateCardDealing();
      }

      _setAnimationState(BlackjackAnimationState.idle);

      // Check for immediate results
      if (currentHand.isBlackjack) {
        if (dealerHand.cards.first.isAce ||
            dealerHand.cards.first.blackjackValue == 10) {
          _statusMessage = 'Checking for dealer blackjack...';
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        await _finishGame();
      } else {
        _updateStatusMessage();
      }

      if (_soundEnabled) {
        _playSound('deal_cards');
      }

      if (_hapticsEnabled) {
        HapticFeedback.lightImpact();
      }

      notifyListeners();
    }
  }

  /// Hit - take another card
  Future<void> hit() async {
    if (_engine.hit()) {
      if (_animationsEnabled) {
        await _animateCardDeal();
      }

      if (_soundEnabled) {
        _playSound('card_deal');
      }

      if (_hapticsEnabled) {
        HapticFeedback.lightImpact();
      }

      // Check if hand is bust or game is over
      if (currentHand.isBust || !gameInProgress) {
        await _finishGame();
      } else {
        _updateStatusMessage();
      }

      notifyListeners();
    }
  }

  /// Stand - keep current hand
  Future<void> stand() async {
    if (_engine.stand()) {
      if (_soundEnabled) {
        _playSound('stand');
      }

      // Check if game is over (all hands played)
      if (!gameInProgress) {
        await _finishGame();
      } else {
        _updateStatusMessage();
      }

      notifyListeners();
    }
  }

  /// Double down - double bet and take exactly one more card
  Future<void> doubleDown() async {
    if (_engine.doubleDown()) {
      if (_animationsEnabled) {
        await _animateCardDeal();
      }

      if (_soundEnabled) {
        _playSound('double_down');
      }

      if (_hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }

      // Check if game is over
      if (!gameInProgress) {
        await _finishGame();
      } else {
        _updateStatusMessage();
      }

      notifyListeners();
    }
  }

  /// Split - create two hands from a pair
  Future<void> split() async {
    if (_engine.split()) {
      if (_animationsEnabled) {
        await _animateCardSplit();
      }

      if (_soundEnabled) {
        _playSound('split');
      }

      if (_hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }

      _updateStatusMessage();
      notifyListeners();
    }
  }

  /// Surrender - forfeit half the bet
  Future<void> surrender() async {
    if (_engine.surrender()) {
      if (_soundEnabled) {
        _playSound('surrender');
      }

      await _finishGame();
      notifyListeners();
    }
  }

  /// Perform the basic strategy recommended action
  Future<void> performBasicStrategyAction() async {
    if (!gameInProgress || availableActions.isEmpty) return;

    final action = basicStrategyAction;

    switch (action) {
      case BlackjackAction.hit:
        await hit();
        break;
      case BlackjackAction.stand:
        await stand();
        break;
      case BlackjackAction.doubleDown:
        if (availableActions.contains(BlackjackAction.doubleDown)) {
          await doubleDown();
        } else {
          await hit(); // Fall back to hit if can't double
        }
        break;
      case BlackjackAction.split:
        await split();
        break;
      case BlackjackAction.surrender:
        if (availableActions.contains(BlackjackAction.surrender)) {
          await surrender();
        } else {
          await hit(); // Fall back to hit if can't surrender
        }
        break;
    }
  }

  /// Toggle auto play basic strategy
  void toggleAutoPlayBasicStrategy() {
    _autoPlayBasicStrategy = !_autoPlayBasicStrategy;

    if (_autoPlayBasicStrategy && gameInProgress && !dealerTurn) {
      _playBasicStrategyAuto();
    }

    notifyListeners();
  }

  /// Toggle basic strategy display
  void toggleBasicStrategy() {
    _showBasicStrategy = !_showBasicStrategy;
    notifyListeners();
  }

  /// Toggle settings display
  void toggleSettings() {
    _showSettings = !_showSettings;
    notifyListeners();
  }

  /// Toggle game history display
  void toggleGameHistory() {
    _showGameHistory = !_showGameHistory;
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
    _updateStatusMessage();
    notifyListeners();
  }

  /// Get hand value display string
  String getHandValueString(BlackjackHand hand) {
    final value = hand.value;

    if (hand.isBust) {
      return 'BUST ($value)';
    } else if (hand.isBlackjack) {
      return 'BLACKJACK';
    } else if (hand.isSoft && value < 21) {
      return 'Soft $value';
    } else {
      return value.toString();
    }
  }

  /// Get result text for a hand
  String getHandResultText(HandResult handResult) {
    switch (handResult.result) {
      case BlackjackResult.win:
        return 'WIN';
      case BlackjackResult.lose:
        return 'LOSE';
      case BlackjackResult.push:
        return 'PUSH';
      case BlackjackResult.blackjack:
        return 'BLACKJACK!';
      case BlackjackResult.bust:
        return 'BUST';
      case BlackjackResult.surrender:
        return 'SURRENDER';
    }
  }

  /// Get result color for a hand
  Color getHandResultColor(HandResult handResult) {
    switch (handResult.result) {
      case BlackjackResult.win:
      case BlackjackResult.blackjack:
        return const Color(0xFF4CAF50); // Green
      case BlackjackResult.lose:
      case BlackjackResult.bust:
        return const Color(0xFFF44336); // Red
      case BlackjackResult.push:
        return const Color(0xFFFF9800); // Orange
      case BlackjackResult.surrender:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  // Private methods

  void _setAnimationState(BlackjackAnimationState state) {
    _animationState = state;
  }

  Future<void> _animateCardDealing() async {
    _isDealingCards = true;
    _dealingCardIndex = 0;

    // Animate dealing 4 cards (2 to player, 2 to dealer)
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      _dealingCardIndex++;
      notifyListeners();
    }

    _isDealingCards = false;
    notifyListeners();
  }

  Future<void> _animateCardDeal() async {
    if (!_animationsEnabled) return;

    _setAnimationState(BlackjackAnimationState.dealing);
    await Future.delayed(const Duration(milliseconds: 300));
    _setAnimationState(BlackjackAnimationState.idle);
  }

  Future<void> _animateCardSplit() async {
    if (!_animationsEnabled) return;

    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _finishGame() async {
    if (dealerTurn) {
      // Animate dealer card reveal
      if (_animationsEnabled) {
        _setAnimationState(BlackjackAnimationState.cardFlip);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      if (_soundEnabled) {
        _playSound('card_flip');
      }
    }

    // Game is finished, get final result
    _lastResult = history.isNotEmpty ? history.last : null;

    if (_lastResult != null) {
      if (_lastResult!.hasWin) {
        _setAnimationState(BlackjackAnimationState.celebrating);

        if (_lastResult!.hasBlackjack) {
          _statusMessage = '🎉 BLACKJACK! You won \$${_lastResult!.netResult}!';
          if (_soundEnabled) _playSound('blackjack');
          if (_hapticsEnabled) HapticFeedback.heavyImpact();
        } else {
          _statusMessage = '🎊 You won \$${_lastResult!.netResult}!';
          if (_soundEnabled) _playSound('win');
          if (_hapticsEnabled) HapticFeedback.mediumImpact();
        }
      } else if (_lastResult!.hasPush) {
        _statusMessage = '🤝 Push - bet returned';
        if (_soundEnabled) _playSound('push');
      } else {
        _statusMessage = '😞 You lost \$${_lastResult!.totalBet}';
        if (_soundEnabled) _playSound('lose');
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    _setAnimationState(BlackjackAnimationState.idle);
    _statusMessage = 'Place your bet to start next game!';
    notifyListeners();
  }

  Future<void> _playBasicStrategyAuto() async {
    while (_autoPlayBasicStrategy && gameInProgress && !dealerTurn) {
      await Future.delayed(const Duration(milliseconds: 800));

      if (_autoPlayBasicStrategy && gameInProgress && !dealerTurn) {
        await performBasicStrategyAction();
      }
    }
  }

  Future<void> _playSound(String soundName) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource('sounds/blackjack_$soundName.mp3'));
    } catch (e) {
      debugPrint('Failed to play sound $soundName: $e');
    }
  }

  void _updateStatusMessage() {
    if (!gameInProgress) {
      _statusMessage = 'Place your bet to start!';
    } else if (dealerTurn) {
      _statusMessage = 'Dealer\'s turn...';
    } else {
      final handNum =
          playerHands.length > 1 ? ' (Hand ${currentHandIndex + 1})' : '';
      final value = getHandValueString(currentHand);

      if (_autoPlayBasicStrategy) {
        final action = basicStrategyAction;
        _statusMessage =
            'Auto: $value - Playing ${_getActionName(action)}$handNum';
      } else {
        _statusMessage = 'Your turn: $value$handNum';
      }
    }
  }

  String _getActionName(BlackjackAction action) {
    switch (action) {
      case BlackjackAction.hit:
        return 'Hit';
      case BlackjackAction.stand:
        return 'Stand';
      case BlackjackAction.doubleDown:
        return 'Double';
      case BlackjackAction.split:
        return 'Split';
      case BlackjackAction.surrender:
        return 'Surrender';
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
