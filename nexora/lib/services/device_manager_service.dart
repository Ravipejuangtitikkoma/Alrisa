import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:nexora/services/auth_service.dart';

enum DeviceType {
  gate,        // Pagar / Gerbang
  light,       // Lampu
  slidingDoor, // Pintu Geser
  curtain,     // Gorden
  waterPump,   // Pompa Air
}

class CustomDeviceItem {
  final String id;              // MQTT ID: misal 'pagar', 'pagar_belakang', 'lampu_taman'
  String name;                  // Nama kustom: misal 'Gerbang Utama', 'Gerbang Belakang'
  final DeviceType type;        // Tipe perangkat
  String hardwarePin;           // Pin ESP32 (GPIO) atau Alamat PLC (%QX0.0)
  bool isActive;
  double value;                 // Slider / level (0 - 100)
  String statusText;

  CustomDeviceItem({
    required this.id,
    required this.name,
    required this.type,
    this.hardwarePin = 'GPIO 2',
    this.isActive = false,
    this.value = 0.0,
    this.statusText = 'Terkunci',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.index,
    'hardwarePin': hardwarePin,
    'isActive': isActive,
    'value': value,
    'statusText': statusText,
  };

  factory CustomDeviceItem.fromJson(Map<String, dynamic> map) {
    return CustomDeviceItem(
      id: map['id'] ?? 'device',
      name: map['name'] ?? 'Perangkat',
      type: DeviceType.values[map['type'] ?? 0],
      hardwarePin: map['hardwarePin'] ?? 'GPIO 2',
      isActive: map['isActive'] ?? false,
      value: (map['value'] ?? 0.0).toDouble(),
      statusText: map['statusText'] ?? '',
    );
  }
}

/// Service Pengelola Daftar Perangkat Dinamis (Singleton dengan Persistensi Lokal)
class DeviceManagerService {
  static final DeviceManagerService _instance = DeviceManagerService._internal();
  factory DeviceManagerService() => _instance;
  DeviceManagerService._internal() {
    _initDefaults();
    // Dengarkan perubahan login untuk otomatis ganti data perangkat per akun
    AuthService().authStream.listen((user) {
      final userKey = user?.email.toLowerCase() ?? 'default';
      loadUserDevices(userKey);
    });
  }

  final StreamController<List<CustomDeviceItem>> _devicesController =
      StreamController<List<CustomDeviceItem>>.broadcast();
  Stream<List<CustomDeviceItem>> get devicesStream => _devicesController.stream;

  // Database Perangkat per Akun (Key = email akun)
  final Map<String, List<CustomDeviceItem>> _userDevicesDb = {};
  String _activeUserKey = 'default';

  final List<CustomDeviceItem> _devices = [];
  List<CustomDeviceItem> get allDevices => List.unmodifiable(_devices);

  List<CustomDeviceItem> get gates =>
      _devices.where((d) => d.type == DeviceType.gate).toList();

  List<CustomDeviceItem> get lights =>
      _devices.where((d) => d.type == DeviceType.light).toList();

  List<CustomDeviceItem> get slidingDoors =>
      _devices.where((d) => d.type == DeviceType.slidingDoor).toList();

  List<CustomDeviceItem> get curtains =>
      _devices.where((d) => d.type == DeviceType.curtain).toList();

  List<CustomDeviceItem> get waterPumps =>
      _devices.where((d) => d.type == DeviceType.waterPump).toList();

  Timer? _saveDebounceTimer;

  String _sanitizeUserKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  Future<File> _getUserDeviceFile(String userKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeKey = _sanitizeUserKey(userKey);
    return File('${dir.path}/alrisa_devices_$safeKey.json');
  }

  /// Muat data dari file disk lokal
  Future<void> _loadFromDisk(String userKey) async {
    try {
      final file = await _getUserDeviceFile(userKey);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final dynamic decoded = json.decode(content);
          if (decoded is List) {
            final loaded = decoded
                .map((item) => CustomDeviceItem.fromJson(Map<String, dynamic>.from(item)))
                .toList();

            if (loaded.isNotEmpty) {
              _userDevicesDb[userKey] = loaded;
              if (_activeUserKey == userKey) {
                _devices.clear();
                _devices.addAll(loaded);
                _devicesController.add(List.unmodifiable(_devices));
              }
              return;
            }
          }
        }
      }
    } catch (_) {}

