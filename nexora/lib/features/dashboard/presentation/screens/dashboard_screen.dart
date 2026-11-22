import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/weather_service.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/features/home/widgets/ambient_sky_background.dart';
import 'package:nexora/features/home/widgets/ambient_header.dart';
import 'package:nexora/features/home/widgets/scene_chips.dart';
import 'package:nexora/features/home/widgets/gate_carousel.dart';
import 'package:nexora/features/home/widgets/bento_grid.dart';
import 'package:nexora/features/home/widgets/pill_nav.dart';
import 'package:nexora/features/rooms/presentation/screens/rooms_view.dart';
import 'package:nexora/features/presets/presentation/screens/presets_view.dart';
import 'package:nexora/features/settings/presentation/screens/settings_view.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/cloud_sync_service.dart';
import 'package:nexora/features/home/widgets/cctv_carousel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  bool _isOffline = false; // banner offline jika terputus dari MQTT
  final ScrollController _homeScrollController = ScrollController();
  bool _isSkyVisible = true;

  late AnimationController _entranceController;
  late Animation<double> _fadeHeader;
  late Animation<double> _fadeChips;
  late Animation<double> _fadeHero;
  late Animation<double> _fadeBento;

  StreamSubscription<WeatherCondition>? _weatherSub;
  StreamSubscription<bool>? _mqttConnSub;
  StreamSubscription<AppLanguage>? _langSub;

  @override
  void initState() {
    super.initState();
    _navIndex = 0; // Item aktif default selalu Beranda
    _isOffline = !MqttService().isConnected;

    // Dengarkan perubahan bahasa untuk rebuild instan
    _langSub = LanguageService().languageStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Dengarkan status koneksi MQTT secara live untuk banner offline
    _mqttConnSub = MqttService().connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isOffline = !connected;
        });
      }
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Staggered entrance 40ms per komponen
    _fadeHeader = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _fadeChips = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
    );
    _fadeHero = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );
    _fadeBento = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();

    _weatherSub = WeatherService().weatherStream.listen((_) {
      if (mounted) setState(() {});
    });

    _homeScrollController.addListener(() {
      final isVisible = _homeScrollController.offset < 340;
      if (isVisible != _isSkyVisible) {
        if (mounted) {
          setState(() {
            _isSkyVisible = isVisible;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _langSub?.cancel();
    _mqttConnSub?.cancel();
    _weatherSub?.cancel();
    _homeScrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _showWeatherSimulationSheet() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeCondition = WeatherService().currentCondition;
            final isMqttConnected = MqttService().isConnected;

            final weatherOptions = [
              {
                'condition': WeatherCondition.cerah,
                'name': 'Cerah',
                'desc': 'Langit biru lembut + pendaran matahari berdenyut 4 detik',
                'icon': Icons.wb_sunny_outlined,
              },
              {
                'condition': WeatherCondition.berawan,
                'name': 'Berawan',
                'desc': 'Gradien lembut + 3-4 awan blur melintas horizontal',
                'icon': Icons.cloud_outlined,
              },
              {
                'condition': WeatherCondition.hujan,
                'name': 'Hujan',
                'desc': 'Gradien sejuk + partikel hujan miring tipis jatuh kontinu',
                'icon': Icons.grain_outlined,
              },
              {
                'condition': WeatherCondition.angin,
                'name': 'Angin',
                'desc': 'Gradien netral + garis lengkung aliran angin horizontal',
                'icon': Icons.air_outlined,
              },
              {
                'condition': WeatherCondition.malam,
                'name': 'Malam',
                'desc': 'Dusk lavender + bulan sabit & bintang berkedip lembut',
                'icon': Icons.nights_stay_outlined,
              },
            ];

            return Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: NexoraTokens.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 1. KARTU STATUS KONEKSI MQTT (SESUAI POIN 5)
                    Text(
                      'STATUS KONEKSI IOT',
                      style: NexoraTokens.sectionLabel,
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMqttConnected ? const Color(0xFFF0FDF4) : NexoraTokens.statusAmberSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMqttConnected ? const Color(0xFFBBF7D0) : NexoraTokens.statusAmber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isMqttConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                    size: 18,
                                    color: isMqttConnected ? NexoraTokens.statusGreen : NexoraTokens.statusAmber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isMqttConnected ? 'Terhubung ke Rumah' : 'Terputus dari Broker',
                                    style: TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isMqttConnected ? const Color(0xFF166534) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isMqttConnected ? NexoraTokens.statusGreen : NexoraTokens.statusAmber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isMqttConnected ? 'LIVE' : 'OFFLINE',
                                  style: const TextStyle(
                                    fontFamily: NexoraTokens.fontFamilySans,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Broker: ${MqttService().broker}:${MqttService().port}',
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 11,
                              color: NexoraTokens.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Client ID: ${MqttService().clientId}',
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 11,
                              color: NexoraTokens.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pesan Terakhir: ${MqttService().lastMessage}',
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 11,
                              color: NexoraTokens.inkSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                await MqttService().reconnect();
                                setModalState(() {});
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: const Text('Hubungkan Ulang (Reconnect)'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white, backgroundColor: NexoraTokens.ink,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. SIMULASI CUACA AMBIENT
                    Text(
                      'SIMULASI CUACA AMBIENT',
                      style: NexoraTokens.sectionLabel,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih Kondisi Cuaca',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Latar langit di belakang layar akan bertransisi langsung secara live',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                  // Status Cuaca Lokasi Live (Global / Google Weather Standard)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: NexoraTokens.statusGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: NexoraTokens.statusGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cuaca Live: ${WeatherService().bmkgWeatherDesc} (${WeatherService().temperature.toStringAsFixed(0)}°C • ${WeatherService().humidity}%)',
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '📍 ${WeatherService().locationName} (Auto-Location)',
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await WeatherService().initLocationAndWeather();
                            setModalState(() {});
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: NexoraTokens.statusGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Deteksi Lokasi',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'PILIH LOKASI KOTA / DETEKSI OTOMATIS',
                    style: NexoraTokens.sectionLabel,
                  ),
                  const SizedBox(height: 8),

                  // Horizontal Chips Pilihan Kota BMKG (Jambi, Palembang, Jakarta, dll)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: WeatherService.supportedCities.entries.map((entry) {
                        final cityKey = entry.key;
                        final cityName = entry.value['name']!;
                        final isCityActive = WeatherService().currentCityKey == cityKey;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await WeatherService().setLocationCity(cityKey);
                              setModalState(() {});
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isCityActive ? NexoraTokens.brandCyan : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isCityActive ? NexoraTokens.brandCyan : NexoraTokens.cardBorder,
                                  width: 1.2,
                                ),
                                boxShadow: isCityActive
                                    ? [
                                        BoxShadow(
                                          color: NexoraTokens.brandCyan.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                cityName,
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 11.5,
                                  fontWeight: isCityActive ? FontWeight.w800 : FontWeight.w600,
                                  color: isCityActive ? Colors.white : NexoraTokens.ink,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'PILIHAN SIMULASI MANUAL',
                    style: NexoraTokens.sectionLabel,
                  ),
                  const SizedBox(height: 8),

                  ...weatherOptions.map((opt) {
                    final cond = opt['condition'] as WeatherCondition;
                    final isSelected = cond == activeCondition;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          WeatherService().setCondition(cond);
                          setModalState(() {});
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
                            borderRadius: NexoraTokens.borderRadiusCard,
                            border: Border.all(
                              color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.cardBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                                  ),
                                ),
                                child: Icon(
                                  opt['icon'] as IconData,
                                  size: 20,
                                  color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['name'] as String,
                                      style: TextStyle(
                                        fontFamily: NexoraTokens.fontFamilySans,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['desc'] as String,
                                      style: const TextStyle(
                                        fontFamily: NexoraTokens.fontFamilySans,
                                        fontSize: 11,
                                        color: NexoraTokens.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: NexoraTokens.brandCyan,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NexoraTokens.statusAmberSubtle,
        borderRadius: NexoraTokens.borderRadiusChip,
        border: Border.all(color: NexoraTokens.statusAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_outlined, size: 16, color: NexoraTokens.statusAmber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Terputus dari rumah - menampilkan status terakhir',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NexoraTokens.statusAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    // 1. Sinkronisasi Perangkat, PIN & URL RTSP dari Website Cloud
    await CloudSyncService().fetchFromCloud();
    // 2. Refresh CCTV Streams
    CctvManagerService().triggerRefresh();
    // 3. Refresh Weather data
    await WeatherService().fetchBMKGWeather();
    // 4. Refresh MQTT sync
    if (!MqttService().isConnected) {
      MqttService().connect();
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 10),
              Text(
                '🔄 Stream CCTV & status sistem telah disegarkan!',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tabBottomPadding = bottomInset + 115.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: NexoraTokens.background,
      body: Stack(
        children: [
          // 1. Ambient Sky Background di Belakang Seluruh Konten (Dorman jika di tab lain atau scrolled out of view)
          Positioned.fill(
            child: AmbientSkyBackground(
              isPageActive: _navIndex == 0 && _isSkyVisible,
            ),
          ),

          // 2. Konten 4 Tab Menggunakan IndexedStack
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _navIndex,
              children: [
                // Tab 0: Beranda (Pull-to-Refresh untuk menyegarkan CCTV & Sistem IoT)
                RefreshIndicator(
                  color: NexoraTokens.brandCyan,
                  backgroundColor: Colors.white,
                  displacement: 40,
                  strokeWidth: 2.5,
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    controller: _homeScrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: tabBottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Offline jika terputus
                        if (_isOffline) _buildOfflineBanner(),

                        // Ambient Header dengan Sapaan + Chip Suhu/Cuaca
                        FadeTransition(
                          opacity: _fadeHeader,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fadeHeader),
                            child: AmbientHeader(
                              userName: 'Fi',
                              temperature: WeatherService().temperature,
                              humidity: WeatherService().humidity,
                              weatherDesc: WeatherService().bmkgWeatherDesc,
                              locationName: WeatherService().locationName,
                              onWeatherTap: _showWeatherSimulationSheet,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Scene Chips Horizontal
                        FadeTransition(
                          opacity: _fadeChips,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fadeChips),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageService().tr('section_scenes'),
                                  style: NexoraTokens.sectionLabel.copyWith(
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 8,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const SceneChips(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Card CCTV Terdedikasi: Dynamic Swipeable CCTV Carousel (Multi-Kamera Slider)
                        FadeTransition(
                          opacity: _fadeHero,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fadeHero),
                            child: RepaintBoundary(
                              child: StreamBuilder<List<CctvCameraItem>>(
                                stream: CctvManagerService().camerasStream,
                                initialData: CctvManagerService().allCameras,
                                builder: (context, snapshot) {
                                  final cameras = CctvManagerService().allCameras;
                                  return CctvCarousel(cameras: cameras);
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Hero Card: Dynamic Swipeable Gate Carousel (Multi-Pagar Slider)
                        FadeTransition(
                          opacity: _fadeHero,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fadeHero),
                            child: RepaintBoundary(
                              child: StreamBuilder<List<CustomDeviceItem>>(
                                stream: DeviceManagerService().devicesStream,
                                initialData: DeviceManagerService().allDevices,
                                builder: (context, snapshot) {
                                  final gates = DeviceManagerService().gates;
                                  return GateCarousel(gates: gates);
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section Label Bento Grid
                        FadeTransition(
                          opacity: _fadeBento,
                          child: Text(
                            LanguageService().tr('section_devices'),
                            style: NexoraTokens.sectionLabel,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Bento Grid Asimetris (WaterCard, Dimmer Light, Pintu Geser, Gorden, EnergyCard)
                        FadeTransition(
                          opacity: _fadeBento,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fadeBento),
                            child: const RepaintBoundary(
                              child: BentoGrid(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab 1: Ruangan
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: tabBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOffline) _buildOfflineBanner(),
                      const RoomsView(),
                    ],
                  ),
                ),

                // Tab 2: Skenario & Preset Pintar (Pengganti Energi)
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: tabBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOffline) _buildOfflineBanner(),
                      const PresetsView(),
                    ],
                  ),
                ),

                // Tab 3: Pengaturan
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: tabBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isOffline) _buildOfflineBanner(),
                      const SettingsView(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Pill Nav 4 Item di bagian bawah (Adaptif dengan Android Navigation Inset)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset > 0 ? bottomInset + 8 : 20,
            child: Center(
              child: RepaintBoundary(
                child: PillNav(
                  currentIndex: _navIndex,
                  onIndexChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _navIndex = index;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
