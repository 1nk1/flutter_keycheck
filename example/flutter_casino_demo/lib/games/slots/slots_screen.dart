import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'slots_viewmodel.dart';
import 'slots_engine.dart';
import 'widgets/reel_widget.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glassmorphic/glassmorphic.dart';
import '../../core/agents/agents.dart';

/// Main slots game screen with MVVM architecture
class SlotsScreen extends StatelessWidget {
  final bool demoMode;
  final int startingBalance;

  const SlotsScreen({
    super.key,
    this.demoMode = false,
    this.startingBalance = 10000,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final engine = SlotsEngine(
          config: SlotConfig.classic,
          gameEngine: GameEngineAgent(
            id: 'slots_engine',
            name: 'Slots Game Engine',
          ),
        );

        final viewModel = SlotsViewModel(engine: engine);
        viewModel.initialize(startingBalance, demoMode: demoMode);

        return viewModel;
      },
      child: const _SlotsScreenContent(),
    );
  }
}

class _SlotsScreenContent extends StatelessWidget {
  const _SlotsScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.coins, size: 20),
            const SizedBox(width: 8),
            const Text('Slots Diamond'),
            const Spacer(),
            Consumer<SlotsViewModel>(
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
          Consumer<SlotsViewModel>(
            builder: (context, viewModel, child) {
              return PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
                onSelected: (value) {
                  switch (value) {
                    case 'paytable':
                      viewModel.togglePaytable();
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
                    value: 'paytable',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.tableList, size: 16),
                        SizedBox(width: 8),
                        Text('Paytable'),
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
              Consumer<SlotsViewModel>(
                builder: (context, viewModel, child) {
                  return Stack(
                    children: [
                      // Paytable overlay
                      if (viewModel.showPaytable) _PaytableOverlay(),

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

  void _showResetDialog(BuildContext context, SlotsViewModel viewModel) {
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
        // Game header with balance and status
        const _GameHeader(),

        const SizedBox(height: 16),

        // Slot machine
        const Expanded(child: _SlotMachine()),

        const SizedBox(height: 16),

        // Betting controls
        const _BettingControls(),

        const SizedBox(height: 16),

        // Action buttons
        const _ActionButtons(),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer<SlotsViewModel>(
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
                icon: FontAwesomeIcons.chartLine,
                color: CasinoColors.emerald,
              ),
              _StatCard(
                title: 'Best Win',
                value: '\$${viewModel.stats['bestWin']}',
                icon: FontAwesomeIcons.trophy,
                color: CasinoColors.gold,
              ),
              _StatCard(
                title: 'Spins',
                value: '${viewModel.stats['totalSpins']}',
                icon: FontAwesomeIcons.dice,
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

class _SlotMachine extends StatelessWidget {
  const _SlotMachine();

  @override
  Widget build(BuildContext context) {
    return Consumer<SlotsViewModel>(
      builder: (context, viewModel, child) {
        return GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            children: [
              // Slot reels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (reelIndex) {
                  final symbols = List.generate(
                      3, (row) => viewModel.getSymbolAt(reelIndex, row));

                  final winningPositions = List.generate(
                      3, (row) => viewModel.isWinningPosition(reelIndex, row));

                  return ReelWidget(
                    reelIndex: reelIndex,
                    symbols: symbols,
                    isSpinning: viewModel.reelSpinning[reelIndex],
                    spinSpeed: viewModel.spinSpeed,
                    isWinningReel: winningPositions.any((w) => w),
                    winningPositions: winningPositions,
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Paylines indicator
              if (viewModel.lastResult != null && viewModel.lastResult!.hasWin)
                _PaylineIndicator(winLines: viewModel.flashingWinLines),
            ],
          ),
        );
      },
    );
  }
}

class _PaylineIndicator extends StatelessWidget {
  final List<WinLine> winLines;

  const _PaylineIndicator({required this.winLines});

  @override
  Widget build(BuildContext context) {
    if (winLines.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CasinoColors.gold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CasinoColors.gold, width: 1),
      ),
      child: Text(
        'Winning Lines: ${winLines.map((line) => line.payLine.name).join(', ')}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CasinoColors.gold,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _BettingControls extends StatelessWidget {
  const _BettingControls();

  @override
  Widget build(BuildContext context) {
    return Consumer<SlotsViewModel>(
      builder: (context, viewModel, child) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bet Amount',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: CasinoColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GlassButton(
                    onPressed:
                        viewModel.isSpinning ? null : viewModel.decreaseBet,
                    style: GlassButtonStyle.outline,
                    width: 50,
                    child: const FaIcon(FontAwesomeIcons.minus, size: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: CasinoColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CasinoColors.gold, width: 1),
                      ),
                      child: Text(
                        '\$${viewModel.currentBet}',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GlassButton(
                    onPressed:
                        viewModel.isSpinning ? null : viewModel.increaseBet,
                    style: GlassButtonStyle.outline,
                    width: 50,
                    child: const FaIcon(FontAwesomeIcons.plus, size: 16),
                  ),
                  const SizedBox(width: 16),
                  GlassButton(
                    onPressed: viewModel.isSpinning ? null : viewModel.maxBet,
                    style: GlassButtonStyle.primary,
                    child: const Text('MAX'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Consumer<SlotsViewModel>(
      builder: (context, viewModel, child) {
        return Row(
          children: [
            // Auto play button
            Expanded(
              child: GlassButton(
                onPressed: viewModel.isAutoPlay
                    ? viewModel.stopAutoPlay
                    : () => _showAutoPlayDialog(context, viewModel),
                style: viewModel.isAutoPlay
                    ? GlassButtonStyle.primary
                    : GlassButtonStyle.outline,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      viewModel.isAutoPlay
                          ? FontAwesomeIcons.stop
                          : FontAwesomeIcons.play,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(viewModel.isAutoPlay
                        ? 'STOP (${viewModel.autoPlayRemaining})'
                        : 'AUTO PLAY'),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Main spin button
            PlayButton(
              onPressed: viewModel.canSpin && !viewModel.isAutoPlay
                  ? viewModel.spin
                  : null,
              text: viewModel.isSpinning ? 'SPINNING...' : 'SPIN',
              icon: FontAwesomeIcons.dice,
              width: 140,
            ),
          ],
        );
      },
    );
  }

  void _showAutoPlayDialog(BuildContext context, SlotsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          width: 300,
          height: 350,
          borderRadius: 24,
          child: Column(
            children: [
              Text(
                'Auto Play',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CasinoColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select number of spins:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).casinoColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [10, 25, 50, 100, 250, 500].map((spins) {
                    return GlassButton(
                      onPressed: () {
                        Navigator.pop(context);
                        viewModel.startAutoPlay(spins);
                      },
                      style: GlassButtonStyle.outline,
                      child: Text('$spins'),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              GlassButton(
                onPressed: () => Navigator.pop(context),
                style: GlassButtonStyle.primary,
                width: double.infinity,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaytableOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => context.read<SlotsViewModel>().togglePaytable(),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: GlassContainer(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              borderRadius: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paytable',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      GlassButton(
                        onPressed: () =>
                            context.read<SlotsViewModel>().togglePaytable(),
                        style: GlassButtonStyle.outline,
                        width: 40,
                        child: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Consumer<SlotsViewModel>(
                      builder: (context, viewModel, child) {
                        return ListView(
                          children: SlotSymbol.values.map((symbol) {
                            return SymbolInfo(
                              symbol: symbol,
                              baseMultiplier: viewModel.currentBet,
                              showMultipliers: true,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
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
        onTap: () => context.read<SlotsViewModel>().toggleSettings(),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: GlassContainer(
              width: 350,
              height: 500,
              borderRadius: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Settings',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: CasinoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      GlassButton(
                        onPressed: () =>
                            context.read<SlotsViewModel>().toggleSettings(),
                        style: GlassButtonStyle.outline,
                        width: 40,
                        child: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Consumer<SlotsViewModel>(
                      builder: (context, viewModel, child) {
                        return Column(
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
                            const SizedBox(height: 20),
                            _SettingsSlider(
                              title: 'Spin Speed',
                              value: viewModel.spinSpeed,
                              min: 0.5,
                              max: 2.0,
                              onChanged: viewModel.setSpinSpeed,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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

class _SettingsSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SettingsSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).casinoColors.textPrimary,
                  ),
            ),
            Text(
              '${value.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CasinoColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: CasinoColors.gold,
            inactiveTrackColor: CasinoColors.gold.withOpacity(0.3),
            thumbColor: CasinoColors.gold,
            overlayColor: CasinoColors.gold.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 15,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
