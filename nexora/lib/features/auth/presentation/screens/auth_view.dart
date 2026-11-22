import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/services/cloud_sync_service.dart';
import 'package:nexora/features/dashboard/presentation/screens/dashboard_screen.dart';

class AuthView extends StatefulWidget {
  const AuthView({Key? key}) : super(key: key);

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _obscurePass = true;

  // Controllers Login
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Otomatis tarik semua akun dari server Node.js saat halaman login dibuka
    AuthService().syncAccountsFromCloud().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // =========================================================================
  // HANDLER LOGIN RESMI KANTOR
  // =========================================================================
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final pass = _passController.text.trim();

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

  // =========================================================================
  // HANDLER LUPA KATA SANDI (MODAL VIA EMAIL)
  // =========================================================================
  void _showForgotPasswordSheet() {
    HapticFeedback.lightImpact();
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool sheetLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Icon & Judul
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF0284C7),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Lupa Kata Sandi?',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Pemulihan akun via email resmi kantor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Masukkan email akun kantor Anda. Sistem akan memverifikasi apakah akun Anda terdaftar dan mengirimkan instruksi pemulihan langsung ke email Anda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildFieldLabel('Email Terdaftar'),
                    const SizedBox(height: 8),
                    _buildModernTextField(
                      controller: resetEmailController,
                      hint: 'nama@kantor.com atau gmail',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // Tombol Submit Reset
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: sheetLoading
                            ? null
                            : () async {
                                final email = resetEmailController.text.trim();
                                if (email.isEmpty) {
                                  _showToast('⚠️ Harap masukkan alamat email Anda.', isError: true);
                                  return;
                                }

                                setSheetState(() => sheetLoading = true);
                                final result = await AuthService().requestPasswordReset(email);
                                setSheetState(() => sheetLoading = false);

                                if (!mounted) return;
                                Navigator.pop(ctx);

                                if (result['success'] == true) {
                                  _showSuccessResetDialog(email: email, message: result['message']);
                                } else {
                                  HapticFeedback.vibrate();
                                  _showAccountNotFoundDialog(
                                    title: 'Email Tidak Terdaftar',
                                    message: result['message'],
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
                        ),
                        child: sheetLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kirim Instruksi Pemulihan',
                                    style: TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Peringatan Jika Akun / Email Tidak Terdaftar
  void _showAccountNotFoundDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Sukses Kirim Email Pemulihan
  void _showSuccessResetDialog({required String email, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF059669), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Instruksi Terkirim!',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog() {
    final ipController = TextEditingController(
      text: CloudSyncService().baseUrl,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Alamat Server ALRISA',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan server Cloud Vercel agar HP bisa mengontrol perangkat dari mana saja (24 Jam) tanpa tergantung WiFi laptop:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                hintText: 'https://alrisa.vercel.app',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF0284C7)),
                  label: const Text('alrisa.vercel.app (Cloud)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => ipController.text = 'https://alrisa.vercel.app',
                ),
                ActionChip(
                  label: const Text('192.168.1.8:3000 (Lokal)', style: TextStyle(fontSize: 11)),
                  onPressed: () => ipController.text = 'http://192.168.1.8:3000',
                ),
                ActionChip(
                  label: const Text('localhost:3000', style: TextStyle(fontSize: 11)),
                  onPressed: () => ipController.text = 'http://localhost:3000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              String newUrl = ipController.text.trim();
              if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
                if (newUrl.contains('vercel.app') || newUrl.startsWith('alrisa.')) {
                  newUrl = 'https://$newUrl';
                } else {
                  newUrl = 'http://$newUrl';
                }
              }
              await CloudSyncService().setBaseUrl(newUrl);
              Navigator.pop(ctx);
              _showToast('Menghubungi server $newUrl...', isError: false);
              final ok = await AuthService().syncAccountsFromCloud();
              if (ok) {
                _showToast('✅ Berhasil terhubung & tersinkron dengan website!', isError: false);
              } else {
                _showToast('⚠️ Gagal terhubung ke $newUrl. Periksa koneksi internet.', isError: true);
              }
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Simpan & Sinkron', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerPill() {
    return GestureDetector(
      onTap: _showServerConfigDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Server Cloud: ${CloudSyncService().baseUrl.replaceAll('http://', '')}',
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.settings_outlined, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
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

  // =========================================================================
  // BUILD UTAMA HALAMAN LOGIN KANTOR
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. AKSEN LENGKUNGAN ARSITEKTURAL SKY-BLUE DI BAGIAN ATAS
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFBAE6FD), // Sky blue soft tint
                    Color(0xFFE0F2FE), // Ice blue transisi
                    Color(0xFFF8FAFC), // Fading to pearl white
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(500, 110),
                ),
              ),
            ),
          ),

          // 2. KONTEN FORMULIR PROFESIONAL
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TOMBOL SERVER IP STATUS PILL
                    _buildServerPill(),

                    // LOGO ALRISA FLOATING BADGE (3D Elevated)
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        'assets/images/logo_alrisa.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Image.asset(
                          'assets/images/logo_nexora.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // TULISAN "Alrisa"
                    const Text(
                      'Alrisa',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Tagline Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Smart Home Living',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // KARTU FORMULIR LOGIN KANTOR TUNGGAL
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [                       
                          const SizedBox(height: 4),                             
                          // Label & Input Email
                          _buildFieldLabel('Email'),
                          const SizedBox(height: 8),
                          _buildModernTextField(
                            controller: _emailController,
                            hint: 'Masukkan email Anda',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 16),

                          // Label & Input Kata Sandi
                          _buildFieldLabel('Kata Sandi'),
                          const SizedBox(height: 8),
                          _buildModernTextField(
                            controller: _passController,
                            hint: 'Masukkan kata sandi',
                            icon: Icons.vpn_key_outlined,
                            obscureText: _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Remember Me & Lupa Kata Sandi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: const Color(0xFF0284C7),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Ingat Saya',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showForgotPasswordSheet,
                                child: const Text(
                                  'Lupa Kata Sandi?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Tombol Masuk Gradasi Biru Laut
                          _buildGradientSubmitButton(
                            title: 'Masuk',
                            onTap: _handleLogin,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
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
  // HELPER WIDGETS & UI COMPONENTS
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
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
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
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
            Color(0xFF0284C7), // Deep Cyan / Sky Teal
            Color(0xFF0369A1), // Rich Ocean Blue
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                ],
              ),
      ),
    );
  }
}
