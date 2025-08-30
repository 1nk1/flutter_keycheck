import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Premium glassmorphic button with casino-style animations and effects
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 56,
    this.borderRadius = 16,
    this.blurIntensity = 10,
    this.glowColor,
    this.backgroundColor,
    this.pressedColor,
    this.disabledColor,
    this.shadowIntensity = 0.3,
    this.hapticFeedback = true,
    this.soundEnabled = false,
    this.gradient,
    this.border,
    this.elevation = 4,
    this.animationDuration = const Duration(milliseconds: 150),
    this.style = GlassButtonStyle.primary,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double height;
  final double borderRadius;
  final double blurIntensity;
  final Color? glowColor;
  final Color? backgroundColor;
  final Color? pressedColor;
  final Color? disabledColor;
  final double shadowIntensity;
  final bool hapticFeedback;
  final bool soundEnabled;
  final Gradient? gradient;
  final Border? border;
  final double elevation;
  final Duration animationDuration;
  final GlassButtonStyle style;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _glowAnimation;
  
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.elevation * 0.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    
    setState(() {
      _isPressed = true;
    });
    
    _controller.forward();
    
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _handleTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    if (!mounted) return;
    
    setState(() {
      _isPressed = false;
    });
    
    _controller.reverse();
    
    if (widget.onPressed != null) {
      widget.onPressed!();
      
      if (widget.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _handleHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;
    final isEnabled = widget.onPressed != null;
    
    final buttonColors = _getButtonColors(theme, casinoColors, isEnabled);

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: _buildBoxShadows(buttonColors, isEnabled),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.blurIntensity,
                      sigmaY: widget.blurIntensity,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _buildGradient(buttonColors),
                        border: widget.border ?? Border.all(
                          color: buttonColors.borderColor,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: widget.animationDuration,
                            style: TextStyle(
                              color: isEnabled
                                  ? buttonColors.textColor
                                  : buttonColors.textColor.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ButtonColors _getButtonColors(
    ThemeData theme,
    CasinoColorScheme casinoColors,
    bool isEnabled,
  ) {
    switch (widget.style) {
      case GlassButtonStyle.primary:
        return ButtonColors(
          backgroundColor: widget.backgroundColor ?? casinoColors.primaryGold,
          glowColor: widget.glowColor ?? casinoColors.primaryGold,
          borderColor: (widget.glowColor ?? casinoColors.primaryGold).withOpacity(0.5),
          textColor: Colors.black,
        );
      case GlassButtonStyle.secondary:
        return ButtonColors(
          backgroundColor: widget.backgroundColor ?? casinoColors.primaryEmerald,
          glowColor: widget.glowColor ?? casinoColors.primaryEmerald,
          borderColor: (widget.glowColor ?? casinoColors.primaryEmerald).withOpacity(0.5),
          textColor: Colors.white,
        );
      case GlassButtonStyle.danger:
        return ButtonColors(
          backgroundColor: widget.backgroundColor ?? casinoColors.primaryRuby,
          glowColor: widget.glowColor ?? casinoColors.primaryRuby,
          borderColor: (widget.glowColor ?? casinoColors.primaryRuby).withOpacity(0.5),
          textColor: Colors.white,
        );
      case GlassButtonStyle.outline:
        return ButtonColors(
          backgroundColor: Colors.transparent,
          glowColor: widget.glowColor ?? casinoColors.primaryGold,
          borderColor: widget.glowColor ?? casinoColors.primaryGold,
          textColor: widget.glowColor ?? casinoColors.primaryGold,
        );
      case GlassButtonStyle.glass:
        return ButtonColors(
          backgroundColor: casinoColors.glassBackground,
          glowColor: widget.glowColor ?? casinoColors.primaryGold,
          borderColor: casinoColors.glassBorder,
          textColor: casinoColors.textPrimary,
        );
    }
  }

  Gradient _buildGradient(ButtonColors colors) {
    if (widget.gradient != null) return widget.gradient!;
    
    switch (widget.style) {
      case GlassButtonStyle.primary:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.backgroundColor.withOpacity(0.9),
            colors.backgroundColor.withOpacity(0.7),
            colors.backgroundColor.withOpacity(0.5),
          ],
        );
      case GlassButtonStyle.glass:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.backgroundColor.withOpacity(0.8),
            colors.backgroundColor.withOpacity(0.6),
          ],
        );
    }
  }

  List<BoxShadow> _buildBoxShadows(ButtonColors colors, bool isEnabled) {
    if (!isEnabled) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }

    List<BoxShadow> shadows = [
      // Base shadow
      BoxShadow(
        color: Colors.black.withOpacity(widget.shadowIntensity),
        blurRadius: _elevationAnimation.value * 4,
        spreadRadius: 0,
        offset: Offset(0, _elevationAnimation.value * 2),
      ),
    ];

    // Glow effect
    if (_isPressed || _isHovered) {
      shadows.addAll([
        BoxShadow(
          color: colors.glowColor.withOpacity(_glowAnimation.value * 0.5),
          blurRadius: 20,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: colors.glowColor.withOpacity(_glowAnimation.value * 0.3),
          blurRadius: 40,
          spreadRadius: 4,
          offset: Offset.zero,
        ),
      ]);
    }

    return shadows;
  }
}