    // Jika file belum pernah ada di disk untuk akun ini, simpan default sekarang
    if (_userDevicesDb.containsKey(userKey)) {
      await _saveToDisk(userKey);
    }
  }

  /// Simpan perubahan data ke file lokal HP
  Future<void> _saveToDisk(String userKey) async {
    try {
      final listToSave = _userDevicesDb[userKey] ?? (_activeUserKey == userKey ? _devices : null);
      if (listToSave == null) return;
      final file = await _getUserDeviceFile(userKey);
      final jsonString = json.encode(listToSave.map((d) => d.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  /// Jadwalkan penyimpanan ke disk (segera atau debounced)
  void _scheduleSave(String userKey, {bool immediate = false}) {
    if (immediate) {
      _saveDebounceTimer?.cancel();
      _saveToDisk(userKey);
      return;
    }
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveToDisk(userKey);
    });
  }

  /// Memulihkan perangkat dari disk (dapat dipanggil dan ditunggu oleh SplashScreen)
  Future<void> restoreFromDisk([String? userKey]) async {
    final key = userKey ?? _activeUserKey;
    await _loadFromDisk(key);
  }

  void _initDefaults() {
    // 1. Data Lengkap Super Admin Ravi Armanza
    final raviDevices = [
      CustomDeviceItem(
        id: 'pagar',
        name: 'Gerbang Utama Depan',
        type: DeviceType.gate,
        hardwarePin: 'GPIO 2 (%QX0.0)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'pagar_belakang',
        name: 'Gerbang Belakang',
        type: DeviceType.gate,
        hardwarePin: 'GPIO 4 (%QX0.1)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'lampu_teras',
        name: 'Lampu Teras Depan',
        type: DeviceType.light,
        hardwarePin: 'GPIO 4 (%QX0.3)',
        value: 80.0,
        isActive: true,
        statusText: 'Menyala 80%',
      ),
      CustomDeviceItem(
        id: 'pintu_geser',
        name: 'Pintu Geser Ruang Tamu',
        type: DeviceType.slidingDoor,
        hardwarePin: 'GPIO 5 (%QX0.1)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'gorden',
        name: 'Gorden Otomatis',
        type: DeviceType.curtain,
        hardwarePin: 'GPIO 18 (%QX0.2)',
        statusText: 'Tertutup',
      ),
      CustomDeviceItem(
        id: 'pompa_toren',
        name: 'Pompa Pengisi Toren',
        type: DeviceType.waterPump,
        hardwarePin: 'GPIO 19 (%QX0.4)',
        statusText: 'Mati',
      ),
    ];
    _userDevicesDb['raviarmanza149@gmail.com'] = raviDevices;

    // 2. Akun Kantor Bos (Mitsubishi FX5U PLC)
    _userDevicesDb['bos@nexora.id'] = [
      CustomDeviceItem(
        id: 'pagar_kantor',
        name: 'Gerbang Utama Kantor',
        type: DeviceType.gate,
        hardwarePin: '%QX0.0 (Relay 1)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'pintu_kantor',
        name: 'Pintu Akses Ruang Direksi',
        type: DeviceType.slidingDoor,
        hardwarePin: '%QX0.1 (Relay 2)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'lampu_lobby',
        name: 'Lampu Lobby & Teras',
        type: DeviceType.light,
        hardwarePin: '%QX0.3 (Relay 3)',
        value: 100.0,
        isActive: true,
        statusText: 'Menyala 100%',
      ),
      CustomDeviceItem(
        id: 'pompa_gedung',
        name: 'Pompa Toren Utama Gedung',
        type: DeviceType.waterPump,
        hardwarePin: '%QX0.4 (Relay 4)',
        statusText: 'Mati',
      ),
    ];

    // 3. Akun Bpk. Budi - Villa Puncak (Raspberry Pi 4)
    _userDevicesDb['villa.budi@nexora.id'] = [
      CustomDeviceItem(
        id: 'pagar_villa',
        name: 'Gerbang Utama Villa',
        type: DeviceType.gate,
        hardwarePin: 'Pi4 GPIO 17 (Pin 11)',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'lampu_taman',
        name: 'Lampu Taman & Kolam',
        type: DeviceType.light,
        hardwarePin: 'Pi4 GPIO 27 (Pin 13)',
        value: 100.0,
        isActive: true,
        statusText: 'Menyala 100%',
      ),
      CustomDeviceItem(
        id: 'pompa_air_villa',
        name: 'Pompa Sumber Air Pegunungan',
        type: DeviceType.waterPump,
        hardwarePin: 'Pi4 GPIO 22 (Pin 15)',
        statusText: 'Mati',
      ),
    ];

    // 4. Data Pengguna Biasa Demo (Ibu Maya - ESP32)
    _userDevicesDb['user@nexora.id'] = [
      CustomDeviceItem(
        id: 'pagar_maya',
        name: 'Pagar Minimalis Depan',
        type: DeviceType.gate,
        hardwarePin: 'ESP32 GPIO 2',
        statusText: 'Terkunci',
      ),
      CustomDeviceItem(
        id: 'lampu_teras_maya',
        name: 'Lampu Teras Otomatis',
        type: DeviceType.light,
        hardwarePin: 'ESP32 GPIO 4',
        value: 100.0,
        isActive: true,
        statusText: 'Menyala 100%',
      ),
      CustomDeviceItem(
        id: 'pintu_depan_maya',
        name: 'Pintu Depan Elektrik',
        type: DeviceType.slidingDoor,
        hardwarePin: 'ESP32 GPIO 5',
        statusText: 'Terkunci',
      ),
    ];

    final currentEmail = AuthService().currentUser?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    loadUserDevices(currentEmail);
  }

  /// Ganti dataset perangkat saat berganti akun
  void loadUserDevices(String userKey) {
    _activeUserKey = userKey;
    if (!_userDevicesDb.containsKey(_activeUserKey)) {
      // User baru mendaftar diberikan setup awal standar yang dapat diedit/ditambah
      _userDevicesDb[_activeUserKey] = [
        CustomDeviceItem(
          id: 'pagar_${_sanitizeUserKey(_activeUserKey)}',
          name: 'Gerbang Utama',
          type: DeviceType.gate,
          hardwarePin: 'GPIO 2 (%QX0.0)',
          statusText: 'Terkunci',
        ),
        CustomDeviceItem(
          id: 'lampu_${_sanitizeUserKey(_activeUserKey)}',
          name: 'Lampu Teras',
          type: DeviceType.light,
          hardwarePin: 'GPIO 4 (%QX0.3)',
          value: 100.0,
          isActive: false,
          statusText: 'Mati',
        ),
      ];
    }

    _devices.clear();
    _devices.addAll(_userDevicesDb[_activeUserKey]!);
    _notify(saveImmediate: false);

    // Muat data dari file disk lokal (jika sudah pernah diedit sebelumnya)
    _loadFromDisk(_activeUserKey);
  }

  void _notify({bool saveImmediate = false}) {
    _userDevicesDb[_activeUserKey] = List.from(_devices);
    _devicesController.add(List.unmodifiable(_devices));
    _scheduleSave(_activeUserKey, immediate: saveImmediate);
  }

  /// Tambah Perangkat Baru (Langsung simpan persisten ke disk)
  void addDevice({
    required String name,
    required DeviceType type,
    String? customId,
    String? hardwarePin,
  }) {
    // Generate ID unik jika tidak diisi
    final prefix = _getPrefix(type);
    final count = _devices.where((d) => d.type == type).length + 1;
    final finalId = customId?.trim().isNotEmpty == true
        ? customId!.trim().toLowerCase().replaceAll(' ', '_')
        : '${prefix}_$count';

    final newDev = CustomDeviceItem(
      id: finalId,
      name: name.trim().isNotEmpty ? name.trim() : 'Perangkat Baru $count',
      type: type,
      hardwarePin: hardwarePin?.trim().isNotEmpty == true
          ? hardwarePin!.trim()
          : 'GPIO 23',
      statusText: type == DeviceType.gate || type == DeviceType.slidingDoor
          ? 'Terkunci'
          : 'Mati',
    );

    _devices.add(newDev);
    _notify(saveImmediate: true);
  }

  /// Edit Nama / Pin / Tipe / ID Perangkat (Langsung simpan persisten ke disk)
  void updateDevice(
    String id, {
    String? newName,
    String? newPin,
    DeviceType? newType,
    String? newId,
  }) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx != -1) {
      final old = _devices[idx];
      _devices[idx] = CustomDeviceItem(
        id: (newId != null && newId.trim().isNotEmpty) ? newId.trim() : old.id,
        name: (newName != null && newName.trim().isNotEmpty) ? newName.trim() : old.name,
        type: newType ?? old.type,
        hardwarePin: (newPin != null && newPin.trim().isNotEmpty) ? newPin.trim() : old.hardwarePin,
        isActive: old.isActive,
        value: old.value,
        statusText: old.statusText,
      );
      _notify(saveImmediate: true);
    }
  }

  /// Hapus Perangkat (Langsung simpan persisten ke disk)
  void removeDevice(String id) {
    _devices.removeWhere((d) => d.id == id);
    _notify(saveImmediate: true);
  }

  /// Update Status / Nilai Perangkat dari MQTT (Penyimpanan debounced)
  void updateState(String id, {bool? isActive, double? value, String? statusText}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx != -1) {
      final dev = _devices[idx];
      bool changed = false;
      if (isActive != null && dev.isActive != isActive) {
        dev.isActive = isActive;
        changed = true;
      }
      if (value != null && dev.value != value) {
        dev.value = value;
        changed = true;
      }
      if (statusText != null && dev.statusText != statusText) {
        dev.statusText = statusText;
        changed = true;
      }
      if (changed) {
        _notify(saveImmediate: false);
      }
    }
  }

  CustomDeviceItem? getDevice(String id) {
    try {
      return _devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  String _getPrefix(DeviceType type) {
    switch (type) {
      case DeviceType.gate:
        return 'pagar';
      case DeviceType.light:
        return 'lampu';
      case DeviceType.slidingDoor:
        return 'pintu';
      case DeviceType.curtain:
        return 'gorden';
      case DeviceType.waterPump:
        return 'pompa';
    }
  }
}
