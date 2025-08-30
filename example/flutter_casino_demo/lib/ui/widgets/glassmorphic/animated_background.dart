import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Premium animated background with casino-style effects
class CasinoAnimatedBackground extends StatefulWidget {
  const CasinoAnimatedBackground({
    super.key,
    required this.child,
    this.showParticles = true,
    this.showGradientAnimation = true,
    this.showGeometricShapes = true,
    this.particleCount = 50,
    this.animationSpeed = 1.0,
    this.intensity = 1.0,
    this.backgroundType = CasinoBackgroundType.premium,
  });

  final Widget child;
  final bool showParticles;
  final bool showGradientAnimation;
  final bool showGeometricShapes;
  final int particleCount;
  final double animationSpeed;
  final double intensity;
  final CasinoBackgroundType backgroundType;

  @override
  State<CasinoAnimatedBackground> createState() => _CasinoAnimatedBackgroundState();
}

class _CasinoAnimatedBackgroundState extends State<CasinoAnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _secondaryController;
  late AnimationController _particleController;
  
  late Animation<double> _gradientAnimation;
  late Animation<double> _shapeAnimation;
  
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeParticles();
  }

  void _setupAnimations() {
    _primaryController = AnimationController(
      duration: Duration(seconds: (8 / widget.animationSpeed).round()),
      vsync: this,
    );
    
    _secondaryController = AnimationController(
      duration: Duration(seconds: (12 / widget.animationSpeed).round()),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: Duration(seconds: (6 / widget.animationSpeed).round()),
      vsync: this,
    );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.easeInOut),
    );

    _shapeAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _secondaryController, curve: Curves.linear),
    );

    _primaryController.repeat(reverse: true);
    _secondaryController.repeat();
    if (widget.showParticles) {
      _particleController.repeat();
    }
  }

  void _initializeParticles() {
    if (!widget.showParticles) return;
    
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle.random(_random, widget.intensity));
    }
  }

  @override
  void didUpdateWidget(CasinoAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.particleCount != oldWidget.particleCount ||
        widget.intensity != oldWidget.intensity) {
      _initializeParticles();
    }
    
    if (widget.animationSpeed != oldWidget.animationSpeed) {
      _setupAnimations();
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Base gradient background
          _buildBaseGradient(),
          
          // Animated gradient overlay
          if (widget.showGradientAnimation)
            _buildAnimatedGradient(),
          
          // Geometric shapes
          if (widget.showGeometricShapes)
            _buildGeometricShapes(),
          
          // Particle system
          if (widget.showParticles)
            _buildParticleSystem(),
          
          // Glass overlay
          _buildGlassOverlay(),
          
          // Child content
          widget.child,
        ],
      ),
    );
  }

  Widget _buildBaseGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: _getBackgroundGradient(),
      ),
    );
  }

  Widget _buildAnimatedGradient() {
    return AnimatedBuilder(
      animation: _gradientAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5 + (_gradientAnimation.value * 0.5),
              colors: [
                CasinoColors.gold.withOpacity(0.1 * widget.intensity),
                CasinoColors.emerald.withOpacity(0.05 * widget.intensity),
                CasinoColors.ruby.withOpacity(0.03 * widget.intensity),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeometricShapes() {
    return AnimatedBuilder(
      animation: _shapeAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: GeometricShapesPainter(
            animation: _shapeAnimation.value,
            intensity: widget.intensity,
            backgroundType: widget.backgroundType,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildParticleSystem() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleSystemPainter(
            particles: _particles,
            animationValue: _particleController.value,
            intensity: widget.intensity,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGlassOverlay() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.02),
                Colors.white.withOpacity(0.01),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getBackgroundGradient() {
    switch (widget.backgroundType) {
      case CasinoBackgroundType.minimal:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0F),
            Color(0xFF1A1A2E),
          ],
        );
      case CasinoBackgroundType.standard:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: CasinoColors.casinoGradient,
        );
      case CasinoBackgroundType.premium:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0F),
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
        );
      case CasinoBackgroundType.vip:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0F),
            const Color(0xFF1A1A2E),
            CasinoColors.gold.withOpacity(0.1),
            const Color(0xFF16213E),
          ],
        );
    }
  }
}

