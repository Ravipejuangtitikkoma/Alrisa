import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/config/mqtt_config.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/features/auth/presentation/screens/auth_view.dart';
import 'package:nexora/features/settings/presentation/screens/cctv_management_screen.dart';
import 'package:nexora/features/settings/presentation/screens/iot_device_management_screen.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isReconnecting = false;

  // State Super Admin
  bool _isSuperAdminUnlocked = false;
  final TextEditingController _brokerController = TextEditingController(text: MqttConfig.broker);
  final TextEditingController _portController = TextEditingController(text: MqttConfig.port.toString());
  final TextEditingController _prefixController = TextEditingController(text: MqttConfig.topicPrefix);
  final TextEditingController _usernameController = TextEditingController(text: MqttConfig.username ?? '');
  final TextEditingController _passwordController = TextEditingController(text: MqttConfig.password ?? '');
  bool _isSavingBroker = false;

  StreamSubscription<bool>? _connSub;
  StreamSubscription<UserModel?>? _authSub;
  bool _isConnected = MqttService().isConnected;

  @override
  void initState() {
    super.initState();
    _connSub = MqttService().connectionStream.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status;
          _isReconnecting = false;
        });
      }
    });

    _authSub = AuthService().authStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _connSub?.cancel();
    _brokerController.dispose();
    _portController.dispose();
    _prefixController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleReconnect() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isReconnecting = true;
    });

    await MqttService().reconnect();

    if (mounted) {
      setState(() {
        _isReconnecting = false;
        _isConnected = MqttService().isConnected;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            _isConnected
                ? '✅ Berhasil terhubung ke broker MQTT!'
                : '⚠️ Gagal terhubung ke broker. Mencoba di latar belakang...',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. HEADER HALAMAN (KONTRAS TINGGI DI ATAS AMBIENT SKY)
        // ==========================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.40),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_suggest_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('settings_title'),
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.tr('settings_subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.92),
                      shadows: const [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ==========================================
        // 2. KARTU PROFIL PENGGUNA (DESAIN BERSIH & RAPIH, TIDAK CRUSHED/CRAMPED)
        // ==========================================
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row Utama: Avatar + Data Pengguna
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Bulat dengan Badge Kamera
                  GestureDetector(
                    onTap: () => _showEditProfileSheet(context),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildProfileAvatar(size: 58),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: NexoraTokens.brandCyan,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: NexoraTokens.brandCyan.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Informasi Profil (Nama, Role Badge, Email)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService().isLoggedIn ? AuthService().currentUserName : 'Ravi Armanza',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: NexoraTokens.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Role Badge Rapi & Ringkas (Anti-Wrap / Anti-Nabrak)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AuthService().isSuperAdmin
                                ? const Color(0xFFFAF5FF)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AuthService().isSuperAdmin
                                  ? const Color(0xFFE9D5FF)
                                  : const Color(0xFFBBF7D0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AuthService().isSuperAdmin ? '👑 SUPER ADMIN' : '👤 PENGHUNI RUMAH',
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AuthService().isSuperAdmin
                                      ? const Color(0xFF7E22CE)
                                      : const Color(0xFF15803D),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Email Akun
                        Row(
                          children: [
                            const Icon(
                              Icons.alternate_email_rounded,
                              size: 13,
                              color: NexoraTokens.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AuthService().currentUser?.email ?? 'raviarmanza149@gmail.com',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: NexoraTokens.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
              const SizedBox(height: 12),

              // Bar Aksi Bawah: 2 Tombol Simetris Bersebelahan (Edit Profil & Keluar Akun)
              Row(
                children: [
                  // Tombol 1: Edit Profil
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _showEditProfileSheet(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.edit_rounded, size: 15, color: Color(0xFF0284C7)),
                              SizedBox(width: 6),
                              Text(
                                'Edit Profil',
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Tombol 2: Keluar Akun
                  Expanded(
                    child: Material(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _confirmLogout,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.logout_rounded, size: 15, color: Color(0xFFDC2626)),
                              SizedBox(width: 6),
                              Text(
                                'Keluar Akun',
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ==========================================
        // 3. STATUS JARINGAN & BROKER MQTT (LENGKAP SEPERTI DULU)
        // ==========================================
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: NexoraTokens.borderRadiusCard,
            border: Border.all(color: NexoraTokens.cardBorder),
            boxShadow: NexoraTokens.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.router_outlined, size: 20, color: NexoraTokens.ink),
                      SizedBox(width: 8),
                      Text(
                        'Koneksi Broker MQTT',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.ink,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isConnected ? NexoraTokens.statusGreenSubtle : NexoraTokens.statusAmberSubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _isConnected ? NexoraTokens.statusGreen : NexoraTokens.statusAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'TERHUBUNG' : 'OFFLINE',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _isConnected ? NexoraTokens.statusGreen : NexoraTokens.statusAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildInfoRow('Server Broker', '${MqttService().broker}:${MqttService().port}', isMono: true),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildInfoRow('Client ID', MqttService().clientId, isMono: true),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildInfoRow('Pesan Terakhir', MqttService().lastMessage),

              const SizedBox(height: 18),

              // Tombol Hubungkan Ulang
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isReconnecting ? null : _handleReconnect,
                  icon: _isReconnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_isReconnecting ? 'Sedang Menghubungkan...' : 'Hubungkan Ulang Broker'),
                  style: ElevatedButton.styleFrom(
                    primary: NexoraTokens.brandCyan,
                    onPrimary: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: NexoraTokens.borderRadiusButton,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tombol Akses Super Admin
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openSuperAdminModal,
                  icon: Icon(
                    _isSuperAdminUnlocked ? Icons.admin_panel_settings : Icons.lock_outline_rounded,
                    size: 18,
                    color: _isSuperAdminUnlocked ? Colors.purple : NexoraTokens.inkSecondary,
                  ),
                  label: Text(
                    _isSuperAdminUnlocked ? '⚙️ Panel Super Admin (Aktif)' : '🔐 Akses Super Admin (Cloud & Hardware)',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isSuperAdminUnlocked ? Colors.purple : NexoraTokens.inkSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: _isSuperAdminUnlocked ? Colors.purple.withOpacity(0.5) : NexoraTokens.cardBorder,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: NexoraTokens.borderRadiusButton,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ==========================================
        // 4. KLASIFIKASI MENU PERANGKAT & CCTV (MODERN LIST)
        // ==========================================
        _buildDeviceClassificationCard(),

        const SizedBox(height: 20),

        // ==========================================
        // 5. PENGATURAN UMUM & SISTEM
        // ==========================================
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: NexoraTokens.borderRadiusCard,
            border: Border.all(color: NexoraTokens.cardBorder),
            boxShadow: NexoraTokens.cardShadow,
          ),
          child: Column(
            children: [
              _buildSimpleListTile(
                icon: Icons.translate_rounded,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                title: lang.isIndonesian ? 'Bahasa Aplikasi' : 'App Language',
                subtitle: lang.isIndonesian ? 'Bahasa Indonesia (ID)' : 'English (EN)',
                onTap: () {
                  HapticFeedback.lightImpact();
                  lang.toggleLanguage();
                  setState(() {});
                },
              ),
              const Divider(height: 1, indent: 68, endIndent: 16, color: NexoraTokens.cardBorder),
              _buildSimpleListTile(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF64748B),
                title: 'Tentang Nexora',
                subtitle: 'Versi 2.4.0 (Smart Automation & Surveillance)',
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ==========================================
  // WIDGET AVATAR PROFIL PENGGUNA
  // ==========================================
  Widget _buildProfileAvatar({double size = 52}) {
    final photoPath = AuthService().currentUser?.photoPath;
    if (photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: NexoraTokens.cardBorder, width: 1.5),
        ),
        child: ClipOval(
          child: Image.file(
            File(photoPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AuthService().isSuperAdmin
            ? const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent])
            : const LinearGradient(colors: [NexoraTokens.brandCyan, Color(0xFF0077B6)]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          AuthService().isSuperAdmin ? Icons.stars_rounded : Icons.person_rounded,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  // ==========================================
  // SHEET EDIT PROFIL & FOTO
  // ==========================================
  void _showEditProfileSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(
      text: AuthService().currentUserName,
    );
    String? tempPhotoPath = AuthService().currentUser?.photoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Profil Pengguna',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ubah foto profil dan nama akun Nexora Anda.',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12.5,
                      color: NexoraTokens.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avatar Preview dengan Tombol Ubah
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: NexoraTokens.brandCyan, width: 2.5),
                          ),
                          child: ClipOval(
                            child: (tempPhotoPath != null && tempPhotoPath!.isNotEmpty && File(tempPhotoPath!).existsSync())
                                ? Image.file(File(tempPhotoPath!), width: 88, height: 88, fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFFE0F2FE),
                                    child: Icon(
                                      AuthService().isSuperAdmin ? Icons.stars_rounded : Icons.person_rounded,
                                      color: NexoraTokens.brandCyan,
                                      size: 46,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: NexoraTokens.brandCyan,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pilihan Ambil Foto: Galeri atau Kamera
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 600,
                            maxHeight: 600,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setModalState(() {
                              tempPhotoPath = picked.path;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Dari Galeri'),
                        style: OutlinedButton.styleFrom(
                          primary: NexoraTokens.ink,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 600,
                            maxHeight: 600,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setModalState(() {
                              tempPhotoPath = picked.path;
                            });
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Kamera'),
                        style: OutlinedButton.styleFrom(
                          primary: NexoraTokens.ink,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Input Nama Pengguna
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nama Pengguna',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NexoraTokens.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama Anda...',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: NexoraTokens.brandCyan),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: NexoraTokens.brandCyan, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final newName = nameCtrl.text.trim();
                        await AuthService().updateProfile(
                          newName: newName,
                          newPhotoPath: tempPhotoPath,
                        );
                        if (mounted) {
                          setState(() {});
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: NexoraTokens.statusGreen,
                              content: Text('✅ Profil berhasil diperbarui!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Simpan Perubahan'),
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        onPrimary: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 📱 KLASIFIKASI MENU PERANGKAT & CCTV
  // ==========================================
  Widget _buildDeviceClassificationCard() {
    final lang = LanguageService();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(color: NexoraTokens.cardBorder),
        boxShadow: NexoraTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: const [
                Icon(Icons.dns_rounded, size: 18, color: NexoraTokens.brandCyan),
                SizedBox(width: 8),
                Text(
                  'Manajemen Perangkat & Pengawasan',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.inkSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: NexoraTokens.cardBorder),

          // Menu 1: Kamera Pengawas (CCTV)
          _buildClassificationMenuItem(
            icon: Icons.videocam_rounded,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: NexoraTokens.brandCyan,
            title: lang.isIndonesian ? 'Kamera CCTV Pengawas' : 'Surveillance Cameras (CCTV)',
            stream: CctvManagerService().camerasStream,
            initialCount: CctvManagerService().allCameras.length,
            subtitleBuilder: (count) => lang.isIndonesian
                ? '$count Kamera Terdaftar • Live RTSP'
                : '$count Registered Cameras • Live RTSP',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CctvManagementScreen()),
              );
            },
          ),

          const Divider(height: 1, indent: 70, endIndent: 16, color: NexoraTokens.cardBorder),

          // Menu 2: Perangkat IoT (ESP32 & PLC)
          _buildClassificationMenuItem(
            icon: Icons.developer_board_rounded,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            title: lang.isIndonesian ? 'Perangkat IoT & Otomasi' : 'IoT Devices & Automation',
            stream: DeviceManagerService().devicesStream,
            initialCount: DeviceManagerService().allDevices.length,
            subtitleBuilder: (count) => lang.isIndonesian
                ? '$count Perangkat Terpasang • Relai & Sensor'
                : '$count Installed Devices • Relay & Sensors',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IotDeviceManagementScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationMenuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Stream stream,
    required int initialCount,
    required String Function(int count) subtitleBuilder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  StreamBuilder(
                    stream: stream,
                    builder: (context, snapshot) {
                      int count = initialCount;
                      if (snapshot.hasData && snapshot.data is List) {
                        count = (snapshot.data as List).length;
                      }
                      return Text(
                        subtitleBuilder(count),
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: NexoraTokens.inkSecondary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: NexoraTokens.inkMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleListTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: NexoraTokens.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: NexoraTokens.inkMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMono = false}) {
    final displayValue = value.trim().isEmpty ? 'Belum ada data' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: NexoraTokens.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: isMono ? 'JetBrains Mono' : NexoraTokens.fontFamilySans,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: NexoraTokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG TENTANG NEXORA
  // ==========================================
  void _showAboutDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.home_work_rounded, color: NexoraTokens.brandCyan, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nexora Smart Home',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sistem Otomasi Gerbang, Perangkat Pintar & Pengawasan CCTV Terintegrasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12.5,
                color: NexoraTokens.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'v2.4.0 • Built with Flutter & MQTT',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NexoraTokens.inkMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG KONFIRMASI LOGOUT
  // ==========================================
  void _confirmLogout() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Keluar dari Akun?',
          style: TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: const Text(
          'Anda akan diarahkan kembali ke layar Login Nexora.',
          style: TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 13,
            color: NexoraTokens.inkSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              AuthService().logout();
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthView()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔐 LOGIK & UI SUPER ADMIN (UBAH BROKER / CLOUD LANGSUNG DARI HP)
  // =========================================================================
  void _openSuperAdminModal() {
    // Jika sudah login dengan akun Ravi (Super Admin), langsung buka tanpa PIN lagi!
    if (AuthService().isSuperAdmin || _isSuperAdminUnlocked) {
      _showBrokerConfigSheet();
    } else {
      _showPinDialog();
    }
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: Colors.purple, size: 24),
            SizedBox(width: 10),
            Text(
              'Akses Super Admin',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: NexoraTokens.ink,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan PIN Keamanan untuk membuka akses pengaturan Cloud Broker & IoT Hardware.',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 13,
                color: NexoraTokens.inkSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'PIN Default: 2026 atau 1234',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin == '2026' || pin == '1234' || pin == '0000') {
                Navigator.pop(ctx);
                setState(() {
                  _isSuperAdminUnlocked = true;
                });
                HapticFeedback.heavyImpact();
                _showBrokerConfigSheet();
              } else {
                HapticFeedback.vibrate();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.redAccent,
                    content: Text('❌ PIN salah! Akses ditolak.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.purple,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Buka Kunci', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBrokerConfigSheet() {
    _brokerController.text = MqttConfig.broker;
    _portController.text = MqttConfig.port.toString();
    _prefixController.text = MqttConfig.topicPrefix;
    _usernameController.text = MqttConfig.username ?? '';
    _passwordController.text = MqttConfig.password ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Colors.purple, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Konfigurasi Cloud & Broker',
                          style: const TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: NexoraTokens.ink,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const Text(
                  'Ubah alamat Cloud MQTT langsung dari HP tanpa perlu membuka laptop atau build ulang APK.',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 12.5,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Preset Cepat
                const Text(
                  'PRESET CEPAT:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('EMQX Publik', style: TextStyle(fontSize: 11.5)),
                      avatar: const Icon(Icons.cloud_queue, size: 14),
                      onPressed: () {
                        setModalState(() {
                          _brokerController.text = 'broker.emqx.io';
                          _portController.text = '1883';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('HiveMQ Cloud', style: TextStyle(fontSize: 11.5)),
                      avatar: const Icon(Icons.speed, size: 14),
                      onPressed: () {
                        setModalState(() {
                          _brokerController.text = 'broker.hivemq.com';
                          _portController.text = '1883';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Laptop / Mini PC (192.168.0.104)', style: TextStyle(fontSize: 11.5)),
                      avatar: const Icon(Icons.laptop_chromebook, size: 14),
                      onPressed: () {
                        setModalState(() {
                          _brokerController.text = '192.168.0.104';
                          _portController.text = '1883';
                          _prefixController.text = 'alrisa';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Local PC / Emulator (10.0.2.2)', style: TextStyle(fontSize: 11.5)),
                      avatar: const Icon(Icons.laptop_mac, size: 14),
                      onPressed: () {
                        setModalState(() {
                          _brokerController.text = '10.0.2.2';
                          _portController.text = '1883';
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Field Broker & Port
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alamat Broker / Cloud Domain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _brokerController,
                            decoration: InputDecoration(
                              hintText: 'misal: iot.domainanda.com',
                              filled: true,
                              fillColor: const Color(0xFFF1F3F5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '1883',
                              filled: true,
                              fillColor: const Color(0xFFF1F3F5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Topic Prefix
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Topic Prefix (Default: nexora)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _prefixController,
                      decoration: InputDecoration(
                        hintText: 'nexora',
                        filled: true,
                        fillColor: const Color(0xFFF1F3F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Username & Password (Opsional)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Username (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: 'user_mqtt',
                              filled: true,
                              fillColor: const Color(0xFFF1F3F5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: '••••••',
                              filled: true,
                              fillColor: const Color(0xFFF1F3F5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Tombol Simpan & Hubungkan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingBroker
                        ? null
                        : () async {
                            final newHost = _brokerController.text.trim();
                            final newPort = int.tryParse(_portController.text.trim()) ?? 1883;
                            final newPrefix = _prefixController.text.trim();
                            final newUsername = _usernameController.text.trim();
                            final newPassword = _passwordController.text.trim();

                            if (newHost.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ Alamat broker tidak boleh kosong!')),
                              );
                              return;
                            }

                            setModalState(() {
                              _isSavingBroker = true;
                            });

                            HapticFeedback.mediumImpact();

                            final success = await MqttService().updateBrokerAndReconnect(
                              newBroker: newHost,
                              newPort: newPort,
                              newPrefix: newPrefix,
                              newUsername: newUsername,
                              newPassword: newPassword,
                            );

                            setModalState(() {
                              _isSavingBroker = false;
                            });

                            if (mounted) {
                              setState(() {
                                _isConnected = success;
                              });
                              Navigator.pop(modalContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: success ? NexoraTokens.statusGreen : NexoraTokens.statusAmber,
                                  content: Text(
                                    success
                                        ? '✅ Terhubung ke broker baru: $newHost:$newPort'
                                        : '⚠️ Berhasil disimpan, sedang mencoba terhubung ke $newHost:$newPort...',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: _isSavingBroker
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSavingBroker ? 'Menghubungkan ke Broker Baru...' : 'Simpan & Terapkan Koneksi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.purple,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}