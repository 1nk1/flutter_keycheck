import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium casino theme with glassmorphism support
class AppTheme {
  AppTheme._();

  // Casino Color Palette
  static const CasinoColors _colors = CasinoColors();

  // Text Styles
  static TextTheme get _textTheme => GoogleFonts.orbitronTextTheme().copyWith(
        displayLarge: GoogleFonts.orbitron(
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        displayMedium: GoogleFonts.orbitron(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        displaySmall: GoogleFonts.orbitron(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineLarge: GoogleFonts.orbitron(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.orbitron(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineSmall: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.orbitron(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      );

  /// Dark theme optimized for casino ambiance
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: CasinoColors.gold,
      onPrimary: CasinoColors.darkBackground,
      secondary: CasinoColors.emerald,
      onSecondary: Colors.white,
      tertiary: CasinoColors.ruby,
      onTertiary: Colors.white,
      error: CasinoColors.ruby,
      onError: Colors.white,
      surface: CasinoColors.darkSurface,
      onSurface: CasinoColors.lightText,
      background: CasinoColors.darkBackground,
      onBackground: CasinoColors.lightText,
      outline: CasinoColors.glassOutline,
      shadow: CasinoColors.shadowColor,
      surfaceVariant: CasinoColors.glassSurface,
      onSurfaceVariant: CasinoColors.lightTextSecondary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: _textTheme.apply(
        bodyColor: CasinoColors.lightText,
        displayColor: CasinoColors.lightText,
      ),
      scaffoldBackgroundColor: CasinoColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: CasinoColors.glassBackground,
        foregroundColor: CasinoColors.lightText,
        elevation: 0,
        titleTextStyle: _textTheme.titleLarge?.copyWith(
          color: CasinoColors.gold,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CasinoColors.gold,
          foregroundColor: CasinoColors.darkBackground,
          elevation: 8,
          shadowColor: CasinoColors.goldGlow.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: CasinoColors.glassSurface,
        elevation: 8,
        shadowColor: CasinoColors.shadowColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CasinoColors.glassOutline,
        thickness: 1,
      ),
    );
  }

  /// Light theme for accessibility (optional casino mode)
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: CasinoColors.darkGold,
      onPrimary: Colors.white,
      secondary: CasinoColors.darkEmerald,
      onSecondary: Colors.white,
      tertiary: CasinoColors.darkRuby,
      onTertiary: Colors.white,
      error: CasinoColors.darkRuby,
      onError: Colors.white,
      surface: CasinoColors.lightSurface,
      onSurface: CasinoColors.darkText,
      background: CasinoColors.lightBackground,
      onBackground: CasinoColors.darkText,
      outline: CasinoColors.lightOutline,
      shadow: CasinoColors.lightShadow,
      surfaceVariant: CasinoColors.lightGlass,
      onSurfaceVariant: CasinoColors.darkTextSecondary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: _textTheme.apply(
        bodyColor: CasinoColors.darkText,
        displayColor: CasinoColors.darkText,
      ),
      scaffoldBackgroundColor: CasinoColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: CasinoColors.lightGlass,
        foregroundColor: CasinoColors.darkText,
        elevation: 0,
        titleTextStyle: _textTheme.titleLarge?.copyWith(
          color: CasinoColors.darkGold,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CasinoColors.darkGold,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: CasinoColors.darkGold.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: CasinoColors.lightGlass,
        elevation: 4,
        shadowColor: CasinoColors.lightShadow.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CasinoColors.lightOutline,
        thickness: 1,
      ),
    );
  }
}

/// Casino-specific color palette with Vegas luxury theme
class CasinoColors {
  const CasinoColors();

  // Primary Casino Colors
  static const Color gold = Color(0xFFFFD700);
  static const Color darkGold = Color(0xFFB8860B);
  static const Color goldGlow = Color(0xFFFFF700);

  static const Color emerald = Color(0xFF50C878);
  static const Color darkEmerald = Color(0xFF006400);
  static const Color emeraldGlow = Color(0xFF7FFFD4);

  static const Color ruby = Color(0xFFE0115F);
  static const Color darkRuby = Color(0xFF8B0000);
  static const Color rubyGlow = Color(0xFFFF69B4);

  // Background Colors
  static const Color darkBackground = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Text Colors
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color lightTextSecondary = Color(0xFFB3B3B3);
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color darkTextSecondary = Color(0xFF666666);

  // Glassmorphism Colors
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassSurface = Color(0x33FFFFFF);
  static const Color glassOutline = Color(0x4DFFFFFF);
  static const Color lightGlass = Color(0x1A000000);
  static const Color lightOutline = Color(0x4D000000);

  // Shadow Colors
  static const Color shadowColor = Color(0x80000000);
  static const Color lightShadow = Color(0x40000000);

  // Casino Chip Colors
  static const Color chipRed = Color(0xFFDC143C);
  static const Color chipBlue = Color(0xFF1E90FF);
  static const Color chipGreen = Color(0xFF32CD32);
  static const Color chipBlack = Color(0xFF2F2F2F);
  static const Color chipWhite = Color(0xFFFFFFF0);
  static const Color chipPurple = Color(0xFF9370DB);
  static const Color chipOrange = Color(0xFFFF8C00);
  static const Color chipPink = Color(0xFFFF69B4);

  // Gradient Colors for Backgrounds
  static const List<Color> casinoGradient = [
    Color(0xFF0A0A0F),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFFFD700),
    Color(0xFFFFA500),
    Color(0xFFFF8C00),
  ];

  static const List<Color> emeraldGradient = [
    Color(0xFF50C878),
    Color(0xFF00FF7F),
    Color(0xFF00CED1),
  ];

  static const List<Color> rubyGradient = [
    Color(0xFFE0115F),
    Color(0xFFFF1493),
    Color(0xFFFF69B4),
  ];

  // Neon Glow Colors
  static const Color neonBlue = Color(0xFF00BFFF);
  static const Color neonPink = Color(0xFFFF1493);
  static const Color neonGreen = Color(0xFF00FF7F);
  static const Color neonPurple = Color(0xFF9400D3);
  static const Color neonOrange = Color(0xFFFF4500);

  /// Get chip color by value
  static Color getChipColor(int value) {
    switch (value) {
      case 1:
        return chipWhite;
      case 5:
        return chipRed;
      case 10:
        return chipBlue;
      case 25:
        return chipGreen;
      case 50:
        return chipOrange;
      case 100:
        return chipBlack;
      case 500:
        return chipPurple;
      case 1000:
        return chipPink;
      default:
        return gold;
    }
  }

  /// Get gradient for casino elements
  static LinearGradient get casinoBackgroundGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: casinoGradient,
      );

