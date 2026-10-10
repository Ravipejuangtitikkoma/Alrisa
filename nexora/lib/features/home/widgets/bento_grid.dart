import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'water_card.dart';
import 'energy_card.dart';

/// Bento Grid Asimetris dengan Animasi Vektor Minimalis untuk Semua Perangkat
class BentoGrid extends StatefulWidget {
  const BentoGrid({Key? key}) : super(key: key);

  @override
  _BentoGridState createState() => _BentoGridState();
}

class _BentoGridState extends State<BentoGrid> {
  // Status Lampu Teras (0.0 sampai 1.0)
  double _terraceLightBrightness = 0.80; // Default 80%

  bool _isSlidingDoorUnlocked = false; // Pintu Geser (default Terkunci)
  bool _isCurtainOpen = false;         // Gorden (default Tertutup)

  StreamSubscription<DeviceStateEvent>? _mqttSub;
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  @override
  void initState() {
    super.initState();

    // Inisialisasi dari status MQTT / DeviceManager tersimpan
    final lampState = MqttService().getDeviceState('lampu_teras');
    final lampDev = DeviceManagerService().getDevice('lampu_teras');
    if (lampState != null) {
      _terraceLightBrightness = (lampState.value ?? (lampState.state ? 80 : 0)) / 100.0;
    } else if (lampDev != null) {
      _terraceLightBrightness = lampDev.isActive ? (lampDev.value / 100.0) : 0.0;
    }

    final doorState = MqttService().getDeviceState('pintu_geser');
    final doorDev = DeviceManagerService().getDevice('pintu_geser');
    if (doorState != null) {
      _isSlidingDoorUnlocked = doorState.state;
    } else if (doorDev != null) {
      _isSlidingDoorUnlocked = doorDev.isActive;
    }

    final curtainState = MqttService().getDeviceState('gorden');
    final curtainDev = DeviceManagerService().getDevice('gorden');
    if (curtainState != null) {
      _isCurtainOpen = curtainState.state;
    } else if (curtainDev != null) {
      _isCurtainOpen = curtainDev.isActive;
    }

    // Dengarkan pesan /state dari broker MQTT (Single Source of Truth)
    _mqttSub = MqttService().stateStream.listen((event) {
      if (!mounted) return;

      if (event.deviceId == 'lampu_teras') {
        setState(() {
          if (event.payload.value != null) {
            _terraceLightBrightness = (event.payload.value! / 100.0).clamp(0.0, 1.0);
          } else {
            _terraceLightBrightness = event.payload.state ? 0.80 : 0.0;
          }
        });
      } else if (event.deviceId == 'pintu_geser') {
        setState(() {
          _isSlidingDoorUnlocked = event.payload.state;
        });
      } else if (event.deviceId == 'gorden') {
        setState(() {
          _isCurtainOpen = event.payload.state;
        });
      }
    });

    // Dengarkan sinkronisasi instan dari DeviceManagerService
    _deviceSub = DeviceManagerService().devicesStream.listen((devs) {
      if (!mounted) return;
      for (var d in devs) {
        if (d.id == 'lampu_teras') {
          setState(() {
            _terraceLightBrightness = d.isActive ? (d.value / 100.0).clamp(0.0, 1.0) : 0.0;
          });
        } else if (d.id == 'pintu_geser') {
          setState(() {
            _isSlidingDoorUnlocked = d.isActive;
          });
        } else if (d.id == 'gorden') {
          setState(() {
            _isCurtainOpen = d.isActive;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _mqttSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Water Card (Pompa Toren) & Lampu Teras dengan Slider Dimmer + Live Radial Glow
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: WaterCard(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildDimmerLightCard(),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Baris 2: Dua Kartu Mini Scene Animasi (Pintu Geser & Gorden)
        Row(
          children: [
            // Pintu Geser dengan Animasi Geser 700ms
            Expanded(
              child: _buildSlidingDoorCard(),
            ),
            const SizedBox(width: 14),

            // Gorden dengan Animasi Menyibak 800ms
            Expanded(
              child: _buildCurtainCard(),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Baris 3: Kartu Lebar Energi Hari Ini dengan Sparkline Hidup
        const EnergyCard(),
      ],
    );
  }

  /// 1. Kartu Lampu Teras dengan Radial Glow Halus Mengikuti Slider Secara Live
  Widget _buildDimmerLightCard() {
    final bool isLightOn = _terraceLightBrightness > 0.0;
    final int brightnessPercentage = (_terraceLightBrightness * 100).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 196,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightOn ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(
          color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
          width: isLightOn ? 1.5 : 1.0,
        ),
        boxShadow: isLightOn
            ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
            : NexoraTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ikon Bohlam dengan Live Radial Glow di Belakangnya
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                  ),
                  boxShadow: [
                    if (isLightOn)
                      BoxShadow(
                        color: NexoraTokens.brandCyan.withOpacity(0.35 * _terraceLightBrightness),
                        blurRadius: 18 * _terraceLightBrightness,
                        spreadRadius: 3 * _terraceLightBrightness,
                      ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: isLightOn ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                ),
              ),

              const SizedBox(width: 6),

              // Badge: "Mati" jika slider = 0, "Menyala <nilai>%" jika slider > 0
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final nextState = !isLightOn;
                    setState(() {
                      if (isLightOn) {
                        _terraceLightBrightness = 0.0;
                      } else {
                        _terraceLightBrightness = 0.80;
                      }
                    });

                    MqttService().publishSet('lampu_teras', state: nextState, value: nextState ? 80 : 0);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isLightOn ? 'Menyala $brightnessPercentage%' : 'Mati',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isLightOn ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Slider Dimmer Halus
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: NexoraTokens.brandCyan,
                  inactiveTrackColor: NexoraTokens.cardBorder,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayColor: NexoraTokens.brandCyan.withOpacity(0.12),
                ),
                child: Slider(
                  value: _terraceLightBrightness,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      _terraceLightBrightness = (val < 0.02) ? 0.0 : val;
                    });
                  },
                  onChangeEnd: (val) {
                    final cleanVal = (val < 0.02) ? 0.0 : val;
                    final state = cleanVal > 0.0;
                    final brightness = (cleanVal * 100).round();
                    if (MqttService().isConnected) {
                      MqttService().publishSet('lampu_teras', state: state, value: brightness);
                    } else {
                      showOfflineWarning(context, 'lampu teras');
                    }
                  },
                ),
              ),
              const Text(
                'Lampu Teras',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: NexoraTokens.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Kartu Pintu Geser: Mini-Scene Panel Pintu Geser 700ms
  Widget _buildSlidingDoorCard() {
    final bool isOpen = _isSlidingDoorUnlocked;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final nextState = !_isSlidingDoorUnlocked;

        // Selalu ubah state dan jalankan animasi seketika di layar
        setState(() {
          _isSlidingDoorUnlocked = nextState;
        });

        // Sync instan ke MqttService & DeviceManager
        MqttService().publishSet('pintu_geser', state: nextState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOpen ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: isOpen ? 1.5 : 1.0,
          ),
          boxShadow: isOpen
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: Row(
          children: [
            // Mini Scene Pintu Geser Animasi
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                ),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: isOpen ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      size: const Size(26, 26),
                      painter: _SlidingDoorPainter(progress: progress),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pintu Geser',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Terbuka' : 'Terkunci',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Kartu Gorden: Mini-Scene Dua Panel Gorden Menyibak 800ms
  Widget _buildCurtainCard() {
    final bool isOpen = _isCurtainOpen;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final nextState = !_isCurtainOpen;

        // Selalu ubah state dan jalankan animasi seketika di layar
        setState(() {
          _isCurtainOpen = nextState;
        });

        // Cek koneksi server/MQTT
        // Sync instan ke MqttService & DeviceManager
        MqttService().publishSet('gorden', state: nextState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOpen ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: isOpen ? 1.5 : 1.0,
          ),
          boxShadow: isOpen
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: Row(
          children: [
            // Mini Scene Gorden Animasi
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                ),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: isOpen ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      size: const Size(26, 26),
                      painter: _CurtainsPainter(progress: progress),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gorden',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Terbuka' : 'Tertutup',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter Vektor Animasi Pintu Geser
class _SlidingDoorPainter extends CustomPainter {
  final double progress; // 0.0 (Terkunci/Tertutup) -> 1.0 (Terbuka)

  _SlidingDoorPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Kusen Luar
    final framePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(3)),
      framePaint,
    );

    // Cahaya Ruangan di Celah saat Terbuka
    if (progress > 0.05) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFF3DB).withOpacity(0.9 * progress)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(2, 2, (size.width - 4) * 0.55 * progress, size.height - 4),
        lightPaint,
      );
    }

    // Panel Daun Pintu yang Bergeser
    final doorWidth = (size.width - 4) * 0.60;
    final slideDistance = (size.width - 4) - doorWidth;
    final currentX = 2.0 + (slideDistance * progress);

    final doorPaint = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.ink.withOpacity(0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final doorFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final doorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(currentX, 2, doorWidth, size.height - 4),
      const Radius.circular(2),
    );

    canvas.drawRRect(doorRect, doorFill);
    canvas.drawRRect(doorRect, doorPaint);

    // Gagang Pintu
    final handlePaint = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final handleX = currentX + (progress > 0.5 ? 4.0 : doorWidth - 4.0);
    canvas.drawLine(Offset(handleX, size.height * 0.42), Offset(handleX, size.height * 0.58), handlePaint);
  }

  @override
  bool shouldRepaint(covariant _SlidingDoorPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Painter Vektor Animasi Gorden Menyibak
class _CurtainsPainter extends CustomPainter {
  final double progress; // 0.0 (Tertutup di tengah) -> 1.0 (Menyibak ke tepi)

  _CurtainsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Rel / Batang Gorden di Atas
    final rodPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(1, 3), Offset(size.width - 1, 3), rodPaint);

    // Jendela Kaca di Balik Gorden saat Terbuka
    if (progress > 0.05) {
      final windowPaint = Paint()
        ..color = const Color(0xFFE2F4FD).withOpacity(0.85 * progress)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 4, size.width - 6, size.height - 5),
          const Radius.circular(2),
        ),
        windowPaint,
      );

      // Garis silang jendela tipis
      final panePaint = Paint()
        ..color = Colors.white.withOpacity(0.7 * progress)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(size.width / 2, 4), Offset(size.width / 2, size.height - 1), panePaint);
      canvas.drawLine(Offset(3, size.height * 0.52), Offset(size.width - 3, size.height * 0.52), panePaint);
    }

