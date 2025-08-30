import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Premium 3D casino chip widget with realistic effects
class CasinoChip extends StatefulWidget {
  const CasinoChip({
    super.key,
    required this.value,
    this.size = 80,
    this.onTap,
    this.isSelected = false,
    this.isAnimating = false,
    this.stackCount = 1,
    this.customColor,
    this.customLabel,
    this.showValue = true,
    this.showShadow = true,
    this.interactive = true,
  });

  final int value;
  final double size;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isAnimating;
  final int stackCount;
  final Color? customColor;
  final String? customLabel;
  final bool showValue;
  final bool showShadow;
  final bool interactive;

  @override
  State<CasinoChip> createState() => _CasinoChipState();
}

class _CasinoChipState extends State<CasinoChip>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _stackController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _stackAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _stackController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _stackAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(
      parent: _stackController,
      curve: Curves.easeInOut,
    ));

    if (widget.isAnimating) {
      _rotationController.repeat();
    }
    
    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CasinoChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
    
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.interactive) return;
    setState(() => _isPressed = true);
    _stackController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.interactive) return;
    setState(() => _isPressed = false);
    _stackController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.interactive) return;
    setState(() => _isPressed = false);
    _stackController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = widget.customColor ?? CasinoColors.getChipColor(widget.value);
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _stackController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value * _stackAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: SizedBox(
                width: widget.size,
                height: widget.size + (widget.stackCount - 1) * (widget.size * 0.1),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shadow
                    if (widget.showShadow)
                      _buildShadow(),
                    
                    // Stack of chips
                    ...List.generate(widget.stackCount, (index) {
                      return _buildSingleChip(
                        context,
                        theme,
                        chipColor,
                        index,
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShadow() {
    return Positioned(
      bottom: 0,
      child: Container(
        width: widget.size * 0.8,
        height: widget.size * 0.2,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(widget.size * 0.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: widget.size * 0.1,
              spreadRadius: widget.size * 0.05,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChip(
    BuildContext context,
    ThemeData theme,
    Color chipColor,
    int stackIndex,
  ) {
    final offset = stackIndex * (widget.size * 0.08);
    
    return Positioned(
      bottom: offset,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1.0,
            colors: [
              chipColor.withOpacity(0.9),
              chipColor,
              chipColor.withOpacity(0.7),
              chipColor.withOpacity(0.4),
            ],
            stops: const [0.0, 0.4, 0.8, 1.0],
          ),
          boxShadow: [
            // Main shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: widget.size * 0.1,
              offset: Offset(0, widget.size * 0.05),
            ),
            // Inner glow
            BoxShadow(
              color: chipColor.withOpacity(0.3),
              blurRadius: widget.size * 0.05,
              offset: Offset.zero,
            ),
            // Selection glow
            if (widget.isSelected)
              BoxShadow(
                color: CasinoColors.gold.withOpacity(0.5),
                blurRadius: widget.size * 0.2,
                spreadRadius: widget.size * 0.02,
                offset: Offset.zero,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Outer ring
            _buildOuterRing(chipColor),
            
            // Inner circle with value
            _buildInnerCircle(theme, chipColor),
            
            // Highlight effect
            _buildHighlight(),
            
            // Edge details
            _buildEdgeDetails(chipColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOuterRing(Color chipColor) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _getContrastColor(chipColor),
          width: widget.size * 0.03,
        ),
      ),
    );
  }

  Widget _buildInnerCircle(ThemeData theme, Color chipColor) {
    return Center(
      child: Container(
        width: widget.size * 0.7,
        height: widget.size * 0.7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: chipColor.withOpacity(0.2),
          border: Border.all(
            color: _getContrastColor(chipColor).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.showValue) ...[
                Text(
                  widget.customLabel ?? _formatValue(widget.value),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _getContrastColor(chipColor),
                    fontWeight: FontWeight.bold,
                    fontSize: widget.size * 0.12,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.value >= 1000)
                  Text(
                    _getCurrency(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getContrastColor(chipColor).withOpacity(0.8),
                      fontSize: widget.size * 0.08,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlight() {
    return Positioned(
      top: widget.size * 0.15,
      left: widget.size * 0.15,
      child: Container(
        width: widget.size * 0.25,
        height: widget.size * 0.25,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.4),
              Colors.white.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeDetails(Color chipColor) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: ChipEdgePainter(
        color: chipColor,
        contrastColor: _getContrastColor(chipColor),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we need dark or light text
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  String _formatValue(int value) {
    if (value < 1000) {
      return value.toString();
    } else if (value < 1000000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    } else {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
  }

  String _getCurrency() {
    return widget.value >= 1000 ? '\$' : '';
  }
}

/// Custom painter for chip edge details
class ChipEdgePainter extends CustomPainter {
  const ChipEdgePainter({
    required this.color,
    required this.contrastColor,
  });

  final Color color;
  final Color contrastColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Edge notches
    final paint = Paint()
      ..color = contrastColor.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 2 * math.pi) / 12;
      final startRadius = radius * 0.85;
      final endRadius = radius * 0.95;
      
      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );
      
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chip stack for multiple chips
class ChipStack extends StatelessWidget {
  const ChipStack({
    super.key,
    required this.chips,
    this.maxVisible = 5,
    this.size = 60,
    this.onTap,
    this.spacing = 0.08,
  });

  final List<int> chips;
  final int maxVisible;
  final double size;
  final VoidCallback? onTap;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    
    final visibleChips = chips.take(maxVisible).toList();
    final remainingCount = chips.length - maxVisible;
    
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + (visibleChips.length - 1) * (size * spacing),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...visibleChips.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              final offset = index * (size * spacing);
              
              return Positioned(
                bottom: offset,
                child: CasinoChip(
                  value: value,
                  size: size,
                  interactive: false,
                  showShadow: index == 0,
                ),
              );
            }).toList(),
            
            // Remaining count indicator
            if (remainingCount > 0)
              Positioned(
                top: 0,
                right: -size * 0.1,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: CasinoColors.ruby,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated chip for winning effects
class WinningChip extends StatefulWidget {
  const WinningChip({
    super.key,
    required this.value,
    required this.onAnimationComplete,
    this.size = 80,
    this.duration = const Duration(seconds: 2),
  });

  final int value;
  final VoidCallback onAnimationComplete;
  final double size;
  final Duration duration;

  @override
  State<WinningChip> createState() => _WinningChipState();
}

class _WinningChipState extends State<WinningChip>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _controller.forward().then((_) => widget.onAnimationComplete());
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 4 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: CasinoChip(
                value: widget.value,
                size: widget.size,
                isAnimating: true,
                interactive: false,
                showShadow: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Chip selector widget for betting
class ChipSelector extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.availableChips,
    required this.selectedChip,
    required this.onChipSelected,
    this.size = 60,
    this.showLabels = true,
  });

  final List<int> availableChips;
  final int? selectedChip;
  final ValueChanged<int> onChipSelected;
  final double size;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableChips.map((value) {
        final isSelected = value == selectedChip;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CasinoChip(
              value: value,
              size: size,
              isSelected: isSelected,
              onTap: () => onChipSelected(value),
            ).animate(
              delay: Duration(milliseconds: availableChips.indexOf(value) * 100),
            ).slideY(
              begin: 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
            ).fadeIn(),
            
            if (showLabels) ...[
              const SizedBox(height: 4),
              Text(
                '\$${value}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? CasinoColors.gold
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}