/// Specialized glass buttons for common casino actions
class CasinoBetButton extends StatelessWidget {
  const CasinoBetButton({
    super.key,
    required this.onPressed,
    required this.amount,
    this.currency = '\$',
    this.isSelected = false,
    this.width = 100,
  });

  final VoidCallback? onPressed;
  final String amount;
  final String currency;
  final bool isSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GlassButton(
      onPressed: onPressed,
      width: width,
      height: 48,
      style: isSelected ? GlassButtonStyle.primary : GlassButtonStyle.outline,
      glowColor: isSelected ? CasinoColors.gold : CasinoColors.gold.withOpacity(0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currency + amount,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'BET',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.onPressed,
    this.text = 'PLAY',
    this.icon,
    this.width = 200,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final double width;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GlassButton(
      onPressed: isLoading ? null : onPressed,
      width: width,
      height: 64,
      borderRadius: 32,
      style: GlassButtonStyle.primary,
      elevation: 8,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon!, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
    ).animate(
      effects: [
        const ScaleEffect(
          duration: Duration(seconds: 2),
          curve: Curves.elasticOut,
        ),
      ],
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style = GlassButtonStyle.glass,
    this.size = 56,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final GlassButtonStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton(
          onPressed: onPressed,
          width: size,
          height: size,
          borderRadius: size / 2,
          style: style,
          child: Icon(icon, size: size * 0.4),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Floating action button with glass effect
class GlassFloatingActionButton extends StatelessWidget {
  const GlassFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.glowColor,
    this.size = 56,
    this.mini = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? glowColor;
  final double size;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;
    final effectiveSize = mini ? size * 0.75 : size;

    return GlassButton(
      onPressed: onPressed,
      width: effectiveSize,
      height: effectiveSize,
      borderRadius: effectiveSize / 2,
      backgroundColor: backgroundColor ?? casinoColors.primaryGold,
      glowColor: glowColor ?? casinoColors.primaryGold,
      elevation: 6,
      blurIntensity: 15,
      style: GlassButtonStyle.primary,
      child: child,
    );
  }
}

/// Button color configuration
class ButtonColors {
  const ButtonColors({
    required this.backgroundColor,
    required this.glowColor,
    required this.borderColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color glowColor;
  final Color borderColor;
  final Color textColor;
}

/// Glass button style variants
enum GlassButtonStyle {
  primary,    // Gold gradient with dark text
  secondary,  // Emerald gradient with white text
  danger,     // Ruby gradient with white text
  outline,    // Transparent with colored border
  glass,      // Full glassmorphic effect
}