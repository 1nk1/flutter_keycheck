# Premium Casino Demo - Glassmorphism UI

A premium Flutter casino application showcasing luxurious glassmorphism UI components with Vegas casino aesthetics.

## Features

### 🎨 Premium Glassmorphism UI Components

- **GlassContainer**: Base glassmorphic container with blur effects
- **GlassmorphicCard**: Interactive cards with casino-style animations
- **GlassButton**: Premium buttons with glow effects and haptic feedback
- **CasinoChip**: Realistic 3D casino chips with stacking effects
- **CasinoAnimatedBackground**: Luxury animated backgrounds with particles

### 🎰 Casino Theme System

- **Dual Themes**: Dark casino mode and light accessibility mode
- **Color Palette**: Gold, Emerald, Ruby with neon glow effects
- **Typography**: Orbitron for headings, Roboto for body text
- **Animations**: Smooth micro-interactions with haptic feedback

### 🌟 Key UI Elements

- **Stats Cards**: Glassmorphic stat displays with trend indicators
- **Game Tiles**: Premium game cards with jackpot amounts
- **Chip Selector**: Interactive casino chip betting system
- **Floating Actions**: Glass floating action buttons
- **Animated Backgrounds**: Particle systems and geometric patterns

## File Structure

```
lib/
├── ui/
│   ├── theme/
│   │   └── app_theme.dart           # Casino theme with dual modes
│   └── widgets/
│       └── glassmorphic/
│           ├── glass_container.dart  # Base glass container
│           ├── glass_card.dart      # Interactive glass cards
│           ├── glass_button.dart    # Premium glass buttons
│           ├── chip_widget.dart     # 3D casino chips
│           ├── animated_background.dart # Luxury backgrounds
│           └── glassmorphic.dart    # Barrel export file
└── main.dart                        # Demo casino application
```

## Design System

### Color Scheme

- **Primary Gold**: `#FFD700` - Premium branding and accents
- **Emerald**: `#50C878` - Success states and wins
- **Ruby**: `#E0115F` - Alerts and losses
- **Dark Background**: `#0A0A0F` - Rich casino ambiance
- **Glass Effects**: Semi-transparent overlays with blur

### Typography

- **Display Text**: Orbitron (futuristic, casino-style)
- **Body Text**: Roboto (readable, accessible)
- **Font Weights**: Light to Bold range for hierarchy

### Animation Principles

- **Micro-interactions**: Subtle hover and press states
- **Easing**: Smooth curves for premium feel
- **Haptic Feedback**: iOS and Android vibration support
- **Performance**: 60fps animations with hardware acceleration

## Usage

```dart
import 'package:flutter_casino_demo/ui/widgets/glassmorphic/glassmorphic.dart';
import 'package:flutter_casino_demo/ui/theme/app_theme.dart';

// Apply casino theme
MaterialApp(
  theme: AppTheme.darkTheme,
  home: MyApp(),
)

// Use glassmorphic components
GlassmorphicCard(
  title: 'Premium Feature',
  glowColor: CasinoColors.gold,
  child: YourContent(),
)

CasinoChip(
  value: 100,
  onTap: () => placeBet(100),
  isSelected: true,
)

GlassButton(
  onPressed: () => startGame(),
  style: GlassButtonStyle.primary,
  child: Text('PLAY'),
)
```

## Technical Details

### Glassmorphism Implementation

- **BackdropFilter**: iOS-style blur effects
- **Custom Gradients**: Multi-stop gradients for depth
- **Box Shadows**: Multiple shadows for realistic lighting
- **Border Effects**: Semi-transparent borders with glow

### Performance Optimizations

- **Efficient Animations**: Using AnimationController properly
- **Image Caching**: Optimized asset loading
- **State Management**: Minimal rebuilds with targeted setState
- **Memory Management**: Proper disposal of controllers

### Accessibility Features

- **High Contrast**: Light mode for accessibility
- **Semantic Labels**: Screen reader support
- **Focus Management**: Keyboard navigation
- **Color Blindness**: Alternative visual indicators

## Building and Running

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for production
flutter build web --release
flutter build apk --release
```

## Demo Features

- **Interactive Betting**: Select chips and place bets
- **Game Previews**: Blackjack, Poker, Roulette, Slots
- **Statistics Tracking**: Wins, rates, and streaks
- **Settings Panel**: Theme switching and preferences
- **Responsive Design**: Works on mobile, tablet, and desktop

## Vegas Luxury Aesthetic

This demo showcases a high-end Vegas casino experience with:

- **Premium Materials**: Glass, gold, and neon effects
- **Sophisticated Animations**: Smooth, luxurious transitions
- **Rich Typography**: Professional casino-style fonts
- **Immersive Backgrounds**: Animated particles and patterns
- **Interactive Elements**: Realistic casino chip physics

Perfect for premium gaming applications, luxury brands, or any app requiring sophisticated glassmorphism UI components.
