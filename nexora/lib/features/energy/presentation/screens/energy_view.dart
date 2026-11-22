import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/mqtt_service.dart';

class EnergyView extends StatefulWidget {
  const EnergyView({Key? key}) : super(key: key);

  @override
  State<EnergyView> createState() => _EnergyViewState();
}

class _EnergyViewState extends State<EnergyView> {
  int _selectedBarIndex = 4; // default jam 18.00 (puncak)
  double _plnCapacityWatt = 2200.0; // Pilihan Daya: 900, 1300, 2200, 3500 VA
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  // Base consumption + state
  bool _isPumpActive = false;
  bool _isAcActive = true;
  double _lampBrightness = 0.8;
  bool _isGateActive = false;

  final List<Map<String, dynamic>> _points = [
    {'time': '00.00', 'watt': 140.0},
    {'time': '04.00', 'watt': 180.0},
    {'time': '08.00', 'watt': 320.0},
    {'time': '12.00', 'watt': 460.0},
    {'time': '18.00', 'watt': 620.0},
    {'time': '20.00', 'watt': 510.0},
  ];

  @override
  void initState() {
    super.initState();
    _syncDeviceStates();

    _mqttSub = MqttService().stateStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _syncDeviceStates();
      });
    });
  }

  void _syncDeviceStates() {
    final pump = MqttService().getDeviceState('pompa_toren');
    if (pump != null) _isPumpActive = pump.state;

    final lamp = MqttService().getDeviceState('lampu_teras');
    if (lamp != null) {
      _lampBrightness = (lamp.value ?? (lamp.state ? 80 : 0)) / 100.0;
    }

    final gate = MqttService().getDeviceState('pagar');
    if (gate != null) _isGateActive = gate.state;
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  double _calculateCurrentWatt() {
    double total = 110.0; // Base load (Router, MiniPC PLC, ESP32, CCTV Gateway)
    if (_isAcActive) total += 220.0;
    if (_isPumpActive) total += 150.0;
    total += 45.0 * _lampBrightness;
    if (_isGateActive) total += 65.0;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final double currentWatt = _calculateCurrentWatt();
    final double powerLoadPercentage = (currentWatt / _plnCapacityWatt).clamp(0.0, 1.0);
    final double remainingWatt = (_plnCapacityWatt - currentWatt).clamp(0.0, _plnCapacityWatt);

    // PLN Tariff calculation: Rp 1.444,70 / kWh (Tarif Golongan R-1)
    const double plnTariffPerKwh = 1444.70;
    final double estimatedDailyKwh = (currentWatt * 24) / 1000.0;
    final double estimatedMonthlyKwh = estimatedDailyKwh * 30.0;
    final double estimatedMonthlyCost = estimatedMonthlyKwh * plnTariffPerKwh;

    // Breakdown components
    final double acWatt = _isAcActive ? 220.0 : 0.0;
    final double pumpWatt = _isPumpActive ? 150.0 : 0.0;
    final double lampWatt = 45.0 * _lampBrightness;
    final double gateWatt = _isGateActive ? 65.0 : 0.0;
    final double standbyWatt = 110.0;

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

        const SizedBox(height: 16),

        // Pilihan Daya Kontrak PLN
        Row(
          children: [
            const Text(
              'Daya PLN:',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NexoraTokens.inkSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [900.0, 1300.0, 2200.0, 3500.0].map((cap) {
                    final isSel = _plnCapacityWatt == cap;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _plnCapacityWatt = cap);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? NexoraTokens.brandCyan : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? NexoraTokens.brandCyan : NexoraTokens.cardBorder,
                          ),
                        ),
                        child: Text(
                          '${cap.toInt()} VA',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.white : NexoraTokens.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. Hero Card: Live Power Meter
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
                      color: powerLoadPercentage > 0.8
                          ? NexoraTokens.statusRedSubtle
                          : (powerLoadPercentage > 0.5 ? NexoraTokens.statusAmberSubtle : NexoraTokens.statusGreenSubtle),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      powerLoadPercentage > 0.8
                          ? 'Beban Tinggi'
                          : (powerLoadPercentage > 0.5 ? 'Beban Sedang' : 'Beban Efisien'),
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: powerLoadPercentage > 0.8
                            ? NexoraTokens.statusRed
                            : (powerLoadPercentage > 0.5 ? NexoraTokens.statusAmber : NexoraTokens.statusGreen),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentWatt.toStringAsFixed(0),
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Watt / ${_plnCapacityWatt.toInt()} VA',
                    style: const TextStyle(
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    powerLoadPercentage > 0.8
                        ? NexoraTokens.statusRed
                        : (powerLoadPercentage > 0.5 ? NexoraTokens.statusAmber : NexoraTokens.brandCyan),
                  ),
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
                  Text(
                    'Sisa Daya: ${remainingWatt.toStringAsFixed(0)} W',
                    style: const TextStyle(
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
                      'Est. Tagihan / Bulan',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_formatRupiah(estimatedMonthlyCost)}',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.check_circle_outline_rounded, size: 12, color: NexoraTokens.statusGreen),
                        SizedBox(width: 4),
                        Text(
                          'Rp 1.444,70 / kWh',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
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
                      'Proyeksi Akumulasi',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${estimatedMonthlyKwh.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rata-rata ${estimatedDailyKwh.toStringAsFixed(1)} kWh/hari',
                      style: const TextStyle(
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
                    'Terpilih: ${_points[_selectedBarIndex]['watt'].toInt()} W',
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
                    final double watt = pt['watt'] as double;
                    final double barHeightRatio = (watt / 700.0).clamp(0.15, 1.0);

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
                            width: 34,
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
                            pt['time'] as String,
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

        // 5. Rincian Konsumsi Perangkat Real-time
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
                    'Proporsi Beban Alat',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  Text(
                    'Total ${currentWatt.toInt()} W',
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.brandCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBreakdownItem(
                'AC & Pendingin Ruang',
                '${acWatt.toInt()} W (${(acWatt / currentWatt * 100).toStringAsFixed(0)}%)',
                acWatt / currentWatt,
                Icons.ac_unit_rounded,
                _isAcActive,
              ),
              const SizedBox(height: 12),
              _buildBreakdownItem(
                'Pompa Toren & Air',
                '${pumpWatt.toInt()} W (${(pumpWatt / currentWatt * 100).toStringAsFixed(0)}%)',
                pumpWatt / currentWatt,
                Icons.opacity_rounded,
                _isPumpActive,
              ),
              const SizedBox(height: 12),
              _buildBreakdownItem(
                'Pencahayaan & Lampu',
                '${lampWatt.toInt()} W (${(lampWatt / currentWatt * 100).toStringAsFixed(0)}%)',
                lampWatt / currentWatt,
                Icons.lightbulb_outline_rounded,
                lampWatt > 0,
              ),
              const SizedBox(height: 12),
              _buildBreakdownItem(
                'Motor Pagar & Gerbang',
                '${gateWatt.toInt()} W (${(gateWatt / currentWatt * 100).toStringAsFixed(0)}%)',
                gateWatt / currentWatt,
                Icons.fence_rounded,
                _isGateActive,
              ),
              const SizedBox(height: 12),
              _buildBreakdownItem(
                'Sistem Gateway, PLC & ESP32',
                '${standbyWatt.toInt()} W (${(standbyWatt / currentWatt * 100).toStringAsFixed(0)}%)',
                standbyWatt / currentWatt,
                Icons.router_rounded,
                true,
              ),
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
            border: Border.all(color: NexoraTokens.statusAmber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NexoraTokens.statusAmber.withValues(alpha: 0.2),
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
                      'Saran Penghematan Pintar Nexora',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Jadwalkan pengisian Toren Air jam 04.00 subuh dan atur dimmer lampu 70% untuk efisiensi tagihan hingga 18%.',
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

  Widget _buildBreakdownItem(String label, String valueText, double ratio, IconData icon, bool isActive) {
    final cleanRatio = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? NexoraTokens.ink : NexoraTokens.inkSecondary,
                  ),
                ),
              ],
            ),
            Text(
              valueText,
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: cleanRatio,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F4F7),
            valueColor: AlwaysStoppedAnimation<Color>(
              isActive ? NexoraTokens.brandCyan : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRupiah(double amount) {
    final int rounded = amount.round();
    final str = rounded.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }
}
