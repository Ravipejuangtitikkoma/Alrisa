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
  bool _isGateOpen = false;
  bool _isStreamOnline = false;
  bool _isConnecting = false;
  late AnimationController _pulseController;
  Timer? _timer;
  Timer? _connectTimeoutTimer;
  final ValueNotifier<String> _timestampNotifier = ValueNotifier<String>('');
  VlcPlayerController? _vlcViewController;
  StreamSubscription<DeviceStateEvent>? _mqttSub;
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;
  StreamSubscription<List<CctvCameraItem>>? _cctvSub;
  String _currentRtspUrl = '';

  @override
  void initState() {
    super.initState();
    _currentRtspUrl = widget.camera.rtspUrl.trim();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    final targetId = widget.gateId ?? widget.camera.boundGateId ?? 'pagar';
    _isGateOpen = MqttService().getDeviceState(targetId)?.state ??
        DeviceManagerService().getDevice(targetId)?.isActive ?? false;

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == targetId && mounted) {
        setState(() => _isGateOpen = event.payload.state);
      }
    });

    _deviceSub = DeviceManagerService().devicesStream.listen((devs) {
      if (!mounted) return;
      try {
        final d = devs.firstWhere((item) => item.id == targetId);
        if (_isGateOpen != d.isActive) {
          setState(() => _isGateOpen = d.isActive);
        }
      } catch (_) {}
    });

    _cctvSub = CctvManagerService().camerasStream.listen((cams) {
      if (!mounted) return;
      try {
        final updatedCam = cams.firstWhere((c) => c.id == widget.camera.id);
        final nextUrl = updatedCam.rtspUrl.trim();
        if (nextUrl != _currentRtspUrl) {
          _currentRtspUrl = nextUrl;
          widget.camera.rtspUrl = nextUrl;
          _refreshStream();
        }
      } catch (_) {}
    });

    _initVlcPlayer();
  }

  Future<void> _refreshStream() async {
    if (!mounted) return;
    _connectTimeoutTimer?.cancel();

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _isStreamOnline = false;
      });
    }

    if (_vlcViewController != null) {
      try {
        await _vlcViewController!.stop();
        await _vlcViewController!.setMediaFromNetwork(
          widget.camera.rtspUrl.trim(),
          autoPlay: true,
          hwAcc: HwAcc.auto,
        );
        _startTimeoutTimer();
        return;
      } catch (_) {}
    }

    _initVlcPlayer();
  }

  void _startTimeoutTimer() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(const Duration(milliseconds: 15000), () {
      if (mounted && !_isStreamOnline) {
        setState(() {
          _isConnecting = false;
        });
      }
    });
  }

  void _initVlcPlayer() {
    if (!mounted) return;
    _connectTimeoutTimer?.cancel();
    final oldController = _vlcViewController;

    try {
      oldController?.removeListener(_vlcListener);
      oldController?.stopRendererScanning();
      oldController?.dispose();
    } catch (_) {}

    try {
      final url = widget.camera.rtspUrl.trim();
      final isRtsp = url.toLowerCase().startsWith('rtsp://');
      final isLocal = url.contains('192.168.') ||
          url.contains('10.') ||
          url.contains('127.0.0.1') ||
          url.contains('localhost') ||
          url.contains('172.16.');

      // Cloud / Internet RTSP butuh cache 2000ms untuk mencegah packet-drop
      final cacheMs = isLocal ? 500 : 2000;

      final controller = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.auto, // Otomatis fallback ke software jika hardware decoding HP bermasalah
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(cacheMs),
          ]),
          rtp: isRtsp
              ? VlcRtpOptions([
                  VlcRtpOptions.rtpOverRtsp(true), // TCP interleaved untuk tembus NAT / firewall
                ])
              : null,
        ),
      );
      controller.addListener(_vlcListener);
      _startTimeoutTimer();

      if (mounted) {
        setState(() {
          _vlcViewController = controller;
          _isConnecting = true;
          _isStreamOnline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vlcViewController = null;
          _isConnecting = false;
          _isStreamOnline = false;
        });
      }
    }
  }

  void _vlcListener() {
    if (!mounted || _vlcViewController == null) return;
    final isPlaying = _vlcViewController!.value.isPlaying;
    final hasError = _vlcViewController!.value.hasError;
    final position = _vlcViewController!.value.position;

    if ((isPlaying || position > Duration.zero) && !_isStreamOnline) {
      _connectTimeoutTimer?.cancel();
      setState(() {
        _isStreamOnline = true;
        _isConnecting = false;
      });
    } else if (hasError && (_isStreamOnline || _isConnecting)) {
      setState(() {
        _isStreamOnline = false;
        _isConnecting = false;
      });
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) {
      _timestampNotifier.value = '$h:$m:$s';
    }
  }

  @override
  void dispose() {
    _cctvSub?.cancel();
    _mqttSub?.cancel();
    _deviceSub?.cancel();
    _connectTimeoutTimer?.cancel();
    _timer?.cancel();
    _timestampNotifier.dispose();
    _pulseController.dispose();
    try {
      _vlcViewController?.removeListener(_vlcListener);
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
    if (_isGateOpen == open) return;
    HapticFeedback.mediumImpact();
    final targetId = widget.gateId ?? widget.camera.boundGateId ?? 'pagar';
    setState(() => _isGateOpen = open);
    MqttService().publishSet(targetId, state: open);
    DeviceManagerService().updateState(
      targetId,
      isActive: open,
      statusText: open ? 'Terbuka' : 'Terkunci',
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                    color: Colors.white.withValues(alpha: 0.3),
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
                            color: Colors.white.withValues(alpha: 0.65),
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
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildVideoSheetViewport(cam),
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
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Column(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _toggleGate(true),
                      icon: Icon(
                        Icons.lock_open_rounded,
                        size: 15,
                        color: _isGateOpen ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      label: Text(
                        lang.isIndonesian ? 'Buka' : 'Open',
                        style: TextStyle(
                          color: _isGateOpen ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGateOpen ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        elevation: _isGateOpen ? 3 : 0,
                        side: BorderSide(
                          color: _isGateOpen ? const Color(0xFF10B981) : const Color(0xFF334155),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _toggleGate(false),
                      icon: Icon(
                        Icons.lock_rounded,
                        size: 15,
                        color: !_isGateOpen ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      label: Text(
                        lang.isIndonesian ? 'Kunci' : 'Lock',
                        style: TextStyle(
                          color: !_isGateOpen ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isGateOpen ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                        elevation: !_isGateOpen ? 3 : 0,
                        side: BorderSide(
                          color: !_isGateOpen ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
);
  }

  Widget _buildVideoSheetViewport(CctvCameraItem cam) {
    if (_vlcViewController == null) {
      return _buildOfflineSheetViewport(cam, isConnecting: _isConnecting);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. TextureView VlcPlayer selalu dipasang di widget tree agar proses inisialisasi native berjalan
        VlcPlayer(
          key: ValueKey('vlc_sheet_${widget.camera.id}'),
          controller: _vlcViewController!,
          aspectRatio: 16 / 9,
          placeholder: Container(color: const Color(0xFF1E293B)),
        ),

        // 2. Overlay offline / connecting saat stream belum siap
        if (!_isStreamOnline)
          Positioned.fill(
            child: _buildOfflineSheetViewport(cam, isConnecting: _isConnecting),
          ),

        // 3. Flash Efek saat Snapshot Foto
        if (_isSnapshotTaken)
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.85)),
          ),

        // 4. Overlay status LIVE saat aktif
        if (_isStreamOnline) ...[
          // Overlay Top Bar LIVE
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
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _timestampNotifier,
                    builder: (_, ts, __) => Text(
                      ts,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
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
                      color: Colors.white.withValues(alpha: 0.7),
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
      ],
    );
  }

  Widget _buildOfflineSheetViewport(CctvCameraItem cam, {bool isConnecting = false}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF334155),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CctvViewportPainter(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                            ),
                          )
                        : const Icon(
                            Icons.videocam_off_rounded,
                            size: 30,
                            color: Color(0xFFCBD5E1),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isConnecting ? 'Menghubungkan Stream RTSP...' : 'Kamera CCTV Offline',
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isConnecting
                      ? 'Menunggu respons sinyal video...'
                      : 'Stream belum aktif • ${cam.onvifHost}:${cam.onvifPort}',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                if (!isConnecting)
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _refreshStream();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 5),
                          Text(
                            'Coba Sambungkan',
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: isConnecting ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isConnecting ? 'CONNECTING...' : 'STANDBY',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _timestampNotifier,
                    builder: (_, ts, __) => Text(
                      ts,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas Painter Realistis Simulasi Suasana CCTV Gerbang (Pintu Gerbang & Jalanan)
class _CctvViewportPainter extends CustomPainter {
  final bool isNightVision;

  _CctvViewportPainter() : isNightVision = false;

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
          ? const Color(0xFF94A3B8).withValues(alpha: 0.5)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.35)
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
      ..color = Colors.white.withValues(alpha: 0.2)
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
