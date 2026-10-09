import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/weather_service.dart';

/// Ambient Sky Background: Latar langit atmosferik dengan visual awan realistis ala aplikasi cuaca
class AmbientSkyBackground extends StatefulWidget {
  const AmbientSkyBackground({Key? key}) : super(key: key);

  @override
  _AmbientSkyBackgroundState createState() => _AmbientSkyBackgroundState();
}

class _AmbientSkyBackgroundState extends State<AmbientSkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late WeatherCondition _currentWeather;
  StreamSubscription<WeatherCondition>? _weatherSub;

  // 75 Partikel hujan miring dengan berbagai kecepatan dan panjang
  final List<_RainParticle> _rainParticles = List.generate(
    75,
    (i) => _RainParticle(
      xPercent: (i * 0.0137) % 1.0,
      initialY: (i * 11.3) % 480.0,
      length: 14.0 + (i % 6) * 4.0,
      speed: 1.6 + (i % 5) * 0.5,
      opacity: 0.35 + (i % 4) * 0.15,
      thickness: 1.0 + (i % 3) * 0.4,
    ),
  );

  // Bintang malam dengan fase kelap-kelip
  final List<_StarTwinkle> _stars = List.generate(
    14,
    (i) => _StarTwinkle(
      xPercent: ((i * 0.073) + 0.05) % 0.90,
      yPercent: 0.04 + (i * 0.022) % 0.26,
      radius: 1.4 + (i % 3) * 0.8,
      speed: 2.0 + (i % 4) * 0.8,
      phase: i * 0.7,
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentWeather = WeatherService().currentCondition;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _weatherSub = WeatherService().weatherStream.listen((newCondition) {
      if (mounted) {
        setState(() {
          _currentWeather = newCondition;
        });
      }
    });
  }

  @override
  void dispose() {
    _weatherSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _getSkyAssetPath(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.cerah:
        return 'assets/images/sky_clear.jpg';
      case WeatherCondition.hujan:
        return 'assets/images/sky_rain.jpg';
      case WeatherCondition.malam:
        return 'assets/images/sky_night.jpg';
      case WeatherCondition.berawan:
      case WeatherCondition.angin:
      default:
        return 'assets/images/sky_overcast.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final skyHeight = mediaQuery.size.height * 0.46;
    final reduceMotion = mediaQuery.accessibleNavigation;

    return RepaintBoundary(
      child: Stack(
        children: [
          // 1. Lapisan Awan Beneran (Fotografi Langit Nyata dengan Animasi Ken-Burns Perlahan)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final p = reduceMotion ? 0.0 : _animController.value;
                // Gerakan mengalir sangat halus (Ken-Burns slow pan & drift)
                final panX = math.sin(p * 2 * math.pi) * 14.0;
                final panY = math.cos(p * 2 * math.pi) * 6.0;
                final scale = 1.08 + (math.sin(p * 2 * math.pi) * 0.03);

                return ClipRect(
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.translate(
                      offset: Offset(panX, panY),
                      child: Image.asset(
                        _getSkyAssetPath(_currentWeather),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) {
                          // Fallback ke gradien jika asset belum termuat
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF4C6377),
                                  const Color(0xFF869DAF),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Gradiasi Scrim Halus Memudar ke Warna Kartu Rumah (#F7F8F7)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight + 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.40, 0.72, 0.90, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.18), // Vignette atas tipis agar teks putih sangat kontras
                    Colors.transparent,
                    NexoraTokens.background.withOpacity(0.40),
                    NexoraTokens.background.withOpacity(0.85),
                    NexoraTokens.background,
                  ],
                ),
              ),
            ),
          ),

          // 3. Efek Partikel Cuaca Dinamis (Hujan Jatuh, Angin, Matahari, Bintang)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _WeatherParticleOverlayPainter(
                    condition: _currentWeather,
                    progress: reduceMotion ? 0.0 : _animController.value,
                    rainParticles: _rainParticles,
                    stars: _stars,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherParticleOverlayPainter extends CustomPainter {
  final WeatherCondition condition;
  final double progress;
  final List<_RainParticle> rainParticles;
  final List<_StarTwinkle> stars;

  _WeatherParticleOverlayPainter({
    required this.condition,
    required this.progress,
    required this.rainParticles,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (condition) {
      case WeatherCondition.cerah:
        _drawSunCorona(canvas, size, progress);
        break;
      case WeatherCondition.hujan:
        _drawCinematicRain(canvas, size, progress);
        break;
      case WeatherCondition.angin:
        _drawWindStreams(canvas, size, progress);
        break;
      case WeatherCondition.malam:
        _drawNightTwinkle(canvas, size, progress);
        break;
      case WeatherCondition.berawan:
      default:
        // Awan alami sudah tampil penuh dari fotografi nyata di background
        break;
    }
  }

  void _drawSunCorona(Canvas canvas, Size size, double p) {
    final sunPulse = (math.sin(p * 40 * (2 * math.pi / 4)) + 1) / 2;
    final sunCenter = Offset(size.width * 0.50, 0);

    // Warm radial sun rays dari atas
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE082).withOpacity(0.35 + 0.15 * sunPulse),
          const Color(0xFFFFD54F).withOpacity(0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: size.width * 0.7));

    canvas.drawCircle(sunCenter, size.width * 0.7, sunPaint);
  }

  void _drawCinematicRain(Canvas canvas, Size size, double p) {
    final travelY = size.height + 40;

    for (final drop in rainParticles) {
      final currentY = ((drop.initialY + (p * 40 * 240 * drop.speed)) % travelY) - 30;
      final currentX = (drop.xPercent * size.width) + (currentY * 0.18);

      final rainPaint = Paint()
        ..color = const Color(0xFFD0E8FF).withOpacity(drop.opacity * 0.85)
        ..strokeWidth = drop.thickness
        ..strokeCap = StrokeCap.round;

      final start = Offset(currentX, currentY);
      final end = Offset(currentX + (drop.length * 0.18), currentY + drop.length);

      canvas.drawLine(start, end, rainPaint);
    }
  }

  void _drawWindStreams(Canvas canvas, Size size, double p) {
    final windLines = [
      {'y': 60.0, 'speed': 1.6, 'width': 180.0, 'opacity': 0.40},
      {'y': 95.0, 'speed': 2.2, 'width': 220.0, 'opacity': 0.50},
      {'y': 135.0, 'speed': 1.4, 'width': 160.0, 'opacity': 0.35},
      {'y': 175.0, 'speed': 2.4, 'width': 200.0, 'opacity': 0.45},
    ];

    for (int i = 0; i < windLines.length; i++) {
      final line = windLines[i];
      final y = line['y'] as double;
      final speed = line['speed'] as double;
      final w = line['width'] as double;
      final op = line['opacity'] as double;

      final loopWidth = size.width + w * 2.5;
      final startX = ((p * 40 * 110 * speed + (i * 120)) % loopWidth) - w;

      final windPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(op),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(startX, y - 10, w, 20))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(startX, y);
      path.cubicTo(
        startX + w * 0.33,
        y - 12 * math.sin(p * 10 + i),
        startX + w * 0.66,
        y + 12 * math.cos(p * 8 + i),
        startX + w,
        y,
      );

      canvas.drawPath(path, windPaint);
    }
  }

  void _drawNightTwinkle(Canvas canvas, Size size, double p) {
    for (final star in stars) {
      final twinkle = (math.sin(p * 40 * star.speed + star.phase) + 1) / 2;
      final x = star.xPercent * size.width;
      final y = star.yPercent * (size.height * 0.85);

      final starPaint = Paint()
        ..color = Colors.white.withOpacity(0.40 + 0.60 * twinkle)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), star.radius * (0.8 + 0.4 * twinkle), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherParticleOverlayPainter oldDelegate) {
    return oldDelegate.condition != condition || oldDelegate.progress != progress;
  }
}



class _RainParticle {
  final double xPercent;
  final double initialY;
  final double length;
  final double speed;
  final double opacity;
  final double thickness;

  _RainParticle({
    required this.xPercent,
    required this.initialY,
    required this.length,
    required this.speed,
    required this.opacity,
    required this.thickness,
  });
}

class _StarTwinkle {
  final double xPercent;
  final double yPercent;
  final double radius;
  final double speed;
  final double phase;

  _StarTwinkle({
    required this.xPercent,
    required this.yPercent,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}
