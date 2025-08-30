import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'slots_engine.dart';
import '../../core/agents/agents.dart';

/// Animation states for the slot machine
enum SlotAnimationState {
  idle,
  spinning,
  stopping,
  celebrating,
  paylineFlash,
}

/// View model for slots game with MVVM architecture
class SlotsViewModel extends ChangeNotifier {
  final SlotsEngine _engine;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Animation and UI state
  SlotAnimationState _animationState = SlotAnimationState.idle;
  List<bool> _reelSpinning = [false, false, false, false, false];
  double _spinSpeed = 1.0;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _animationsEnabled = true;
  
  // Game state
  SpinResult? _lastResult;
  List<WinLine> _flashingWinLines = [];
  bool _showPaytable = false;
  bool _showSettings = false;
  String _statusMessage = 'Ready to spin!';
  
  // Auto play state
  bool _autoPlayPaused = false;
  Duration _autoPlayDelay = const Duration(milliseconds: 1500);
  
  SlotsViewModel({
    required SlotsEngine engine,
  }) : _engine = engine;
  
  // Getters for engine state
  int get balance => _engine.balance;
  int get currentBet => _engine.currentBet;
  bool get canSpin => _engine.canSpin();
  SlotConfig get config => _engine.config;
  bool get isDemoMode => _engine.isDemoMode;
  bool get isAutoPlay => _engine.isAutoPlay;
  int get autoPlayRemaining => _engine.autoPlayRemaining;
  Map<String, dynamic> get stats => _engine.getStats();
  List<SpinResult> get history => _engine.history;
  
  // UI state getters
  SlotAnimationState get animationState => _animationState;
  List<bool> get reelSpinning => List.unmodifiable(_reelSpinning);
  SpinResult? get lastResult => _lastResult;
  List<WinLine> get flashingWinLines => List.unmodifiable(_flashingWinLines);
  bool get isSpinning => _animationState == SlotAnimationState.spinning;
  bool get showPaytable => _showPaytable;
  bool get showSettings => _showSettings;
  String get statusMessage => _statusMessage;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get animationsEnabled => _animationsEnabled;
  double get spinSpeed => _spinSpeed;
  
  /// Initialize the slots game
  void initialize(int startingBalance, {bool demoMode = false}) {
    _engine.initialize(startingBalance, demoMode: demoMode);
    _updateStatusMessage();
    notifyListeners();
  }
  
  /// Set bet amount
  void setBet(int amount) {
    if (_engine.setBet(amount)) {
      _updateStatusMessage();
      notifyListeners();
    }
  }
  
  /// Increase bet by one step
  void increaseBet() {
    final betOptions = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000];
    final currentIndex = betOptions.indexOf(currentBet);
    
