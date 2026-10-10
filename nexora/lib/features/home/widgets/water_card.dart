import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';

import 'package:nexora/features/water_level/presentation/screens/water_level_screen.dart';

/// Kartu Sedang Pompa Toren dengan Gelombang Air Animasi 82%
class WaterCard extends StatefulWidget {
  final bool initialActive;
  final ValueChanged<bool>? onActiveChanged;

  const WaterCard({
    Key? key,
    this.initialActive = true,
    this.onActiveChanged,
  }) : super(key: key);

  @override
  _WaterCardState createState() => _WaterCardState();
}

class _WaterCardState extends State<WaterCard> with SingleTickerProviderStateMixin {
  late bool _isActive;
  late AnimationController _waveController;
  final double _waterLevel = 0.82; // 82%
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialActive;

    final initialPayload = MqttService().getDeviceState('pompa_toren');
    if (initialPayload != null) {
      _isActive = initialPayload.state;
    }

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == 'pompa_toren' && mounted) {
        setState(() {
          _isActive = event.payload.state;
        });
      }
    });

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _togglePump() {
    HapticFeedback.lightImpact();
    final nextState = !_isActive;

    setState(() {
      _isActive = nextState;
    });
    widget.onActiveChanged?.call(_isActive);

    if (MqttService().isConnected) {
      MqttService().publishSet('pompa_toren', state: nextState);
    } else {
      showOfflineWarning(context, 'pompa toren');
    }
  }

  void _openWaterDetails() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterLevelScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openWaterDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 196,
        decoration: BoxDecoration(
          color: _isActive ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: _isActive ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: _isActive ? 1.5 : 1.0,
          ),
          boxShadow: _isActive
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: NexoraTokens.borderRadiusCard,
          child: Stack(
            children: [
              // Gelombang Air Animasi di bagian bawah kartu
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 196 * _waterLevel,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SmoothWavePainter(
                        progress: _waveController.value,
                        waterColor: _isActive
                            ? const Color(0xFFC7ECF9).withOpacity(0.55)
                            : const Color(0xFFE2E8F0).withOpacity(0.4),
                      ),
                    );
                  },
                ),
              ),

              // Konten Teks & Kontrol
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: NexoraTokens.cardBorder),
                          ),
                          child: Icon(
                            Icons.opacity,
                            size: 18,
                            color: _isActive ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap: _togglePump,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: NexoraTokens.cardBorder),
                            ),
                            child: Text(
                              _isActive ? 'Mengalir' : 'Siaga',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isActive ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Informasi Level & Nama
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Pompa Toren',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: NexoraTokens.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: NexoraTokens.inkMuted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Penuh 82%',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _isActive ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '• 820 L',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: NexoraTokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmoothWavePainter extends CustomPainter {
  final double progress;
  final Color waterColor;

  _SmoothWavePainter({required this.progress, required this.waterColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, 14);

    for (double i = 0; i <= size.width; i++) {
      final y = 8 * math.sin((i / size.width * 2 * math.pi) + (progress * 2 * math.pi)) + 8;
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmoothWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waterColor != waterColor;
  }
}
