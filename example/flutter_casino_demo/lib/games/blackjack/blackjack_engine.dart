import 'dart:math';
import '../../core/agents/agents.dart';

/// Playing card suits
enum CardSuit {
  hearts('♥', '♥️'),
  diamonds('♦', '♦️'),
  clubs('♣', '♣️'),
  spades('♠', '♠️');
  
  const CardSuit(this.symbol, this.emoji);
  
  final String symbol;
  final String emoji;
  
  bool get isRed => this == hearts || this == diamonds;
  bool get isBlack => !isRed;
}

/// Playing card ranks
enum CardRank {
  ace(1, 'A', 11),
  two(2, '2', 2),
  three(3, '3', 3),
  four(4, '4', 4),
  five(5, '5', 5),
  six(6, '6', 6),
  seven(7, '7', 7),
  eight(8, '8', 8),
  nine(9, '9', 9),
  ten(10, '10', 10),
  jack(11, 'J', 10),
  queen(12, 'Q', 10),
  king(13, 'K', 10);
  
  const CardRank(this.value, this.symbol, this.blackjackValue);
  
  final int value;
  final String symbol;
  final int blackjackValue;
}

/// Individual playing card
class PlayingCard {
  final CardSuit suit;
  final CardRank rank;
  final bool isHidden;
  
  const PlayingCard({
    required this.suit,
    required this.rank,
    this.isHidden = false,
  });
  
  /// Get the blackjack value of this card
  int get blackjackValue => rank.blackjackValue;
  
  /// Check if this is an Ace
  bool get isAce => rank == CardRank.ace;
  
  /// Check if this is a face card
  bool get isFaceCard => [CardRank.jack, CardRank.queen, CardRank.king].contains(rank);
  
  /// Get display string
  String get displayString => '${rank.symbol}${suit.symbol}';
  
  /// Create a copy with different hidden state
  PlayingCard copyWith({bool? isHidden}) {
    return PlayingCard(
      suit: suit,
      rank: rank,
      isHidden: isHidden ?? this.isHidden,
    );
  }
  
  @override
  String toString() => displayString;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard && other.suit == suit && other.rank == rank;
  }
  
  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}

/// Standard deck of 52 playing cards
class CardDeck {
  final List<PlayingCard> _cards = [];
  final Random _random;
  
  CardDeck({int? seed}) : _random = Random(seed) {
    reset();
  }
  
  /// Reset and shuffle the deck
  void reset() {
    _cards.clear();
    
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        _cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    
    shuffle();
  }
  
  /// Shuffle the deck
  void shuffle() {
    _cards.shuffle(_random);
  }
  
  /// Deal a card from the top of the deck
  PlayingCard? dealCard() {
    if (_cards.isEmpty) return null;
    return _cards.removeLast();
  }
  
  /// Get remaining card count
  int get remainingCards => _cards.length;
  
  /// Check if deck needs reshuffling (less than 25% remaining)
  bool get needsReshuffle => remainingCards < 13;
}

/// Hand of cards with blackjack-specific logic
class BlackjackHand {
  final List<PlayingCard> _cards = [];
  
  /// Get all cards in the hand
  List<PlayingCard> get cards => List.unmodifiable(_cards);
  
  /// Add a card to the hand
  void addCard(PlayingCard card) {
    _cards.add(card);
  }
  
  /// Clear all cards from the hand
  void clear() {
    _cards.clear();
  }
  
  /// Get the best blackjack value for this hand
  int get value {
    int total = 0;
    int aces = 0;
    
    for (final card in _cards.where((c) => !c.isHidden)) {
      total += card.blackjackValue;
      if (card.isAce) aces++;
    }
    
    // Adjust for aces (use as 1 instead of 11 if it prevents bust)
    while (total > 21 && aces > 0) {
      total -= 10; // Convert ace from 11 to 1
      aces--;
    }
    
    return total;
  }
  
