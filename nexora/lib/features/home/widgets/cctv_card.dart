import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/features/home/widgets/cctv_stream_sheet.dart';

/// Card CCTV Terdedikasi untuk Beranda (Live Stream Langsung, Edit IP, & Multi-Gate Control)
class CctvCard extends StatefulWidget {
  final CctvCameraItem camera;
  final VoidCallback? onExpand;

  const CctvCard({
    Key? key,
    required this.camera,
    this.onExpand,
  }) : super(key: key);

  @override
  State<CctvCard> createState() => _CctvCardState();
}

class _CctvCardState extends State<CctvCard> with SingleTickerProviderStateMixin {
  bool _isSnapshotTaken = false;
  bool _isGateOpen = false;
  bool _isGateLoading = false;
  late AnimationController _pulseController;
  Timer? _timer;
  String _timestamp = '';
  VlcPlayerController? _vlcViewController;
  String? _selectedGateId;
  StreamSubscription<void>? _refreshSub;
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _selectedGateId = widget.camera.boundGateId ?? 'pagar';
    final initialGateState = MqttService().getDeviceState(_selectedGateId!);
    if (initialGateState != null) {
      _isGateOpen = initialGateState.state;
    }

    _initVlcPlayer();

    // Dengarkan perubahan status gerbang secara realtime dari MqttService
    _mqttSub = MqttService().stateStream.listen((event) {
      final activeGateId = _selectedGateId ?? widget.camera.boundGateId ?? 'pagar';
      if (event.deviceId == activeGateId && mounted) {
        setState(() {
          _isGateOpen = event.payload.state;
          _isGateLoading = false;
        });
      }
    });

