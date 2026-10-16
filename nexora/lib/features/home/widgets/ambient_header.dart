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

  @override
  Widget build(BuildContext context) {
    final currentWeather = WeatherService().currentCondition;
    final lang = LanguageService();
    final bool isEn = lang.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. TOP ROW: SWITCH BAHASA (KIRI) & TOMBOL CEPAT TAMBAH PERANGKAT (KANAN)
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 16,
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

        // Sapaan Editorial Warna Putih Kontras Tinggi di Latar Langit Pekat
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
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
                          text: '${AuthService().isLoggedIn ? AuthService().currentUserName : userName}.',
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
                  const SizedBox(height: 5),
                  // Badge & Mode Rumah Live (Preset / Manual) - Menggunakan Wrap agar tidak pernah overflow
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Badge Role
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AuthService().isSuperAdmin
                              ? Colors.purple.withOpacity(0.4)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AuthService().isSuperAdmin
                                ? Colors.purpleAccent.withOpacity(0.6)
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
                                letterSpacing: 0.8,
                                color: AuthService().isSuperAdmin ? Colors.amberAccent : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Indicator Mode Rumah Aktif Live (Mode Santai / Mode Keluar / Mode Manual)
                      StreamBuilder<String>(
                        stream: PresetManagerService().activeModeStream,
                        initialData: PresetManagerService().activeModeName,
                        builder: (context, snap) {
                          final modeName = snap.data ?? 'Mode Manual';
                          final isManual = modeName == 'Mode Manual';
                          final modeColor = isManual ? Colors.white70 : const Color(0xFF34D399);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isManual ? Colors.black.withOpacity(0.25) : const Color(0xFF064E3B).withOpacity(0.65),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isManual ? Colors.white24 : const Color(0xFF34D399).withOpacity(0.5),
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
                                    letterSpacing: 0.6,
                                    color: modeColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
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