  /// Get gold gradient for premium elements
  static LinearGradient get premiumGoldGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: goldGradient,
      );

  /// Get neon glow effect
  static List<BoxShadow> getNeonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.6 * intensity),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 40,
        spreadRadius: 4,
      ),
    ];
  }

  /// Get glassmorphism shadow
  static List<BoxShadow> get glassMorphismShadow => [
        BoxShadow(
          color: shadowColor.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.1),
          blurRadius: 1,
          spreadRadius: 0,
          offset: const Offset(0, -1),
        ),
      ];
}

/// Extension for theme-aware colors
extension CasinoThemeData on ThemeData {
  /// Get casino-specific colors based on brightness
  CasinoColorScheme get casinoColors => brightness == Brightness.dark
      ? const DarkCasinoColorScheme()
      : const LightCasinoColorScheme();
}

/// Abstract casino color scheme
abstract class CasinoColorScheme {
  const CasinoColorScheme();

  Color get primaryGold;
  Color get primaryEmerald;
  Color get primaryRuby;
  Color get glassBackground;
  Color get glassBorder;
  Color get textPrimary;
  Color get textSecondary;
  LinearGradient get backgroundGradient;
  List<BoxShadow> get defaultGlow;
}

/// Dark casino color scheme
class DarkCasinoColorScheme extends CasinoColorScheme {
  const DarkCasinoColorScheme();

  @override
  Color get primaryGold => CasinoColors.gold;

  @override
  Color get primaryEmerald => CasinoColors.emerald;

  @override
  Color get primaryRuby => CasinoColors.ruby;

  @override
  Color get glassBackground => CasinoColors.glassBackground;

  @override
  Color get glassBorder => CasinoColors.glassOutline;

  @override
  Color get textPrimary => CasinoColors.lightText;

  @override
  Color get textSecondary => CasinoColors.lightTextSecondary;

  @override
  LinearGradient get backgroundGradient =>
      CasinoColors.casinoBackgroundGradient;

  @override
  List<BoxShadow> get defaultGlow =>
      CasinoColors.getNeonGlow(CasinoColors.gold);
}

/// Light casino color scheme
class LightCasinoColorScheme extends CasinoColorScheme {
  const LightCasinoColorScheme();

  @override
  Color get primaryGold => CasinoColors.darkGold;

  @override
  Color get primaryEmerald => CasinoColors.darkEmerald;

  @override
  Color get primaryRuby => CasinoColors.darkRuby;

  @override
  Color get glassBackground => CasinoColors.lightGlass;

  @override
  Color get glassBorder => CasinoColors.lightOutline;

  @override
  Color get textPrimary => CasinoColors.darkText;

  @override
  Color get textSecondary => CasinoColors.darkTextSecondary;

  @override
  LinearGradient get backgroundGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          CasinoColors.lightBackground,
          Color(0xFFF0F0F0),
          Color(0xFFE8E8E8),
        ],
      );

  @override
  List<BoxShadow> get defaultGlow => [
        BoxShadow(
          color: CasinoColors.darkGold.withOpacity(0.3),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
}