    // Panel Gorden Kiri & Kanan
    final halfWidth = size.width / 2 - 1.5;
    // Saat progress = 0 (tertutup): lebar gorden = halfWidth
    // Saat progress = 1 (menyibak): lebar gorden menyusut ke samping
    final currentPanelWidth = halfWidth - (halfWidth * 0.65 * progress);

    final curtainStroke = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.ink.withOpacity(0.75)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final curtainFill = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    // Panel Kiri
    final leftPath = Path()
      ..moveTo(2, 4)
      ..lineTo(2 + currentPanelWidth, 4)
      ..quadraticBezierTo(2 + currentPanelWidth * 0.85, size.height * 0.5, 2 + currentPanelWidth, size.height - 1)
      ..lineTo(2, size.height - 1)
      ..close();

    canvas.drawPath(leftPath, curtainFill);
    canvas.drawPath(leftPath, curtainStroke);

    // Panel Kanan
    final rightX = size.width - 2 - currentPanelWidth;
    final rightPath = Path()
      ..moveTo(size.width - 2, 4)
      ..lineTo(rightX, 4)
      ..quadraticBezierTo(rightX + currentPanelWidth * 0.15, size.height * 0.5, rightX, size.height - 1)
      ..lineTo(size.width - 2, size.height - 1)
      ..close();

    canvas.drawPath(rightPath, curtainFill);
    canvas.drawPath(rightPath, curtainStroke);
  }

  @override
  bool shouldRepaint(covariant _CurtainsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
