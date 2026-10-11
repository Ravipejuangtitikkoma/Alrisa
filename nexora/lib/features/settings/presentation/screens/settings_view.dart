import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/config/mqtt_config.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/weather_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/features/auth/presentation/screens/auth_view.dart';
import 'package:nexora/features/home/widgets/cctv_stream_sheet.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _autoGateAlert = true;
  bool _torenDryProtection = true;
  bool _biometricLock = false;
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
  }

  @override
  void dispose() {
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
        // 1. Header
        Text(
          lang.tr('settings_title'),
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: NexoraTokens.ink,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lang.tr('settings_subtitle'),
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: NexoraTokens.inkSecondary,
          ),
        ),

        const SizedBox(height: 20),

        // 2. Profil Pemilik Rumah
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: NexoraTokens.borderRadiusCard,
            border: Border.all(color: NexoraTokens.cardBorder),
            boxShadow: NexoraTokens.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
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
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService().isLoggedIn ? AuthService().currentUserName : 'Ravi Armanza',
                          style: const TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: NexoraTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AuthService().isSuperAdmin
                              ? '👑 Super Admin • Full IoT & Cloud Control'
                              : '👤 Penghuni Rumah • Kendali Perangkat',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AuthService().isSuperAdmin ? Colors.purple : NexoraTokens.inkSecondary,
                          ),
                        ),
                        if (AuthService().currentUser != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            AuthService().currentUser!.email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: NexoraTokens.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AuthService().isSuperAdmin ? Colors.purple.withOpacity(0.1) : NexoraTokens.brandCyanSubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AuthService().isSuperAdmin ? 'ADMIN' : 'USER',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AuthService().isSuperAdmin ? Colors.purple : NexoraTokens.brandCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: NexoraTokens.cardBorder),
              const SizedBox(height: 10),
              // Tombol Keluar Akun (Logout)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Keluar dari Akun?'),
                          content: const Text('Anda akan diarahkan kembali ke layar Login.'),
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
                              style: ElevatedButton.styleFrom(primary: Colors.redAccent, elevation: 0),
                              child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'Keluar Akun (Logout)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Status Jaringan & Broker MQTT
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

              _buildInfoRow('Server Broker', '${MqttService().broker}:${MqttService().port}'),
              const Divider(height: 20, color: NexoraTokens.cardBorder),
              _buildInfoRow('Client ID', MqttService().clientId),
              const Divider(height: 20, color: NexoraTokens.cardBorder),
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
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(NexoraTokens.brandCyan),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                    elevation: MaterialStateProperty.all(0),
                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 13)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: NexoraTokens.borderRadiusButton,
                      ),
                    ),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
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
                    _isSuperAdminUnlocked ? '⚙️ Panel Super Admin (Aktif)' : '🔐 Mode Super Admin (Ubah Cloud via HP)',
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

        // 3.5 MANAJEMEN PERANGKAT IOT (ESP32 & PLC FX5U)
        _buildDeviceManagementSection(),

        const SizedBox(height: 20),

        // 3.6 MANAJEMEN KAMERA CCTV (RTSP / ONVIF)
        _buildCctvManagementSection(),

        const SizedBox(height: 20),

        // 4. Simulasi Cuaca & Lingkungan Ambient
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
                children: const [
                  Icon(Icons.wb_sunny_outlined, size: 20, color: NexoraTokens.ink),
                  SizedBox(width: 8),
                  Text(
                    'Simulasi Cuaca & Pencahayaan Langit',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Mengubah tema warna langit, suhu, dan pencahayaan rumah secara live.',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12,
                  color: NexoraTokens.inkSecondary,
                ),
              ),

              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: WeatherCondition.values.map((cond) {
                    final isCurrent = WeatherService().currentCondition == cond;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(WeatherService().getConditionLabel(cond)),
                        selected: isCurrent,
                        selectedColor: NexoraTokens.brandCyan,
                        labelStyle: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent ? Colors.white : NexoraTokens.ink,
                        ),
                        backgroundColor: const Color(0xFFF1F4F7),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            WeatherService().setCondition(cond);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 5. Keamanan & Otomasi Rumah
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
                children: const [
                  Icon(Icons.shield_outlined, size: 20, color: NexoraTokens.ink),
                  SizedBox(width: 8),
                  Text(
                    'Otomasi & Keamanan',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Peringatan Pagar Terbuka',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.ink,
                  ),
                ),
                subtitle: const Text(
                  'Kirim alarm notifikasi jika pagar terbuka lebih dari 5 menit',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
                value: _autoGateAlert,
                activeColor: NexoraTokens.brandCyan,
                onChanged: (val) {
                  setState(() => _autoGateAlert = val);
                },
              ),

              const Divider(color: NexoraTokens.cardBorder),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Proteksi Pompa Air Kering',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.ink,
                  ),
                ),
                subtitle: const Text(
                  'Matikan otomatis pompa toren jika level air sumber habis',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
                value: _torenDryProtection,
                activeColor: NexoraTokens.brandCyan,
                onChanged: (val) {
                  setState(() => _torenDryProtection = val);
                },
              ),

              const Divider(color: NexoraTokens.cardBorder),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Autentikasi Biometrik',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.ink,
                  ),
                ),
                subtitle: const Text(
                  'Minta sidik jari / FaceID saat membuka gerbang atau pintu',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
                value: _biometricLock,
                activeColor: NexoraTokens.brandCyan,
                onChanged: (val) {
                  setState(() => _biometricLock = val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 6. Info Versi
        Center(
          child: Column(
            children: const [
              Text(
                'NEXORA HOME OS',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: NexoraTokens.inkMuted,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Versi 2.4.0 (Build 2026.1) • PLC & IoT Edition',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 11.5,
                  color: NexoraTokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: NexoraTokens.inkSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: NexoraTokens.fontFamilySans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: NexoraTokens.ink,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MANAJEMEN PERANGKAT IOT (ESP32 / PLC FX5U)
  // ==========================================
  Widget _buildDeviceManagementSection() {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.developer_board_rounded, size: 20, color: NexoraTokens.brandCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService().tr('settings_iot_manage'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => _showAddDeviceSheet(context),
                icon: const Icon(Icons.add, size: 15),
                label: Text(LanguageService().tr('settings_add_btn')),
                style: ElevatedButton.styleFrom(
                  primary: NexoraTokens.brandCyan,
                  onPrimary: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Konfigurasi kontrol gerbang, saklar, dan aktuator. Kompatibel dengan ESP32 GPIO maupun PLC Mitsubishi FX5U.',
            style: TextStyle(
              fontFamily: NexoraTokens.fontFamilySans,
              fontSize: 12,
              color: NexoraTokens.inkSecondary,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<CustomDeviceItem>>(
            stream: DeviceManagerService().devicesStream,
            initialData: DeviceManagerService().allDevices,
            builder: (context, snapshot) {
              final devices = DeviceManagerService().allDevices;
              if (devices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Belum ada perangkat terdaftar.',
                      style: TextStyle(fontSize: 12, color: NexoraTokens.inkMuted),
                    ),
                  ),
                );
              }

              return Column(
                children: devices.map((dev) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NexoraTokens.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getDeviceColor(dev.type).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getDeviceIcon(dev.type),
                            size: 19,
                            color: _getDeviceColor(dev.type),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dev.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: NexoraTokens.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Topic: nexora/${dev.id}/set',
                                    style: const TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: NexoraTokens.inkMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dev.hardwarePin,
                                      style: const TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: NexoraTokens.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _showEditDeviceSheet(context, dev),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.edit_outlined, size: 17, color: NexoraTokens.inkSecondary),
                              ),
                            ),
                            InkWell(
                              onTap: () => _confirmDeleteDevice(context, dev),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.gate:
        return Icons.sensor_door_outlined;
      case DeviceType.light:
        return Icons.lightbulb_outline;
      case DeviceType.slidingDoor:
        return Icons.meeting_room_outlined;
      case DeviceType.curtain:
        return Icons.view_sidebar_outlined;
      case DeviceType.waterPump:
        return Icons.opacity_outlined;
    }
  }

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.gate:
        return NexoraTokens.brandCyan;
      case DeviceType.light:
        return const Color(0xFFEAB308);
      case DeviceType.slidingDoor:
        return const Color(0xFF6366F1);
      case DeviceType.curtain:
        return const Color(0xFFEC4899);
      case DeviceType.waterPump:
        return const Color(0xFF0EA5E9);
    }
  }

  void _showAddDeviceSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: 'GPIO 2 (%QX0.0)');
    final idCtrl = TextEditingController();
    DeviceType selectedType = DeviceType.gate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Perangkat Baru',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Perangkat langsung aktif di Beranda & dapat dites via ESP32 / PLC.',
                    style: TextStyle(fontSize: 12, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 18),

                  // Tipe Perangkat
                  const Text(
                    'Tipe Perangkat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<DeviceType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: DeviceType.gate, child: Text('Pagar / Gerbang Otomatis')),
                      DropdownMenuItem(value: DeviceType.light, child: Text('Lampu Pintar (Dimmer/Relay)')),
                      DropdownMenuItem(value: DeviceType.slidingDoor, child: Text('Pintu Geser')),
                      DropdownMenuItem(value: DeviceType.curtain, child: Text('Gorden Elektrik')),
                      DropdownMenuItem(value: DeviceType.waterPump, child: Text('Pompa Air / Toren')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedType = val;
                          if (val == DeviceType.gate) {
                            pinCtrl.text = 'GPIO 2 (%QX0.0)';
                          } else if (val == DeviceType.light) {
                            pinCtrl.text = 'GPIO 4 (%QX0.3)';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Nama Perangkat
                  const Text(
                    'Nama Perangkat (contoh: Gerbang Belakang, Lampu Taman)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Gerbang Belakang',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ID MQTT
                  const Text(
                    'ID Perangkat MQTT (opsional, contoh: pagar_belakang)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: idCtrl,
                    decoration: InputDecoration(
                      hintText: 'Biarkan kosong untuk otomatis',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pin Hardware
                  const Text(
                    'Pin ESP32 / Alamat PLC FX5U (contoh: GPIO 4 atau %QX0.1)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pinCtrl,
                    decoration: InputDecoration(
                      hintText: 'GPIO 4 (%QX0.1)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama perangkat tidak boleh kosong!')),
                          );
                          return;
                        }
                        DeviceManagerService().addDevice(
                          name: name,
                          type: selectedType,
                          customId: idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : null,
                          hardwarePin: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : null,
                        );
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: NexoraTokens.statusGreen,
                            content: Text('✅ Perangkat "$name" berhasil ditambahkan!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan & Pasang Perangkat',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  void _showEditDeviceSheet(BuildContext context, CustomDeviceItem dev) {
    final nameCtrl = TextEditingController(text: dev.name);
    final pinCtrl = TextEditingController(text: dev.hardwarePin);
    DeviceType selectedType = dev.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getDeviceColor(selectedType).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getDeviceIcon(selectedType),
                          size: 19,
                          color: _getDeviceColor(selectedType),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Perangkat',
                              style: const TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: NexoraTokens.ink,
                              ),
                            ),
                            Text(
                              'Topic MQTT: nexora/${dev.id}/set',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: NexoraTokens.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tipe Perangkat
                  const Text(
                    'Tipe Perangkat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<DeviceType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: DeviceType.gate, child: Text('Pagar / Gerbang Otomatis')),
                      DropdownMenuItem(value: DeviceType.light, child: Text('Lampu Pintar (Dimmer/Relay)')),
                      DropdownMenuItem(value: DeviceType.slidingDoor, child: Text('Pintu Geser')),
                      DropdownMenuItem(value: DeviceType.curtain, child: Text('Gorden Elektrik')),
                      DropdownMenuItem(value: DeviceType.waterPump, child: Text('Pompa Air / Toren')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Nama Perangkat
                  const Text(
                    'Nama Perangkat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Gerbang Belakang',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pin ESP32 / Alamat PLC
                  const Text(
                    'Pin ESP32 / Alamat PLC (contoh: GPIO 4 atau %QX0.1)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pinCtrl,
                    decoration: InputDecoration(
                      hintText: 'GPIO 4 (%QX0.1)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final updatedName = nameCtrl.text.trim();
                        final updatedPin = pinCtrl.text.trim();
                        if (updatedName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama perangkat tidak boleh kosong!')),
                          );
                          return;
                        }

                        DeviceManagerService().updateDevice(
                          dev.id,
                          newName: updatedName,
                          newPin: updatedPin.isNotEmpty ? updatedPin : dev.hardwarePin,
                          newType: selectedType,
                        );

                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: NexoraTokens.statusGreen,
                            content: Text('✅ Perangkat "$updatedName" berhasil diperbarui!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  void _confirmDeleteDevice(BuildContext context, CustomDeviceItem dev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus "${dev.name}"?'),
        content: Text('Perangkat dengan ID "${dev.id}" akan dihapus dari sistem dan dashboard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              DeviceManagerService().removeDevice(dev.id);
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.redAccent,
                  content: Text('🗑️ Perangkat "${dev.name}" telah dihapus.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(primary: Colors.redAccent, elevation: 0),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MANAJEMEN KAMERA CCTV (RTSP / ONVIF)
  // ==========================================
  Widget _buildCctvManagementSection() {
    final lang = LanguageService();

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam_rounded, size: 16, color: NexoraTokens.brandCyan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.isIndonesian ? 'Kamera Pengawas (RTSP / ONVIF)' : 'Surveillance Cameras (RTSP / ONVIF)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => _showAddCctvSheet(context),
                icon: const Icon(Icons.add, size: 15),
                label: Text(lang.isIndonesian ? 'Tambah' : 'Add'),
                style: ElevatedButton.styleFrom(
                  primary: const Color(0xFF0F172A),
                  onPrimary: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang.isIndonesian
                ? 'Streaming video real-time via jalur RTSP & ONVIF langsung dari IP Cam ke HP tanpa membebani MQTT broker.'
                : 'Real-time video stream directly over RTSP & ONVIF from IP Cam without burdening the MQTT broker.',
            style: const TextStyle(
              fontFamily: NexoraTokens.fontFamilySans,
              fontSize: 12,
              color: NexoraTokens.inkSecondary,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<CctvCameraItem>>(
            stream: CctvManagerService().camerasStream,
            initialData: CctvManagerService().allCameras,
            builder: (context, snapshot) {
              final cameras = CctvManagerService().allCameras;
              if (cameras.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Belum ada kamera CCTV terdaftar.',
                      style: TextStyle(fontSize: 12, color: NexoraTokens.inkMuted),
                    ),
                  ),
                );
              }

              return Column(
                children: cameras.map((cam) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: NexoraTokens.brandCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.videocam_outlined,
                                size: 19,
                                color: NexoraTokens.brandCyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          cam.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: NexoraTokens.fontFamilySans,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF065F46),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'RTSP LIVE',
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6EE7B7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cam.location} • ${cam.resolution}',
                                    style: const TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Tombol Preview Live Stream
                            InkWell(
                              onTap: () {
                                CctvStreamSheet.show(
                                  context,
                                  camera: cam,
                                  gateId: cam.boundGateId,
                                  gateName: cam.name,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: NexoraTokens.brandCyan,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      lang.isIndonesian ? 'Pantau' : 'View',
                                      style: const TextStyle(
                                        fontFamily: NexoraTokens.fontFamilySans,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _showEditCctvSheet(context, cam),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.edit_outlined, size: 17, color: NexoraTokens.inkSecondary),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _confirmDeleteCctv(context, cam),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cam.rtspUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                              if (cam.boundGateId != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Pagar: ${cam.boundGateId}',
                                    style: const TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 9,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddCctvSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Pagar Depan');
    final rtspCtrl = TextEditingController(text: 'rtsp://admin:123456@192.168.1.105:554/live/ch0');
    final onvifHostCtrl = TextEditingController(text: '192.168.1.105');
    final onvifPortCtrl = TextEditingController(text: '80');
    String? selectedGateId = 'pagar';

    final gateDevices = DeviceManagerService().allDevices.where((d) => d.type == DeviceType.gate).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Kamera CCTV (RTSP / ONVIF)',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hubungkan feed kamera pengawas IP Cam ke kontrol gerbang.',
                    style: TextStyle(fontSize: 12, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 18),

                  const Text('Nama Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: CCTV Pintu Masuk Satpam',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Lokasi / Area Pemasangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Gerbang Utama & Halaman Depan',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('RTSP Stream URL (H.264 / H.265)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: rtspCtrl,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                    onChanged: (val) {
                      try {
                        final uri = Uri.parse(val.trim());
                        if (uri.host.isNotEmpty) {
                          onvifHostCtrl.text = uri.host;
                          if (uri.hasPort && uri.port != 0) {
                            onvifPortCtrl.text = uri.port.toString();
                          } else {
                            onvifPortCtrl.text = '554';
                          }
                        }
                      } catch (_) {}
                    },
                    decoration: InputDecoration(
                      hintText: 'rtsp://user:pass@ip:554/live/ch0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IP Host ONVIF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: onvifHostCtrl,
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '192.168.1.105',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
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
                            const Text('Port ONVIF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: onvifPortCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '80',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (gateDevices.isNotEmpty) ...[
                    const Text('Hubungkan ke Gerbang (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedGateId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tidak Terhubung (Kamera Bebas)')),
                        ...gateDevices.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text('${g.name} (${g.hardwarePin})'))),
                      ],
                      onChanged: (val) {
                        setModalState(() => selectedGateId = val);
                      },
                    ),
                    const SizedBox(height: 22),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final rtsp = rtspCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama kamera tidak boleh kosong!')),
                          );
                          return;
                        }
                        if (rtsp.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('RTSP URL tidak boleh kosong!')),
                          );
                          return;
                        }
                        final port = int.tryParse(onvifPortCtrl.text.trim()) ?? 80;

                        CctvManagerService().addCamera(
                          name: name,
                          location: locationCtrl.text.trim(),
                          rtspUrl: rtsp,
                          onvifHost: onvifHostCtrl.text.trim(),
                          onvifPort: port,
                          boundGateId: selectedGateId,
                        );
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: NexoraTokens.statusGreen,
                            content: Text('✅ Kamera CCTV "$name" berhasil ditambahkan!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan & Pasang CCTV',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  void _showEditCctvSheet(BuildContext context, CctvCameraItem cam) {
    final nameCtrl = TextEditingController(text: cam.name);
    final locationCtrl = TextEditingController(text: cam.location);
    final rtspCtrl = TextEditingController(text: cam.rtspUrl);
    final onvifHostCtrl = TextEditingController(text: cam.onvifHost);
    final onvifPortCtrl = TextEditingController(text: cam.onvifPort.toString());
    String? selectedGateId = cam.boundGateId;

    final gateDevices = DeviceManagerService().allDevices.where((d) => d.type == DeviceType.gate).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: NexoraTokens.brandCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.videocam_outlined,
                          size: 20,
                          color: NexoraTokens.brandCyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Edit Kamera CCTV',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: NexoraTokens.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Nama Kamera
                  const Text('Nama Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: CCTV Gerbang Utama',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Lokasi
                  const Text('Lokasi Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Pagar Depan & Jalan',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // RTSP Stream URL
                  const Text('RTSP Stream URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: rtspCtrl,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                    onChanged: (val) {
                      try {
                        final uri = Uri.parse(val.trim());
                        if (uri.host.isNotEmpty) {
                          onvifHostCtrl.text = uri.host;
                          if (uri.hasPort && uri.port != 0) {
                            onvifPortCtrl.text = uri.port.toString();
                          } else {
                            onvifPortCtrl.text = '554';
                          }
                        }
                      } catch (_) {}
                    },
                    decoration: InputDecoration(
                      hintText: 'rtsp://192.168.0.104:8554/',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ONVIF Host & Port
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IP / Host ONVIF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: onvifHostCtrl,
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '192.168.0.104',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
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
                            const Text('Port ONVIF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: onvifPortCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '8554',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (gateDevices.isNotEmpty) ...[
                    const Text('Hubungkan ke Gerbang (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedGateId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tidak Terhubung (Kamera Bebas)')),
                        ...gateDevices.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text('${g.name} (${g.hardwarePin})'))),
                      ],
                      onChanged: (val) {
                        setModalState(() => selectedGateId = val);
                      },
                    ),
                    const SizedBox(height: 22),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final rtsp = rtspCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama kamera tidak boleh kosong!')),
                          );
                          return;
                        }
                        if (rtsp.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('RTSP URL tidak boleh kosong!')),
                          );
                          return;
                        }
                        final port = int.tryParse(onvifPortCtrl.text.trim()) ?? 80;

                        CctvManagerService().updateCamera(
                          cam.id,
                          name: name,
                          location: locationCtrl.text.trim(),
                          rtspUrl: rtsp,
                          onvifHost: onvifHostCtrl.text.trim(),
                          onvifPort: port,
                          boundGateId: selectedGateId,
                        );

                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: NexoraTokens.statusGreen,
                            content: Text('✅ Kamera CCTV "$name" berhasil diperbarui!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  void _confirmDeleteCctv(BuildContext context, CctvCameraItem cam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus "${cam.name}"?'),
        content: Text('Kamera CCTV dengan URL RTSP "${cam.rtspUrl}" akan dihapus dari sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              CctvManagerService().removeCamera(cam.id);
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(primary: Colors.redAccent, elevation: 0),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
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
