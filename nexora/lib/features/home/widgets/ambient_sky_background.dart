import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/weather_service.dart';

/// Ambient Sky Background: Latar langit atmosferik dengan visual awan realistis ala aplikasi cuaca
class AmbientSkyBackground extends StatefulWidget {
  final bool isPageActive;

  const AmbientSkyBackground({
    Key? key,
    this.isPageActive = true,
  }) : super(key: key);

  @override
  _AmbientSkyBackgroundState createState() => _AmbientSkyBackgroundState();
}

class _AmbientSkyBackgroundState extends State<AmbientSkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late WeatherCondition _currentWeather;
  StreamSubscription<WeatherCondition>? _weatherSub;

  // 22 Partikel hujan miring elegan: sangat ringan, 2 batch draw call GPU, 60-120 FPS buttery smooth
  final List<_RainParticle> _rainParticles = List.generate(
    22,
    (i) => _RainParticle(
      xPercent: (i * 0.0455) % 1.0,
      initialY: (i * 22.0) % 480.0,
      length: 15.0 + (i % 4) * 3.5,
      speed: 1.5 + (i % 3) * 0.45,
      isForeground: i % 2 == 0,
    ),
  );

  // Bintang malam dengan fase kelap-kelip efisien
  final List<_StarTwinkle> _stars = List.generate(
    12,
    (i) => _StarTwinkle(
      xPercent: ((i * 0.081) + 0.04) % 0.92,
      yPercent: 0.04 + (i * 0.024) % 0.25,
      radius: 1.4 + (i % 2) * 0.7,
      speed: 2.0 + (i % 3) * 0.7,
      phase: i * 0.8,
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentWeather = WeatherService().currentCondition;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );

    if (widget.isPageActive) {
      _animController.repeat();
    }

    _weatherSub = WeatherService().weatherStream.listen((newCondition) {
      if (mounted) {
        setState(() {
          _currentWeather = newCondition;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AmbientSkyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPageActive != widget.isPageActive) {
      if (widget.isPageActive) {
        if (!_animController.isAnimating) {
          _animController.repeat();
        }
      } else {
        if (_animController.isAnimating) {
          _animController.stop();
        }
      }
    }
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
          // 1. Lapisan Awan Beneran (Fotografi Langit Nyata dengan Animasi Ken-Burns Perlahan yang di-cache child-nya)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animController,
                child: Image.asset(
                  _getSkyAssetPath(_currentWeather),
                  fit: BoxFit.cover,
                  cacheWidth: 800, // Memory image caching hemat RAM & GPU
                  errorBuilder: (ctx, err, stack) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF4C6377),
                            Color(0xFF869DAF),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                builder: (context, cachedImage) {
                  if (reduceMotion || !widget.isPageActive) {
                    return cachedImage!;
                  }
                  final p = _animController.value;
                  // Gerakan mengalir Ken-Burns sangat hemat matrix
                  final panX = math.sin(p * 2 * math.pi) * 10.0;
                  final panY = math.cos(p * 2 * math.pi) * 4.0;
                  final scale = 1.05 + (math.sin(p * 2 * math.pi) * 0.015);

                  return ClipRect(
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.translate(
                        offset: Offset(panX, panY),
                        child: cachedImage,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Gradiasi Scrim Halus Memudar ke Warna Kartu Rumah (#F7F8F7)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight + 2,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.40, 0.72, 0.90, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.18),
                      Colors.transparent,
                      NexoraTokens.background.withOpacity(0.40),
                      NexoraTokens.background.withOpacity(0.85),
                      NexoraTokens.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Efek Partikel Cuaca Dinamis Ringan (Hujan Jatuh, Angin, Matahari, Bintang)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyHeight,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _WeatherParticleOverlayPainter(
                      condition: _currentWeather,
                      progress: (reduceMotion || !widget.isPageActive) ? 0.0 : _animController.value,
                      rainParticles: _rainParticles,
                      stars: _stars,
                    ),
                  );
                },
              ),
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

  // Cached static paint untuk 2-batch hardware-accelerated GPU draw call
  static final Paint _fgRainPaint = Paint()
    ..color = const Color(0xFFD0E8FF).withOpacity(0.48)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _bgRainPaint = Paint()
    ..color = const Color(0xFFD0E8FF).withOpacity(0.24)
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _windBasePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;

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

    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE082).withOpacity(0.32 + 0.12 * sunPulse),
          const Color(0xFFFFD54F).withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: size.width * 0.7));

    canvas.drawCircle(sunCenter, size.width * 0.7, sunPaint);
  }

  /// 2-Batch Draw Call: Mengurangi 45 draw call individu menjadi tepat 2 draw call Skia/Impeller
  void _drawCinematicRain(Canvas canvas, Size size, double p) {
    final travelY = size.height + 40;
    final pathFg = Path();
    final pathBg = Path();

    for (int i = 0; i < rainParticles.length; i++) {
      final drop = rainParticles[i];
      final currentY = ((drop.initialY + (p * 40 * 220 * drop.speed)) % travelY) - 30;
      final currentX = (drop.xPercent * size.width) + (currentY * 0.18);
      final endX = currentX + (drop.length * 0.18);
      final endY = currentY + drop.length;

      if (drop.isForeground) {
        pathFg.moveTo(currentX, currentY);
        pathFg.lineTo(endX, endY);
      } else {
        pathBg.moveTo(currentX, currentY);
        pathBg.lineTo(endX, endY);
      }
    }

    canvas.drawPath(pathBg, _bgRainPaint);
    canvas.drawPath(pathFg, _fgRainPaint);
  }

  void _drawWindStreams(Canvas canvas, Size size, double p) {
    final windLines = [
      {'y': 60.0, 'speed': 1.6, 'width': 180.0, 'opacity': 0.35},
      {'y': 105.0, 'speed': 2.2, 'width': 210.0, 'opacity': 0.45},
      {'y': 155.0, 'speed': 1.4, 'width': 160.0, 'opacity': 0.30},
    ];

    for (int i = 0; i < windLines.length; i++) {
      final line = windLines[i];
      final y = line['y'] as double;
      final speed = line['speed'] as double;
      final w = line['width'] as double;
      final op = line['opacity'] as double;

      final loopWidth = size.width + w * 2.5;
      final startX = ((p * 40 * 110 * speed + (i * 120)) % loopWidth) - w;

      _windBasePaint.shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(op),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(startX, y - 10, w, 20));

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

      canvas.drawPath(path, _windBasePaint);
    }
  }

  void _drawNightTwinkle(Canvas canvas, Size size, double p) {
    for (final star in stars) {
      final twinkle = (math.sin(p * 40 * star.speed + star.phase) + 1) / 2;
      final x = star.xPercent * size.width;
      final y = star.yPercent * (size.height * 0.85);

      _starPaint.color = Colors.white.withOpacity(0.35 + 0.55 * twinkle);
      canvas.drawCircle(Offset(x, y), star.radius * (0.8 + 0.4 * twinkle), _starPaint);
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
  final bool isForeground;

  _RainParticle({
    required this.xPercent,
    required this.initialY,
    required this.length,
    required this.speed,
    required this.isForeground,
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
