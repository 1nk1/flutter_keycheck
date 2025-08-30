import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'roulette_viewmodel.dart';
import 'roulette_engine.dart';
import 'widgets/roulette_wheel.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glassmorphic/glassmorphic.dart';
import '../../core/agents/agents.dart';

/// Main roulette game screen with MVVM architecture
class RouletteScreen extends StatelessWidget {
  final bool demoMode;
  final int startingBalance;

  const RouletteScreen({
    super.key,
    this.demoMode = false,
    this.startingBalance = 10000,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final engine = RouletteEngine(
          config: RouletteConfig.european,
          gameEngine: GameEngineAgent(
            id: 'roulette_engine',
            name: 'Roulette Game Engine',
          ),
        );

        final viewModel = RouletteViewModel(engine: engine);
        viewModel.initialize(startingBalance, demoMode: demoMode);

        return viewModel;
      },
      child: const _RouletteScreenContent(),
    );
  }
}

class _RouletteScreenContent extends StatelessWidget {
  const _RouletteScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.circleHalfStroke, size: 20),
            const SizedBox(width: 8),
            const Text('Roulette Gold'),
            const Spacer(),
            Consumer<RouletteViewModel>(
              builder: (context, viewModel, child) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: viewModel.isDemoMode
                        ? CasinoColors.emerald.withOpacity(0.2)
                        : CasinoColors.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: viewModel.isDemoMode
                          ? CasinoColors.emerald
                          : CasinoColors.gold,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    viewModel.isDemoMode ? 'DEMO' : 'LIVE',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: viewModel.isDemoMode
                              ? CasinoColors.emerald
                              : CasinoColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          Consumer<RouletteViewModel>(
            builder: (context, viewModel, child) {
              return PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
                onSelected: (value) {
                  switch (value) {
                    case 'statistics':
                      viewModel.toggleStatistics();
                      break;
                    case 'history':
                      viewModel.toggleBetHistory();
                      break;
                    case 'settings':
                      viewModel.toggleSettings();
                      break;
                    case 'reset':
                      _showResetDialog(context, viewModel);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'statistics',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.chartLine, size: 16),
                        SizedBox(width: 8),
                        Text('Statistics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16),
                        SizedBox(width: 8),
                        Text('History'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.gear, size: 16),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
                        SizedBox(width: 8),
                        Text('Reset Stats'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: CasinoAnimatedBackground(
        backgroundType: CasinoBackgroundType.premium,
        intensity: 0.6,
        child: SafeArea(
          child: Stack(
            children: [
              const _GameContent(),

              // Overlays
              Consumer<RouletteViewModel>(
                builder: (context, viewModel, child) {
                  return Stack(
                    children: [
                      // Statistics overlay
                      if (viewModel.showStatistics) _StatisticsOverlay(),

                      // History overlay
                      if (viewModel.showBetHistory) _HistoryOverlay(),

                      // Settings overlay
                      if (viewModel.showSettings) _SettingsOverlay(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, RouletteViewModel viewModel) {
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
                FontAwesomeIcons.triangleExclamation,
                size: 48,
                color: CasinoColors.ruby,
              ),
              const SizedBox(height: 16),
              Text(
                'Reset Statistics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).casinoColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will reset all game statistics.\nAre you sure?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).casinoColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GlassButton(
                    onPressed: () => Navigator.pop(context),
                    style: GlassButtonStyle.outline,
                    child: const Text('Cancel'),
                  ),
                  GlassButton(
                    onPressed: () {
                      viewModel.resetStats();
                      Navigator.pop(context);
                    },
                    style: GlassButtonStyle.primary,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameContent extends StatelessWidget {
  const _GameContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game header
        const _GameHeader(),

        const SizedBox(height: 16),

        // Main game area
        Expanded(
          child: Row(
            children: [
              // Betting table
              const Expanded(
                flex: 2,
                child: _BettingTable(),
              ),

              const SizedBox(width: 16),

              // Wheel and controls
              const Expanded(
                flex: 1,
                child: _WheelArea(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer<RouletteViewModel>(
      builder: (context, viewModel, child) {
        return PremiumGlassPanel(
          height: 100,
          title: 'Balance: \$${viewModel.balance}',
          subtitle: viewModel.statusMessage,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatCard(
                title: 'Win Rate',
                value: '${viewModel.stats['winRate'].toStringAsFixed(1)}%',
                icon: FontAwesomeIcons.percentage,
                color: CasinoColors.emerald,
              ),
              _StatCard(
                title: 'Total Bet',
                value: '\$${viewModel.totalBetAmount}',
                icon: FontAwesomeIcons.coins,
                color: CasinoColors.gold,
              ),
              _StatCard(
                title: 'Spins',
                value: '${viewModel.stats['totalSpins']}',
                icon: FontAwesomeIcons.circleNotch,
                color: CasinoColors.ruby,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        FaIcon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.casinoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BettingTable extends StatelessWidget {
  const _BettingTable();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          // Chip selector
          const _ChipSelector(),

          const SizedBox(height: 16),

          // Betting grid
          Expanded(child: _BettingGrid()),

          const SizedBox(height: 16),

          // Outside bets
          const _OutsideBets(),
        ],
      ),
    );
  }
}

class _ChipSelector extends StatelessWidget {
  const _ChipSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer<RouletteViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Chip Value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CasinoColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ChipSelector(
              availableChips: viewModel.chipValues,
              selectedChip: viewModel.selectedChipValue,
              onChipSelected: viewModel.selectChipValue,
              size: 50,
            ),
          ],
        );
      },
    );
  }
}

class _BettingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RouletteViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CasinoColors.emerald.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CasinoColors.gold, width: 2),
          ),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 37, // 0-36
            itemBuilder: (context, index) {
              return _NumberBetButton(
                number: index,
                onTap: () => viewModel.placeStraightBet(index),
                hasChips: viewModel.hasChipsAt('straight_$index'),
                chipCount: viewModel.getChipCountAt('straight_$index'),
              );
            },
          ),
        );
      },
    );
  }
}

class _NumberBetButton extends StatelessWidget {
  final int number;
  final VoidCallback onTap;
  final bool hasChips;
  final int chipCount;

  const _NumberBetButton({
    required this.number,
    required this.onTap,
    required this.hasChips,
    required this.chipCount,
  });

  @override
  Widget build(BuildContext context) {
    final rouletteNumber = RouletteNumber(number);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _getBackgroundColor(rouletteNumber.color),
          border: Border.all(
            color: hasChips ? CasinoColors.gold : Colors.white.withOpacity(0.3),
            width: hasChips ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: hasChips
              ? CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.5)
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasChips)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: CasinoColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chipCount.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(RouletteColor color) {
    switch (color) {
      case RouletteColor.red:
        return CasinoColors.ruby;
      case RouletteColor.black:
        return Colors.black87;
      case RouletteColor.green:
        return CasinoColors.emerald;
    }
  }
}

class _OutsideBets extends StatelessWidget {
  const _OutsideBets();

  @override
  Widget build(BuildContext context) {
    return Consumer<RouletteViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outside Bets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CasinoColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Color and even/odd bets
            Row(
              children: [
                Expanded(
                  child: _OutsideBetButton(
                    label: 'RED',
                    color: CasinoColors.ruby,
                    onTap: () => viewModel.placeOutsideBet(BetType.red),
                    hasChips: viewModel.hasChipsAt('Red'),
                    chipCount: viewModel.getChipCountAt('Red'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutsideBetButton(
                    label: 'BLACK',
                    color: Colors.black87,
                    onTap: () => viewModel.placeOutsideBet(BetType.black),
                    hasChips: viewModel.hasChipsAt('Black'),
                    chipCount: viewModel.getChipCountAt('Black'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutsideBetButton(
                    label: 'EVEN',
                    color: Colors.blue,
                    onTap: () => viewModel.placeOutsideBet(BetType.even),
                    hasChips: viewModel.hasChipsAt('Even'),
                    chipCount: viewModel.getChipCountAt('Even'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutsideBetButton(
                    label: 'ODD',
                    color: Colors.purple,
                    onTap: () => viewModel.placeOutsideBet(BetType.odd),
                    hasChips: viewModel.hasChipsAt('Odd'),
                    chipCount: viewModel.getChipCountAt('Odd'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Range bets
            Row(
              children: [
                Expanded(
                  child: _OutsideBetButton(
                    label: '1-18',
                    color: Colors.indigo,
                    onTap: () => viewModel.placeOutsideBet(BetType.low),
                    hasChips: viewModel.hasChipsAt('1-18'),
                    chipCount: viewModel.getChipCountAt('1-18'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutsideBetButton(
                    label: '19-36',
                    color: Colors.teal,
                    onTap: () => viewModel.placeOutsideBet(BetType.high),
                    hasChips: viewModel.hasChipsAt('19-36'),
                    chipCount: viewModel.getChipCountAt('19-36'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OutsideBetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool hasChips;
  final int chipCount;

  const _OutsideBetButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.hasChips,
    required this.chipCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: hasChips ? CasinoColors.gold : Colors.white.withOpacity(0.3),
            width: hasChips ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: hasChips
              ? CasinoColors.getNeonGlow(CasinoColors.gold, intensity: 0.3)
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasChips)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: CasinoColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chipCount.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
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

class _WheelArea extends StatelessWidget {
  const _WheelArea();

  @override
  Widget build(BuildContext context) {
    return Consumer<RouletteViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            // Roulette wheel
            Expanded(
              flex: 3,
              child: Center(
                child: RouletteWheel(
                  rotation: viewModel.wheelRotation,
                  ballRotation: viewModel.ballRotation,
                  animationState: viewModel.animationState,
                  winningNumber: viewModel.lastResult?.winningNumber,
                  size: 280,
                  type: viewModel.config.type,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recent numbers
            RecentNumbersDisplay(
              recentNumbers: viewModel.getRecentNumbers(count: 8),
              highlightedNumber: viewModel.lastResult?.winningNumber.number,
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed:
                        viewModel.hasBets ? viewModel.clearAllBets : null,
                    style: GlassButtonStyle.outline,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.trash, size: 16),
                        SizedBox(width: 8),
                        Text('CLEAR'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PlayButton(
                    onPressed: viewModel.hasBets && !viewModel.isSpinning
                        ? viewModel.spin
                        : null,
                    text: viewModel.isSpinning ? 'SPINNING...' : 'SPIN',
                    icon: FontAwesomeIcons.circleNotch,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// Overlay widgets would go here - _StatisticsOverlay, _HistoryOverlay, _SettingsOverlay
// Similar structure to the slots overlays but with roulette-specific content

class _StatisticsOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => context.read<RouletteViewModel>().toggleStatistics(),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: GlassContainer(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              borderRadius: 24,
              child: Consumer<RouletteViewModel>(
                builder: (context, viewModel, child) {
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statistics',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          GlassButton(
                            onPressed: () => viewModel.toggleStatistics(),
                            style: GlassButtonStyle.outline,
                            width: 40,
                            child:
                                const FaIcon(FontAwesomeIcons.xmark, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              HotColdNumbers(
                                hotNumbers: viewModel.getHotNumbers(),
                                coldNumbers: viewModel.getColdNumbers(),
                              ),
                              const SizedBox(height: 20),
                              RecentNumbersDisplay(
                                recentNumbers:
                                    viewModel.getRecentNumbers(count: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => context.read<RouletteViewModel>().toggleBetHistory(),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: GlassContainer(
              width: 350,
              height: 500,
              borderRadius: 24,
              child: Consumer<RouletteViewModel>(
                builder: (context, viewModel, child) {
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bet History',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          GlassButton(
                            onPressed: () => viewModel.toggleBetHistory(),
                            style: GlassButtonStyle.outline,
                            width: 40,
                            child:
                                const FaIcon(FontAwesomeIcons.xmark, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: viewModel.history.length,
                          itemBuilder: (context, index) {
                            final result = viewModel.history[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      RouletteNumberDisplay(
                                        number: result.winningNumber.number,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Spin #${index + 1}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .casinoColors
                                                      .textPrimary,
                                                ),
                                          ),
                                          Text(
                                            '${result.timestamp.hour}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .casinoColors
                                                      .textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    result.hasWin
                                        ? '+\$${result.totalWin}'
                                        : '-\$${result.totalLoss}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: result.hasWin
                                              ? CasinoColors.emerald
                                              : CasinoColors.ruby,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => context.read<RouletteViewModel>().toggleSettings(),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: GlassContainer(
              width: 350,
              height: 400,
              borderRadius: 24,
              child: Consumer<RouletteViewModel>(
                builder: (context, viewModel, child) {
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          GlassButton(
                            onPressed: () => viewModel.toggleSettings(),
                            style: GlassButtonStyle.outline,
                            width: 40,
                            child:
                                const FaIcon(FontAwesomeIcons.xmark, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _SettingsSwitch(
                              title: 'Sound Effects',
                              value: viewModel.soundEnabled,
                              onChanged: viewModel.setSoundEnabled,
                            ),
                            _SettingsSwitch(
                              title: 'Haptic Feedback',
                              value: viewModel.hapticsEnabled,
                              onChanged: viewModel.setHapticsEnabled,
                            ),
                            _SettingsSwitch(
                              title: 'Animations',
                              value: viewModel.animationsEnabled,
                              onChanged: viewModel.setAnimationsEnabled,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).casinoColors.textPrimary,
                ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: CasinoColors.gold,
          ),
        ],
      ),
    );
  }
}
