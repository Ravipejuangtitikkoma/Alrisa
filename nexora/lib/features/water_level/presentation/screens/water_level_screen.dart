import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';

class WaterLevelScreen extends StatefulWidget {
  const WaterLevelScreen({Key? key}) : super(key: key);

  @override
  _WaterLevelScreenState createState() => _WaterLevelScreenState();
}

class _WaterLevelScreenState extends State<WaterLevelScreen> {
  final double _waterPercentage = 0.82; // 82%
  bool _isAutoCutoff = true;
  bool _isPumpActive = false;
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  // Data grafik 7 hari terakhir (dalam persentase)
  final List<double> _weeklyData = [0.65, 0.70, 0.82, 0.55, 0.90, 0.75, 0.82];
  final List<String> _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Hari Ini'];

  @override
  void initState() {
    super.initState();
    final pump = MqttService().getDeviceState('pompa_toren');
    if (pump != null) {
      _isPumpActive = pump.state;
    }

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == 'pompa_toren' && mounted) {
        setState(() {
          _isPumpActive = event.payload.state;
        });
      }
    });
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  void _togglePump() {
    HapticFeedback.lightImpact();
    final nextState = !_isPumpActive;
    setState(() {
      _isPumpActive = nextState;
    });

    if (MqttService().isConnected) {
      MqttService().publishSet('pompa_toren', state: nextState);
    } else {
      showOfflineWarning(context, 'pompa toren');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLiters = (_waterPercentage * 1000).toInt();

    return Scaffold(
      backgroundColor: NexoraTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: NexoraTokens.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Monitoring Tandon Air',
          style: TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            color: NexoraTokens.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: NexoraTokens.brandCyan),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: const Text('✅ Sinkronisasi sensor ultrasonik toren sukses!'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu Indikator Utama Tandon Air
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: NexoraTokens.borderRadiusCard,
                border: Border.all(color: NexoraTokens.cardBorder),
                boxShadow: NexoraTokens.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kapasitas Tangki',
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 13,
                              color: NexoraTokens.inkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currentLiters / 1.000 L',
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: NexoraTokens.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: NexoraTokens.brandCyanSubtle,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: NexoraTokens.statusGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Level Aman',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: NexoraTokens.brandCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Visualisasi Level Air Melengkung
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: _waterPercentage,
                          strokeWidth: 14,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(NexoraTokens.brandCyan),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.opacity_rounded,
                            color: NexoraTokens.brandCyan,
                            size: 34,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_waterPercentage * 100).toInt()}%',
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: NexoraTokens.ink,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const Text(
                            'Volume Tersedia',
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NexoraTokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Status Info Tambahan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        icon: Icons.speed_rounded,
                        label: 'Tekanan Pipa',
                        value: '2.4 Bar',
                      ),
                      Container(width: 1, height: 32, color: NexoraTokens.cardBorder),
                      _buildQuickStat(
                        icon: Icons.thermostat_rounded,
                        label: 'Suhu Air',
                        value: '26.5 °C',
                      ),
                      Container(width: 1, height: 32, color: NexoraTokens.cardBorder),
                      _buildQuickStat(
                        icon: Icons.flash_on_rounded,
                        label: 'Pompa Toren',
                        value: _isPumpActive ? 'Aktif' : 'Standby',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Kartu Grafik Riwayat Pemakaian 7 Hari
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
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
                    children: const [
                      Text(
                        'Grafik Level 7 Hari Terakhir',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.ink,
                        ),
                      ),
                      Text(
                        'Rata-rata: 74%',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.brandCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bar Chart 7 hari
                  SizedBox(
                    height: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_weeklyData.length, (index) {
                        final val = _weeklyData[index];
                        final isToday = index == _weeklyData.length - 1;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${(val * 100).toInt()}%',
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 10,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 26,
                              height: 90 * val,
                              decoration: BoxDecoration(
                                color: isToday ? NexoraTokens.brandCyan : NexoraTokens.brandCyanSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isToday ? NexoraTokens.brandCyan : NexoraTokens.brandCyanBorder,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _days[index],
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday ? NexoraTokens.ink : NexoraTokens.inkSecondary,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Kontrol Otomatisasi Pompa
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: NexoraTokens.borderRadiusCard,
                border: Border.all(color: NexoraTokens.cardBorder),
                boxShadow: NexoraTokens.cardShadow,
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto Cut-Off Pompa Otomatis',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    subtitle: const Text(
                      'Matikan daya pompa otomatis saat sensor mendeteksi tangki mencapai 95%',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    value: _isAutoCutoff,
                    activeColor: NexoraTokens.brandCyan,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isAutoCutoff = val;
                      });
                    },
                  ),
                  const Divider(height: 24),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Daya Pompa Pengisi Toren',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    subtitle: Text(
                      _isPumpActive ? 'Pompa sedang aktif mengisi tangki' : 'Pompa saat ini siaga / standby',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        color: _isPumpActive ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                      ),
                    ),
                    value: _isPumpActive,
                    activeColor: NexoraTokens.brandCyan,
                    onChanged: (val) => _togglePump(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: NexoraTokens.brandCyan),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 11,
            color: NexoraTokens.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: NexoraTokens.ink,
          ),
        ),
      ],
    );
  }
}
