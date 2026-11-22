import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/features/home/widgets/cctv_card.dart';

/// Carousel CCTV Dinamis: Slider horizontal multi-kamera di atas kartu gerbang
class CctvCarousel extends StatefulWidget {
  final List<CctvCameraItem> cameras;

  const CctvCarousel({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  State<CctvCarousel> createState() => _CctvCarouselState();
}

class _CctvCarouselState extends State<CctvCarousel> {
  int _currentIndex = 0;
  Offset? _pointerDownPos;

  void _goToCamera(int index) {
    if (index < 0 || index >= widget.cameras.length || index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    if (widget.cameras.isEmpty) {
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
          children: [
            const Icon(Icons.videocam_off_outlined, size: 40, color: NexoraTokens.inkMuted),
            const SizedBox(height: 8),
            Text(
              lang.isIndonesian ? 'Belum Ada Kamera CCTV' : 'No CCTV Registered',
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: NexoraTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lang.isIndonesian
                  ? 'Daftarkan URL stream RTSP di Pengaturan > Kamera Pengawas.'
                  : 'Register RTSP stream URL in Settings > Surveillance Cameras.',
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

    final hasMultiple = widget.cameras.length > 1;

    // Pastikan _currentIndex tidak out of bounds jika ada kamera yang dihapus
    if (_currentIndex >= widget.cameras.length) {
      _currentIndex = widget.cameras.length - 1;
    }

    final activeCam = widget.cameras[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Chips Pemilih Kamera jika ada lebih dari 1 kamera
        if (hasMultiple) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Horizontal Chip Selector
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(widget.cameras.length, (index) {
                        final isSelected = index == _currentIndex;
                        final cam = widget.cameras[index];

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _goToCamera(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? NexoraTokens.brandCyan : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? NexoraTokens.brandCyan : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 14,
                                    color: isSelected ? Colors.white : NexoraTokens.inkSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    cam.name,
                                    style: TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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

                const SizedBox(width: 6),

                // Indikator Posisi Halaman (misal: "1 / 2")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.cameras.length}',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Kartu CCTV Aktif dengan Ukuran Alami + Listener Swipe (Tidak pernah mencuri tap pada Dropdown / Tombol)
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
                    if (delta.dx < 0 && _currentIndex < widget.cameras.length - 1) {
                      _goToCamera(_currentIndex + 1);
                    } else if (delta.dx > 0 && _currentIndex > 0) {
                      _goToCamera(_currentIndex - 1);
                    }
                  }
                }
              : null,
          child: RepaintBoundary(
            child: CctvCard(
              key: ValueKey('cctv_${activeCam.id}'),
              camera: activeCam,
              isActive: true,
            ),
          ),
        ),

        // Dot Indicator di Bawah Slider jika kamera > 1
        if (hasMultiple) ...[
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.cameras.length, (index) {
                final isSelected = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? NexoraTokens.brandCyan : const Color(0xFFCBD5E1),
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
}
