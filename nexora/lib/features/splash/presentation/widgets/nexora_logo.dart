import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Logo NEXORA Clean Light Minimalis (Apple Home / Google Home style)
class NexoraLogo extends StatelessWidget {
  final double size;
  final double pulseValue;

  const NexoraLogo({
    Key? key,
    this.size = 100.0,
    this.pulseValue = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primaryCyan.withOpacity(0.15 * pulseValue),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(
        'assets/images/logo_nexora.png',
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Icon(
          Icons.home_work_rounded,
          color: AppColors.primaryCyan,
          size: 48,
        ),
      ),
    );
  }
}
