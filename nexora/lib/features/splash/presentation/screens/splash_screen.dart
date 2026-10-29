import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexora/core/constants/app_strings.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/preset_manager_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/cloud_sync_service.dart';
import 'package:nexora/features/auth/presentation/screens/auth_view.dart';
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

  late Future<bool> _sessionFuture;
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

    // Pulihkan sesi login dan konfigurasi perangkat dari disk lokal secara paralel
    _sessionFuture = () async {
      final restored = await AuthService().restoreSession();
      final email = AuthService().currentUser?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
      await Future.wait([
        DeviceManagerService().restoreFromDisk(email),
        PresetManagerService().restoreFromDisk(email),
        CctvManagerService().restoreFromDisk(email),
      ]);
      // Tarik perangkat terbaru dari Cloud (jika diubah di website), jika belum ada unggah ke Cloud
      await CloudSyncService().fetchFromCloud();
      return restored;
    }();

    // Tampilkan Splash Screen dengan durasi yang pas (1800 ms), tap layar untuk skip
    _navTimer = Timer(const Duration(milliseconds: 1800), _navigateToHome);
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;
    _navTimer?.cancel();

    // Pastikan pembacaan sesi selesai
    await _sessionFuture;
    if (!mounted) return;

    final isLoggedIn = AuthService().isLoggedIn;
    final targetScreen = isLoggedIn ? const DashboardScreen() : const AuthView();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
              // 1. Logo ALRISA & Tagline di Tengah Layar
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NexoraLogo(size: 130),

                      const SizedBox(height: 16),

                      // Tagline: Smart Systems. Simplified.
                      const Text(
                        AppStrings.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Loading Indicator & Footer Byline di Bagian Bawah
              Positioned(
                bottom: 38,
                left: 20,
                right: 20,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF65B8EA)),
                            backgroundColor: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Menyiapkan ekosistem pintar...',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: NexoraTokens.inkMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Byline Alfatech Solutions IDN.
                      const Text(
                        AppStrings.productBy,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.4,
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
