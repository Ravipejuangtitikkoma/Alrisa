import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/data/mock_home.dart';


class EnergyView extends StatefulWidget {
  const EnergyView({Key? key}) : super(key: key);

  @override
  State<EnergyView> createState() => _EnergyViewState();
}

class _EnergyViewState extends State<EnergyView> {
  int _selectedBarIndex = 4; // default jam 18.00 (puncak)
  final List<EnergyPoint> _points = MockHomeData.getEnergyPoints();

  @override
  Widget build(BuildContext context) {
    const double maxCapacityWatt = 2200.0;
    const double currentWatt = 540.0;
    final double powerLoadPercentage = (currentWatt / maxCapacityWatt).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header
        const Text(
          'Konsumsi Energi',
          style: TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: NexoraTokens.ink,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pemantauan Beban Daya & Tagihan Listrik Real-Time',
          style: TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: NexoraTokens.inkSecondary,
          ),
        ),

        const SizedBox(height: 20),

        // 2. Hero Card: Live Power Meter (540 W)
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NexoraTokens.brandCyanSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: NexoraTokens.brandCyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Daya Aktif Saat Ini',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.ink,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NexoraTokens.statusGreenSubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Beban Rendah',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.statusGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Text(
                    '540',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Watt / 2.200 VA',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NexoraTokens.inkSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Progress Bar Beban Daya
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: powerLoadPercentage,
                  minHeight: 8,
                  backgroundColor: NexoraTokens.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(NexoraTokens.brandCyan),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(powerLoadPercentage * 100).toStringAsFixed(1)}% Kapasitas Terpakai',
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: NexoraTokens.inkMuted,
                    ),
                  ),
                  const Text(
                    'Sisa Daya: 1.660 W',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: NexoraTokens.brandCyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Dua Kartu Metrik: Tagihan & kWh
        Row(
          children: [
            // Kartu Estimasi Tagihan
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: NexoraTokens.borderRadiusCard,
                  border: Border.all(color: NexoraTokens.cardBorder),
                  boxShadow: NexoraTokens.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Est. Tagihan Bulan Ini',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rp 342.500',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.arrow_downward_rounded, size: 12, color: NexoraTokens.statusGreen),
                        SizedBox(width: 4),
                        Text(
                          '14% lebih hemat',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: NexoraTokens.statusGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Kartu Total Konsumsi kWh
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: NexoraTokens.borderRadiusCard,
                  border: Border.all(color: NexoraTokens.cardBorder),
                  boxShadow: NexoraTokens.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Akumulasi Listrik',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '238 kWh',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Rata-rata 7.9 kWh/hari',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 4. Grafik Batang Interaktif Konsumsi Harian
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
                  const Text(
                    'Grafik Beban Harian',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  Text(
                    'Terpilih: ${_points[_selectedBarIndex].watt.toInt()} W',
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.brandCyan,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bar Chart Minimalis Interaktif
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_points.length, (index) {
                    final pt = _points[index];
                    final isSelected = index == _selectedBarIndex;
                    final double barHeightRatio = (pt.watt / 700.0).clamp(0.15, 1.0);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedBarIndex = index;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            width: 32,
                            height: 85 * barHeightRatio,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NexoraTokens.brandCyan
                                  : NexoraTokens.brandCyanSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? NexoraTokens.brandCyan
                                    : NexoraTokens.brandCyanBorder,
                                width: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pt.timeLabel,
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 5. Rincian Konsumsi Perangkat
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
              const Text(
                'Proporsi Beban Alat',
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: NexoraTokens.ink,
                ),
              ),
              const SizedBox(height: 16),
              _buildBreakdownItem('AC & Pendingin Ruang', '226 W (42%)', 0.42, Icons.ac_unit),
              const SizedBox(height: 12),
              _buildBreakdownItem('Pompa Toren & Air', '151 W (28%)', 0.28, Icons.opacity),
              const SizedBox(height: 12),
              _buildBreakdownItem('Pencahayaan & Lampu', '97 W (18%)', 0.18, Icons.lightbulb_outline),
              const SizedBox(height: 12),
              _buildBreakdownItem('Motor Pagar & Solenoid', '66 W (12%)', 0.12, Icons.meeting_room_outlined),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 6. Nexora AI Eco-Optimizer Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NexoraTokens.statusAmberSubtle,
            borderRadius: NexoraTokens.borderRadiusCard,
            border: Border.all(color: NexoraTokens.statusAmber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NexoraTokens.statusAmber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: NexoraTokens.statusAmber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Saran Penghematan Pintar',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Jadwalkan pengisian Toren Air jam 04.00 subuh untuk tegangan listrik lebih stabil.',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, String valueText, double ratio, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: NexoraTokens.inkSecondary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.ink,
                  ),
                ),
              ],
            ),
            Text(
              valueText,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: NexoraTokens.inkSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F4F7),
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio > 0.35 ? NexoraTokens.brandCyan : const Color(0xFF89B4FA),
            ),
          ),
        ),
      ],
    );
  }
}
