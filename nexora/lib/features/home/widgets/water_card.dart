import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/features/water_level/presentation/screens/water_level_screen.dart';

/// Kartu Sedang Pompa Air Dinamis dengan Gelombang Air Animasi (Mendukung Multi-Pompa)
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
  late AnimationController _waveController;
  final double _waterLevel = 0.82; // 82%
  late PageController _pageController;
  int _currentIndex = 0;

  List<CustomDeviceItem> _pumps = [];
  StreamSubscription<DeviceStateEvent>? _mqttSub;
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _loadPumps();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _mqttSub = MqttService().stateStream.listen((event) {
      if (!mounted) return;
      bool matched = false;
      for (var p in _pumps) {
        if (p.id == event.deviceId) {
          p.isActive = event.payload.state;
          matched = true;
        }
      }
      if (matched) {
        setState(() {});
      }
    });

    _deviceSub = DeviceManagerService().devicesStream.listen((_) {
      if (!mounted) return;
      _loadPumps();
    });
  }

  void _loadPumps() {
    final devPumps = DeviceManagerService().waterPumps;
    setState(() {
      if (devPumps.isNotEmpty) {
        _pumps = List.from(devPumps);
      } else {
        _pumps = [
          CustomDeviceItem(
            id: 'pompa_toren',
            name: 'Pompa Toren',
            type: DeviceType.waterPump,
            isActive: true,
            hardwarePin: 'GPIO 19 (%QX0.4)',
          ),
        ];
      }
      if (_currentIndex >= _pumps.length) {
        _currentIndex = math.max(0, _pumps.length - 1);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceSub?.cancel();
    _mqttSub?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _togglePump(CustomDeviceItem pump) {
    HapticFeedback.lightImpact();
    final nextState = !pump.isActive;

    setState(() {
      pump.isActive = nextState;
    });
    widget.onActiveChanged?.call(nextState);

    MqttService().publishSet(pump.id, state: nextState);
    DeviceManagerService().updateState(
      pump.id,
      isActive: nextState,
      statusText: nextState ? 'Mengalir' : 'Mati',
    );
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
    if (_pumps.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_pumps.length == 1) {
      return _buildPumpCard(_pumps[0], showDots: false);
    }

    return Stack(
      children: [
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _pumps.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              return _buildPumpCard(_pumps[index], showDots: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPumpCard(CustomDeviceItem pump, {required bool showDots}) {
    final bool isActive = pump.isActive;

    return GestureDetector(
      onTap: _openWaterDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 196,
        decoration: BoxDecoration(
          color: isActive ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: isActive ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
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
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _SmoothWavePainter(
                          progress: _waveController.value,
                          waterColor: isActive
                              ? const Color(0xFFC7ECF9).withOpacity(0.55)
                              : const Color(0xFFE2E8F0).withOpacity(0.4),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Konten Teks & Kontrol
              Padding(
                padding: const EdgeInsets.all(16),
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
                            color: isActive ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                          ),
                        ),
                        Row(
                          children: [
                            if (showDots) ...[
                              Row(
                                children: List.generate(_pumps.length, (i) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 3),
                                    width: i == _currentIndex ? 10 : 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: i == _currentIndex ? NexoraTokens.brandCyan : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(width: 6),
                            ],
                            GestureDetector(
                              onTap: () => _togglePump(pump),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: NexoraTokens.cardBorder),
                                ),
                                child: Text(
                                  isActive ? 'Mengalir' : 'Siaga',
                                  style: TextStyle(
                                    fontFamily: NexoraTokens.fontFamilySans,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Informasi Level & Nama
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                pump.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: NexoraTokens.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: NexoraTokens.inkMuted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              'Penuh 82%',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isActive ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '• ${pump.hardwarePin}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: NexoraTokens.inkMuted,
                                ),
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

    final w = size.width;
    final phase = progress * 2 * math.pi;
    const baseH = 8.0;
    const amp = 5.0;

    // Menghasilkan ombak fluida alami dengan kurva Bezier kubik instan (< 0.001 ms, zero CPU loop)
    final y0 = baseH + amp * math.sin(phase);
    final y1 = baseH + amp * math.sin(phase + math.pi * 0.67);
    final y2 = baseH + amp * math.sin(phase + math.pi * 1.33);
    final y3 = baseH + amp * math.sin(phase + 2 * math.pi);

    path.lineTo(0, y0);
    path.cubicTo(w * 0.25, y0 - amp, w * 0.25, y1 + amp, w * 0.5, (y1 + y2) / 2);
    path.cubicTo(w * 0.75, y2 - amp, w * 0.75, y3 + amp, w, y3);
    path.lineTo(w, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmoothWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waterColor != waterColor;
  }
}