  /// Check if hand is blackjack (21 with exactly 2 cards)
  bool get isBlackjack {
    return _cards.length == 2 && value == 21;
  }
  
  /// Check if hand is bust (over 21)
  bool get isBust => value > 21;
  
  /// Check if hand is soft (contains ace counted as 11)
  bool get isSoft {
    if (_cards.isEmpty) return false;
    
    int total = 0;
    bool hasUsableAce = false;
    
    for (final card in _cards.where((c) => !c.isHidden)) {
      total += card.blackjackValue;
      if (card.isAce) hasUsableAce = true;
    }
    
    return hasUsableAce && total <= 21;
  }
  
  /// Check if hand can be split (two cards of same rank)
  bool get canSplit {
    return _cards.length == 2 && 
           _cards[0].rank == _cards[1].rank;
  }
  
  /// Get the number of cards
  int get cardCount => _cards.length;
  
  /// Check if hand is empty
  bool get isEmpty => _cards.isEmpty;
  
  /// Split the hand (returns the second card)
  PlayingCard? split() {
    if (!canSplit) return null;
    return _cards.removeLast();
  }
}

/// Blackjack game actions
enum BlackjackAction {
  hit,
  stand,
  doubleDown,
  split,
  surrender,
}

/// Blackjack game results
enum BlackjackResult {
  win,
  lose,
  push,
  blackjack,
  bust,
  surrender,
}

/// Individual blackjack hand result
class HandResult {
  final BlackjackHand hand;
  final BlackjackResult result;
  final int bet;
  final int payout;
  final bool isActive;
  
  const HandResult({
    required this.hand,
    required this.result,
    required this.bet,
    required this.payout,
    this.isActive = false,
  });
  
  int get netResult => payout - bet;
}

/// Complete blackjack game result
class BlackjackGameResult {
  final BlackjackHand dealerHand;
  final List<HandResult> playerHands;
  final int totalBet;
  final int totalPayout;
  final DateTime timestamp;
  final double gameDuration;
  
  const BlackjackGameResult({
    required this.dealerHand,
    required this.playerHands,
    required this.totalBet,
    required this.totalPayout,
    required this.timestamp,
    required this.gameDuration,
  });
  
  int get netResult => totalPayout - totalBet;
  bool get hasWin => netResult > 0;
  bool get hasPush => netResult == 0;
  bool get hasBlackjack => playerHands.any((h) => h.result == BlackjackResult.blackjack);
}

/// Blackjack game configuration
class BlackjackConfig {
  final int deckCount;
  final bool dealerHitsOn17;
  final bool surrenderAllowed;
  final bool doubleAfterSplitAllowed;
  final bool resplitAcesAllowed;
  final int maxSplitHands;
  final double blackjackPayout;
  final int minBet;
  final int maxBet;
  
  const BlackjackConfig({
    this.deckCount = 6,
    this.dealerHitsOn17 = true,
    this.surrenderAllowed = true,
    this.doubleAfterSplitAllowed = true,
    this.resplitAcesAllowed = false,
    this.maxSplitHands = 4,
    this.blackjackPayout = 1.5,
    this.minBet = 5,
    this.maxBet = 1000,
  });
  
  /// Standard Vegas rules
  static const BlackjackConfig standard = BlackjackConfig();
  
  /// Conservative house rules
  static const BlackjackConfig conservative = BlackjackConfig(
    dealerHitsOn17: false,
    surrenderAllowed: false,
    doubleAfterSplitAllowed: false,
    blackjackPayout = 1.2,
  );
  
  /// Liberal player-friendly rules
  static const BlackjackConfig liberal = BlackjackConfig(
    dealerHitsOn17: false,
    surrenderAllowed: true,
    doubleAfterSplitAllowed: true,
    resplitAcesAllowed: true,
    blackjackPayout = 1.5,
  );
}

