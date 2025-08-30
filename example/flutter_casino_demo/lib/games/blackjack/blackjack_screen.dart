import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'blackjack_viewmodel.dart';
import 'blackjack_engine.dart';
import 'widgets/playing_card.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glassmorphic/glassmorphic.dart';
import '../../core/agents/agents.dart';

/// Main blackjack game screen with MVVM architecture
class BlackjackScreen extends StatelessWidget {
  final bool demoMode;
  final int startingBalance;
  
  const BlackjackScreen({
    super.key,
    this.demoMode = false,
    this.startingBalance = 10000,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final engine = BlackjackEngine(
          config: BlackjackConfig.standard,
          gameEngine: GameEngineAgent(
            id: 'blackjack_engine',
            name: 'Blackjack Game Engine',
          ),
        );
        
        final viewModel = BlackjackViewModel(engine: engine);
        viewModel.initialize(startingBalance, demoMode: demoMode);
        
        return viewModel;
      },
      child: const _BlackjackScreenContent(),
    );
  }
}

class _BlackjackScreenContent extends StatelessWidget {
  const _BlackjackScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.spade, size: 20),
            const SizedBox(width: 8),
            const Text('Blackjack VIP'),
            const Spacer(),
            Consumer<BlackjackViewModel>(
              builder: (context, viewModel, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          Consumer<BlackjackViewModel>(
            builder: (context, viewModel, child) {
              return PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
                onSelected: (value) {
                  switch (value) {
                    case 'basic_strategy':
                      viewModel.toggleBasicStrategy();
                      break;
                    case 'history':
                      viewModel.toggleGameHistory();
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
                    value: 'basic_strategy',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.brain, size: 16),
                        SizedBox(width: 8),
                        Text('Basic Strategy'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16),
                        SizedBox(width: 8),
                        Text('Game History'),
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
        child: const SafeArea(
          child: _GameContent(),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, BlackjackViewModel viewModel) {
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
                    style: GlassButtonStyle.filled,
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
        
        // Game table
        const Expanded(child: _GameTable()),
        
        const SizedBox(height: 16),
        
        // Controls
        const _GameControls(),
        
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer<BlackjackViewModel>(
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
                title: 'Blackjacks',
                value: '${viewModel.stats['totalBlackjacks']}',
                icon: FontAwesomeIcons.crown,
                color: CasinoColors.gold,
              ),
              _StatCard(
                title: 'Games',
                value: '${viewModel.stats['totalGames']}',
                icon: FontAwesomeIcons.gamepad,
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

class _GameTable extends StatelessWidget {
  const _GameTable();

  @override
  Widget build(BuildContext context) {
    return Consumer<BlackjackViewModel>(
      builder: (context, viewModel, child) {
        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Dealer hand
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text(
                        'Dealer',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).casinoColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: HandDisplayWidget(
                            hand: viewModel.dealerHand,
                            isDealer: true,
                            label: 'Dealer',
                            valueText: viewModel.dealerTurn || !viewModel.gameInProgress 
                                ? viewModel.getHandValueString(viewModel.dealerHand)
                                : null,
                            cardWidth: 70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        CasinoColors.gold.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                
                // Player hands
                Expanded(
                  flex: 3,
                  child: viewModel.playerHands.length == 1
                      ? _buildSingleHand(viewModel)
                      : _buildMultipleHands(viewModel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleHand(BlackjackViewModel viewModel) {
    return Center(
      child: HandDisplayWidget(
        hand: viewModel.playerHands[0],
        isActive: viewModel.gameInProgress && viewModel.currentHandIndex == 0,
        label: 'Player',
        valueText: viewModel.getHandValueString(viewModel.playerHands[0]),
        cardWidth: 80,
      ),
    );
  }

  Widget _buildMultipleHands(BlackjackViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: viewModel.playerHands.asMap().entries.map((entry) {
        final index = entry.key;
        final hand = entry.value;
        
        return Expanded(
          child: HandDisplayWidget(
            hand: hand,
            isActive: viewModel.gameInProgress && viewModel.currentHandIndex == index,
            label: 'Hand ${index + 1}',
            valueText: viewModel.getHandValueString(hand),
            cardWidth: 60,
          ),
        );
      }).toList(),
    );
  }
}

class _GameControls extends StatelessWidget {
  const _GameControls();

  @override
  Widget build(BuildContext context) {
    return Consumer<BlackjackViewModel>(
      builder: (context, viewModel, child) {
        if (!viewModel.gameInProgress) {
          return _buildBettingControls(viewModel);
        } else {
          return _buildGameActionControls(viewModel);
        }
      },
    );
  }

  Widget _buildBettingControls(BlackjackViewModel viewModel) {
    return Column(
      children: [
        // Bet selector
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Place Your Bet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: CasinoColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ChipSelector(
                availableChips: viewModel.betAmounts,
                selectedChip: viewModel.selectedBet,
                onChipSelected: viewModel.setBet,
                size: 60,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Deal button
        PlayButton(
          onPressed: viewModel.startNewGame,
          text: 'DEAL CARDS',
          icon: FontAwesomeIcons.handHolding,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildGameActionControls(BlackjackViewModel viewModel) {
    final actions = viewModel.availableActions;
    
    return Column(
      children: [
        // Basic strategy hint
        if (viewModel.showBasicStrategy || viewModel.autoPlayBasicStrategy)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: CasinoColors.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CasinoColors.emerald, width: 1),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.brain, 
                    color: CasinoColors.emerald, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Basic Strategy: ${_getActionName(viewModel.basicStrategyAction)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CasinoColors.emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: viewModel.toggleAutoPlayBasicStrategy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: viewModel.autoPlayBasicStrategy 
                          ? CasinoColors.emerald 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CasinoColors.emerald),
                    ),
                    child: Text(
                      'AUTO',
                      style: TextStyle(
                        color: viewModel.autoPlayBasicStrategy 
                            ? Colors.black 
                            : CasinoColors.emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Action buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (actions.contains(BlackjackAction.hit))
              GlassButton(
                onPressed: viewModel.hit,
                style: GlassButtonStyle.filled,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.plus, size: 16),
                    SizedBox(width: 8),
                    Text('HIT'),
                  ],
                ),
              ),
            
            if (actions.contains(BlackjackAction.stand))
              GlassButton(
                onPressed: viewModel.stand,
                style: GlassButtonStyle.outline,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.handPaper, size: 16),
                    SizedBox(width: 8),
                    Text('STAND'),
                  ],
                ),
              ),
            
            if (actions.contains(BlackjackAction.doubleDown))
              GlassButton(
                onPressed: viewModel.doubleDown,
                style: GlassButtonStyle.glass,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.arrowUp, size: 16),
                    SizedBox(width: 8),
                    Text('DOUBLE'),
                  ],
                ),
              ),
            
            if (actions.contains(BlackjackAction.split))
              GlassButton(
                onPressed: viewModel.split,
                style: GlassButtonStyle.glass,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.scissors, size: 16),
                    SizedBox(width: 8),
                    Text('SPLIT'),
                  ],
                ),
              ),
            
            if (actions.contains(BlackjackAction.surrender))
              GlassButton(
                onPressed: viewModel.surrender,
                style: GlassButtonStyle.outline,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.flag, size: 16),
                    SizedBox(width: 8),
                    Text('SURRENDER'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _getActionName(BlackjackAction action) {
    switch (action) {
      case BlackjackAction.hit:
        return 'Hit';
      case BlackjackAction.stand:
        return 'Stand';
      case BlackjackAction.doubleDown:
        return 'Double Down';
      case BlackjackAction.split:
        return 'Split';
      case BlackjackAction.surrender:
        return 'Surrender';
    }
  }
}