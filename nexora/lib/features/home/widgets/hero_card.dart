import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/language_service.dart';

enum GateStatus { locked, opening, open, closing }

/// Hero Card: Pagar Otomatis Dinamis (Dapat disesuaikan nama & ID untuk ESP32/PLC)
class HeroCard extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String hardwarePin;
  final ValueChanged<bool>? onLockChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HeroCard({
    Key? key,
    this.deviceId = 'pagar',
    this.deviceName = 'Gerbang Utama Depan',
    this.hardwarePin = 'GPIO 2 (%QX0.0)',
    this.onLockChanged,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  _HeroCardState createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> with TickerProviderStateMixin {
  GateStatus _status = GateStatus.locked;
  late AnimationController _gateController;
  late Animation<double> _gateCurve;
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();

    _gateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _gateCurve = CurvedAnimation(
      parent: _gateController,
      curve: Curves.easeInOutCubic,
    );

    _gateController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        setState(() {
          _status = GateStatus.open;
        });
        widget.onLockChanged?.call(false);
      } else if (status == AnimationStatus.dismissed) {
        HapticFeedback.lightImpact();
        setState(() {
          _status = GateStatus.locked;
        });
        widget.onLockChanged?.call(true);
      }
    });

    // Cek status awal pagar dari cache MqttService
    final initialPayload = MqttService().getDeviceState(widget.deviceId);
    if (initialPayload?.state == true) {
      _status = GateStatus.open;
      _gateController.value = 1.0;
    }

    // Dengarkan pesan masuk /state dari broker MQTT (Single Source of Truth)
    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == widget.deviceId && mounted) {
        final reduceMotion = MediaQuery.of(context).accessibleNavigation;
        if (event.payload.state && _status == GateStatus.locked) {
          setState(() {
            _status = GateStatus.opening;
          });
          if (reduceMotion) {
            _gateController.value = 1.0;
            setState(() {
              _status = GateStatus.open;
            });
          } else {
            _gateController.forward(from: 0.0);
          }
        } else if (!event.payload.state && _status == GateStatus.open) {
          setState(() {
            _status = GateStatus.closing;
          });
          if (reduceMotion) {
            _gateController.value = 0.0;
            setState(() {
              _status = GateStatus.locked;
            });
          } else {
            _gateController.reverse(from: 1.0);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    _gateController.dispose();
    super.dispose();
  }

  void _handleGateAction() {
    HapticFeedback.lightImpact();

    // Hindari spam klik saat pagar sedang bergerak
    if (_status == GateStatus.opening || _status == GateStatus.closing) return;

    final willOpen = (_status == GateStatus.locked);

    // Jalankan animasi lokal seketika (Optimistic UI) agar selalu responsif
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    if (willOpen) {
      setState(() => _status = GateStatus.opening);
      if (reduceMotion) {
        _gateController.value = 1.0;
        setState(() => _status = GateStatus.open);
      } else {
        _gateController.forward(from: 0.0);
      }
    } else {
      setState(() => _status = GateStatus.closing);
      if (reduceMotion) {
        _gateController.value = 0.0;
        setState(() => _status = GateStatus.locked);
      } else {
        _gateController.reverse(from: 1.0);
      }
    }

    // Cek konektivitas MQTT / Server
    if (MqttService().isConnected) {
      // Jika Online: Teruskan perintah ke broker MQTT sesuai deviceId dinamis
      MqttService().publishSet(widget.deviceId, state: willOpen);
    } else {
      // Jika Offline: Tampilkan notifikasi peringatan bahwa koneksi server bermasalah
      showOfflineWarning(context, widget.deviceName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOpen = _status == GateStatus.open;
    final bool isMoving = _status == GateStatus.opening || _status == GateStatus.closing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFFCFDFE) : Colors.white,
        borderRadius: NexoraTokens.borderRadiusCard,
        gradient: isOpen
            ? const LinearGradient(
                colors: [Color(0xFFF0FDFA), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFFAFCFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        border: Border.all(
          color: isOpen
              ? NexoraTokens.brandCyanBorder
              : (isMoving ? NexoraTokens.statusAmber.withOpacity(0.5) : const Color(0xFFE2E8F0)),
          width: isOpen ? 1.5 : 1.0,
        ),
        boxShadow: isOpen
            ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: NexoraTokens.brandCyan.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Judul Akses Gerbang & Badge Status (Anti-Overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          LanguageService().tr('section_gate'),
                          style: NexoraTokens.sectionLabel,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.hardwarePin,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: NexoraTokens.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: NexoraTokens.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (widget.onEdit != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onEdit,
                            child: const Icon(Icons.edit_outlined, size: 15, color: NexoraTokens.inkMuted),
                          ),
                        ],
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge Gerbang (TERKUNCI / TERBUKA / BERGERAK)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFFFEF2F2)
                      : (isMoving ? NexoraTokens.statusAmberSubtle : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen
                        ? const Color(0xFFFECACA)
                        : (isMoving ? NexoraTokens.statusAmber : const Color(0xFFBBF7D0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFEF4444)
                            : (isMoving ? NexoraTokens.statusAmber : NexoraTokens.statusGreen),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen
                          ? (LanguageService().isIndonesian ? 'TERBUKA' : 'OPEN')
                          : (isMoving
                              ? (LanguageService().isIndonesian ? 'BERGERAK' : 'MOVING')
                              : (LanguageService().isIndonesian ? 'TERKUNCI' : 'LOCKED')),
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isOpen
                            ? const Color(0xFFDC2626)
                            : (isMoving ? const Color(0xFFB45309) : const Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. VIEWPORT GERBANG DEDIKASI (TIDAK BERTUBRUKAN DENGAN TEKS APAPUN)
          Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDF2F7)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AnimatedBuilder(
                animation: _gateCurve,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _GateDedicatedScenePainter(
                      progress: _gateCurve.value,
                      isLocked: _status == GateStatus.locked,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Footer: Status & Tombol Aksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow(),
                    const SizedBox(height: 3),
                    const Text(
                      '14.32 - Kurir meninggalkan paket',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: NexoraTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    final lang = LanguageService();
    switch (_status) {
      case GateStatus.locked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: NexoraTokens.statusGreen),
            const SizedBox(width: 5),
            Text(
              lang.tr('gate_locked'),
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.statusGreen,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      case GateStatus.opening:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(NexoraTokens.brandCyan),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              lang.tr('gate_opening'),
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.brandCyan,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      case GateStatus.closing:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(NexoraTokens.statusAmber),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              lang.tr('gate_closing'),
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.statusAmber,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      case GateStatus.open:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open_outlined, size: 16, color: NexoraTokens.statusAmber),
            const SizedBox(width: 5),
            Text(
              lang.tr('gate_open'),
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NexoraTokens.statusAmber,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildActionButton() {
    final isBusy = _status == GateStatus.opening || _status == GateStatus.closing;
    final isOpen = _status == GateStatus.open;
    final lang = LanguageService();

    String buttonLabel;
    IconData buttonIcon;
    if (_status == GateStatus.opening) {
      buttonLabel = lang.tr('gate_opening');
      buttonIcon = Icons.hourglass_top_rounded;
    } else if (_status == GateStatus.closing) {
      buttonLabel = lang.tr('gate_closing');
      buttonIcon = Icons.hourglass_bottom_rounded;
    } else if (isOpen) {
      buttonLabel = lang.tr('btn_lock_gate');
      buttonIcon = Icons.lock_outline_rounded;
    } else {
      buttonLabel = lang.tr('btn_open_gate');
      buttonIcon = Icons.lock_open_rounded;
    }

    return GestureDetector(
      onTap: isBusy ? null : _handleGateAction,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOpen ? NexoraTokens.brandCyan : NexoraTokens.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isOpen ? NexoraTokens.brandCyan : NexoraTokens.ink).withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(buttonIcon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              buttonLabel,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canvas Pagar Minimalis Modern dengan Stage Tersendiri
class _GateDedicatedScenePainter extends CustomPainter {
  final double progress; // 0.0 (Terkunci) s/d 1.0 (Terbuka)
  final bool isLocked;

  _GateDedicatedScenePainter({
    required this.progress,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topRailY = 16.0;
    final bottomRailY = size.height - 16.0;

    // 1. Lintasan Jalan Masuk (Driveway)
    if (progress > 0.02) {
      final drivewayOpening = (size.width * 0.50) * progress;
      final amberTintPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            NexoraTokens.statusAmber.withOpacity(0.18 * progress),
            NexoraTokens.statusAmber.withOpacity(0.04 * progress),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(18, 0, drivewayOpening, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(18, 0, drivewayOpening, size.height), amberTintPaint);
    }

    // 2. Rel Geser Atas dan Bawah
    final railPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(14, topRailY), Offset(size.width - 14, topRailY), railPaint);
    canvas.drawLine(Offset(14, bottomRailY), Offset(size.width - 14, bottomRailY), railPaint);

    // 3. Pilar Tetap Kiri
    final pillarPaint = Paint()
      ..color = NexoraTokens.inkSecondary
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(16, topRailY - 4), Offset(16, bottomRailY + 4), pillarPaint);

    // Ikon gembok kecil di rel kiri saat terkunci
    if (progress < 0.2) {
      final lockAlpha = ((0.2 - progress) / 0.2).clamp(0.0, 1.0);
      final lockPaint = Paint()
        ..color = NexoraTokens.statusGreen.withOpacity(lockAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final lockCenter = Offset(24, topRailY);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(lockCenter.dx, lockCenter.dy - 3), radius: 2.5),
        3.14,
        3.14,
        false,
        lockPaint,
      );
      final bodyPaint = Paint()
        ..color = NexoraTokens.statusGreen.withOpacity(lockAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(lockCenter.dx, lockCenter.dy + 3), width: 7, height: 6),
          const Radius.circular(1.5),
        ),
        bodyPaint,
      );
    }

    // 4. Daun Pintu Pagar Geser (8 Bar Vertikal)
    final totalGateWidth = size.width * 0.48;
    final maxSlideDistance = size.width - totalGateWidth - 28;
    final currentSlideX = maxSlideDistance * progress;
    final gateStartX = 18.0 + currentSlideX;

    // Bingkai Pintu Pagar
    final gateFramePaint = Paint()
      ..color = NexoraTokens.ink.withOpacity(0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(gateStartX, topRailY + 1, gateStartX + totalGateWidth, bottomRailY - 1),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(frameRect, gateFramePaint);

    // 8 Bar Vertikal di dalam Pagar
    final barPaint = Paint()
      ..color = NexoraTokens.ink.withOpacity(0.70)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final barCount = 8;
    final barStep = totalGateWidth / (barCount + 1);

    for (int i = 1; i <= barCount; i++) {
      final barX = gateStartX + (i * barStep);
      canvas.drawLine(
        Offset(barX, topRailY + 2),
        Offset(barX, bottomRailY - 2),
        barPaint,
      );
    }

    // 5. Roda Rel Pintu Pagar
    final wheelPaint = Paint()
      ..color = NexoraTokens.inkSecondary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(gateStartX + 10, bottomRailY), 2.2, wheelPaint);
    canvas.drawCircle(Offset(gateStartX + totalGateWidth - 10, bottomRailY), 2.2, wheelPaint);
  }

  @override
  bool shouldRepaint(covariant _GateDedicatedScenePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isLocked != isLocked;
  }
}
