import 'package:flutter/material.dart';
import 'package:nexora/core/constants/app_colors.dart';

class WaterLevelScreen extends StatefulWidget {
  const WaterLevelScreen({Key? key}) : super(key: key);

  @override
  _WaterLevelScreenState createState() => _WaterLevelScreenState();
}

class _WaterLevelScreenState extends State<WaterLevelScreen> {
  final double _waterPercentage = 0.78; // 78%
  bool _isAutoCutoff = true;
  bool _isPumpActive = false;

  // Data grafik 7 hari terakhir (dalam persentase)
  final List<double> _weeklyData = [0.65, 0.70, 0.82, 0.55, 0.90, 0.75, 0.78];
  final List<String> _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final currentLiters = (_waterPercentage * 1000).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_outlined, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Monitoring Tandon Air',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryBlue),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sinkronisasi sensor ultrasonik sukses!'),
                  duration: Duration(seconds: 1),
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.cardShadow,
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
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currentLiters / 1000 L',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cyanLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.statusOnline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Aman',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

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
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.opacity,
                            color: AppColors.neonCyan,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_waterPercentage * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Volume Tersedia',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Status Info Tambahan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        icon: Icons.speed,
                        label: 'Tekanan',
                        value: '2.4 Bar',
                      ),
                      Container(width: 1, height: 32, color: AppColors.cardBorder),
                      _buildQuickStat(
                        icon: Icons.ac_unit,
                        label: 'Suhu Air',
                        value: '26.5 °C',
                      ),
                      Container(width: 1, height: 32, color: AppColors.cardBorder),
                      _buildQuickStat(
                        icon: Icons.flash_on,
                        label: 'Pompa',
                        value: _isPumpActive ? 'Aktif' : 'Standby',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Kartu Grafik Riwayat Pemakaian
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.cardShadow,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Rata-rata: 73%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
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
                                fontSize: 10,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday ? AppColors.primaryBlue : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 24,
                              height: 90 * val,
                              decoration: BoxDecoration(
                                gradient: isToday
                                    ? AppColors.primaryGradient
                                    : const LinearGradient(
                                        colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _days[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto Cut-Off Pompa',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Matikan pompa otomatis saat tangki mencapai 95%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _isAutoCutoff,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        _isAutoCutoff = val;
                      });
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Daya Pompa Air',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _isPumpActive ? 'Pompa sedang aktif menyedot air' : 'Pompa saat ini mati',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _isPumpActive,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        _isPumpActive = val;
                      });
                    },
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
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
