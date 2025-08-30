import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../roulette_engine.dart';
import '../../../ui/theme/app_theme.dart';

/// Animated spinning roulette wheel widget
class RouletteWheel extends StatefulWidget {
  final double rotation;
  final double ballRotation;
  final RouletteAnimationState animationState;
  final RouletteNumber? winningNumber;
  final double size;
  final RouletteType type;
  final VoidCallback? onTap;
  
  const RouletteWheel({
    super.key,
    required this.rotation,
    required this.ballRotation,
    required this.animationState,
    this.winningNumber,
    this.size = 300,
    this.type = RouletteType.european,
    this.onTap,
  });

  @override
  State<RouletteWheel> createState() => _RouletteWheelState();
}

class _RouletteWheelState extends State<RouletteWheel>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(RouletteWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.animationState != oldWidget.animationState) {
      if (widget.animationState == RouletteAnimationState.celebrating) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer rim
                _buildOuterRim(),
                
                // Rotating wheel
                Transform.rotate(
                  angle: widget.rotation * math.pi / 180,
                  child: _buildWheel(),
                ),
                
                // Center hub
                _buildCenterHub(),
                
                // Ball
                _buildBall(),
                
                // Win glow effect
                if (widget.animationState == RouletteAnimationState.celebrating)
                  _buildWinGlow(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOuterRim() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            CasinoColors.darkGold,
            CasinoColors.gold,
            CasinoColors.darkGold,
          ],
          stops: const [0.85, 0.92, 1.0],
        ),
        boxShadow: CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.5),
      ),
    );
  }

  Widget _buildWheel() {
    return Container(
      width: widget.size * 0.85,
      height: widget.size * 0.85,
      child: CustomPaint(
        painter: RouletteWheelPainter(
          type: widget.type,
          winningNumber: widget.winningNumber,
          animationState: widget.animationState,
        ),
      ),
    );
  }

  Widget _buildCenterHub() {
    return Container(
      width: widget.size * 0.15,
      height: widget.size * 0.15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            CasinoColors.gold,
            CasinoColors.darkGold,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.fiber_manual_record,
          color: CasinoColors.darkGold,
          size: widget.size * 0.03,
        ),
      ),
    );
  }

  Widget _buildBall() {
    final ballSize = widget.size * 0.03;
    final ballRadius = widget.size * 0.35;
    
    return Transform.rotate(
      angle: widget.ballRotation * math.pi / 180,
      child: Transform.translate(
        offset: Offset(ballRadius, 0),
        child: Container(
          width: ballSize,
          height: ballSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white,
                Colors.grey.shade300,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinGlow() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.transparent,
            CasinoColors.gold.withOpacity(0.3 * _glowAnimation.value),
            CasinoColors.goldGlow.withOpacity(0.5 * _glowAnimation.value),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }
}

/// Custom painter for the roulette wheel numbers and colors
class RouletteWheelPainter extends CustomPainter {
  final RouletteType type;
  final RouletteNumber? winningNumber;
  final RouletteAnimationState animationState;
  
  RouletteWheelPainter({
    required this.type,
    this.winningNumber,
    required this.animationState,
  });
  
  static const List<int> _europeanLayout = [
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
    5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
  ];
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final numbers = _europeanLayout;
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = CasinoColors.darkBackground
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw number sectors
    for (int i = 0; i < numbers.length; i++) {
      final number = numbers[i];
      final startAngle = (i * 2 * math.pi / numbers.length) - (math.pi / 2);
      final sweepAngle = 2 * math.pi / numbers.length;
      
      _drawSector(
        canvas,
        center,
        radius,
        startAngle,
        sweepAngle,
        number,
        _getNumberColor(number),
      );
    }
    
    // Draw separator lines
    _drawSeparatorLines(canvas, center, radius, numbers.length);
    
    // Highlight winning number
    if (winningNumber != null && animationState == RouletteAnimationState.celebrating) {
      _highlightWinningNumber(canvas, center, radius, numbers);
    }
  }
  
  void _drawSector(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, int number, Color color) {
    // Draw sector background
    final sectorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      startAngle,
      sweepAngle,
      false,
    );
    path.close();
    
    canvas.drawPath(path, sectorPaint);
    
    // Draw number text
    _drawNumberText(canvas, center, radius, startAngle, sweepAngle, number);
  }
  
  void _drawNumberText(Canvas canvas, Offset center, double radius,
      double startAngle, double sweepAngle, int number) {
    final textAngle = startAngle + sweepAngle / 2;
    final textRadius = radius * 0.75;
    
    final textX = center.dx + textRadius * math.cos(textAngle);
    final textY = center.dy + textRadius * math.sin(textAngle);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.08,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Rotate text to be upright
    canvas.save();
    canvas.translate(textX, textY);
    
    // Adjust rotation so text is always readable
    double rotationAngle = textAngle + math.pi / 2;
    if (rotationAngle > math.pi / 2 && rotationAngle < 3 * math.pi / 2) {
      rotationAngle += math.pi;
    }
    
    canvas.rotate(rotationAngle);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }
  
  void _drawSeparatorLines(Canvas canvas, Offset center, double radius, int segments) {
    final linePaint = Paint()
      ..color = CasinoColors.gold
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < segments; i++) {
      final angle = (i * 2 * math.pi / segments) - (math.pi / 2);
      final startX = center.dx + (radius * 0.7) * math.cos(angle);
      final startY = center.dy + (radius * 0.7) * math.sin(angle);
      final endX = center.dx + (radius * 0.9) * math.cos(angle);
      final endY = center.dy + (radius * 0.9) * math.sin(angle);
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);
    }
  }
  
  void _highlightWinningNumber(Canvas canvas, Offset center, double radius, List<int> numbers) {
    if (winningNumber == null) return;
    
    final numberIndex = numbers.indexOf(winningNumber!.number);
    if (numberIndex == -1) return;
    
    final startAngle = (numberIndex * 2 * math.pi / numbers.length) - (math.pi / 2);
    final sweepAngle = 2 * math.pi / numbers.length;
    
    // Draw highlight glow
    final glowPaint = Paint()
      ..color = CasinoColors.gold.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
    
    final path = Path();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      startAngle,
      sweepAngle,
    );
    
    canvas.drawPath(path, glowPaint);
  }
  
  Color _getNumberColor(int number) {
    if (number == 0) return CasinoColors.emerald;
    
    const redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
    return redNumbers.contains(number) ? CasinoColors.ruby : Colors.black;
  }
  
  @override
  bool shouldRepaint(RouletteWheelPainter oldDelegate) {
    return winningNumber != oldDelegate.winningNumber ||
           animationState != oldDelegate.animationState;
  }
}

