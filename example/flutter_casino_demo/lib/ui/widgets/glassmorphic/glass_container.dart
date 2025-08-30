import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Premium glassmorphic container with blur effects and casino styling
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.blurIntensity = 10,
    this.opacity = 0.1,
    this.borderWidth = 1,
    this.borderOpacity = 0.2,
    this.shadowIntensity = 0.3,
    this.gradient,
    this.border,
    this.glowEffect = false,
    this.glowColor,
    this.glowIntensity = 0.5,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blurIntensity;
  final double opacity;
  final double borderWidth;
  final double borderOpacity;
  final double shadowIntensity;
  final Gradient? gradient;
  final Border? border;
  final bool glowEffect;
  final Color? glowColor;
  final double glowIntensity;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;
    
    final effectiveGlowColor = glowColor ?? casinoColors.primaryGold;
    final backgroundGradient = gradient ?? 
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(opacity * 0.7),
            Colors.white.withOpacity(opacity * 0.3),
          ],
        );

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(
          color: Colors.white.withOpacity(borderOpacity),
          width: borderWidth,
        ),
        gradient: backgroundGradient,
        boxShadow: _buildBoxShadows(effectiveGlowColor, casinoColors),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity,
            sigmaY: blurIntensity,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      container = GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }

  List<BoxShadow> _buildBoxShadows(Color glowColor, CasinoColorScheme colors) {
    List<BoxShadow> shadows = [];

    // Basic shadow
    shadows.add(
      BoxShadow(
        color: Colors.black.withOpacity(shadowIntensity * 0.5),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
    );

    // Inner highlight
    shadows.add(
      BoxShadow(
        color: Colors.white.withOpacity(0.1),
        blurRadius: 1,
        spreadRadius: 0,
        offset: const Offset(0, -1),
      ),
    );

    // Glow effect
    if (glowEffect) {
      shadows.addAll([
        BoxShadow(
          color: glowColor.withOpacity(glowIntensity * 0.6),
          blurRadius: 20,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: glowColor.withOpacity(glowIntensity * 0.3),
          blurRadius: 40,
          spreadRadius: 4,
          offset: Offset.zero,
        ),
      ]);
    }

    return shadows;
  }
}

/// Specialized glass container variants for common use cases
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(8),
    this.onTap,
    this.glowEffect = false,
    this.glowColor,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool glowEffect;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      borderRadius: 24,
      blurIntensity: 15,
      opacity: 0.15,
      borderOpacity: 0.3,
      shadowIntensity: 0.4,
      glowEffect: glowEffect,
      glowColor: glowColor,
      glowIntensity: 0.6,
      onTap: onTap,
      child: child,
    );
  }
}

/// Premium glass panel with gold accents
class PremiumGlassPanel extends StatelessWidget {
  const PremiumGlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.all(12),
    this.title,
    this.subtitle,
    this.onTap,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;

    return GlassContainer(
      width: width,
      height: height,
      margin: margin,
      borderRadius: 28,
      blurIntensity: 20,
      opacity: 0.2,
      borderOpacity: 0.4,
      shadowIntensity: 0.5,
      glowEffect: true,
      glowColor: casinoColors.primaryGold,
      glowIntensity: 0.3,
      onTap: onTap,
      border: Border.all(
        color: casinoColors.primaryGold.withOpacity(0.3),
        width: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || subtitle != null) ...[
            _buildHeader(theme, casinoColors),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, CasinoColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            colors.primaryGold.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: colors.primaryGold.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.primaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Floating glass container with enhanced effects
class FloatingGlassContainer extends StatefulWidget {
  const FloatingGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(10),
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 300),
    this.hoverEffect = true,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Duration animationDuration;
  final bool hoverEffect;

  @override
  State<FloatingGlassContainer> createState() => _FloatingGlassContainerState();
}

class _FloatingGlassContainerState extends State<FloatingGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    if (!widget.hoverEffect) return;
    
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GlassContainer(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              margin: widget.margin,
              borderRadius: 24,
              blurIntensity: 12,
              opacity: 0.12,
              borderOpacity: _isHovered ? 0.4 : 0.25,
              shadowIntensity: _elevationAnimation.value,
              glowEffect: _isHovered,
              glowColor: casinoColors.primaryGold,
              glowIntensity: 0.4,
              onTap: widget.onTap,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}