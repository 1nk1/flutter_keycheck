import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:ui';

void main() {
  runApp(const CasinoApp());
}

class CasinoApp extends StatelessWidget {
  const CasinoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CasinoViewModel(),
      child: MaterialApp(
        title: 'Flutter Casino Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.amber,
          scaffoldBackgroundColor: const Color(0xFF0F1419),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

// ViewModel
class CasinoViewModel extends ChangeNotifier {
  double _balance = 1000.0;
  double _currentBet = 10.0;
  final Random _random = Random();

  double get balance => _balance;
  double get currentBet => _currentBet;

  void setBet(double bet) {
    if (bet <= _balance && bet > 0) {
      _currentBet = bet;
      notifyListeners();
    }
  }

  void addWinnings(double amount) {
    _balance += amount;
    notifyListeners();
  }

  void placeBet() {
    if (_currentBet <= _balance) {
      _balance -= _currentBet;
      notifyListeners();
    }
  }

  bool canBet() => _balance >= _currentBet;

  // Slots logic
  List<String> spinSlots() {
    if (!canBet()) return [];
    placeBet();

    final symbols = ['🍒', '🍋', '🍊', '🍇', '💎', '7️⃣'];
    final result =
        List.generate(3, (_) => symbols[_random.nextInt(symbols.length)]);

    // Check win
    if (result[0] == result[1] && result[1] == result[2]) {
      double multiplier = result[0] == '7️⃣'
          ? 10
          : result[0] == '💎'
              ? 5
              : 3;
      addWinnings(_currentBet * multiplier);
    }

    return result;
  }

  // Roulette logic
  int spinRoulette(String betType, dynamic betValue) {
    if (!canBet()) return -1;
    placeBet();

    int result = _random.nextInt(37); // 0-36
    bool won = false;
    double multiplier = 0;

    if (betType == 'number' && betValue == result) {
      won = true;
      multiplier = 35;
    } else if (betType == 'color') {
      bool isRed = [
        1,
        3,
        5,
        7,
        9,
        12,
        14,
        16,
        18,
        19,
        21,
        23,
        25,
        27,
        30,
        32,
        34,
        36
      ].contains(result);
      if ((betValue == 'red' && isRed) ||
          (betValue == 'black' && !isRed && result != 0)) {
        won = true;
        multiplier = 2;
      }
    } else if (betType == 'even' && result != 0 && result % 2 == 0) {
      won = true;
      multiplier = 2;
    } else if (betType == 'odd' && result % 2 == 1) {
      won = true;
      multiplier = 2;
    }

    if (won) {
      addWinnings(_currentBet * multiplier);
    }

    return result;
  }

  // Blackjack logic
  int getCardValue(String card) {
    if (card == 'A') return 11;
    if (['K', 'Q', 'J'].contains(card)) return 10;
    return int.tryParse(card) ?? 0;
  }

  List<String> dealCards(int count) {
    final cards = [
      'A',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      'J',
      'Q',
      'K'
    ];
    return List.generate(count, (_) => cards[_random.nextInt(cards.length)]);
  }
}

// Home Screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const AnimatedBackground(),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with balance
                const BalanceHeader(),

                // Game selection
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        GameCard(
                          key: const Key('slotsGameCard'),
                          title: 'SLOTS',
                          icon: '🎰',
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SlotsScreen()),
                          ),
                        ),
                        GameCard(
                          key: const Key('rouletteGameCard'),
                          title: 'ROULETTE',
                          icon: '🎯',
                          color: Colors.red,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RouletteScreen()),
                          ),
                        ),
                        GameCard(
                          key: const Key('blackjackGameCard'),
                          title: 'BLACKJACK',
                          icon: '🃏',
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BlackjackScreen()),
                          ),
                        ),
                        GameCard(
                          key: const Key('demoModeCard'),
                          title: 'DEMO MODE',
                          icon: '🎮',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DemoModeScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Glassmorphic Game Card
class GameCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const GameCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Balance Header
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CasinoViewModel>(
      builder: (context, vm, _) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.amber.withOpacity(0.3),
                Colors.amber.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.amber.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BALANCE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '\$${vm.balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Animated Background
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
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
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                sin(_controller.value * 2 * pi),
                cos(_controller.value * 2 * pi),
              ),
              colors: const [
                Color(0xFF1A237E),
                Color(0xFF0F1419),
              ],
            ),
          ),
        );
      },
    );
  }
}

// SLOTS SCREEN
class SlotsScreen extends StatefulWidget {
  const SlotsScreen({Key? key}) : super(key: key);

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  List<String> reels = ['🎰', '🎰', '🎰'];
  bool isSpinning = false;

  void spin() async {
    if (isSpinning) return;

    final vm = context.read<CasinoViewModel>();
    if (!vm.canBet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance!')),
      );
      return;
    }