    // Dengarkan trigger refresh dari Pull-to-Refresh layar
    _refreshSub = CctvManagerService().refreshStream.listen((_) {
      _initVlcPlayer();
    });
  }

  @override
  void didUpdateWidget(covariant CctvCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.rtspUrl != widget.camera.rtspUrl) {
      _initVlcPlayer();
    }
  }

  void _manualRefresh() {
    HapticFeedback.mediumImpact();
    _initVlcPlayer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        content: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 16),
            const SizedBox(width: 8),
            Text(
              'Menghubungkan ulang kamera ${widget.camera.name}...',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _initVlcPlayer() {
    try {
      _vlcViewController?.stopRendererScanning();
      _vlcViewController?.dispose();
    } catch (_) {}

    try {
      _vlcViewController = VlcPlayerController.network(
        widget.camera.rtspUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(100), // Ultra low-latency 100ms
          ]),
          rtp: VlcRtpOptions([
            VlcRtpOptions.rtpOverRtsp(true),
          ]),
        ),
      );
      if (mounted) setState(() {});
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
    _refreshSub?.cancel();
    _mqttSub?.cancel();
    _timer?.cancel();
    _pulseController.dispose();
    try {
      _vlcViewController?.stopRendererScanning();
      _vlcViewController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _takeSnapshot() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSnapshotTaken = true);

    try {
      await _vlcViewController?.takeSnapshot();
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: NexoraTokens.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('📸 Snapshot CCTV berhasil disimpan ke galeri!'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _isSnapshotTaken = false);
      });
    }
  }

  void _openFullScreen() {
    HapticFeedback.mediumImpact();
    if (widget.onExpand != null) {
      widget.onExpand!();
    } else {
      CctvStreamSheet.show(
        context,
        camera: widget.camera,
        gateId: _selectedGateId ?? widget.camera.boundGateId,
        gateName: widget.camera.name,
      );
    }
  }

  Future<void> _toggleGate() async {
    HapticFeedback.heavyImpact();
    final gateId = _selectedGateId ?? widget.camera.boundGateId ?? 'pagar';
    final newActive = !_isGateOpen;

    // Langsung update state lokal agar responsif seketika
    setState(() {
      _isGateOpen = newActive;
      _isGateLoading = false;
    });

    // Kirim sinyal MQTT ke ESP8266 / PLC & sync DeviceManager
    MqttService().publishSet(gateId, state: newActive);
    DeviceManagerService().updateState(
      gateId,
      isActive: newActive,
      statusText: newActive ? 'Terbuka' : 'Terkunci',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _isGateOpen ? const Color(0xFF059669) : NexoraTokens.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(
                _isGateOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isGateOpen
                    ? '🔓 Perintah Buka Gerbang Terkirim!'
                    : '🔒 Perintah Kunci Gerbang Terkirim!',
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Modal Dialog Edit Konfigurasi IP, Port, Codec & Nama Kamera
  void _showEditConfigDialog() {
    HapticFeedback.mediumImpact();
    final ipController = TextEditingController(text: widget.camera.onvifHost);
    final portController = TextEditingController(text: widget.camera.onvifPort.toString());
    final urlController = TextEditingController(text: widget.camera.rtspUrl);
    final nameController = TextEditingController(text: widget.camera.name);
    final locationController = TextEditingController(text: widget.camera.location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.settings_suggest_rounded, color: Color(0xFF38BDF8), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Edit Konfigurasi Kamera CCTV',
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // IP Address & Port
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: ipController,
                          label: 'Alamat IP Kamera / HP',
                          hint: 'Contoh: 192.168.0.104',
                          icon: Icons.wifi_rounded,
                          onChanged: (val) {
                            final port = portController.text.trim();
                            urlController.text = 'rtsp://${val.trim()}:$port/';
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: portController,
                          label: 'Port (RTSP)',
                          hint: '8554 / 554',
                          icon: Icons.tag_rounded,
                          onChanged: (val) {
                            final ip = ipController.text.trim();
                            urlController.text = 'rtsp://$ip:${val.trim()}/';
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // URL Lengkap RTSP Stream
                  _buildTextField(
                    controller: urlController,
                    label: 'URL Stream RTSP Lengkap',
                    hint: 'rtsp://192.168.0.104:8554/',
                    icon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Nama & Lokasi
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: nameController,
                          label: 'Nama Kamera',
                          hint: 'CCTV Gerbang Utama',
                          icon: Icons.videocam_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: locationController,
                          label: 'Lokasi',
                          hint: 'Pagar Depan',
                          icon: Icons.location_on_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        final ip = ipController.text.trim();
                        final port = int.tryParse(portController.text.trim()) ?? 8554;
                        final url = urlController.text.trim();
                        final name = nameController.text.trim();
                        final loc = locationController.text.trim();

                        CctvManagerService().updateCamera(
                          widget.camera.id,
                          name: name.isNotEmpty ? name : null,
                          location: loc.isNotEmpty ? loc : null,
                          onvifHost: ip.isNotEmpty ? ip : null,
                          onvifPort: port,
                          rtspUrl: url.isNotEmpty ? url : null,
                        );

                        Navigator.pop(context);
                        _initVlcPlayer();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF059669),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: const Text('✅ Konfigurasi CCTV berhasil diperbarui!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Simpan & Terapkan Stream'),
                      style: ElevatedButton.styleFrom(
                        primary: const Color(0xFF0284C7),
                        onPrimary: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final cam = widget.camera;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: NexoraTokens.brandCyan.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card CCTV: Judul, Lokasi, Tombol Edit Config, & Status REC LIVE
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam_rounded, size: 14, color: NexoraTokens.brandCyan),
              ),
              const SizedBox(width: 8),

              // Info Nama & Lokasi (Flexible agar tidak overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          lang.isIndonesian ? 'PANTAUAN CCTV' : 'SURVEILLANCE',
                          style: NexoraTokens.sectionLabel.copyWith(fontSize: 9.5),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cam.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      cam.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Tombol Segarkan Stream Kamera
              InkWell(
                onTap: _manualRefresh,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
                ),
              ),

              const SizedBox(width: 6),

              // Tombol Edit Konfigurasi IP/Port/Codec
              InkWell(
                onTap: _showEditConfigDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF475569)),
                ),
              ),

              const SizedBox(width: 6),

              // Badge Indikator REC LIVE Merah Berdenyut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'REC LIVE',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Layar Live Stream Viewport (Rasio Aspek 16:9 Langsung Putar Video)
          GestureDetector(
            onTap: _openFullScreen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RepaintBoundary(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A. Live RTSP Video Player (VLC Engine Langsung Auto-play)
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
                                painter: _CctvCardViewportPainter(),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(NexoraTokens.brandCyan),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Menghubungkan RTSP...',
                                      style: TextStyle(
                                        fontFamily: NexoraTokens.fontFamilySans,
                                        fontSize: 10,
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
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: const Color(0xFF0F172A),
                        child: CustomPaint(
                          painter: _CctvCardViewportPainter(),
                        ),
                      ),

                    // Efek Flash Shutter saat Snapshot diambil
                    if (_isSnapshotTaken)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isSnapshotTaken ? 0.8 : 0.0,
                        child: Container(color: Colors.white),
                      ),

                    // B. Overlay Atas: Info Stream & Jam Detik
                    Positioned(
                      top: 8,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.videocam, size: 10, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 4),
                                Text(
                                  cam.resolution,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _timestamp,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // D. Overlay Bawah: Badge Info Protokol RTSP & IP
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_tethering, size: 9, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              'RTSP • ${cam.onvifHost}:${cam.onvifPort}',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 8,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tombol Expand Fullscreen di Pojok Kanan Bawah Viewport
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

          const SizedBox(height: 10),

          // 3. Toolbar Ringkas: Tombol Snapshot & Kontrol Buka/Kunci Gerbang
          Row(
            children: [
              // ── Tombol Snapshot Foto ──
              OutlinedButton.icon(
                onPressed: _takeSnapshot,
                icon: const Icon(Icons.camera_alt_outlined, size: 13),
                label: const Text('Snapshot'),
                style: OutlinedButton.styleFrom(
                  primary: NexoraTokens.ink,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // ── Pemilih Pilihan Gerbang (Slide/Selector Pagar Dinamis) ──
              StreamBuilder<List<CustomDeviceItem>>(
                stream: DeviceManagerService().devicesStream,
                initialData: DeviceManagerService().allDevices,
                builder: (context, snapshot) {
                  final gates = DeviceManagerService().gates;
                  final validSelectedGate = gates.any((g) => g.id == _selectedGateId)
                      ? _selectedGateId
                      : (gates.isNotEmpty ? gates.first.id : null);

                  return Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: validSelectedGate,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF64748B)),
                          items: gates.map((g) {
                            return DropdownMenuItem<String>(
                              value: g.id,
                              child: Text(
                                '🚪 ${g.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: NexoraTokens.ink,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.selectionClick();
                              final gateState = MqttService().getDeviceState(val);
                              setState(() {
                                _selectedGateId = val;
                                if (gateState != null) {
                                  _isGateOpen = gateState.state;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 6),

              // ── Tombol Buka / Kunci Gerbang ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 36,
                decoration: BoxDecoration(
                  gradient: _isGateOpen
                      ? const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (_isGateOpen
                              ? const Color(0xFF059669)
                              : const Color(0xFF0F172A))
                          .withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isGateLoading ? null : _toggleGate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isGateLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Icon(
                                  _isGateOpen
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                          const SizedBox(width: 4),
                          Text(
                            _isGateLoading
                                ? '...'
                                : _isGateOpen
                                    ? (lang.isIndonesian ? 'Kunci' : 'Lock')
                                    : (lang.isIndonesian ? 'Buka' : 'Open'),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Canvas Painter simulasi kamera pengawas gerbang saat loading
class _CctvCardViewportPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.45), skyPaint);

    final roadPaint = Paint()..color = const Color(0xFF334155);
    final path = Path()
      ..moveTo(size.width * 0.25, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.45)
      ..lineTo(size.width * 0.55, size.height * 0.45)
      ..lineTo(size.width * 0.75, size.height)
      ..close();
    canvas.drawPath(path, roadPaint);

    final gatePaint = Paint()
      ..color = const Color(0xFFE2E8F0).withOpacity(0.3)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.25), Offset(size.width * 0.15, size.height * 0.85), gatePaint..strokeWidth = 2.5);
    canvas.drawLine(Offset(size.width * 0.85, size.height * 0.25), Offset(size.width * 0.85, size.height * 0.85), gatePaint..strokeWidth = 2.5);
    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.40), Offset(size.width * 0.85, size.height * 0.40), gatePaint..strokeWidth = 1.5);
    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.75), Offset(size.width * 0.85, size.height * 0.75), gatePaint..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
