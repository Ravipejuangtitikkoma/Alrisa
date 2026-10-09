import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// AppColors bridge ke NexoraTokens
class AppColors {
  static const Color background = NexoraTokens.background;
  static const Color surface = NexoraTokens.surface;
  static const Color card = NexoraTokens.card;
  static const Color cardBorder = NexoraTokens.cardBorder;

  static const Color primaryCyan = NexoraTokens.brandCyan;
  static const Color cyanLight = NexoraTokens.brandCyanSubtle;
  static const Color cyanGlow = Color(0x3300A6E0);

  static const Color textPrimary = NexoraTokens.ink;
  static const Color textSecondary = NexoraTokens.inkSecondary;
  static const Color statusOff = NexoraTokens.statusGray;

  static const Color statusOnline = NexoraTokens.statusGreen;
  static const Color statusAlert = NexoraTokens.statusAmber;

  static const Color primaryBlue = NexoraTokens.brandCyan;
  static const Color neonCyan = NexoraTokens.brandCyan;
  static const Color textMuted = NexoraTokens.inkMuted;

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF1EC9FF), Color(0xFF00A6E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient primaryGradient = cyanGradient;

  static const LinearGradient cardActiveGradient = LinearGradient(
    colors: [Color(0xFFF7FCFE), Color(0xFFE6F6FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => NexoraTokens.cardShadow;
  static List<BoxShadow> get cardShadow => NexoraTokens.cardShadow;
  static List<BoxShadow> get cyanSoftGlow => [
    BoxShadow(
      color: primaryCyan.withOpacity(0.18),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get activeGlow => cyanSoftGlow;
}