/// Geometric shapes painter for background decoration
class GeometricShapesPainter extends CustomPainter {
  const GeometricShapesPainter({
    required this.animation,
    required this.intensity,
    required this.backgroundType,
  });

  final double animation;
  final double intensity;
  final CasinoBackgroundType backgroundType;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * intensity;

    _paintDiamondShapes(canvas, size, paint);
    _paintCircularPatterns(canvas, size, paint);
    _paintCardSuits(canvas, size, paint);
    
    if (backgroundType == CasinoBackgroundType.premium ||
        backgroundType == CasinoBackgroundType.vip) {
      _paintLuxuryElements(canvas, size, paint);
    }
  }

  void _paintDiamondShapes(Canvas canvas, Size size, Paint paint) {
    paint.color = CasinoColors.gold.withOpacity(0.1 * intensity);
    
    for (int i = 0; i < 5; i++) {
      final center = Offset(
        size.width * 0.2 * (i + 1),
        size.height * 0.3 + math.sin(animation + i) * 50 * intensity,
      );
      
      final path = Path();
      final diamondSize = 30 + math.sin(animation + i * 0.5) * 10;
      
      path.moveTo(center.dx, center.dy - diamondSize);
      path.lineTo(center.dx + diamondSize, center.dy);
      path.lineTo(center.dx, center.dy + diamondSize);
      path.lineTo(center.dx - diamondSize, center.dy);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  void _paintCircularPatterns(Canvas canvas, Size size, Paint paint) {
    paint.color = CasinoColors.emerald.withOpacity(0.08 * intensity);
    
    for (int i = 0; i < 3; i++) {
      final center = Offset(
        size.width * 0.7,
        size.height * 0.2 + i * size.height * 0.3,
      );
      
      final radius = 40 + math.cos(animation + i * 0.3) * 15;
      canvas.drawCircle(center, radius, paint);
      
      // Inner circle
      paint.strokeWidth = 0.5;
      canvas.drawCircle(center, radius * 0.6, paint);
      paint.strokeWidth = 1.5 * intensity;
    }
  }

  void _paintCardSuits(Canvas canvas, Size size, Paint paint) {
    paint.color = CasinoColors.ruby.withOpacity(0.06 * intensity);
    paint.style = PaintingStyle.fill;
    
    // Spade shape
    final spadeCenter = Offset(
      size.width * 0.9,
      size.height * 0.8 + math.sin(animation * 0.5) * 20,
    );
    
    _drawSpade(canvas, spadeCenter, 25 * intensity, paint);
    
    // Heart shape
    paint.color = CasinoColors.ruby.withOpacity(0.05 * intensity);
    final heartCenter = Offset(
      size.width * 0.1,
      size.height * 0.7 + math.cos(animation * 0.7) * 30,
    );
    
    _drawHeart(canvas, heartCenter, 20 * intensity, paint);
  }

  void _paintLuxuryElements(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.stroke;
    paint.color = CasinoColors.gold.withOpacity(0.15 * intensity);
    
    // Crown pattern
    final crownPath = Path();
    final crownCenter = Offset(size.width * 0.5, size.height * 0.1);
    
    crownPath.moveTo(crownCenter.dx - 40, crownCenter.dy);
    crownPath.lineTo(crownCenter.dx - 20, crownCenter.dy - 30);
    crownPath.lineTo(crownCenter.dx, crownCenter.dy - 20);
    crownPath.lineTo(crownCenter.dx + 20, crownCenter.dy - 35);
    crownPath.lineTo(crownCenter.dx + 40, crownCenter.dy);
    
    canvas.drawPath(crownPath, paint);
  }

  void _drawSpade(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx - size * 0.8, center.dy - size * 0.3,
      center.dx - size * 0.5, center.dy,
    );
    path.quadraticBezierTo(
      center.dx - size * 0.3, center.dy + size * 0.3,
      center.dx, center.dy + size * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.3, center.dy + size * 0.3,
      center.dx + size * 0.5, center.dy,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.8, center.dy - size * 0.3,
      center.dx, center.dy - size,
    );
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.5);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.5,
      center.dx - size * 0.5, center.dy - size,
      center.dx, center.dy - size * 0.3,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size,
      center.dx + size, center.dy - size * 0.5,
      center.dx, center.dy + size * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Particle system painter
class ParticleSystemPainter extends CustomPainter {
  const ParticleSystemPainter({
    required this.particles,
    required this.animationValue,
    required this.intensity,
  });

  final List<Particle> particles;
  final double animationValue;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      particle.update(animationValue, size);
      
      paint.color = particle.color.withOpacity(
        particle.opacity * intensity,
      );
      
      canvas.drawCircle(
        particle.position,
        particle.size * intensity,
        paint,
      );
      
      // Add glow effect for special particles
      if (particle.hasGlow) {
        paint.color = particle.color.withOpacity(
          particle.opacity * 0.3 * intensity,
        );
        canvas.drawCircle(
          particle.position,
          particle.size * 2 * intensity,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Individual particle class
class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.hasGlow,
    required this.lifespan,
    this.age = 0,
  });

  factory Particle.random(Random random, double intensity) {
    final colors = [
      CasinoColors.gold,
      CasinoColors.emerald,
      CasinoColors.ruby,
      CasinoColors.neonBlue,
      CasinoColors.neonPink,
    ];

    return Particle(
      position: Offset(
        random.nextDouble() * 1000,
        random.nextDouble() * 1000,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 2 * intensity,
        (random.nextDouble() - 0.5) * 2 * intensity,
      ),
      color: colors[random.nextInt(colors.length)],
      size: 1.0 + random.nextDouble() * 3 * intensity,
      opacity: 0.3 + random.nextDouble() * 0.4,
      hasGlow: random.nextBool() && intensity > 0.5,
      lifespan: 5.0 + random.nextDouble() * 5,
    );
  }

  Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final double opacity;
  final bool hasGlow;
  final double lifespan;
  double age;

  void update(double deltaTime, Size screenSize) {
    age += deltaTime * 0.016; // Approximate 60fps
    
    position = Offset(
      position.dx + velocity.dx,
      position.dy + velocity.dy,
    );
    
    // Wrap around screen
    if (position.dx < -size) {
      position = Offset(screenSize.width + size, position.dy);
    } else if (position.dx > screenSize.width + size) {
      position = Offset(-size, position.dy);
    }
    
    if (position.dy < -size) {
      position = Offset(position.dx, screenSize.height + size);
    } else if (position.dy > screenSize.height + size) {
      position = Offset(position.dx, -size);
    }
  }
}

/// Floating light orbs widget
class FloatingLightOrbs extends StatefulWidget {
  const FloatingLightOrbs({
    super.key,
    this.orbCount = 8,
    this.size = 100,
    this.color = CasinoColors.gold,
    this.intensity = 0.8,
  });

  final int orbCount;
  final double size;
  final Color color;
  final double intensity;

  @override
  State<FloatingLightOrbs> createState() => _FloatingLightOrbsState();
}

class _FloatingLightOrbsState extends State<FloatingLightOrbs>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _positionAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controllers = List.generate(
      widget.orbCount,
      (index) => AnimationController(
        duration: Duration(seconds: 8 + (index % 3) * 2),
        vsync: this,
      ),
    );

    _positionAnimations = _controllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      
      return Tween<Offset>(
        begin: Offset(
          math.sin(index * 0.5) * 0.3,
          math.cos(index * 0.7) * 0.2,
        ),
        end: Offset(
          math.sin(index * 0.5 + math.pi) * 0.4,
          math.cos(index * 0.7 + math.pi) * 0.3,
        ),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
    }).toList();

    for (final controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _positionAnimations.asMap().entries.map((entry) {
        final index = entry.key;
        final animation = entry.value;
        
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Positioned(
              left: MediaQuery.of(context).size.width * 0.5 + 
                     animation.value.dx * MediaQuery.of(context).size.width,
              top: MediaQuery.of(context).size.height * 0.5 + 
                    animation.value.dy * MediaQuery.of(context).size.height,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(widget.intensity * 0.3),
                      widget.color.withOpacity(widget.intensity * 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

/// Background type enumeration
enum CasinoBackgroundType {
  minimal,    // Simple gradient
  standard,   // Basic casino effects
  premium,    // Enhanced effects
  vip,        // Maximum luxury effects
}