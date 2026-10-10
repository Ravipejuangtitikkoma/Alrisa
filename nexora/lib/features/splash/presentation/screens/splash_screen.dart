import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexora/core/constants/app_strings.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/features/dashboard/presentation/screens/dashboard_screen.dart';
import '../widgets/nexora_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _loadingFadeAnimation;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _loadingFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Navigasi kilat ke Home Dashboard (900 ms)
    _navTimer = Timer(const Duration(milliseconds: 900), _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    _navTimer?.cancel();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome, // Sentuh layar untuk langsung masuk seketika
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Logo & Nama Brand di Tengah Layar
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NexoraLogo(size: 112),

                      const SizedBox(height: 24),

                      // Nama Brand NEXORA
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.5,
                          color: NexoraTokens.ink,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Tagline Abu-abu
                      const Text(
                        AppStrings.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: NexoraTokens.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Loading Indicator & Status di Bagian Bawah
              Positioned(
                bottom: 48,
                child: FadeTransition(
                  opacity: _loadingFadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading Bar Halus Bergaya Modern
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(NexoraTokens.brandCyan),
                            backgroundColor: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Menyiapkan sistem pintar...',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NexoraTokens.inkSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
