import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// Tema Clean Light Editorial untuk NEXORA
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: NexoraTokens.fontFamilySans,
      scaffoldBackgroundColor: NexoraTokens.background,
      primaryColor: NexoraTokens.brandCyan,
      accentColor: NexoraTokens.brandCyan,
      cardColor: NexoraTokens.card,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: NexoraTokens.brandCyan,
        primaryVariant: Color(0xFF008BBF),
        secondary: NexoraTokens.brandCyan,
        surface: NexoraTokens.surface,
        background: NexoraTokens.background,
        error: NexoraTokens.statusAmber,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: NexoraTokens.ink,
        onBackground: NexoraTokens.ink,
      ),

      // Tipografi default Plus Jakarta Sans
      textTheme: const TextTheme(
        headline1: TextStyle(
          fontFamily: NexoraTokens.fontFamilySans,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: NexoraTokens.ink,
          letterSpacing: -0.6,
        ),
        bodyText1: TextStyle(
          fontFamily: NexoraTokens.fontFamilySans,
          fontSize: 15,
          color: NexoraTokens.ink,
        ),
        bodyText2: TextStyle(
          fontFamily: NexoraTokens.fontFamilySans,
          fontSize: 13,
          color: NexoraTokens.inkSecondary,
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: NexoraTokens.fontFamilySans,
          color: NexoraTokens.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(
          color: NexoraTokens.ink,
        ),
      ),

      // Card Theme: radius 24 dengan border 1px #EBEEF0
      cardTheme: CardTheme(
        color: NexoraTokens.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: NexoraTokens.borderRadiusCard,
          side: const BorderSide(
            color: NexoraTokens.cardBorder,
            width: 1.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