/// Core blackjack game engine
class BlackjackEngine {
  final BlackjackConfig config;
  final GameEngineAgent _gameEngine;
  final List<CardDeck> _decks;
  final Random _random;
  
  // Game state
  int _balance = 0;
  BlackjackHand _dealerHand = BlackjackHand();
  List<BlackjackHand> _playerHands = [BlackjackHand()];
  List<int> _handBets = [0];
  int _currentHandIndex = 0;
  bool _gameInProgress = false;
  bool _dealerTurn = false;
  
  // Statistics
  int _totalGames = 0;
  int _totalWins = 0;
  int _totalBlackjacks = 0;
  double _totalWagered = 0;
  double _totalWon = 0;
  List<BlackjackGameResult> _history = [];
  
  // Demo mode
  bool _isDemoMode = true;
  
  BlackjackEngine({
    required this.config,
    required GameEngineAgent gameEngine,
    int? seed,
  }) : _gameEngine = gameEngine,
       _random = Random(seed),
       _decks = List.generate(
         config.deckCount, 
         (index) => CardDeck(seed: seed != null ? seed + index : null),
       );
  
  // Getters
  int get balance => _balance;
  BlackjackHand get dealerHand => _dealerHand;
  List<BlackjackHand> get playerHands => List.unmodifiable(_playerHands);
  List<int> get handBets => List.unmodifiable(_handBets);
  int get currentHandIndex => _currentHandIndex;
  BlackjackHand get currentHand => _playerHands[_currentHandIndex];
  int get currentBet => _handBets[_currentHandIndex];
  bool get gameInProgress => _gameInProgress;
  bool get dealerTurn => _dealerTurn;
  bool get isDemoMode => _isDemoMode;
  int get totalGames => _totalGames;
  int get totalWins => _totalWins;
  int get totalBlackjacks => _totalBlackjacks;
  double get winRate => _totalGames > 0 ? (_totalWins / _totalGames) * 100 : 0;
  double get totalWagered => _totalWagered;
  double get totalWon => _totalWon;
  double get actualRtp => _totalWagered > 0 ? (_totalWon / _totalWagered) * 100 : 0;
  List<BlackjackGameResult> get history => List.unmodifiable(_history);
  
  /// Initialize the engine
  void initialize(int startingBalance, {bool demoMode = false}) {
    _balance = startingBalance;
    _isDemoMode = demoMode;
    _resetGame();
  }
  
  /// Start a new game with the given bet
  bool startNewGame(int bet) {
    if (_gameInProgress) return false;
    if (bet < config.minBet || bet > config.maxBet) return false;
    if (!_isDemoMode && bet > _balance) return false;
    
    _resetGame();
    _handBets[0] = bet;
    
    // Deduct bet from balance
    if (!_isDemoMode) {
      _balance -= bet;
    }
    
    // Deal initial cards
    _dealInitialCards();
    
    _gameInProgress = true;
    
    // Check for immediate blackjack
    if (_playerHands[0].isBlackjack) {
      if (_dealerHand.cards[0].rank.blackjackValue == 10 || _dealerHand.cards[0].isAce) {
        // Dealer might have blackjack, reveal hole card
        _dealerHand.cards[1] = _dealerHand.cards[1].copyWith(isHidden: false);
      }
      
      if (!_dealerHand.isBlackjack) {
        // Player blackjack wins immediately
        return _finishGame();
      } else {
        // Both have blackjack - push
        return _finishGame();
      }
    }
    
    return true;
  }
  
  /// Hit - take another card
  bool hit() {
    if (!_canPerformAction(BlackjackAction.hit)) return false;
    
    final card = _dealCard();
    if (card == null) return false;
    
    currentHand.addCard(card);
    
    // Check if busted
    if (currentHand.isBust) {
      _moveToNextHand();
    }
    
    return true;
  }
  
  /// Stand - keep current hand
  bool stand() {
    if (!_canPerformAction(BlackjackAction.stand)) return false;
    
    _moveToNextHand();
    return true;
  }
  
