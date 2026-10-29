import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/weather_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/services/preset_manager_service.dart';
import 'package:nexora/features/home/widgets/quick_add_device_sheet.dart';

/// Ambient Header: Sapaan editorial kontras putih tajam di atas langit pekat atmosferik
class AmbientHeader extends StatelessWidget {
  final String userName;
  final String? statusSentence;
  final double temperature;
  final int humidity;
  final String? weatherDesc;
  final String? locationName;
  final VoidCallback? onWeatherTap;
  final VoidCallback? onAddTap;

  const AmbientHeader({
    Key? key,
    this.userName = 'Fi',
    this.statusSentence,
    this.temperature = 27.0,
    this.humidity = 80,
    this.weatherDesc,
    this.locationName,
    this.onWeatherTap,
    this.onAddTap,
  }) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final lang = LanguageService();
    if (hour < 11) return lang.tr('greeting_morning');
    if (hour < 15) return lang.tr('greeting_afternoon');
    if (hour < 18) return lang.tr('greeting_evening');
    return lang.tr('greeting_night');
  }

  IconData _getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.cerah:
        return Icons.wb_sunny_rounded;
      case WeatherCondition.berawan:
        return Icons.cloud_rounded;
      case WeatherCondition.hujan:
        return Icons.grain_rounded;
      case WeatherCondition.angin:
        return Icons.air_rounded;
      case WeatherCondition.malam:
        return Icons.nights_stay_rounded;
    }
  }

  String _cleanDisplayName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    return cleaned.isEmpty ? ' Pengguna' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final currentWeather = WeatherService().currentCondition;
    final lang = LanguageService();
    final bool isEn = lang.isEnglish;
    final rawName = AuthService().isLoggedIn ? AuthService().currentUserName : userName;
    final displayName = _cleanDisplayName(rawName);
    final shortCity = (locationName ?? WeatherService().locationName).split(',').first.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. TOP ROW: SWITCH BAHASA (KIRI), CHIP CUACA LOKASI (TENGAH), & TOMBOL TAMBAH (KANAN)
        Row(
          children: [
            // Switch Bahasa Elegan (Paling Atas Sebelah Kiri)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                lang.toggleLanguage();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.40),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: !isEn ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🇮🇩 ID',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 10,
                          fontWeight: !isEn ? FontWeight.w800 : FontWeight.w600,
                          color: !isEn ? NexoraTokens.ink : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEn ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🇬🇧 EN',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 10,
                          fontWeight: isEn ? FontWeight.w800 : FontWeight.w600,
                          color: isEn ? NexoraTokens.ink : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Tombol Cepat Tambah Perangkat '+' (Paling Atas Sebelah Kanan)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (onAddTap != null) {
                  onAddTap!();
                } else {
                  QuickAddDeviceSheet.show(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEn ? 'Add' : 'Tambah',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 1. SAPAAN EDITORIAL PENUH LEBAR (MAKSIMAL 2 BARIS, RAPI & TIDAK MEMANJANG KE BAWAH)
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: _getGreeting(),
                style: NexoraTokens.greetingText.copyWith(
                  fontSize: 22,
                  height: 1.22,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              TextSpan(
                text: '$displayName.',
                style: NexoraTokens.greetingAccent.copyWith(
                  fontSize: 22,
                  height: 1.22,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. BARIS BADGE ROLE, MODE RUMAH, & CHIP CUACA LOKASI REALTIME (MENGGUNAKAN WRAP ANTI-OVERFLOW)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Badge Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AuthService().isSuperAdmin
                    ? const Color(0xFF581C87).withOpacity(0.65)
                    : Colors.black.withOpacity(0.30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthService().isSuperAdmin
                      ? Colors.purpleAccent.withOpacity(0.7)
                      : Colors.white38,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AuthService().isSuperAdmin ? Icons.stars_rounded : Icons.person_rounded,
                    size: 12,
                    color: AuthService().isSuperAdmin ? Colors.amberAccent : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AuthService().isSuperAdmin ? 'ADMIN' : 'USER',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: AuthService().isSuperAdmin ? Colors.amberAccent : Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Indicator Mode Rumah Aktif Live
            StreamBuilder<String>(
              stream: PresetManagerService().activeModeStream,
              initialData: PresetManagerService().activeModeName,
              builder: (context, snap) {
                final modeName = snap.data ?? 'Mode Manual';
                final isManual = modeName == 'Mode Manual';
                final modeColor = isManual ? Colors.white : const Color(0xFF34D399);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isManual
                        ? Colors.black.withOpacity(0.32)
                        : const Color(0xFF064E3B).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isManual ? Colors.white30 : const Color(0xFF34D399).withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: modeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        modeName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: modeColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Chip Cuaca & Lokasi Otomatis (Tap untuk Detail Cuaca & Status Koneksi)
            GestureDetector(
              onTap: onWeatherTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.32),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.42),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getWeatherIcon(currentWeather),
                      size: 13,
                      color: Colors.amberAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${temperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• ${weatherDesc ?? WeatherService().bmkgWeatherDesc}',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    if (shortCity.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        shortCity,
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE0F2FE),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 3. SATU KALIMAT STATUS RUMAH (KONTRAS JELAS DI ATAS LANGIT)
        Text(
          statusSentence ?? lang.tr('status_sentence'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NexoraTokens.ambientStatus.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.95),
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
