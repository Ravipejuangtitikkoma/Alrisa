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
  bool _isStreamOnline = false;
  bool _isConnecting = false;
  late AnimationController _pulseController;
  Timer? _timer;
  Timer? _connectTimeoutTimer;
  String _timestamp = '';
  VlcPlayerController? _vlcViewController;
  String? _selectedGateId;
  StreamSubscription<void>? _refreshSub;
  StreamSubscription<DeviceStateEvent>? _mqttSub;
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

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
    final initialGateState = MqttService().getDeviceState(_selectedGateId!)?.state ??
        DeviceManagerService().getDevice(_selectedGateId!)?.isActive ?? false;
    _isGateOpen = initialGateState;

    _initVlcPlayer();

    // Dengarkan perubahan status gerbang secara realtime dari MqttService
    _mqttSub = MqttService().stateStream.listen((event) {
      final activeGateId = _selectedGateId ?? widget.camera.boundGateId ?? 'pagar';
      if (event.deviceId == activeGateId && mounted) {
        setState(() {
          _isGateOpen = event.payload.state;
        });
      }
    });

    // Dengarkan perubahan status gerbang secara realtime dari DeviceManagerService
    _deviceSub = DeviceManagerService().devicesStream.listen((devs) {
      final activeGateId = _selectedGateId ?? widget.camera.boundGateId ?? 'pagar';
      try {
        final dev = devs.firstWhere((item) => item.id == activeGateId);
        if (mounted && _isGateOpen != dev.isActive) {
          setState(() {
            _isGateOpen = dev.isActive;
          });
        }
      } catch (_) {}
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
    _connectTimeoutTimer?.cancel();

    // Lepas controller lama dari widget tree terlebih dahulu untuk mencegah duplikasi texture Android
    final oldController = _vlcViewController;
    _vlcViewController = null;
    if (mounted) {
      setState(() {
        _isConnecting = true;
        _isStreamOnline = false;
      });
    }

    try {
      oldController?.removeListener(_vlcListener);
      oldController?.stopRendererScanning();
      oldController?.dispose();
    } catch (_) {}

    try {
      final controller = VlcPlayerController.network(
        widget.camera.rtspUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(150), // Ultra low-latency 150ms
          ]),
          rtp: VlcRtpOptions([
            VlcRtpOptions.rtpOverRtsp(true),
          ]),
        ),
      );

      _vlcViewController = controller;
      controller.addListener(_vlcListener);

      // Batas waktu timeout 3.5 detik untuk deteksi offline jika stream RTSP tidak merespons
      _connectTimeoutTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted && !_isStreamOnline) {
          setState(() {
            _isConnecting = false;
          });
        }
      });

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
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

    if (isPlaying && !_isStreamOnline) {
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
      setState(() {
        _timestamp = '$h:$m:$s';
      });
    }
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _connectTimeoutTimer?.cancel();
    _refreshSub?.cancel();
    _mqttSub?.cancel();
    _timer?.cancel();
    _pulseController.dispose();
    try {
      _vlcViewController?.removeListener(_vlcListener);
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

  Future<void> _setGate(bool open) async {
    if (_isGateOpen == open) return;
    HapticFeedback.heavyImpact();
    final gateId = _selectedGateId ?? widget.camera.boundGateId ?? 'pagar';

    // Langsung update state lokal agar responsif seketika tanpa delay
    setState(() {
      _isGateOpen = open;
    });

    // Kirim sinyal MQTT ke ESP8266 / PLC & sync DeviceManager
    MqttService().publishSet(gateId, state: open);
    DeviceManagerService().updateState(
      gateId,
      isActive: open,
      statusText: open ? 'Terbuka' : 'Terkunci',
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
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Card CCTV: Judul, Lokasi, Tombol Edit Config, & Status Stream
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

                // Badge Indikator Status Kamera (REC LIVE / CONNECTING / OFFLINE)
                _buildStreamStatusBadge(),
              ],
            ),

            const SizedBox(height: 10),

            // 2. Layar Live Stream Viewport (Rasio Aspek 16:9)
            GestureDetector(
              onTap: _openFullScreen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: (_isStreamOnline && _vlcViewController != null)
                      ? _buildLiveViewport(cam)
                      : _buildOfflineViewport(cam, isConnecting: _isConnecting),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Toolbar Ringkas: Tombol Snapshot & Kontrol Buka/Kunci Gerbang
            Row(
              children: [
                // ── Tombol Snapshot Foto ──
                OutlinedButton.icon(
                  onPressed: _isStreamOnline ? _takeSnapshot : null,
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
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
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
                                final gateState = MqttService().getDeviceState(val)?.state ??
                                    DeviceManagerService().getDevice(val)?.isActive ?? false;
                                setState(() {
                                  _selectedGateId = val;
                                  _isGateOpen = gateState;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                             // ── Tombol Buka / Kunci Gerbang ──
                Container(
                  height: 36,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol BUKA
                      InkWell(
                        onTap: () => _setGate(true),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isGateOpen ? const Color(0xFF059669) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isGateOpen
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF059669).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_open_rounded,
                                size: 12.5,
                                color: _isGateOpen ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                lang.isIndonesian ? 'Buka' : 'Open',
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isGateOpen ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tombol KUNCI
                      InkWell(
                        onTap: () => _setGate(false),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_isGateOpen ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isGateOpen
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 12.5,
                                color: !_isGateOpen ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                lang.isIndonesian ? 'Kunci' : 'Lock',
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: !_isGateOpen ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Badge Indikator Status Header: Hijau/Merah REC LIVE jika aktif, Kuning jika memuat, Abu jika offline
  Widget _buildStreamStatusBadge() {
    if (_isStreamOnline) {
      return Container(
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
      );
    } else if (_isConnecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 7,
              height: 7,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(Color(0xFFD97706)),
              ),
            ),
            SizedBox(width: 4),
            Text(
              'MEMUAT',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.videocam_off_rounded, size: 10, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              'OFFLINE',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Viewport saat kamera online & aktif memutar video RTSP
  Widget _buildLiveViewport(CctvCameraItem cam) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VlcPlayer(
          controller: _vlcViewController!,
          aspectRatio: 16 / 9,
          placeholder: _buildOfflineViewport(cam, isConnecting: true),
        ),

        // Efek Flash Shutter saat Snapshot diambil
        if (_isSnapshotTaken)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _isSnapshotTaken ? 0.8 : 0.0,
            child: Container(color: Colors.white),
          ),

        // Overlay Atas: Resolusi & Jam Detik
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

        // Overlay Bawah: Badge Info Protokol RTSP & IP
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
    );
  }

  /// Viewport saat kamera CCTV OFF / belum aktif: Latar abu-abu gelap slate + Ikon CCTV dicoret di tengah
  Widget _buildOfflineViewport(CctvCameraItem cam, {bool isConnecting = false}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF334155), // Slate 700 Elegant Grey
            Color(0xFF1E293B), // Slate 800 Dark Grey
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background garis grid pengawas teknikal
          CustomPaint(
            painter: _CctvGridBackgroundPainter(),
          ),

          // Konten Tengah: Ikon Kamera CCTV Dicoret + Status Teks Elegan
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lingkaran Frosted Glass dengan Ikon CCTV Dicoret
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                            ),
                          )
                        : const Icon(
                            Icons.videocam_off_rounded,
                            size: 26,
                            color: Color(0xFFCBD5E1),
                          ),
                  ),
                ),
                const SizedBox(height: 7),

                // Judul Status Kamera
                Text(
                  isConnecting ? 'Menghubungkan RTSP...' : 'Kamera CCTV Offline',
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),

                // Subtitle Alamat RTSP
                Text(
                  isConnecting
                      ? 'Menunggu sinyal video...'
                      : 'Stream belum aktif • ${cam.onvifHost}:${cam.onvifPort}',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8).withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 6),

                // Tombol Coba Sambungkan jika tidak sedang connecting
                if (!isConnecting)
                  InkWell(
                    onTap: _manualRefresh,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 11, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            'Coba Sambungkan',
                            style: TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 9.5,
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

          // Overlay Atas: Badge Status STANDBY / CONNECTING + Jam Detik Realtime
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
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: isConnecting ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnecting ? 'CONNECTING...' : 'STANDBY',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4),
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

          // Tombol Expand Fullscreen di Pojok Kanan Bawah Viewport
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas Painter grid monitor teknikal berlatar abu-abu untuk kamera CCTV offline
class _CctvGridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

