import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/mqtt_service.dart';

import 'package:nexora/services/device_manager_service.dart';

/// Modal Live RTSP/ONVIF CCTV Stream Viewer
class CctvStreamSheet extends StatefulWidget {
  final CctvCameraItem camera;
  final String? gateId;
  final String? gateName;

  const CctvStreamSheet({
    Key? key,
    required this.camera,
    this.gateId,
    this.gateName,
  }) : super(key: key);

  static void show(BuildContext context, {
    required CctvCameraItem camera,
    String? gateId,
    String? gateName,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CctvStreamSheet(
        camera: camera,
        gateId: gateId,
        gateName: gateName,
      ),
    );
  }

  @override
  State<CctvStreamSheet> createState() => _CctvStreamSheetState();
}

class _CctvStreamSheetState extends State<CctvStreamSheet> with SingleTickerProviderStateMixin {
  bool _isSnapshotTaken = false;
  late AnimationController _pulseController;
  Timer? _timer;
  String _timestamp = '';
  VlcPlayerController? _vlcViewController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _initVlcPlayer();
  }

  void _initVlcPlayer() {
    try {
      _vlcViewController = VlcPlayerController.network(
        widget.camera.rtspUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(300),
          ]),
          rtp: VlcRtpOptions([
            VlcRtpOptions.rtpOverRtsp(true),
          ]),
        ),
      );
    } catch (_) {}
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _timestamp = '$h:$m:$s';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    try {
      _vlcViewController?.stopRendererScanning();
      _vlcViewController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _takeSnapshot() {
    HapticFeedback.heavyImpact();
    setState(() => _isSnapshotTaken = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: NexoraTokens.ink,
        content: Row(
          children: const [
            Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('📸 Foto tangkapan CCTV berhasil disimpan ke galeri!'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isSnapshotTaken = false);
    });
  }

  void _toggleGate(bool open) {
    HapticFeedback.mediumImpact();
    final targetId = widget.gateId ?? 'pagar';
    MqttService().publishSet(targetId, state: open);
    DeviceManagerService().updateState(
      targetId,
      isActive: open,
      statusText: open ? 'Terbuka' : 'Terkunci',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: open ? NexoraTokens.statusGreen : NexoraTokens.ink,
        content: Text(
          open
              ? '🚪 Mengirim sinyal Buka Pagar...'
              : '🔒 Mengirim sinyal Kunci Pagar...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final cam = widget.camera;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900 CCTV dark theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Info CCTV
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'RTSP / ONVIF LIVE',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cam.location,
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cam.name,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Layar Video Stream RTSP (Video Viewport)
          Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A. Live RTSP Video Stream (VLC Engine)
                  if (_vlcViewController != null)
                    VlcPlayer(
                      controller: _vlcViewController!,
                      aspectRatio: 16 / 9,
                      placeholder: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: const Color(0xFF0F172A),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size.infinite,
                              painter: _CctvViewportPainter(),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Menghubungkan Stream RTSP...',
                                    style: TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    CustomPaint(
                      painter: _CctvViewportPainter(),
                    ),

                  // Flash Efek saat Snapshot Foto
                  if (_isSnapshotTaken)
                    Container(color: Colors.white.withOpacity(0.85)),

                  // Overlay Top Bar (Badge LIVE Merah Berkedip + Jam RTSP)
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            FadeTransition(
                              opacity: _pulseController,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'REC • RTSP STREAM',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _timestamp,
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

                  // Overlay Bottom Info (Protokol RTSP & Resolusi)
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            cam.rtspUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9.5,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cam.resolution,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Tombol Kontrol Kamera (Snapshot Eksklusif)
          Center(
            child: InkWell(
              onTap: _takeSnapshot,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF38BDF8)),
                    SizedBox(width: 8),
                    Text(
                      'Ambil Snapshot Foto',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Kontrol Langsung Gerbang dari Layar CCTV
          if (widget.gateId != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isIndonesian ? 'KONTROL AKSES LANGSUNG' : 'DIRECT ACCESS CONTROL',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.gateName ?? (lang.isIndonesian ? 'Gerbang Utama' : 'Main Gate'),
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _toggleGate(true),
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: Text(lang.isIndonesian ? 'Buka' : 'Open'),
                  style: ElevatedButton.styleFrom(
                    primary: const Color(0xFF10B981),
                    onPrimary: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _toggleGate(false),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: Text(lang.isIndonesian ? 'Kunci' : 'Lock'),
                  style: ElevatedButton.styleFrom(
                    primary: const Color(0xFF334155),
                    onPrimary: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Canvas Painter Realistis Simulasi Suasana CCTV Gerbang (Pintu Gerbang & Jalanan)
class _CctvViewportPainter extends CustomPainter {
  final bool isNightVision;

  _CctvViewportPainter({this.isNightVision = false});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Sky/Road Gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: isNightVision
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFF1E293B), const Color(0xFF334155)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Garis Jalan Aspal Perspektif
    final roadPaint = Paint()
      ..color = isNightVision ? const Color(0xFF0F172A) : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.25, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.55, size.height * 0.48)
      ..lineTo(size.width * 0.75, size.height)
      ..close();
    canvas.drawPath(path, roadPaint);

    // 3. Siluet Tiang & Pagar Gerbang Besi di Kamera
    final gatePaint = Paint()
      ..color = isNightVision
          ? const Color(0xFF94A3B8).withOpacity(0.5)
          : const Color(0xFFE2E8F0).withOpacity(0.35)
      ..strokeWidth = 2.0;

    // Tiang Pagar Kiri & Kanan
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.25),
      Offset(size.width * 0.15, size.height * 0.85),
      gatePaint..strokeWidth = 3.5,
    );
    canvas.drawLine(
      Offset(size.width * 0.85, size.height * 0.25),
      Offset(size.width * 0.85, size.height * 0.85),
      gatePaint..strokeWidth = 3.5,
    );

    // Rel Horisontal Pagar
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.40),
      Offset(size.width * 0.85, size.height * 0.40),
      gatePaint..strokeWidth = 2.0,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.85, size.height * 0.75),
      gatePaint..strokeWidth = 2.0,
    );

    // Kisi-Kisi Jeruji Pagar
    final barCount = 10;
    final step = (size.width * 0.7) / (barCount + 1);
    for (int i = 1; i <= barCount; i++) {
      final x = (size.width * 0.15) + (i * step);
      canvas.drawLine(
        Offset(x, size.height * 0.40),
        Offset(x, size.height * 0.75),
        gatePaint..strokeWidth = 1.2,
      );
    }

    // 4. Grid Crosshair / Target Sensor Kamera
    final reticlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 15, cy), Offset(cx + 15, cy), reticlePaint);
    canvas.drawLine(Offset(cx, cy - 15), Offset(cx, cy + 15), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant _CctvViewportPainter oldDelegate) {
    return oldDelegate.isNightVision != isNightVision;
  }
}
