import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design Tokens NEXORA: Clean Light Editorial
/// Doktrin: Premium, asimetris, manusiawi (Apple Home / Google Home editorial vibe).
class NexoraTokens {
  // ==========================================
  // 1. WARNA (COLORS)
  // Doktrin: background warm-white #F7F8F7; ink #0F1417; aksen cyan #00A6E0
  // pendukung: green #17B26A, amber #F5A524, gray #8A949E.
  // ==========================================
  static const Color background = Color(0xFFF7F8F7);  // Warm-white
  static const Color surface = Color(0xFFFFFFFF);     // Pure card white
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEBEEF0); // 1px border

  // Ink (Teks Utama)
  static const Color ink = Color(0xFF0F1417);
  static const Color inkSecondary = Color(0xFF5A6672);
  static const Color inkMuted = Color(0xFF8A949E);

  // Aksen Brand Cyan (HEMAT, maks 10% layar)
  static const Color brandCyan = Color(0xFF00A6E0);
  static const Color brandCyanSubtle = Color(0xFFE6F6FC); // Tint kartu ON
  static const Color brandCyanBorder = Color(0xFFBCE7F8);

  // Warna Pendukung Fungsional
  static const Color statusGreen = Color(0xFF17B26A); // Aman / terkunci
  static const Color statusGreenSubtle = Color(0xFFE8FAF0);
  static const Color statusAmber = Color(0xFFF5A524); // Energi / peringatan
  static const Color statusAmberSubtle = Color(0xFFFEF6E9);
  static const Color statusGray = Color(0xFF8A949E);  // Idle / nonaktif
  static const Color statusGraySubtle = Color(0xFFF1F3F5);

  // ==========================================
  // 2. RADIUS
  // Doktrin: radius 24 untuk kartu, border 1px #EBEEF0
  // ==========================================
  static const double radiusCard = 24.0;
  static const double radiusButton = 16.0;
  static const double radiusChip = 12.0;
  static const double radiusPill = 999.0;

  static final BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);
  static final BorderRadius borderRadiusButton = BorderRadius.circular(radiusButton);
  static final BorderRadius borderRadiusChip = BorderRadius.circular(radiusChip);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ==========================================
  // 3. ELEVATION & SHADOWS (Apple Home 2026 Multi-layered Soft Shadows)
  // ==========================================
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F1417).withOpacity(0.04),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F1417).withOpacity(0.02),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadowActive(Color glowColor) => [
    BoxShadow(
      color: glowColor.withOpacity(0.18),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF0F1417).withOpacity(0.03),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get pillNavShadow => [
    BoxShadow(
      color: const Color(0xFF0F1417).withOpacity(0.12),
      blurRadius: 30,
      spreadRadius: 0,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF0F1417).withOpacity(0.04),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  // ==========================================
  // 4. TIPOGRAFI (TYPOGRAPHY)
  // Base: "Plus Jakarta Sans" (400, 500, 600, 800)
  // Aksen: "Fraunces" italic untuk kata aksen sapaan
  // ==========================================
  static const String fontFamilySans = 'Plus Jakarta Sans';

  static TextStyle get greetingText => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static TextStyle get greetingAccent => GoogleFonts.fraunces(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: ink,
    letterSpacing: -0.6,
  );

  static TextStyle get sectionLabel => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: inkMuted,
    letterSpacing: 1.2,
  );

  static TextStyle get ambientStatus => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: inkSecondary,
    height: 1.4,
  );

  static TextStyle get cardTitle => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: ink,
    letterSpacing: -0.2,
  );

  static TextStyle get cardStatus => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static TextStyle get microcopy => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: inkMuted,
  );

  static TextStyle get chipLabel => const TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ink,
    letterSpacing: -0.1,
  );
}