    setState(() {
      isSpinning = true;
    });

    // Spinning animation
    for (int i = 0; i < 10; i++) {
      setState(() {
        reels = ['🎲', '🎲', '🎲'];
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Get result
    final result = vm.spinSlots();
    setState(() {
      reels = result;
      isSpinning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SLOTS'),
        backgroundColor: Colors.purple.withOpacity(0.3),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              const BalanceHeader(),

              // Slot Machine
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.3),
                          Colors.purple.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: reels
                              .map((symbol) => Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.amber,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      symbol,
                                      style: const TextStyle(fontSize: 48),
                                    ),
                                  ))
                              .toList(),
                        ),

                        const SizedBox(height: 30),

                        // Bet controls
                        BetControls(),

                        const SizedBox(height: 20),

                        // Spin button
                        ElevatedButton(
                          key: const Key('spinButton'),
                          onPressed: isSpinning ? null : spin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            isSpinning ? 'SPINNING...' : 'SPIN',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ROULETTE SCREEN
class RouletteScreen extends StatefulWidget {
  const RouletteScreen({Key? key}) : super(key: key);

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int? result;
  String selectedBet = 'red';
  bool isSpinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void spin() async {
    if (isSpinning) return;

    final vm = context.read<CasinoViewModel>();
    if (!vm.canBet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance!')),
      );
      return;
    }

    setState(() {
      isSpinning = true;
    });

    _controller.forward(from: 0);

    await Future.delayed(const Duration(seconds: 3));

    final newResult = vm.spinRoulette('color', selectedBet);

    setState(() {
      result = newResult;
      isSpinning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROULETTE'),
        backgroundColor: Colors.red.withOpacity(0.3),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              const BalanceHeader(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Roulette Wheel
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _controller.value * 10 * pi,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [Colors.red, Colors.black],
                                ),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  result?.toString() ?? '?',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Betting options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            key: const Key('redBet'),
                            label: const Text('RED'),
                            selected: selectedBet == 'red',
                            selectedColor: Colors.red,
                            onSelected: (_) =>
                                setState(() => selectedBet = 'red'),
                          ),
                          const SizedBox(width: 20),
                          ChoiceChip(
                            key: const Key('blackBet'),
                            label: const Text('BLACK'),
                            selected: selectedBet == 'black',
                            selectedColor: Colors.black,
                            onSelected: (_) =>
                                setState(() => selectedBet = 'black'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Bet controls
                      BetControls(),

                      const SizedBox(height: 20),

                      // Spin button
                      ElevatedButton(
                        key: const Key('spinRouletteButton'),
                        onPressed: isSpinning ? null : spin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isSpinning ? 'SPINNING...' : 'SPIN',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// BLACKJACK SCREEN
class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({Key? key}) : super(key: key);

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  List<String> playerCards = [];
  List<String> dealerCards = [];
  bool gameStarted = false;
  bool gameOver = false;
  String? result;

  void startGame() {
    final vm = context.read<CasinoViewModel>();
    if (!vm.canBet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance!')),
      );
      return;
    }

    vm.placeBet();

    setState(() {
      playerCards = vm.dealCards(2);
      dealerCards = vm.dealCards(2);
      gameStarted = true;
      gameOver = false;
      result = null;
    });

    checkBlackjack();
  }

  void hit() {
    final vm = context.read<CasinoViewModel>();
    setState(() {
      playerCards.add(vm.dealCards(1).first);
    });

    if (getHandValue(playerCards) > 21) {
      endGame('BUST! You lose!');
    }
  }

  void stand() {
    final vm = context.read<CasinoViewModel>();

    // Dealer draws cards
    while (getHandValue(dealerCards) < 17) {
      setState(() {
        dealerCards.add(vm.dealCards(1).first);
      });
    }

    final playerValue = getHandValue(playerCards);
    final dealerValue = getHandValue(dealerCards);

    if (dealerValue > 21) {
      endGame('Dealer bust! You win!');
      vm.addWinnings(vm.currentBet * 2);
    } else if (playerValue > dealerValue) {
      endGame('You win!');
      vm.addWinnings(vm.currentBet * 2);
    } else if (playerValue < dealerValue) {
      endGame('Dealer wins!');
    } else {
      endGame('Push! It\'s a tie!');
      vm.addWinnings(vm.currentBet);
    }
  }

  void checkBlackjack() {
    final playerValue = getHandValue(playerCards);
    final dealerValue = getHandValue(dealerCards);

    if (playerValue == 21 && playerCards.length == 2) {
      if (dealerValue == 21 && dealerCards.length == 2) {
        endGame('Both have Blackjack! Push!');
        context
            .read<CasinoViewModel>()
            .addWinnings(context.read<CasinoViewModel>().currentBet);
      } else {
        endGame('BLACKJACK! You win!');
        context
            .read<CasinoViewModel>()
            .addWinnings(context.read<CasinoViewModel>().currentBet * 2.5);
      }
    }
  }

  void endGame(String message) {
    setState(() {
      gameOver = true;
      result = message;
    });
  }

  int getHandValue(List<String> cards) {
    final vm = context.read<CasinoViewModel>();
    int value = 0;
    int aces = 0;

    for (final card in cards) {
      final cardValue = vm.getCardValue(card);
      value += cardValue;
      if (card == 'A') aces++;
    }

    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLACKJACK'),
        backgroundColor: Colors.green.withOpacity(0.3),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              const BalanceHeader(),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dealer cards
                        Column(
                          children: [
                            const Text(
                              'DEALER',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dealerCards
                                  .map((card) => Card(
                                        margin: const EdgeInsets.all(5),
                                        color: Colors.black.withOpacity(0.7),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Text(
                                            card,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            if (gameOver)
                              Text(
                                'Value: ${getHandValue(dealerCards)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Result
                        if (result != null)
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: result!.contains('win')
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              result!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        const SizedBox(height: 40),

                        // Player cards
                        Column(
                          children: [
                            const Text(
                              'PLAYER',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: playerCards
                                  .map((card) => Card(
                                        margin: const EdgeInsets.all(5),
                                        color: Colors.black.withOpacity(0.7),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Text(
                                            card,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            if (gameStarted)
                              Text(
                                'Value: ${getHandValue(playerCards)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Bet controls
                        if (!gameStarted) BetControls(),

                        const SizedBox(height: 20),

                        // Game controls
                        if (!gameStarted)
                          ElevatedButton(
                            key: const Key('dealButton'),
                            onPressed: startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 20,
                              ),
                            ),
                            child: const Text(
                              'DEAL',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        if (gameStarted && !gameOver)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                key: const Key('hitButton'),
                                onPressed: hit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.all(20),
                                ),
                                child: const Text(
                                  'HIT',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton(
                                key: const Key('standButton'),
                                onPressed: stand,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.all(20),
                                ),
                                child: const Text(
                                  'STAND',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            ],
                          ),

                        if (gameOver)
                          ElevatedButton(
                            key: const Key('newGameButton'),
                            onPressed: () {
                              setState(() {
                                playerCards = [];
                                dealerCards = [];
                                gameStarted = false;
                                gameOver = false;
                                result = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.all(20),
                            ),
                            child: const Text(
                              'NEW GAME',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// DEMO MODE SCREEN
class DemoModeScreen extends StatefulWidget {
  const DemoModeScreen({Key? key}) : super(key: key);

  @override
  State<DemoModeScreen> createState() => _DemoModeScreenState();
}

class _DemoModeScreenState extends State<DemoModeScreen> {
  bool isRunning = false;
  List<String> log = [];

  void runDemo() async {
    if (isRunning) return;

    setState(() {
      isRunning = true;
      log = ['Starting demo mode...'];
    });

    final vm = context.read<CasinoViewModel>();

    // Run 10 rounds of each game
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));

      // Slots
      final slotsResult = vm.spinSlots();
      setState(() {
        log.add('Slots: ${slotsResult.join(" ")}');
      });

      await Future.delayed(const Duration(milliseconds: 500));

      // Roulette
      final rouletteResult =
          vm.spinRoulette('color', i % 2 == 0 ? 'red' : 'black');
      setState(() {
        log.add('Roulette: $rouletteResult');
      });

      if (log.length > 10) {
        setState(() {
          log.removeAt(0);
        });
      }
    }

    setState(() {
      isRunning = false;
      log.add('Demo complete! Balance: \$${vm.balance.toStringAsFixed(2)}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEMO MODE'),
        backgroundColor: Colors.blue.withOpacity(0.3),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              const BalanceHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'AUTO-PLAY LOG',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: log.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text(
                                log[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        key: const Key('runDemoButton'),
                        onPressed: isRunning ? null : runDemo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 20,
                          ),
                        ),
                        child: Text(
                          isRunning ? 'RUNNING...' : 'RUN DEMO',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bet Controls Widget
class BetControls extends StatelessWidget {
  const BetControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CasinoViewModel>(
      builder: (context, vm, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('decreaseBetButton'),
              onPressed: () => vm.setBet(vm.currentBet - 10),
              icon: const Icon(Icons.remove_circle, size: 32),
              color: Colors.red,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(
                'BET: \$${vm.currentBet.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              key: const Key('increaseBetButton'),
              onPressed: () => vm.setBet(vm.currentBet + 10),
              icon: const Icon(Icons.add_circle, size: 32),
              color: Colors.green,
            ),
          ],
        );
      },
    );
  }
}