/// Roulette number display widget
class RouletteNumberDisplay extends StatelessWidget {
  final int number;
  final bool isHighlighted;
  final double size;
  final VoidCallback? onTap;
  
  const RouletteNumberDisplay({
    super.key,
    required this.number,
    this.isHighlighted = false,
    this.size = 40,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rouletteNumber = RouletteNumber(number);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getBackgroundColor(rouletteNumber.color),
          border: Border.all(
            color: isHighlighted ? CasinoColors.gold : Colors.white.withOpacity(0.3),
            width: isHighlighted ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isHighlighted
              ? CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.5)
              : null,
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getBackgroundColor(RouletteColor color) {
    switch (color) {
      case RouletteColor.red:
        return CasinoColors.ruby;
      case RouletteColor.black:
        return Colors.black;
      case RouletteColor.green:
        return CasinoColors.emerald;
    }
  }
}

/// Recent numbers display
class RecentNumbersDisplay extends StatelessWidget {
  final List<int> recentNumbers;
  final int? highlightedNumber;
  
  const RecentNumbersDisplay({
    super.key,
    required this.recentNumbers,
    this.highlightedNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).casinoColors.glassBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).casinoColors.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Numbers',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: CasinoColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentNumbers.map((number) {
              return RouletteNumberDisplay(
                number: number,
                size: 35,
                isHighlighted: number == highlightedNumber,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Hot and cold numbers statistics
class HotColdNumbers extends StatelessWidget {
  final List<MapEntry<int, int>> hotNumbers;
  final List<MapEntry<int, int>> coldNumbers;
  
  const HotColdNumbers({
    super.key,
    required this.hotNumbers,
    required this.coldNumbers,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildNumberList(
            context,
            'Hot Numbers',
            hotNumbers,
            CasinoColors.ruby,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNumberList(
            context,
            'Cold Numbers',
            coldNumbers,
            Colors.blue,
          ),
        ),
      ],
    );
  }
  
  Widget _buildNumberList(
    BuildContext context,
    String title,
    List<MapEntry<int, int>> numbers,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).casinoColors.glassBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...numbers.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RouletteNumberDisplay(
                  number: entry.key,
                  size: 30,
                ),
                Text(
                  '${entry.value}x',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}