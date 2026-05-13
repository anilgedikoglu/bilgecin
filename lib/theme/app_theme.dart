import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF6C3FC5);
  static const _bgDark = Color(0xFF0F0C1E);
  static const _bgCard = Color(0xFF1E1840);
  static const _accent = Color(0xFFB07FFF);
  static const _accentGold = Color(0xFFFFD700);

  static const colorYes = Color(0xFF22C55E);
  static const colorProbably = Color(0xFF84CC16);
  static const colorDontKnow = Color(0xFF64748B);
  static const colorProbablyNot = Color(0xFFF97316);
  static const colorNo = Color(0xFFEF4444);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
        surface: _bgDark,
        primary: _accent,
        secondary: _accentGold,
      ),
      scaffoldBackgroundColor: _bgDark,
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      cardTheme: CardTheme(
        color: _bgCard,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accent,
        linearTrackColor: Color(0xFF2D2560),
      ),
    );
  }

  static const Color bgDark = _bgDark;
  static const Color bgCard = _bgCard;
  static const Color accent = _accent;
  static const Color accentGold = _accentGold;
}
