import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/features/home/widgets/hero_card.dart';

/// Carousel Gerbang Dinamis: Slider geser horizontal yang mewah, responsif, dan elegan
class GateCarousel extends StatefulWidget {
  final List<CustomDeviceItem> gates;

  const GateCarousel({
    Key? key,
    required this.gates,
  }) : super(key: key);

  @override
  State<GateCarousel> createState() => _GateCarouselState();
}

class _GateCarouselState extends State<GateCarousel> {
  int _currentIndex = 0;
  Offset? _pointerDownPos;

  void _goToGate(int index) {
    if (index < 0 || index >= widget.gates.length || index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(color: NexoraTokens.cardBorder),
          boxShadow: NexoraTokens.cardShadow,
        ),
        child: Column(
          children: [
            const Icon(Icons.sensor_door_outlined, size: 44, color: NexoraTokens.brandCyan),
            const SizedBox(height: 10),
            Text(
              LanguageService().isEnglish ? 'No Gate Registered' : 'Belum Ada Gerbang Terdaftar',
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LanguageService().isEnglish
                  ? 'Add gates in Settings > IoT Device Management.'
                  : 'Tambahkan gerbang di menu Pengaturan > Manajemen Perangkat IoT.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                color: NexoraTokens.inkSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final hasMultiple = widget.gates.length > 1;
    if (_currentIndex >= widget.gates.length) {
      _currentIndex = widget.gates.length - 1;
    }
    final activeGate = widget.gates[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indikator Tab Gerbang & Navigasi Panah Cepat jika ada lebih dari 1 gerbang
        if (hasMultiple) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pill Chips Gerbang (Swipeable & Clickable)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(widget.gates.length, (index) {
                        final isSelected = index == _currentIndex;
                        final gate = widget.gates[index];

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _goToGate(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? NexoraTokens.brandCyan : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? NexoraTokens.brandCyan
                                      : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: NexoraTokens.brandCyan.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sensor_door_outlined,
                                    size: 13,
                                    color: isSelected ? Colors.white : NexoraTokens.inkSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    gate.name,
                                    style: TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : NexoraTokens.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Counter Index Gerbang (misal: "1 / 3")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.gates.length}',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // HeroCard dengan Tinggi Alami + Listener Swipe (Tidak pernah mencuri tap pada Tombol / Edit)
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: hasMultiple
              ? (event) {
                  _pointerDownPos = event.position;
                }
              : null,
          onPointerUp: hasMultiple
              ? (event) {
                  if (_pointerDownPos == null) return;
                  final delta = event.position - _pointerDownPos!;
                  _pointerDownPos = null;
                  if (delta.dx.abs() > 64 && delta.dx.abs() > delta.dy.abs() * 1.6) {
                    if (delta.dx < 0 && _currentIndex < widget.gates.length - 1) {
                      _goToGate(_currentIndex + 1);
                    } else if (delta.dx > 0 && _currentIndex > 0) {
                      _goToGate(_currentIndex - 1);
                    }
                  }
                }
              : null,
          child: HeroCard(
            key: ValueKey('${activeGate.id}_${activeGate.name}_${activeGate.hardwarePin}'),
            deviceId: activeGate.id,
            deviceName: activeGate.name,
            hardwarePin: activeGate.hardwarePin,
            onEdit: () => _showQuickEditGate(context, activeGate),
          ),
        ),

        // Dots Indicator Elegan jika ada lebih dari 1 gerbang
        if (hasMultiple) ...[
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.gates.length, (index) {
                final isSelected = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NexoraTokens.brandCyan
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  void _showQuickEditGate(BuildContext context, CustomDeviceItem gate) {
    final nameCtrl = TextEditingController(text: gate.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                      color: NexoraTokens.brandCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sensor_door_outlined,
                      size: 20,
                      color: NexoraTokens.brandCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Info Gerbang',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: NexoraTokens.ink,
                          ),
                        ),
                        Text(
                          'Topic MQTT: nexora/${gate.id}/set',
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

              // Nama Gerbang
              const Text(
                'Nama Gerbang',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Misal: Gerbang Utama Depan',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NexoraTokens.cardBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 16, color: NexoraTokens.brandCyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PIN Hardware gerbang dikontrol langsung oleh Super Admin di Website.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: NexoraTokens.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final updatedName = nameCtrl.text.trim();
                    if (updatedName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama gerbang tidak boleh kosong!')),
                      );
                      return;
                    }

                    DeviceManagerService().updateDevice(
                      gate.id,
                      newName: updatedName,
                    );

                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: NexoraTokens.statusGreen,
                        content: Text('✅ Gerbang "$updatedName" berhasil diperbarui!'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NexoraTokens.brandCyan,
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
      ),
    );
  }
}
