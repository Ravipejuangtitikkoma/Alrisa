import 'dart:async';

class CctvCameraItem {
  final String id;
  String name;
  String location;
  String rtspUrl;
  String onvifHost;
  int onvifPort;
  String? boundGateId; // Terhubung ke gerbang mana, misal: 'pagar'
  bool isOnline;
  double fps;
  String resolution;

  CctvCameraItem({
    required this.id,
    required this.name,
    required this.location,
    required this.rtspUrl,
    this.onvifHost = '192.168.1.50',
    this.onvifPort = 80,
    this.boundGateId,
    this.isOnline = true,
    this.fps = 25.0,
    this.resolution = '1080P FHD (H.264)',
  });
}

class CctvManagerService {
  static final CctvManagerService _instance = CctvManagerService._internal();
  factory CctvManagerService() => _instance;
  CctvManagerService._internal() {
    _initDefaults();
  }

  final StreamController<List<CctvCameraItem>> _cctvController =
      StreamController<List<CctvCameraItem>>.broadcast();
  Stream<List<CctvCameraItem>> get camerasStream => _cctvController.stream;

  final StreamController<void> _refreshController =
      StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  void triggerRefresh() {
    _refreshController.add(null);
  }

  final List<CctvCameraItem> _cameras = [];
  List<CctvCameraItem> get allCameras => List.unmodifiable(_cameras);

  void _initDefaults() {
    if (_cameras.isNotEmpty) return;

    _cameras.addAll([
      CctvCameraItem(
        id: 'cctv_gerbang_depan',
        name: 'CCTV Gerbang Utama',
        location: 'Pagar Depan & Jalan',
        rtspUrl: 'rtsp://192.168.0.104:8554/',
        onvifHost: '192.168.0.104',
        onvifPort: 8554,
        boundGateId: 'pagar',
        isOnline: true,
        fps: 30.0,
        resolution: '1080P FHD (H.264)',
      ),
      CctvCameraItem(
        id: 'cctv_gerbang_belakang',
        name: 'CCTV Gerbang Belakang',
        location: 'Area Servis & Garasi',
        rtspUrl: 'rtsp://admin:123456@192.168.1.102:554/live/ch0',
        onvifHost: '192.168.1.102',
        onvifPort: 80,
        boundGateId: 'pagar_belakang',
        isOnline: true,
        fps: 25.0,
        resolution: '1080P FHD • 25 FPS',
      ),
      CctvCameraItem(
        id: 'cctv_halaman_dalam',
        name: 'CCTV Halaman Samping',
        location: 'Taman Samping & Teras',
        rtspUrl: 'rtsp://admin:123456@192.168.1.103:554/live/ch0',
        onvifHost: '192.168.1.103',
        onvifPort: 80,
        boundGateId: null,
        isOnline: true,
        fps: 20.0,
        resolution: '720P HD • 20 FPS',
      ),
    ]);
  }

  CctvCameraItem? getCameraForGate(String gateId) {
    try {
      return _cameras.firstWhere(
        (cam) => cam.boundGateId == gateId,
        orElse: () => _cameras.first,
      );
    } catch (_) {
      return null;
    }
  }

  void updateCamera(String id, {
    String? name,
    String? location,
    String? rtspUrl,
    String? onvifHost,
    int? onvifPort,
    String? boundGateId,
    String? resolution,
  }) {
    final idx = _cameras.indexWhere((c) => c.id == id);
    if (idx != -1) {
      if (name != null) _cameras[idx].name = name;
      if (location != null) _cameras[idx].location = location;
      if (rtspUrl != null) _cameras[idx].rtspUrl = rtspUrl;
      if (onvifHost != null) _cameras[idx].onvifHost = onvifHost;
      if (onvifPort != null) _cameras[idx].onvifPort = onvifPort;
      if (boundGateId != null) _cameras[idx].boundGateId = boundGateId;
      if (resolution != null) _cameras[idx].resolution = resolution;
      _cctvController.add(List.unmodifiable(_cameras));
    }
  }

  void addCamera({
    required String name,
    required String location,
    required String rtspUrl,
    String? onvifHost,
    int? onvifPort,
    String? boundGateId,
  }) {
    final newId = 'cctv_${DateTime.now().millisecondsSinceEpoch}';
    final newCam = CctvCameraItem(
      id: newId,
      name: name.trim().isNotEmpty ? name.trim() : 'Kamera CCTV Baru',
      location: location.trim().isNotEmpty ? location.trim() : 'Rumah',
      rtspUrl: rtspUrl.trim().isNotEmpty
          ? rtspUrl.trim()
          : 'rtsp://admin:123456@192.168.1.50:554/live/ch0',
      onvifHost: onvifHost?.trim() ?? '192.168.1.50',
      onvifPort: onvifPort ?? 80,
      boundGateId: boundGateId,
      isOnline: true,
    );
    _cameras.add(newCam);
    _cctvController.add(List.unmodifiable(_cameras));
  }

  void removeCamera(String id) {
    _cameras.removeWhere((c) => c.id == id);
    _cctvController.add(List.unmodifiable(_cameras));
  }
}
