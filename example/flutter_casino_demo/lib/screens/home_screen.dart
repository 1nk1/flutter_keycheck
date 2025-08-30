import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/glassmorphic/glassmorphic.dart';
import '../games/slots/slots_screen.dart';
import '../games/roulette/roulette_screen.dart';
import '../games/blackjack/blackjack_screen.dart';
import 'statistics_screen.dart';

/// Main home screen with game selection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _balance = 10000;
  bool _isDemoMode = true;
  String _playerLevel = 'Gold VIP';
  int _totalWins = 42;
  double _winRate = 68.5;
  int _currentStreak = 7;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  void _navigateToGame(Widget gameScreen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => gameScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToStatistics() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StatisticsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _toggleDemoMode() {
    setState(() {
      _isDemoMode = !_isDemoMode;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CasinoAnimatedBackground(
        backgroundType: CasinoBackgroundType.premium,
        intensity: 0.8,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 32),
                _buildFeaturedGames(),
                const SizedBox(height: 32),
                _buildQuickActions(),
                const SizedBox(height: 32),
                _buildBottomContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    
    return PremiumGlassPanel(
      height: 120,
      title: 'Premium Casino',
      subtitle: 'Welcome to the VIP Experience',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.casinoColors.textSecondary,
                ),
              ),
              Text(
                '\$${_balance.toStringAsFixed(0)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: CasinoColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CasinoColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _playerLevel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: CasinoColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Column(
            children: [
              ActionButton(
                onPressed: _toggleDemoMode,
                icon: _isDemoMode ? Icons.casino : Icons.monetization_on,
                label: _isDemoMode ? 'Demo' : 'Live',
                style: _isDemoMode ? GlassButtonStyle.glass : GlassButtonStyle.filled,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDemoMode 
                      ? CasinoColors.emerald.withOpacity(0.2)
                      : CasinoColors.ruby.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDemoMode ? CasinoColors.emerald : CasinoColors.ruby,
                    width: 1,
                  ),
                ),
                child: Text(
                  _isDemoMode ? 'DEMO MODE' : 'LIVE MODE',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isDemoMode ? CasinoColors.emerald : CasinoColors.ruby,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: StatsGlassCard(
            title: 'Total Wins',
            value: _totalWins.toString(),
            icon: Icons.emoji_events,
            trend: '+12%',
            trendIcon: Icons.trending_up,
            glowColor: CasinoColors.emerald,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsGlassCard(
            title: 'Win Rate',
            value: '${_winRate.toStringAsFixed(1)}%',
            icon: Icons.show_chart,
            trend: '+5%',
            trendIcon: Icons.trending_up,
            glowColor: CasinoColors.gold,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsGlassCard(
            title: 'Streak',
            value: _currentStreak.toString(),
            icon: Icons.local_fire_department,
            subtitle: 'Current',
            glowColor: CasinoColors.ruby,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedGames() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Games',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: CasinoColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _GameCard(
                title: 'Slots Diamond',
                subtitle: 'Premium Slots',
                icon: FontAwesomeIcons.coins,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6A5ACD),
                    Color(0xFF9370DB),
                    Color(0xFFDA70D6),
                  ],
                ),
                onTap: () => _navigateToGame(SlotsScreen(
                  demoMode: _isDemoMode,
                  startingBalance: _balance,
                )),
                jackpotAmount: '\$1,000,000',
                playersCount: 256,
                difficulty: 'Easy',
                isNew: true,
              ),
              _GameCard(
                title: 'Roulette Gold',
                subtitle: 'European',
                icon: FontAwesomeIcons.circleHalfStroke,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B6B),
                    Color(0xFFFF8E53),
                    Color(0xFFFF6B9D),
                  ],
                ),
                onTap: () => _navigateToGame(RouletteScreen(
                  demoMode: _isDemoMode,
                  startingBalance: _balance,
                )),
                jackpotAmount: '\$50,000',
                playersCount: 67,
                difficulty: 'Medium',
                isHot: true,
              ),
              _GameCard(
                title: 'Blackjack VIP',
                subtitle: 'Classic 21',
                icon: FontAwesomeIcons.spade,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4ECDC4),
                    Color(0xFF44A08D),
                    Color(0xFF093637),
                  ],
                ),
                onTap: () => _navigateToGame(BlackjackScreen(
                  demoMode: _isDemoMode,
                  startingBalance: _balance,
                )),
                jackpotAmount: '\$25,000',
                playersCount: 42,
                difficulty: 'Hard',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: CasinoColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Statistics',
                subtitle: 'View detailed stats',
                icon: FontAwesomeIcons.chartLine,
                color: CasinoColors.emerald,
                onTap: _navigateToStatistics,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _QuickActionCard(
                title: 'Tournaments',
                subtitle: 'Join competitions',
                icon: FontAwesomeIcons.trophy,
                color: CasinoColors.gold,
                onTap: () => _showComingSoonDialog('Tournaments'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _QuickActionCard(
                title: 'Achievements',
                subtitle: 'View progress',
                icon: FontAwesomeIcons.medal,
                color: CasinoColors.ruby,
                onTap: () => _showComingSoonDialog('Achievements'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomContent() {
    return FloatingGlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ActionButton(
                onPressed: () => _showComingSoonDialog('Wallet'),
                icon: Icons.account_balance_wallet,
                label: 'Wallet',
              ),
              ActionButton(
                onPressed: () => _showComingSoonDialog('Leaderboard'),
                icon: Icons.leaderboard,
                label: 'Leaderboard',
              ),
              ActionButton(
                onPressed: () => _showComingSoonDialog('Rewards'),
                icon: Icons.card_giftcard,
                label: 'Rewards',
              ),
              ActionButton(
                onPressed: () => _showComingSoonDialog('Support'),
                icon: Icons.support_agent,
                label: 'Support',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Premium Casino Experience',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).casinoColors.textSecondary,
            ),
          ),
          Text(
            'Glassmorphism UI • Vegas Luxury Theme',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).casinoColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          width: 300,
          height: 200,
          borderRadius: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.clock,
                size: 48,
                color: CasinoColors.gold,
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).casinoColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$feature feature is coming soon!\nStay tuned for updates.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).casinoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final String jackpotAmount;
  final int playersCount;
  final String difficulty;
  final bool isNew;
  final bool isHot;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.jackpotAmount,
    required this.playersCount,
    required this.difficulty,
    this.isNew = false,
    this.isHot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: GameTileCard(
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        jackpotAmount: jackpotAmount,
        playersCount: playersCount,
        difficulty: difficulty,
        gradient: gradient,
        icon: icon,
        badges: [
          if (isNew) 'NEW',
          if (isHot) 'HOT',
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).casinoColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).casinoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}