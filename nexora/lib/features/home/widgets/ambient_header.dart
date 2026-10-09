import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/weather_service.dart';
import 'package:nexora/services/language_service.dart';

/// Ambient Header: Sapaan editorial kontras putih tajam di atas langit pekat atmosferik
class AmbientHeader extends StatelessWidget {
  final String userName;
  final String? statusSentence;
  final double temperature;
  final int humidity;
  final String? weatherDesc;
  final String? locationName;
  final VoidCallback? onWeatherTap;

  const AmbientHeader({
    Key? key,
    this.userName = 'Fi',
    this.statusSentence,
    this.temperature = 27.0,
    this.humidity = 80,
    this.weatherDesc,
    this.locationName,
    this.onWeatherTap,
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

  @override
  Widget build(BuildContext context) {
    final currentWeather = WeatherService().currentCondition;
    final lang = LanguageService();
    final bool isEn = lang.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. TOP ROW: SWITCH BAHASA (DI PALING ATAS SEBELAH KIRI)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opsi ID (Indonesia)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !isEn ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🇮🇩 ID',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 10.5,
                          fontWeight: !isEn ? FontWeight.w800 : FontWeight.w600,
                          color: !isEn ? NexoraTokens.ink : Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Opsi EN (English)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEn ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🇬🇧 EN',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 10.5,
                          fontWeight: isEn ? FontWeight.w800 : FontWeight.w600,
                          color: isEn ? NexoraTokens.ink : Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Sapaan Editorial Warna Putih Kontras Tinggi di Latar Langit Pekat
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _getGreeting(),
                      style: NexoraTokens.greetingText.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: '$userName.',
                      style: NexoraTokens.greetingAccent.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chip Suhu & Cuaca Frosted Glass Elegan (Gaya App Cuaca Infinix)
            GestureDetector(
              onTap: onWeatherTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getWeatherIcon(currentWeather),
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${temperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      weatherDesc ?? WeatherService().bmkgWeatherDesc,
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Satu Kalimat Status Rumah (Putih Lembut dengan Kontras Jelas)
        Text(
          statusSentence ?? lang.tr('status_sentence'),
          style: NexoraTokens.ambientStatus.copyWith(
            color: Colors.white.withOpacity(0.92),
            shadows: const [
              Shadow(
                color: Colors.black26,
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