    if (currentIndex < betOptions.length - 1) {
      setBet(betOptions[currentIndex + 1]);
    }
  }
  
  /// Decrease bet by one step
  void decreaseBet() {
    final betOptions = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000];
    final currentIndex = betOptions.indexOf(currentBet);
    
    if (currentIndex > 0) {
      setBet(betOptions[currentIndex - 1]);
    }
  }
  
  /// Set maximum bet
  void maxBet() {
    final maxAffordable = isDemoMode ? config.maxBet : balance;
    setBet(maxAffordable.clamp(config.minBet, config.maxBet));
  }
  
  /// Perform a single spin
  Future<void> spin() async {
    if (!canSpin || isSpinning) return;
    
    try {
      // Start spin animation
      _startSpinAnimation();
      
      // Play spin sound
      if (_soundEnabled) {
        _playSound('spin_start');
      }
      
      // Haptic feedback
      if (_hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }
      
      // Perform the actual spin
      final result = await _engine.spin();
      
      // Animate reel stopping with staggered timing
      await _animateReelStopping(result);
      
      // Update result and check for wins
      _lastResult = result;
      
      if (result.hasWin) {
        await _celebrateWin(result);
      } else {
        _setAnimationState(SlotAnimationState.idle);
        _statusMessage = 'Try again!';
      }
      
    } catch (e) {
      _setAnimationState(SlotAnimationState.idle);
      _statusMessage = 'Error: ${e.toString()}';
      debugPrint('Spin error: $e');
    }
    
    notifyListeners();
  }
  
  /// Start auto play
  void startAutoPlay(int spins) {
    if (spins <= 0 || !canSpin) return;
    
    _engine.startAutoPlay(spins);
    _autoPlayPaused = false;
    _statusMessage = 'Auto play started ($spins spins)';
    notifyListeners();
    
    _runAutoPlay();
  }
  
  /// Stop auto play
  void stopAutoPlay() {
    _engine.stopAutoPlay();
    _autoPlayPaused = false;
    _statusMessage = 'Auto play stopped';
    notifyListeners();
  }
  
  /// Pause/resume auto play
  void toggleAutoPlayPause() {
    _autoPlayPaused = !_autoPlayPaused;
    
    if (!_autoPlayPaused && isAutoPlay) {
      _runAutoPlay();
    }
    
    notifyListeners();
  }
  
  /// Run auto play sequence
  Future<void> _runAutoPlay() async {
    while (isAutoPlay && !_autoPlayPaused && canSpin) {
      await spin();
      
      if (isAutoPlay && !_autoPlayPaused) {
        await Future.delayed(_autoPlayDelay);
      }
    }
  }
  
  /// Toggle paytable display
  void togglePaytable() {
    _showPaytable = !_showPaytable;
    notifyListeners();
  }
  
  /// Toggle settings display
  void toggleSettings() {
    _showSettings = !_showSettings;
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
  
  /// Update spin speed
  void setSpinSpeed(double speed) {
    _spinSpeed = speed.clamp(0.5, 2.0);
    notifyListeners();
  }
  
  /// Set auto play delay
  void setAutoPlayDelay(Duration delay) {
    _autoPlayDelay = delay;
    notifyListeners();
  }
  
  /// Reset game statistics
  void resetStats() {
    _engine.resetStats();
    _lastResult = null;
    _flashingWinLines.clear();
    _updateStatusMessage();
    notifyListeners();
  }
  
  /// Get symbol at specific position
  SlotSymbol getSymbolAt(int reel, int row) {
    if (_lastResult == null) return SlotSymbol.cherry;
    if (reel < 0 || reel >= _lastResult!.reels.length) return SlotSymbol.cherry;
    if (row < 0 || row >= _lastResult!.reels[reel].length) return SlotSymbol.cherry;
    
    return _lastResult!.reels[reel][row];
  }
  
  /// Check if position is part of winning line
  bool isWinningPosition(int reel, int row) {
    if (_lastResult == null) return false;
    
    final gridPosition = row * config.reelCount + reel;
    
    return _flashingWinLines.any((line) => 
        line.positions.contains(gridPosition));
  }
  
  /// Start spin animation
  void _startSpinAnimation() {
    _setAnimationState(SlotAnimationState.spinning);
    _reelSpinning = List.filled(config.reelCount, true);
    _flashingWinLines.clear();
    _statusMessage = 'Spinning...';
  }
  
  /// Animate reels stopping with staggered timing
  Future<void> _animateReelStopping(SpinResult result) async {
    _setAnimationState(SlotAnimationState.stopping);
    
    // Stop reels one by one with delay
    for (int i = 0; i < config.reelCount; i++) {
      await Future.delayed(Duration(milliseconds: (200 / _spinSpeed).round()));
      _reelSpinning[i] = false;
      
      if (_soundEnabled) {
        _playSound('reel_stop');
      }
      
      if (_hapticsEnabled && i == config.reelCount - 1) {
        HapticFeedback.lightImpact();
      }
      
      notifyListeners();
    }
  }
  
  /// Celebrate winning result
  Future<void> _celebrateWin(SpinResult result) async {
    _setAnimationState(SlotAnimationState.celebrating);
    
    if (result.isJackpot) {
      _statusMessage = '🎰 JACKPOT! You won ${result.totalWin}!';
      if (_soundEnabled) _playSound('jackpot');
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    } else if (result.isBigWin) {
      _statusMessage = '💎 BIG WIN! You won ${result.totalWin}!';
      if (_soundEnabled) _playSound('big_win');
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    } else {
      _statusMessage = '🎉 You won ${result.totalWin}!';
      if (_soundEnabled) _playSound('win');
      if (_hapticsEnabled) HapticFeedback.lightImpact();
    }
    
    // Flash winning paylines
    if (_animationsEnabled) {
      await _flashWinLines(result.winLines);
    }
    
    _setAnimationState(SlotAnimationState.idle);
  }
  
  /// Flash winning paylines animation
  Future<void> _flashWinLines(List<WinLine> winLines) async {
    _setAnimationState(SlotAnimationState.paylineFlash);
    
    for (int flash = 0; flash < 3; flash++) {
      _flashingWinLines = winLines;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
      
      _flashingWinLines.clear();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
  
  /// Set animation state and notify
  void _setAnimationState(SlotAnimationState state) {
    _animationState = state;
    notifyListeners();
  }
  
  /// Play sound effect
  Future<void> _playSound(String soundName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e) {
      debugPrint('Failed to play sound $soundName: $e');
    }
  }
  
  /// Update status message based on game state
  void _updateStatusMessage() {
    if (!canSpin && !isDemoMode) {
      _statusMessage = 'Insufficient balance';
    } else if (isAutoPlay) {
      _statusMessage = 'Auto play: $autoPlayRemaining spins remaining';
    } else {
      _statusMessage = 'Ready to spin!';
    }
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}