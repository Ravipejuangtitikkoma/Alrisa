import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'rtspUrl': rtspUrl,
    'onvifHost': onvifHost,
    'onvifPort': onvifPort,
    'boundGateId': boundGateId,
    'isOnline': isOnline,
    'fps': fps,
    'resolution': resolution,
  };

  factory CctvCameraItem.fromJson(Map<String, dynamic> map) {
    return CctvCameraItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      rtspUrl: map['rtspUrl'] ?? '',
      onvifHost: map['onvifHost'] ?? '192.168.1.50',
      onvifPort: map['onvifPort'] ?? 80,
      boundGateId: map['boundGateId'],
      isOnline: map['isOnline'] ?? true,
      fps: (map['fps'] ?? 25.0).toDouble(),
      resolution: map['resolution'] ?? '1080P FHD (H.264)',
    );
  }

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

  String _sanitizeUserKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  Future<File> _getUserCctvFile(String userKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeKey = _sanitizeUserKey(userKey);
    return File('${dir.path}/alrisa_cctv_$safeKey.json');
  }

  Future<void> _loadFromDisk(String userKey) async {
    try {
      final file = await _getUserCctvFile(userKey);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final dynamic decoded = json.decode(content);
          if (decoded is List) {
            final loaded = decoded
                .map((item) => CctvCameraItem.fromJson(Map<String, dynamic>.from(item)))
                .toList();
            if (loaded.isNotEmpty) {
              _userCamerasDb[userKey] = loaded;
              if (_activeUserKey == userKey) {
                _cameras.clear();
                _cameras.addAll(loaded);
                _cctvController.add(List.unmodifiable(_cameras));
              }
              return;
            }
          }
        }
      }
    } catch (_) {}

    if (_userCamerasDb.containsKey(userKey)) {
      await _saveToDisk(userKey);
    }
  }

  Future<void> _saveToDisk(String userKey) async {
    try {
      final listToSave = _userCamerasDb[userKey] ?? (_activeUserKey == userKey ? _cameras : null);
      if (listToSave == null) return;
      final file = await _getUserCctvFile(userKey);
      final jsonString = json.encode(listToSave.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  Future<void> restoreFromDisk([String? userKey]) async {
    final key = userKey ?? _activeUserKey;
    await _loadFromDisk(key);
  }

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

    // 2. Data Kamera untuk Akun Kantor Bos (Mitsubishi FX5U PLC)
    _userCamerasDb['bos@nexora.id'] = [
      CctvCameraItem(
        id: 'cctv_kantor_gerbang',
        name: 'Kamera Gerbang Utama Kantor',
        location: 'Pos Satpam Kantor',
        rtspUrl: 'rtsp://admin:bos2026@192.168.1.50:554/live',
        onvifHost: '192.168.1.50',
        onvifPort: 80,
        boundGateId: 'pagar_kantor',
        isOnline: true,
        fps: 25.0,
        resolution: '1080P FHD (H.264)',
      ),
      CctvCameraItem(
        id: 'cctv_kantor_lobby',
        name: 'Kamera Lobby & Resepsionis',
        location: 'Lobby Lantai 1',
        rtspUrl: 'rtsp://admin:bos2026@192.168.1.51:554/live',
        onvifHost: '192.168.1.51',
        onvifPort: 80,
        boundGateId: 'pintu_kantor',
        isOnline: true,
        fps: 25.0,
        resolution: '1080P FHD',
      ),
    ];

    // 3. Data Kamera untuk Akun Villa Bpk. Budi (Raspberry Pi 4)
    _userCamerasDb['villa.budi@nexora.id'] = [
      CctvCameraItem(
        id: 'cctv_villa_gate',
        name: 'Kamera Gerbang Villa',
        location: 'Pos Keamanan Villa',
        rtspUrl: 'rtsp://admin:villa2026@192.168.1.100:554/stream1',
        onvifHost: '192.168.1.100',
        onvifPort: 80,
        boundGateId: 'pagar_villa',
        isOnline: true,
        fps: 30.0,
        resolution: '4K Ultra-HD (H.265)',
      ),
      CctvCameraItem(
        id: 'cctv_villa_pool',
        name: 'Kamera Kolam Renang',
        location: 'Area Belakang Villa',
        rtspUrl: 'rtsp://admin:villa2026@192.168.1.101:554/stream1',
        onvifHost: '192.168.1.101',
        onvifPort: 80,
        boundGateId: 'pagar_villa',
        isOnline: true,
        fps: 25.0,
        resolution: '1080P FHD (H.264)',
      ),
    ];

    // 4. Data Kamera untuk Akun Ibu Maya (ESP32)
    _userCamerasDb['user@nexora.id'] = [
      CctvCameraItem(
        id: 'cctv_maya_carport',
        name: 'CCTV Carport Depan',
        location: 'Depan Garasi',
        rtspUrl: 'rtsp://user:maya123@192.168.1.200:554/live',
        onvifHost: '192.168.1.200',
        onvifPort: 80,
        boundGateId: 'pagar_maya',
        isOnline: true,
        fps: 20.0,
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
    _notify(saveDisk: false);

    // Muat konfigurasi CCTV kustom dari file disk lokal jika ada
    _loadFromDisk(_activeUserKey);
  }

  void _notify({bool saveDisk = false}) {
    // Pastikan data aktif tersimpan di database user tersebut
    _userCamerasDb[_activeUserKey] = List.from(_cameras);
    _cctvController.add(List.unmodifiable(_cameras));
    if (saveDisk) {
      _saveToDisk(_activeUserKey);
    }
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
      _notify(saveDisk: true);
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
    _notify(saveDisk: true);
  }

  void removeCamera(String id) {
    _cameras.removeWhere((c) => c.id == id);
    _notify(saveDisk: true);
  }
}
