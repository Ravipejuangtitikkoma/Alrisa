import 'package:flutter/material.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/data/mock_home.dart';

/// Kartu Lebar Energi Hari Ini dengan Sparkline Hidup Halus
class EnergyCard extends StatefulWidget {
  const EnergyCard({Key? key}) : super(key: key);

  @override
  _EnergyCardState createState() => _EnergyCardState();
}

class _EnergyCardState extends State<EnergyCard> with SingleTickerProviderStateMixin {
  late AnimationController _sparklineController;
  final List<EnergyPoint> _data = MockHomeData.getEnergyPoints();

  @override
  void initState() {
    super.initState();
    _sparklineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sparklineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NexoraTokens.surface,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(color: NexoraTokens.cardBorder),
        boxShadow: NexoraTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NexoraTokens.statusAmberSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_outlined,
                      size: 18,
                      color: NexoraTokens.statusAmber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KONSUMSI LISTRIK',
                        style: NexoraTokens.sectionLabel,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Energi Hari Ini',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NexoraTokens.statusGreenSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '-12% Hemat',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.statusGreen,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Total Nilai Daya
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text(
                '3.4',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: NexoraTokens.ink,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'kWh',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NexoraTokens.inkSecondary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '• Beban saat ini 380W',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: NexoraTokens.inkMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Sparkline Kurva Interaktif Terisolasi
          SizedBox(
            height: 60,
            width: double.infinity,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _sparklineController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SparklinePainter(
                      points: _data,
                      pulse: _sparklineController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Label Waktu Jam Sparkline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _data.map((p) {
              return Text(
                p.timeLabel,
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: NexoraTokens.inkMuted,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<EnergyPoint> points;
  final double pulse;

  _SparklinePainter({required this.points, required this.pulse});

  static final Paint _linePaint = Paint()
    ..color = NexoraTokens.statusAmber
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  static final Paint _dotPaint = Paint()
    ..color = NexoraTokens.statusAmber
    ..style = PaintingStyle.fill;

  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static Size? _lastShaderSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = 750.0;
    final minVal = 100.0;
    final stepX = size.width / (points.length - 1);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      // Sedikit bernafas halus di titik tertinggi
      final breath = (i == 4) ? (pulse * 3.5) : 0.0;
      final normalizedY = (points[i].watt + breath - minVal) / (maxVal - minVal);
      final y = size.height - (normalizedY * (size.height - 10)) - 5;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNormY = (points[i - 1].watt - minVal) / (maxVal - minVal);
        final prevY = size.height - (prevNormY * (size.height - 10)) - 5;

        final controlX1 = prevX + (stepX / 2);
        final controlY1 = prevY;
        final controlX2 = prevX + (stepX / 2);
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Cache fill shader hanya saat dimensi berubah
    if (_lastShaderSize != size) {
      _lastShaderSize = size;
      _fillPaint.shader = LinearGradient(
        colors: [
          NexoraTokens.statusAmber.withValues(alpha: 0.18),
          NexoraTokens.statusAmber.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    canvas.drawPath(fillPath, _fillPaint);
    canvas.drawPath(path, _linePaint);

    // Current time indicator dot
    final lastX = size.width;
    final lastNormY = (points.last.watt - minVal) / (maxVal - minVal);
    final lastY = size.height - (lastNormY * (size.height - 10)) - 5;

    canvas.drawCircle(Offset(lastX, lastY), 4, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
