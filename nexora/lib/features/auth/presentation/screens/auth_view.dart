import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/features/dashboard/presentation/screens/dashboard_screen.dart';

class AuthView extends StatefulWidget {
  const AuthView({Key? key}) : super(key: key);

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> with SingleTickerProviderStateMixin {
  bool _isLogin = true; // true = Login, false = Register
  bool _isLoading = false;

  // Toggle Visibility Password
  bool _obscureLoginPass = true;
  bool _obscureRegPass = true;
  bool _obscureRegConfirmPass = true;

  // Controllers Login
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPassController = TextEditingController();

  // Controllers Register
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  final TextEditingController _regConfirmPassController = TextEditingController();

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPassController.dispose();
    _regConfirmPassController.dispose();
    super.dispose();
  }

  void _fillSuperAdmin() {
    setState(() {
      _isLogin = true;
      _loginEmailController.text = 'raviarmanza149@gmail.com';
      _loginPassController.text = 'ravi18';
    });
    HapticFeedback.lightImpact();
    _showToast('⚡ Akun Super Admin Ravi berhasil diisi otomatis!', isError: false);
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final pass = _loginPassController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showToast('⚠️ Harap isi email dan kata sandi Anda.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await AuthService().login(email: email, password: pass);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showToast(result['message'], isError: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      HapticFeedback.vibrate();
      _showToast(result['message'], isError: true);
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPassController.text.trim();
    final confirmPass = _regConfirmPassController.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      _showToast('⚠️ Semua kolom pendaftaran wajib diisi!', isError: true);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showToast('⚠️ Format email tidak valid.', isError: true);
      return;
    }

    if (pass.length < 4) {
      _showToast('⚠️ Kata sandi minimal 4 karakter.', isError: true);
      return;
    }

    if (pass != confirmPass) {
      _showToast('⚠️ Konfirmasi kata sandi tidak cocok!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await AuthService().register(
      name: name,
      email: email,
      password: pass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showToast(result['message'], isError: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      HapticFeedback.vibrate();
      _showToast(result['message'], isError: true);
    }
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isError ? NexoraTokens.statusRed : const Color(0xFF0F766E),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT ATMOSFERIK AESTHETIC (Sesuai Desain Figma)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.25, 0.65, 1.0],
                  colors: [
                    Color(0xFFFFDAB9), // Warm peach / sunset gold lembut di kiri atas
                    Color(0xFFFBE4D8), // Peach transisi
                    Color(0xFFE2F0F9), // Ice blue transisi
                    Color(0xFF90C2E7), // Ocean sky blue di kanan bawah
                  ],
                ),
              ),
            ),
          ),

          // Orb Cahaya Ambient Halus di Latar Belakang
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFAE70).withOpacity(0.35),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -30,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF64B5F6).withOpacity(0.4),
              ),
            ),
          ),

          // 2. KONTEN FORMULIR DENGAN GLASSMORPHISM
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  crossAxisAlignment: _isLogin ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    // Header Bar (Ikon Rumah di Login & Tombol Pintas Super Admin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_isLogin)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.home_outlined,
                              size: 32,
                              color: Color(0xFF1E293B),
                            ),
                          )
                        else
                          const SizedBox(width: 40),

                        // Tombol Cepat Super Admin Ravi
                        InkWell(
                          onTap: _fillSuperAdmin,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.stars_rounded, size: 16, color: Color(0xFF0F766E)),
                                SizedBox(width: 5),
                                Text(
                                  'Super Admin',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Judul Halaman
                    Text(
                      _isLogin ? 'Selamat Datang\nKembali' : 'Buat Akun Baru',
                      textAlign: _isLogin ? TextAlign.start : TextAlign.center,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A), // Dark Navy
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subjudul Halaman
                    Text(
                      _isLogin ? 'Silakan masuk ke akun Anda' : 'Daftar untuk mulai mengelola\nrumah pintar Anda',
                      textAlign: _isLogin ? TextAlign.start : TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF334155).withOpacity(0.85),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 3. KARTU GLASSMORPHISM FROSTED BLUR
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.52), // Kaca transparan frosted
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.85), // Kilauan tepian kaca
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.08),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: _isLogin ? _buildLoginForm() : _buildRegisterForm(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Switcher Bawah: "Belum punya akun? Daftar" / "Sudah punya akun? Masuk"
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 13.5,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(text: _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? '),
                              TextSpan(
                                text: _isLogin ? 'Daftar' : 'Masuk',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7), // Sky blue aksen
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FORM LOGIN (Persis Screenshot Kanan)
  // =========================================================================
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label & Input Email
        _buildFieldLabel('Email'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _loginEmailController,
          hint: 'Masukkan email Anda',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 18),

        // Label & Input Kata Sandi
        _buildFieldLabel('Kata Sandi'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _loginPassController,
          hint: 'Masukkan kata sandi',
          icon: Icons.vpn_key_outlined,
          obscureText: _obscureLoginPass,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureLoginPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
          ),
        ),

        const SizedBox(height: 12),

        // Lupa Kata Sandi Link
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              _showToast('💡 Hubungi Super Admin Ravi jika Anda lupa kata sandi.', isError: false);
            },
            child: const Text(
              'Lupa Kata Sandi?',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Tombol Masuk Gradasi Cyan/Teal (Sesuai Desain Figma)
        _buildGradientSubmitButton(
          title: 'Masuk',
          onTap: _handleLogin,
        ),
      ],
    );
  }

  // =========================================================================
  // FORM REGISTER (Persis Screenshot Kiri)
  // =========================================================================
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label & Input Nama Lengkap
        _buildFieldLabel('Nama Lengkap'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _regNameController,
          hint: 'Nama Lengkap',
          icon: Icons.person_outline_rounded,
        ),

        const SizedBox(height: 16),

        // Label & Input Email
        _buildFieldLabel('Email'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _regEmailController,
          hint: 'Email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // Label & Input Kata Sandi
        _buildFieldLabel('Kata Sandi'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _regPassController,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureRegPass,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureRegPass = !_obscureRegPass),
          ),
        ),

        const SizedBox(height: 16),

        // Label & Input Konfirmasi Kata Sandi
        _buildFieldLabel('Konfirmasi Kata Sandi'),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _regConfirmPassController,
          hint: 'Konfirmasi Kata Sandi',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureRegConfirmPass,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureRegConfirmPass = !_obscureRegConfirmPass),
          ),
        ),

        const SizedBox(height: 24),

        // Tombol Daftar Gradasi Cyan/Teal (Sesuai Desain Figma)
        _buildGradientSubmitButton(
          title: 'Daftar',
          onTap: _handleRegister,
        ),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: NexoraTokens.fontFamilySans,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB0CEDB).withOpacity(0.35), // Soft bluish-gray glass capsule
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: const Color(0xFF475569).withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildGradientSubmitButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0284C7), // Sky Teal / Deep Cyan
            Color(0xFF0E7490), // Ocean Cyan
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          primary: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
