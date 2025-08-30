import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'glass_container.dart';

/// Premium glassmorphic card for casino games and content
class GlassmorphicCard extends StatefulWidget {
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.width = 300,
    this.height = 200,
    this.onTap,
    this.onLongPress,
    this.title,
    this.subtitle,
    this.headerImage,
    this.backgroundImage,
    this.glowColor,
    this.interactive = true,
    this.animationDelay = Duration.zero,
    this.customDecoration,
  });

  final Widget child;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? title;
  final String? subtitle;
  final Widget? headerImage;
  final ImageProvider? backgroundImage;
  final Color? glowColor;
  final bool interactive;
  final Duration animationDelay;
  final Decoration? customDecoration;

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.01).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.interactive) return;
    setState(() {
      _isPressed = false;
    });
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;
    final effectiveGlowColor = widget.glowColor ?? casinoColors.primaryGold;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onLongPress: widget.onLongPress,
              child: Container(
                width: widget.width,
                height: widget.height,
                margin: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    // Background image layer
                    if (widget.backgroundImage != null) _buildBackgroundImage(),

                    // Main glass container
                    _buildMainContainer(
                        theme, casinoColors, effectiveGlowColor),

                    // Content overlay
                    _buildContentOverlay(theme, casinoColors),

                    // Interactive glow effect
                    if (widget.interactive && _isPressed)
                      _buildPressedGlowEffect(effectiveGlowColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    )
        .animate(delay: widget.animationDelay)
        .slideY(
          begin: 0.3,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
        )
        .fadeIn(
          duration: const Duration(milliseconds: 400),
        );
  }

  Widget _buildBackgroundImage() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: widget.backgroundImage!,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContainer(
    ThemeData theme,
    CasinoColorScheme casinoColors,
    Color glowColor,
  ) {
    return Positioned.fill(
      child: Container(
        decoration: widget.customDecoration ??
            BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: glowColor.withOpacity(_isPressed ? 0.4 : 0.2),
                  blurRadius: _isPressed ? 30 : 20,
                  spreadRadius: _isPressed ? 3 : 1,
                  offset: Offset.zero,
                ),
              ],
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentOverlay(ThemeData theme, CasinoColorScheme casinoColors) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            if (widget.title != null ||
                widget.subtitle != null ||
                widget.headerImage != null)
              _buildHeader(theme, casinoColors),

            // Content section
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, CasinoColorScheme casinoColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Header image
          if (widget.headerImage != null) ...[
            SizedBox(
              width: 40,
              height: 40,
              child: widget.headerImage,
            ),
            const SizedBox(width: 12),
          ],

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: casinoColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: casinoColors.textSecondary,
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

  Widget _buildPressedGlowEffect(Color glowColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.6),
              blurRadius: 40,
              spreadRadius: 5,
              offset: Offset.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// Game tile card specifically designed for casino games
class GameTileCard extends StatelessWidget {
  const GameTileCard({
    super.key,
    required this.title,
    required this.gameImage,
    required this.onTap,
    this.subtitle,
    this.isLocked = false,
    this.jackpotAmount,
    this.playersCount,
    this.difficulty,
  });

  final String title;
  final ImageProvider gameImage;
  final VoidCallback onTap;
  final String? subtitle;
  final bool isLocked;
  final String? jackpotAmount;
  final int? playersCount;
  final String? difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;

    return GlassmorphicCard(
      width: 280,
      height: 360,
      onTap: isLocked ? null : onTap,
      interactive: !isLocked,
      glowColor: isLocked ? Colors.grey : casinoColors.primaryGold,
      backgroundImage: gameImage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isLocked)
                _buildLockIndicator(theme)
              else
                _buildDifficultyIndicator(theme, casinoColors),
              if (playersCount != null)
                _buildPlayersIndicator(theme, casinoColors),
            ],
          ),

          const Spacer(),

          // Game info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
                if (jackpotAmount != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: CasinoColors.goldGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'JACKPOT: $jackpotAmount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildLockIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.lock,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildDifficultyIndicator(ThemeData theme, CasinoColorScheme colors) {
    if (difficulty == null) return const SizedBox.shrink();

    Color difficultyColor;
    switch (difficulty!.toLowerCase()) {
      case 'easy':
        difficultyColor = CasinoColors.emerald;
        break;
      case 'medium':
        difficultyColor = CasinoColors.gold;
        break;
      case 'hard':
        difficultyColor = CasinoColors.ruby;
        break;
      default:
        difficultyColor = colors.primaryGold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: difficultyColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty!.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPlayersIndicator(ThemeData theme, CasinoColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.glassBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: 12,
            color: colors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            '$playersCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats card for displaying casino statistics
class StatsGlassCard extends StatelessWidget {
  const StatsGlassCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.trend,
    this.trendIcon,
    this.glowColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final String? trend;
  final IconData? trendIcon;
  final Color? glowColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casinoColors = theme.casinoColors;
    final effectiveGlowColor = glowColor ?? casinoColors.primaryGold;

    return GlassmorphicCard(
      width: 160,
      height: 120,
      onTap: onTap,
      glowColor: effectiveGlowColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: effectiveGlowColor,
                size: 24,
              ),
              if (trend != null && trendIcon != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendIcon!,
                      color: trendIcon == Icons.trending_up
                          ? CasinoColors.emerald
                          : CasinoColors.ruby,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: trendIcon == Icons.trending_up
                            ? CasinoColors.emerald
                            : CasinoColors.ruby,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: casinoColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: casinoColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: casinoColors.textSecondary.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
