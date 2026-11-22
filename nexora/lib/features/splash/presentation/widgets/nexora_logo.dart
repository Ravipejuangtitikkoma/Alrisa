import 'package:flutter/material.dart';

/// Logo ALRISA Clean Light Minimalis (Apple Home / Google Home style)
class NexoraLogo extends StatelessWidget {
  final double size;
  final double pulseValue;
  final bool showCard;

  const NexoraLogo({
    Key? key,
    this.size = 120.0,
    this.pulseValue = 1.0,
    this.showCard = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showCard) {
      return Image.asset(
        'assets/images/logo_alrisa.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => Image.asset(
          'assets/images/logo_nexora.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF65B8EA).withValues(alpha: 0.20 * pulseValue),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(
        'assets/images/logo_alrisa.png',
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Icon(
          Icons.home_work_rounded,
          color: Color(0xFF65B8EA),
          size: 48,
        ),
      ),
    );
  }
}
