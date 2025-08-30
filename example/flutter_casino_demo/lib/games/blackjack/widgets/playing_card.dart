import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../blackjack_engine.dart';
import '../../../ui/theme/app_theme.dart';

/// Animated playing card widget for blackjack
class PlayingCardWidget extends StatefulWidget {
  final PlayingCard? card;
  final bool isHidden;
  final bool isHighlighted;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool showAnimation;
  
  const PlayingCardWidget({
    super.key,
    this.card,
    this.isHidden = false,
    this.isHighlighted = false,
    this.width = 80,
    this.height = 112,
    this.onTap,
    this.showAnimation = true,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _highlightController;
  
  late Animation<double> _flipAnimation;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(PlayingCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle card flip animation
    if (widget.card != null && 
        oldWidget.card?.isHidden != widget.card?.isHidden &&
        widget.showAnimation) {
      if (widget.card!.isHidden) {
        _flipController.reverse();
      } else {
        _flipController.forward();
      }
    }
    
    // Handle highlight animation
    if (widget.isHighlighted != oldWidget.isHighlighted) {
      if (widget.isHighlighted) {
        _highlightController.forward();
      } else {
        _highlightController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card == null) {
      return _buildEmptySlot();
    }
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipAnimation, _highlightAnimation]),
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * 3.14159),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  if (widget.isHighlighted)
                    BoxShadow(
                      color: CasinoColors.gold.withOpacity(0.6 * _highlightAnimation.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: _flipAnimation.value < 0.5 || !widget.showAnimation
                  ? _buildCardFace()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _buildCardFace(),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardFace() {
    final card = widget.card!;
    final isHidden = widget.isHidden || card.isHidden;
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isHighlighted 
              ? CasinoColors.gold 
              : Colors.grey.shade400,
          width: widget.isHighlighted ? 2 : 1,
        ),
      ),
      child: isHidden ? _buildCardBack() : _buildCardFront(card),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CasinoColors.darkBackground,
            CasinoColors.darkSurface,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Pattern background
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              image: const DecorationImage(
                image: AssetImage('assets/images/card_back_pattern.png'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
          ),
          
          // Center logo
          const Center(
            child: Icon(
              Icons.casino,
              color: CasinoColors.gold,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(PlayingCard card) {
    final isRed = card.suit.isRed;
    final suitColor = isRed ? Colors.red : Colors.black;
    
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          // Top-left rank and suit
          Positioned(
            top: 2,
            left: 2,
            child: Column(
              children: [
                Text(
                  card.rank.symbol,
                  style: TextStyle(
                    color: suitColor,
                    fontSize: widget.width * 0.15,
                    fontWeight: FontWeight.bold,
                    height: 0.9,
                  ),
                ),
                Text(
                  card.suit.symbol,
                  style: TextStyle(
                    color: suitColor,
                    fontSize: widget.width * 0.15,
                    height: 0.8,
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom-right rank and suit (upside down)
          Positioned(
            bottom: 2,
            right: 2,
            child: Transform.rotate(
              angle: 3.14159, // 180 degrees
              child: Column(
                children: [
                  Text(
                    card.rank.symbol,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: widget.width * 0.15,
                      fontWeight: FontWeight.bold,
                      height: 0.9,
                    ),
                  ),
                  Text(
                    card.suit.symbol,
                    style: TextStyle(
                      color: suitColor,
                      fontSize: widget.width * 0.15,
                      height: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Center suit symbol(s)
          Center(
            child: _buildCenterPattern(card, suitColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPattern(PlayingCard card, Color suitColor) {
    if (card.isFaceCard) {
      return _buildFaceCardCenter(card, suitColor);
    }
    
    if (card.rank == CardRank.ace) {
      return Text(
        card.suit.symbol,
        style: TextStyle(
          color: suitColor,
          fontSize: widget.width * 0.4,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    
    return _buildNumberCardCenter(card, suitColor);
  }

  Widget _buildFaceCardCenter(PlayingCard card, Color suitColor) {
    String faceSymbol;
    
    switch (card.rank) {
      case CardRank.jack:
        faceSymbol = 'J';
        break;
      case CardRank.queen:
        faceSymbol = 'Q';
        break;
      case CardRank.king:
        faceSymbol = 'K';
        break;
      default:
        faceSymbol = card.rank.symbol;
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          faceSymbol,
          style: TextStyle(
            color: suitColor,
            fontSize: widget.width * 0.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          card.suit.symbol,
          style: TextStyle(
            color: suitColor,
            fontSize: widget.width * 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberCardCenter(PlayingCard card, Color suitColor) {
    final value = card.rank.value;
    
    if (value <= 1 || value > 10) {
      return Text(
        card.suit.symbol,
        style: TextStyle(
          color: suitColor,
          fontSize: widget.width * 0.25,
        ),
      );
    }
    
    // Create pattern based on card value
    return _buildSuitPattern(value, card.suit.symbol, suitColor);
  }

  Widget _buildSuitPattern(int count, String suitSymbol, Color color) {
    final symbols = <Widget>[];
    final symbolSize = widget.width * 0.12;
    
    for (int i = 0; i < count && i < 10; i++) {
      symbols.add(
        Text(
          suitSymbol,
          style: TextStyle(
            color: color,
            fontSize: symbolSize,
            height: 0.8,
          ),
        ),
      );
    }
    
    if (count <= 3) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: symbols,
      );
    } else if (count <= 6) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: symbols.take(2).toList(),
          ),
          if (count >= 4)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: symbols.skip(2).take(2).toList(),
            ),
          if (count >= 6)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: symbols.skip(4).take(2).toList(),
            ),
        ],
      );
    } else {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 1,
        children: symbols,
      );
    }
  }

  Widget _buildEmptySlot() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.add,
          color: Colors.white24,
          size: 24,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _highlightController.dispose();
    super.dispose();
  }
}

/// Hand of cards display widget
class HandDisplayWidget extends StatelessWidget {
  final BlackjackHand hand;
  final bool isDealer;
  final bool isActive;
  final String? label;
  final String? valueText;
  final double cardWidth;
  final double cardSpacing;
  
  const HandDisplayWidget({
    super.key,
    required this.hand,
    this.isDealer = false,
    this.isActive = false,
    this.label,
    this.valueText,
    this.cardWidth = 80,
    this.cardSpacing = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Label and value
        if (label != null || valueText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive 
                  ? CasinoColors.gold.withOpacity(0.2)
                  : theme.casinoColors.glassBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive 
                    ? CasinoColors.gold
                    : theme.casinoColors.glassBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isActive 
                          ? CasinoColors.gold
                          : theme.casinoColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (valueText != null) const SizedBox(width: 8),
                ],
                if (valueText != null)
                  Text(
                    valueText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isActive 
                          ? CasinoColors.gold
                          : CasinoColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Cards
        SizedBox(
          height: cardWidth * 1.4, // Card aspect ratio
          child: Stack(
            children: hand.cards.asMap().entries.map((entry) {
              final index = entry.key;
              final card = entry.value;
              
              return Positioned(
                left: index * cardSpacing,
                child: PlayingCardWidget(
                  card: card,
                  isHidden: card.isHidden,
                  width: cardWidth,
                  height: cardWidth * 1.4,
                  isHighlighted: isActive,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Card dealing animation helper
class CardDealAnimation extends StatefulWidget {
  final Widget child;
  final bool isDealing;
  final Duration delay;
  
  const CardDealAnimation({
    super.key,
    required this.child,
    this.isDealing = false,
    this.delay = Duration.zero,
  });

  @override
  State<CardDealAnimation> createState() => _CardDealAnimationState();
}

class _CardDealAnimationState extends State<CardDealAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(CardDealAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isDealing && !oldWidget.isDealing) {
      _controller.reset();
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}