  /// Double down - double bet and take exactly one more card
  bool doubleDown() {
    if (!_canPerformAction(BlackjackAction.doubleDown)) return false;
    
    final additionalBet = _handBets[_currentHandIndex];
    
    // Check if player can afford to double
    if (!_isDemoMode && additionalBet > _balance) return false;
    
    // Deduct additional bet
    if (!_isDemoMode) {
      _balance -= additionalBet;
    }
    
    _handBets[_currentHandIndex] *= 2;
    
    // Deal exactly one card
    final card = _dealCard();
    if (card == null) return false;
    
    currentHand.addCard(card);
    
    // Move to next hand (stand after double down)
    _moveToNextHand();
    
    return true;
  }
  
  /// Split - create two hands from a pair
  bool split() {
    if (!_canPerformAction(BlackjackAction.split)) return false;
    
    final splitBet = _handBets[_currentHandIndex];
    
    // Check if player can afford to split
    if (!_isDemoMode && splitBet > _balance) return false;
    
    // Deduct split bet
    if (!_isDemoMode) {
      _balance -= splitBet;
    }
    
    // Split the hand
    final splitCard = currentHand.split();
    if (splitCard == null) return false;
    
    // Create new hand
    final newHand = BlackjackHand();
    newHand.addCard(splitCard);
    
    // Insert new hand after current hand
    _playerHands.insert(_currentHandIndex + 1, newHand);
    _handBets.insert(_currentHandIndex + 1, splitBet);
    
    // Deal one card to each split hand
    final card1 = _dealCard();
    final card2 = _dealCard();
    
    if (card1 != null) currentHand.addCard(card1);
    if (card2 != null) _playerHands[_currentHandIndex + 1].addCard(card2);
    
    return true;
  }
  
  /// Surrender - forfeit half the bet and end the hand
  bool surrender() {
    if (!_canPerformAction(BlackjackAction.surrender)) return false;
    
    // Return half the bet
    if (!_isDemoMode) {
      _balance += (_handBets[_currentHandIndex] / 2).round();
    }
    
    // Mark hand as surrendered and finish game
    return _finishGame();
  }
  
  /// Get available actions for current hand
  List<BlackjackAction> getAvailableActions() {
    if (!_gameInProgress || _dealerTurn) return [];
    
    final actions = <BlackjackAction>[];
    
    if (_canPerformAction(BlackjackAction.hit)) actions.add(BlackjackAction.hit);
    if (_canPerformAction(BlackjackAction.stand)) actions.add(BlackjackAction.stand);
    if (_canPerformAction(BlackjackAction.doubleDown)) actions.add(BlackjackAction.doubleDown);
    if (_canPerformAction(BlackjackAction.split)) actions.add(BlackjackAction.split);
    if (_canPerformAction(BlackjackAction.surrender)) actions.add(BlackjackAction.surrender);
    
    return actions;
  }
  
