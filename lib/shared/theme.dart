import 'package:flutter/material.dart';

/// Tether design system color palette — dark theme only.
class TetherColors {
  TetherColors._();

  static const Color backgroundBase = Color(0xFF0D0D0F);
  static const Color surfaceElevated = Color(0xFF141418);
  static const Color surfaceHigher = Color(0xFF1C1C22);
  static const Color borderSubtle = Color(0xFF2A2A35);
  static const Color borderStrong = Color(0xFF3D3D50);
  static const Color accentPrimary = Color(0xFF5B85AA);
  static const Color accentSecondary = Color(0xFFA3BACF);
  static const Color accentDanger = Color(0xFFFF4D6A);
  static const Color accentWarning = Color(0xFFF5A623);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8888A0);
  static const Color textDisabled = Color(0xFF44445A);
}

/// Spacing scale based on 4px base unit.
class TetherSpacing {
  TetherSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Border radius presets.
class TetherRadius {
  TetherRadius._();

  static const double card = 6;
  static const double badge = 4;
  static const double modal = 12;
  static const double button = 6;
}

/// Theme provider for the Tether app.
class TetherTheme {
  TetherTheme._();

  static const String _fontFamily = 'Inter';
  static const String _monoFontFamily = 'JetBrainsMono';

  static TextStyle get monoStyle => const TextStyle(
        fontFamily: _monoFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: TetherColors.textPrimary,
      );

  static TextStyle get monoSmall => const TextStyle(
        fontFamily: _monoFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: TetherColors.textDisabled,
      );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: TetherColors.backgroundBase,
      canvasColor: TetherColors.surfaceElevated,
      colorScheme: const ColorScheme.dark(
        primary: TetherColors.accentPrimary,
        secondary: TetherColors.accentSecondary,
        surface: TetherColors.surfaceElevated,
        error: TetherColors.accentDanger,
        onPrimary: TetherColors.textPrimary,
        onSecondary: TetherColors.textPrimary,
        onSurface: TetherColors.textPrimary,
        onError: TetherColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TetherColors.backgroundBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TetherColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: TetherColors.textSecondary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: TetherColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetherRadius.card),
          side: const BorderSide(color: TetherColors.borderSubtle, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        // Page titles — 20px, w600
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: TetherColors.textPrimary,
        ),
        // Section headers — 13px, w600, uppercase
        titleMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 13,
          color: TetherColors.textSecondary,
        ),
        // Body text — 14px, w400
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: TetherColors.textPrimary,
        ),
        // Metadata — 12px, w400
        bodySmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: TetherColors.textSecondary,
        ),
        // Mono data — 13px JetBrainsMono
        labelSmall: TextStyle(
          fontFamily: _monoFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: TetherColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TetherColors.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TetherRadius.button),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TetherColors.textPrimary,
          side: const BorderSide(color: TetherColors.borderSubtle),
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TetherRadius.button),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TetherColors.accentPrimary,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TetherColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TetherRadius.card),
          borderSide: const BorderSide(color: TetherColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TetherRadius.card),
          borderSide: const BorderSide(color: TetherColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TetherRadius.card),
          borderSide: const BorderSide(color: TetherColors.borderStrong),
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: TetherColors.textDisabled,
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: TetherColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TetherColors.borderSubtle,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TetherColors.backgroundBase,
        selectedItemColor: TetherColors.accentPrimary,
        unselectedItemColor: TetherColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(TetherColors.borderSubtle),
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: TetherColors.surfaceHigher,
          borderRadius: BorderRadius.circular(TetherRadius.badge),
          border: Border.all(color: TetherColors.borderSubtle),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: TetherColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TetherColors.surfaceHigher,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: TetherColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetherRadius.card),
          side: const BorderSide(color: TetherColors.borderSubtle),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TetherColors.surfaceHigher,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TetherRadius.modal),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TetherColors.textPrimary,
        ),
      ),
    );
  }
}
