import 'dart:async';

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

/// Service Pengelola Daftar Perangkat Dinamis (Singleton)
class DeviceManagerService {
  static final DeviceManagerService _instance = DeviceManagerService._internal();
  factory DeviceManagerService() => _instance;
  DeviceManagerService._internal() {
    _initDefaults();
  }

  final StreamController<List<CustomDeviceItem>> _devicesController =
      StreamController<List<CustomDeviceItem>>.broadcast();
  Stream<List<CustomDeviceItem>> get devicesStream => _devicesController.stream;

  final List<CustomDeviceItem> _devices = [];
  List<CustomDeviceItem> get allDevices => List.unmodifiable(_devices);

  List<CustomDeviceItem> get gates =>
      _devices.where((d) => d.type == DeviceType.gate).toList();

  void _initDefaults() {
    if (_devices.isNotEmpty) return;
    
    // Perangkat Bawaan (Default)
    _devices.addAll([
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
    ]);
    _notify();
  }

  void _notify() {
    _devicesController.add(List.unmodifiable(_devices));
  }

  /// Tambah Perangkat Baru
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
    _notify();
  }

  /// Edit Nama / Pin / Tipe / ID Perangkat
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
      _notify();
    }
  }

  /// Hapus Perangkat
  void removeDevice(String id) {
    _devices.removeWhere((d) => d.id == id);
    _notify();
  }

  /// Update Status / Nilai Perangkat dari MQTT
  void updateState(String id, {bool? isActive, double? value, String? statusText}) {
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx != -1) {
      if (isActive != null) _devices[idx].isActive = isActive;
      if (value != null) _devices[idx].value = value;
      if (statusText != null) _devices[idx].statusText = statusText;
      _notify();
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