  /// Get optimal basic strategy action
  BlackjackAction getBasicStrategyAction() {
    if (!_gameInProgress || _dealerTurn) return BlackjackAction.stand;
    
    final playerValue = currentHand.value;
    final dealerUpCard = _dealerHand.cards.first.rank.blackjackValue;
    final canDouble = getAvailableActions().contains(BlackjackAction.doubleDown);
    
    // Basic strategy logic (simplified)
    if (currentHand.canSplit && getAvailableActions().contains(BlackjackAction.split)) {
      final pairValue = currentHand.cards.first.rank.blackjackValue;
      
      // Always split Aces and 8s
      if (pairValue == 11 || pairValue == 8) return BlackjackAction.split;
      
      // Never split 10s, 5s, or 4s
      if (pairValue == 10 || pairValue == 5 || pairValue == 4) {
        // Continue to regular strategy
      } else {
        // Simplified split strategy
        if ((pairValue == 2 || pairValue == 3) && dealerUpCard <= 7) return BlackjackAction.split;
        if (pairValue == 6 && dealerUpCard <= 6) return BlackjackAction.split;
        if (pairValue == 7 && dealerUpCard <= 7) return BlackjackAction.split;
        if (pairValue == 9 && dealerUpCard != 7 && dealerUpCard != 10 && dealerUpCard != 11) return BlackjackAction.split;
      }
    }
    
    // Soft hands (with Ace)
    if (currentHand.isSoft) {
      if (playerValue <= 17) return BlackjackAction.hit;
      if (playerValue == 18 && dealerUpCard >= 9) return BlackjackAction.hit;
      return BlackjackAction.stand;
    }
    
    // Hard hands
    if (playerValue <= 8) return BlackjackAction.hit;
    if (playerValue == 9 && canDouble && dealerUpCard >= 3 && dealerUpCard <= 6) return BlackjackAction.doubleDown;
    if (playerValue == 10 && canDouble && dealerUpCard <= 9) return BlackjackAction.doubleDown;
    if (playerValue == 11 && canDouble && dealerUpCard <= 10) return BlackjackAction.doubleDown;
    if (playerValue <= 11) return BlackjackAction.hit;
    if (playerValue <= 16 && dealerUpCard >= 7) return BlackjackAction.hit;
    
    return BlackjackAction.stand;
  }
  
  /// Reset game statistics
  void resetStats() {
    _totalGames = 0;
    _totalWins = 0;
    _totalBlackjacks = 0;
    _totalWagered = 0;
    _totalWon = 0;
    _history.clear();
  }
  
  /// Get game statistics summary
  Map<String, dynamic> getStats() {
    return {
      'totalGames': _totalGames,
      'totalWins': _totalWins,
      'totalBlackjacks': _totalBlackjacks,
      'winRate': winRate,
      'totalWagered': _totalWagered,
      'totalWon': _totalWon,
      'actualRtp': actualRtp,
      'balance': _balance,
      'averageBet': _totalGames > 0 ? _totalWagered / _totalGames : 0,
      'biggestWin': _history.isNotEmpty 
          ? _history.map((r) => r.netResult).reduce((a, b) => a > b ? a : b)
          : 0,
    };
  }
  
  // Private methods
  
  void _resetGame() {
    _dealerHand.clear();
    _playerHands = [BlackjackHand()];
    _handBets = [0];
    _currentHandIndex = 0;
    _gameInProgress = false;
    _dealerTurn = false;
  }
  
  void _dealInitialCards() {
    // Deal two cards to player
    final playerCard1 = _dealCard();
    final playerCard2 = _dealCard();
    
    // Deal two cards to dealer (second card hidden)
    final dealerCard1 = _dealCard();
    final dealerCard2 = _dealCard();
    
    if (playerCard1 != null) _playerHands[0].addCard(playerCard1);
    if (playerCard2 != null) _playerHands[0].addCard(playerCard2);
    
    if (dealerCard1 != null) _dealerHand.addCard(dealerCard1);
    if (dealerCard2 != null) _dealerHand.addCard(dealerCard2.copyWith(isHidden: true));
  }
  
  PlayingCard? _dealCard() {
    // Try each deck until we find one with cards
    for (final deck in _decks) {
      final card = deck.dealCard();
      if (card != null) {
        // Reshuffle if deck is getting low
        if (deck.needsReshuffle) {
          deck.reset();
        }
        return card;
      }
    }
    
    // All decks empty - reshuffle all
    for (final deck in _decks) {
      deck.reset();
    }
    
    return _decks.first.dealCard();
  }
  
