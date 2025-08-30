import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../slots_engine.dart';
import '../../../ui/theme/app_theme.dart';

/// Animated spinning reel widget for slot machine
class ReelWidget extends StatefulWidget {
  final int reelIndex;
  final List<SlotSymbol> symbols;
  final bool isSpinning;
  final double spinSpeed;
  final bool isWinningReel;
  final List<bool> winningPositions;
  final VoidCallback? onSpinComplete;
  
  const ReelWidget({
    super.key,
    required this.reelIndex,
    required this.symbols,
    required this.isSpinning,
    this.spinSpeed = 1.0,
    this.isWinningReel = false,
    this.winningPositions = const [false, false, false],
    this.onSpinComplete,
  });

  @override
  State<ReelWidget> createState() => _ReelWidgetState();
}

class _ReelWidgetState extends State<ReelWidget>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _stopController;
  late AnimationController _winController;
  
  late Animation<double> _spinAnimation;
  late Animation<double> _stopAnimation;
  late Animation<double> _winGlowAnimation;
  
  bool _wasPreviouslySpinning = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Continuous spin animation
    _spinController = AnimationController(
      duration: Duration(milliseconds: (1000 / widget.spinSpeed).round()),
      vsync: this,
    );
    
    _spinAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.linear,
    ));
    
    // Stop animation with bounce effect
    _stopController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _stopAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stopController,
      curve: Curves.elasticOut,
    ));
    
    // Win glow animation
    _winController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _winGlowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _winController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(ReelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle spin state changes
    if (widget.isSpinning != oldWidget.isSpinning) {
      if (widget.isSpinning) {
        _startSpinning();
      } else {
        _stopSpinning();
      }
    }
    
    // Handle win state changes
    if (widget.isWinningReel != oldWidget.isWinningReel) {
      if (widget.isWinningReel) {
        _startWinAnimation();
      } else {
        _winController.reset();
      }
    }
    
    // Update spin speed
    if (widget.spinSpeed != oldWidget.spinSpeed && widget.isSpinning) {
      _updateSpinSpeed();
    }
  }

  void _startSpinning() {
    _winController.reset();
    _stopController.reset();
    _spinController.repeat();
    _wasPreviouslySpinning = true;
  }

  void _stopSpinning() {
    if (_wasPreviouslySpinning) {
      _spinController.stop();
      _stopController.forward().then((_) {
        widget.onSpinComplete?.call();
      });
      _wasPreviouslySpinning = false;
    }
  }

  void _startWinAnimation() {
    _winController.repeat(reverse: true);
  }

  void _updateSpinSpeed() {
    if (_spinController.isAnimating) {
      _spinController.duration = Duration(
        milliseconds: (1000 / widget.spinSpeed).round(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 80,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.casinoColors.glassBorder,
          width: 2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.casinoColors.glassBackground.withOpacity(0.3),
            theme.casinoColors.glassBackground.withOpacity(0.1),
            theme.casinoColors.glassBackground.withOpacity(0.3),
          ],
        ),
        boxShadow: widget.isWinningReel
            ? CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.8)
            : CasinoColors.glassMorphismShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _spinAnimation,
            _stopAnimation,
            _winGlowAnimation,
          ]),
          builder: (context, child) {
            return Stack(
              children: [
                // Background pattern
                _buildReelBackground(),
                
                // Symbol column
                _buildSymbolColumn(),
                
                // Win glow overlay
                if (widget.isWinningReel) _buildWinGlow(),
                
                // Reel frame overlay
                _buildReelFrame(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReelBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.transparent,
            Colors.black.withOpacity(0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolColumn() {
    return Transform.translate(
      offset: Offset(0, _getSpinOffset()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Extra symbols above for smooth spinning effect
          if (widget.isSpinning) ..._buildSpinningSymbols(),
          
          // Actual visible symbols
          for (int i = 0; i < widget.symbols.length; i++)
            _buildSymbolCell(widget.symbols[i], i),
          
          // Extra symbols below for smooth spinning effect
          if (widget.isSpinning) ..._buildSpinningSymbols(),
        ],
      ),
    );
  }

  double _getSpinOffset() {
    if (widget.isSpinning) {
      return -(_spinAnimation.value * 240); // Height of 3 symbols
    } else if (_stopController.isAnimating) {
      return -(_stopAnimation.value * 20); // Bounce effect
    }
    return 0;
  }

  List<Widget> _buildSpinningSymbols() {
    // Generate random symbols for spinning effect
    final spinSymbols = SlotSymbol.values.toList()..shuffle();
    return spinSymbols.take(6).map((symbol) => 
        _buildSymbolCell(symbol, -1, isSpinning: true)).toList();
  }

  Widget _buildSymbolCell(SlotSymbol symbol, int position, {bool isSpinning = false}) {
    final isWinning = !isSpinning && 
        position >= 0 && 
        position < widget.winningPositions.length && 
        widget.winningPositions[position];
    
    return Container(
      width: 76,
      height: 76,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isWinning 
            ? CasinoColors.gold.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        border: isWinning 
            ? Border.all(color: CasinoColors.gold, width: 2)
            : null,
        boxShadow: isWinning 
            ? CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.5)
            : null,
      ),
      child: Center(
        child: Text(
          symbol.emoji,
          style: TextStyle(
            fontSize: isWinning ? 32 : 28,
            fontWeight: isWinning ? FontWeight.bold : FontWeight.normal,
          ),
        ).animate(target: isWinning ? 1 : 0)
         .scale(
           duration: const Duration(milliseconds: 300),
           begin: const Offset(1.0, 1.0),
           end: const Offset(1.1, 1.1),
         ),
      ),
    );
  }

  Widget _buildWinGlow() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              CasinoColors.gold.withOpacity(0.3 * _winGlowAnimation.value),
              CasinoColors.goldGlow.withOpacity(0.1 * _winGlowAnimation.value),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReelFrame() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isWinningReel 
                ? CasinoColors.gold.withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
            width: widget.isWinningReel ? 3 : 1,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _stopController.dispose();
    _winController.dispose();
    super.dispose();
  }
}

/// Symbol info display for paytable
class SymbolInfo extends StatelessWidget {
  final SlotSymbol symbol;
  final int baseMultiplier;
  final bool showMultipliers;
  
  const SymbolInfo({
    super.key,
    required this.symbol,
    required this.baseMultiplier,
    this.showMultipliers = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.casinoColors.glassBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.casinoColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Symbol display
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                symbol.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Symbol name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getSymbolName(symbol),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.casinoColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showMultipliers) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getPayoutText(symbol, baseMultiplier),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CasinoColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSymbolName(SlotSymbol symbol) {
    switch (symbol) {
      case SlotSymbol.cherry:
        return 'Cherry';
      case SlotSymbol.lemon:
        return 'Lemon';
      case SlotSymbol.orange:
        return 'Orange';
      case SlotSymbol.plum:
        return 'Plum';
      case SlotSymbol.bell:
        return 'Bell';
      case SlotSymbol.bar:
        return 'Bar';
      case SlotSymbol.seven:
        return 'Lucky Seven';
      case SlotSymbol.diamond:
        return 'Diamond';
      case SlotSymbol.crown:
        return 'Crown';
      case SlotSymbol.jackpot:
        return 'Jackpot';
    }
  }

  String _getPayoutText(SlotSymbol symbol, int bet) {
    final base = symbol.multiplier * bet;
    return '3x: ${base}  4x: ${(base * 2.5).round()}  5x: ${base * 5}';
  }
}