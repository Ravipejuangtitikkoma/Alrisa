import 'dart:async';
import 'package:nexora/services/auth_service.dart';

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

  String get hostDisplay {
    try {
      final uri = Uri.parse(rtspUrl);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return onvifHost.isNotEmpty ? onvifHost : 'RTSP Host';
  }

  int get portDisplay {
    try {
      final uri = Uri.parse(rtspUrl);
      if (uri.hasPort && uri.port != 0) return uri.port;
    } catch (_) {}
    return onvifPort != 0 ? onvifPort : 554;
  }
}

class CctvManagerService {
  static final CctvManagerService _instance = CctvManagerService._internal();
  factory CctvManagerService() => _instance;
  CctvManagerService._internal() {
    _initDefaults();
    // Dengarkan perubahan login untuk otomatis ganti data kamera per akun
    AuthService().authStream.listen((user) {
      final userKey = user?.email.toLowerCase() ?? 'default';
      loadUserCameras(userKey);
    });
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

  // Database Kamera per Akun (Key = email akun)
  final Map<String, List<CctvCameraItem>> _userCamerasDb = {};
  String _activeUserKey = 'default';

  final List<CctvCameraItem> _cameras = [];
  List<CctvCameraItem> get allCameras => List.unmodifiable(_cameras);

  void _initDefaults() {
    // 1. Data Default untuk Super Admin Ravi
    final raviCameras = [
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
        boundGateId: 'pagar',
        isOnline: true,
        fps: 25.0,
        resolution: '720P HD • 25 FPS',
      ),
    ];
    _userCamerasDb['raviarmanza149@gmail.com'] = raviCameras;

    // 2. Data Kamera untuk Akun User Biasa (Keluarga)
    _userCamerasDb['user@nexora.id'] = [
      CctvCameraItem(
        id: 'cctv_keluarga_depan',
        name: 'CCTV Pintu Masuk',
        location: 'Teras Utama',
        rtspUrl: 'rtsp://192.168.0.104:8554/',
        onvifHost: '192.168.0.104',
        onvifPort: 8554,
        boundGateId: 'pagar',
        isOnline: true,
        fps: 25.0,
        resolution: '1080P FHD',
      ),
    ];

    // Aktifkan kamera sesuai user aktif saat ini
    final currentEmail = AuthService().currentUser?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    loadUserCameras(currentEmail);
  }

  /// Ganti dataset kamera saat berpindah akun
  void loadUserCameras(String userKey) {
    _activeUserKey = userKey;
    if (!_userCamerasDb.containsKey(_activeUserKey)) {
      // Jika akun baru mendaftar, beri 1 kamera bawaan awal yang bisa ditambah/diedit
      _userCamerasDb[_activeUserKey] = [
        CctvCameraItem(
          id: 'cctv_user_utama',
          name: 'CCTV Gerbang Rumah',
          location: 'Depan Rumah',
          rtspUrl: 'rtsp://192.168.0.104:8554/',
          onvifHost: '192.168.0.104',
          onvifPort: 8554,
          boundGateId: 'pagar',
          isOnline: true,
          fps: 25.0,
          resolution: '1080P FHD',
        ),
      ];
    }

    _cameras.clear();
    _cameras.addAll(_userCamerasDb[_activeUserKey]!);
    _notify();
  }

  void _notify() {
    // Pastikan data aktif tersimpan di database user tersebut
    _userCamerasDb[_activeUserKey] = List.from(_cameras);
    _cctvController.add(List.unmodifiable(_cameras));
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
      if (rtspUrl != null) {
        _cameras[idx].rtspUrl = rtspUrl.trim();
        try {
          final uri = Uri.parse(rtspUrl.trim());
          if (uri.host.isNotEmpty && (onvifHost == null || onvifHost.trim().isEmpty)) {
            _cameras[idx].onvifHost = uri.host;
          }
          if (uri.hasPort && uri.port != 0 && onvifPort == null) {
            _cameras[idx].onvifPort = uri.port;
          }
        } catch (_) {}
      }
      if (onvifHost != null) _cameras[idx].onvifHost = onvifHost.trim();
      if (onvifPort != null) _cameras[idx].onvifPort = onvifPort;
      if (boundGateId != null) _cameras[idx].boundGateId = boundGateId;
      if (resolution != null) _cameras[idx].resolution = resolution;
      _notify();
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
    final cleanUrl = rtspUrl.trim().isNotEmpty
        ? rtspUrl.trim()
        : 'rtsp://admin:123456@192.168.1.50:554/live/ch0';
    String derivedHost = onvifHost?.trim() ?? '';
    int derivedPort = onvifPort ?? 554;
    try {
      final uri = Uri.parse(cleanUrl);
      if (derivedHost.isEmpty && uri.host.isNotEmpty) {
        derivedHost = uri.host;
      }
      if (uri.hasPort && uri.port != 0 && onvifPort == null) {
        derivedPort = uri.port;
      }
    } catch (_) {}
    if (derivedHost.isEmpty) derivedHost = '192.168.1.50';

    final newId = 'cctv_${DateTime.now().millisecondsSinceEpoch}';
    final newCam = CctvCameraItem(
      id: newId,
      name: name.trim().isNotEmpty ? name.trim() : 'Kamera CCTV Baru',
      location: location.trim().isNotEmpty ? location.trim() : 'Rumah',
      rtspUrl: cleanUrl,
      onvifHost: derivedHost,
      onvifPort: derivedPort,
      boundGateId: boundGateId,
      isOnline: true,
    );
    _cameras.add(newCam);
    _notify();
  }

  void removeCamera(String id) {
    _cameras.removeWhere((c) => c.id == id);
    _notify();
  }
}