  bool _canPerformAction(BlackjackAction action) {
    if (!_gameInProgress || _dealerTurn || currentHand.isBust) return false;
    
    switch (action) {
      case BlackjackAction.hit:
        return true;
      case BlackjackAction.stand:
        return true;
      case BlackjackAction.doubleDown:
        return currentHand.cardCount == 2 && 
               (_isDemoMode || _handBets[_currentHandIndex] <= _balance);
      case BlackjackAction.split:
        return currentHand.canSplit && 
               _playerHands.length < config.maxSplitHands &&
               (_isDemoMode || _handBets[_currentHandIndex] <= _balance);
      case BlackjackAction.surrender:
        return config.surrenderAllowed && 
               currentHand.cardCount == 2 && 
               _playerHands.length == 1;
    }
  }
  
  void _moveToNextHand() {
    _currentHandIndex++;
    
    if (_currentHandIndex >= _playerHands.length) {
      // All player hands complete - dealer's turn
      _playDealerHand();
    }
  }
  
  void _playDealerHand() {
    _dealerTurn = true;
    
    // Reveal hole card
    _dealerHand.cards[1] = _dealerHand.cards[1].copyWith(isHidden: false);
    
    // Dealer hits on soft 17 if configured
    while (_shouldDealerHit()) {
      final card = _dealCard();
      if (card != null) {
        _dealerHand.addCard(card);
      }
    }
    
    _finishGame();
  }
  
  bool _shouldDealerHit() {
    final dealerValue = _dealerHand.value;
    
    if (dealerValue < 17) return true;
    if (dealerValue > 17) return false;
    
    // Exactly 17 - check if it's soft and dealer hits soft 17
    return config.dealerHitsOn17 && _dealerHand.isSoft;
  }
  
  bool _finishGame() {
    final startTime = DateTime.now();
    
    // Calculate results for each hand
    final handResults = <HandResult>[];
    int totalPayout = 0;
    int totalBet = 0;
    
    for (int i = 0; i < _playerHands.length; i++) {
      final hand = _playerHands[i];
      final bet = _handBets[i];
      totalBet += bet;
      
      final result = _calculateHandResult(hand, bet);
      handResults.add(result);
      totalPayout += result.payout;
      
      // Add payout to balance
      if (!_isDemoMode) {
        _balance += result.payout;
      }
    }
    
    // Update statistics
    _totalGames++;
    _totalWagered += totalBet;
    _totalWon += totalPayout;
    
    if (totalPayout > totalBet) {
      _totalWins++;
    }
    
    if (handResults.any((r) => r.result == BlackjackResult.blackjack)) {
      _totalBlackjacks++;
    }
    
    final gameResult = BlackjackGameResult(
      dealerHand: _dealerHand,
      playerHands: handResults,
      totalBet: totalBet,
      totalPayout: totalPayout,
      timestamp: DateTime.now(),
      gameDuration: DateTime.now().difference(startTime).inMilliseconds / 1000.0,
    );
    
    // Add to history (keep last 100 games)
    _history.add(gameResult);
    if (_history.length > 100) {
      _history = _history.skip(_history.length - 100).toList();
    }
    
    _gameInProgress = false;
    return true;
  }
  
  HandResult _calculateHandResult(BlackjackHand hand, int bet) {
    BlackjackResult result;
    int payout = 0;
    
    if (hand.isBust) {
      result = BlackjackResult.bust;
      payout = 0;
    } else if (hand.isBlackjack && !_dealerHand.isBlackjack) {
      result = BlackjackResult.blackjack;
      payout = bet + (bet * config.blackjackPayout).round();
    } else if (_dealerHand.isBust) {
      result = BlackjackResult.win;
      payout = bet * 2;
    } else if (hand.value > _dealerHand.value) {
      result = BlackjackResult.win;
      payout = bet * 2;
    } else if (hand.value == _dealerHand.value) {
      result = BlackjackResult.push;
      payout = bet; // Return original bet
    } else {
      result = BlackjackResult.lose;
      payout = 0;
    }
    
    return HandResult(
      hand: hand,
      result: result,
      bet: bet,
      payout: payout,
    );
  }
}