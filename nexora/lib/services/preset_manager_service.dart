import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/auth_service.dart';

/// Target aksi perangkat di dalam satu preset
class PresetDeviceAction {
  final String deviceId;
  final String deviceName;
  bool targetState; // true = ON/BUKA, false = OFF/TUTUP
  double? targetValue;

  PresetDeviceAction({
    required this.deviceId,
    required this.deviceName,
    required this.targetState,
    this.targetValue,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'targetState': targetState,
    'targetValue': targetValue,
  };

  factory PresetDeviceAction.fromJson(Map<String, dynamic> json) {
    return PresetDeviceAction(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? '',
      targetState: json['targetState'] ?? false,
      targetValue: json['targetValue'] != null ? (json['targetValue'] as num).toDouble() : null,
    );
  }
}

/// Model Data Skenario / Preset Otomasi
class PresetSceneItem {
  final String id;
  String name;
  String description;
  IconData icon;
  Color accentColor;
  List<PresetDeviceAction> actions;
  final bool isDefault;
  bool isActive;

  PresetSceneItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.actions,
    this.isDefault = false,
    this.isActive = false,
  });
}

/// Singleton Service untuk mengelola Preset Otomasi Kustom & Mode Aktif Rumah
class PresetManagerService {
  static final PresetManagerService _instance = PresetManagerService._internal();
  factory PresetManagerService() => _instance;

  PresetManagerService._internal() {
    _initDefaultPresets();
    // Dengarkan perubahan login akun agar data preset langsung beralih per akun
    AuthService().authStream.listen((user) {
      final userKey = user?.email.toLowerCase() ?? 'default';
      loadUserPresets(userKey);
    });
  }

  // Database Preset per Akun (Key = email akun)
  final Map<String, List<PresetSceneItem>> _userPresetsDb = {};
  String _activeUserKey = 'default';

  final List<PresetSceneItem> _presets = [];
  final StreamController<List<PresetSceneItem>> _presetsController =
      StreamController<List<PresetSceneItem>>.broadcast();

  // Mode Rumah Aktif: nama preset aktif (misal 'Mode Santai (Chill)') atau 'Mode Manual'
  String _activeModeName = 'Mode Manual';
  Color _activeModeColor = const Color(0xFF0F766E);

  final StreamController<String> _activeModeController =
      StreamController<String>.broadcast();

  Stream<List<PresetSceneItem>> get presetsStream => _presetsController.stream;
  Stream<String> get activeModeStream => _activeModeController.stream;

  List<PresetSceneItem> get allPresets => List.unmodifiable(_presets);
  String get activeModeName => _activeModeName;
  Color get activeModeColor => _activeModeColor;

  void _initDefaultPresets() {
    // 1. Preset Default Khusus Super Admin Ravi
    final raviPresets = [
      PresetSceneItem(
        id: 'scene_chill',
        name: 'Mode Santai (Chill)',
        description: 'Lampu depan mati, gerbang terkunci aman, gorden tertutup.',
        icon: Icons.coffee_rounded,
        accentColor: const Color(0xFF8B5CF6),
        actions: [
          PresetDeviceAction(deviceId: 'lampu_teras', deviceName: 'Lampu Teras Depan', targetState: false),
          PresetDeviceAction(deviceId: 'pagar', deviceName: 'Pintu Gerbang Utama', targetState: false),
          PresetDeviceAction(deviceId: 'gorden', deviceName: 'Gorden Ruang Utama', targetState: false),
          PresetDeviceAction(deviceId: 'pintu_geser', deviceName: 'Pintu Geser', targetState: false),
        ],
        isDefault: true,
      ),
      PresetSceneItem(
        id: 'scene_leaving',
        name: 'Keluar Rumah (Away)',
        description: 'Kunci seluruh pintu & gerbang, matikan lampu dan pompa air.',
        icon: Icons.flight_takeoff_rounded,
        accentColor: const Color(0xFFEF4444),
        actions: [
          PresetDeviceAction(deviceId: 'pagar', deviceName: 'Pintu Gerbang Utama', targetState: false),
          PresetDeviceAction(deviceId: 'pintu_geser', deviceName: 'Pintu Geser', targetState: false),
          PresetDeviceAction(deviceId: 'lampu_teras', deviceName: 'Lampu Teras Depan', targetState: false),
          PresetDeviceAction(deviceId: 'pompa_kolam', deviceName: 'Pompa Kolam Ikan', targetState: false),
          PresetDeviceAction(deviceId: 'gorden', deviceName: 'Gorden Ruang Utama', targetState: false),
        ],
        isDefault: true,
      ),
      PresetSceneItem(
        id: 'scene_night',
        name: 'Selamat Malam (Sleep)',
        description: 'Tutup rapat gerbang & pintu, nyalakan lampu teras untuk keamanan.',
        icon: Icons.bedtime_rounded,
        accentColor: const Color(0xFF3B82F6),
        actions: [
          PresetDeviceAction(deviceId: 'pagar', deviceName: 'Pintu Gerbang Utama', targetState: false),
          PresetDeviceAction(deviceId: 'pintu_geser', deviceName: 'Pintu Geser', targetState: false),
          PresetDeviceAction(deviceId: 'lampu_teras', deviceName: 'Lampu Teras Depan', targetState: true),
          PresetDeviceAction(deviceId: 'gorden', deviceName: 'Gorden Ruang Utama', targetState: false),
        ],
        isDefault: true,
      ),
    ];
    _userPresetsDb['raviarmanza149@gmail.com'] = raviPresets;

    // 2. Preset Default untuk Akun Pengguna Biasa
    _userPresetsDb['user@nexora.id'] = [
      PresetSceneItem(
        id: 'scene_keluarga_malam',
        name: 'Mode Malam Keluarga',
        description: 'Kunci gerbang dan nyalakan lampu teras depan.',
        icon: Icons.nightlight_round,
        accentColor: const Color(0xFF0284C7),
        actions: [
          PresetDeviceAction(deviceId: 'pagar_keluarga', deviceName: 'Gerbang Depan', targetState: false),
          PresetDeviceAction(deviceId: 'lampu_teras_keluarga', deviceName: 'Lampu Teras', targetState: true),
        ],
        isDefault: true,
      ),
    ];

    final currentEmail = AuthService().currentUser?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    loadUserPresets(currentEmail);
  }

  /// Ganti dataset preset saat berganti akun
  void loadUserPresets(String userKey) {
    _activeUserKey = userKey;
    if (!_userPresetsDb.containsKey(_activeUserKey)) {
      // Akun baru mendaftar diberikan 1 preset awal yang bisa diedit/ditambah
      _userPresetsDb[_activeUserKey] = [
        PresetSceneItem(
          id: 'scene_default_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Mode Rumah Aman',
          description: 'Kunci semua akses dan matikan lampu luar.',
          icon: Icons.shield_rounded,
          accentColor: const Color(0xFF10B981),
          actions: [
            PresetDeviceAction(deviceId: 'pagar', deviceName: 'Pagar Utama', targetState: false),
          ],
          isDefault: true,
        ),
      ];
    }

    _presets.clear();
    _presets.addAll(_userPresetsDb[_activeUserKey]!);
    _activeModeName = 'Mode Manual';
    _notify();
  }

  /// Aktifkan / Toggle Preset Skenario
  Future<void> togglePreset(String presetId, bool turnOn) async {
    final index = _presets.indexWhere((p) => p.id == presetId);
    if (index == -1) return;

    if (!turnOn) {
      // Jika pengguna mematikan toggle preset ini -> otomatis kembali ke Mode Manual
      _presets[index].isActive = false;
      _activeModeName = 'Mode Manual';
      _activeModeColor = const Color(0xFF64748B);
      _notify();
      _activeModeController.add(_activeModeName);
      return;
    }

    // Jika diaktifkan: Matikan semua preset lain (hanya 1 preset yang aktif)
    for (var p in _presets) {
      p.isActive = (p.id == presetId);
    }

    final targetPreset = _presets[index];
    _activeModeName = targetPreset.name;
    _activeModeColor = targetPreset.accentColor;

    _notify();
    _activeModeController.add(_activeModeName);

    // Eksekusi aksi perangkat secara serentak via MQTT
    for (final action in targetPreset.actions) {
      MqttService().publishSet(
        action.deviceId,
        state: action.targetState,
        value: action.targetValue,
        fromPreset: true,
      );
      DeviceManagerService().updateState(
        action.deviceId,
        isActive: action.targetState,
        value: action.targetValue,
        statusText: action.targetState ? 'Aktif' : 'Mati/Terkunci',
      );
    }
  }

  /// Pindah ke Mode Manual (dipanggil otomatis jika user mengklik salah satu saklar di Home)
  void setManualMode() {
    bool hadActive = false;
    for (var p in _presets) {
      if (p.isActive) {
        p.isActive = false;
        hadActive = true;
      }
    }
    _activeModeName = 'Mode Manual';
    _activeModeColor = const Color(0xFF64748B);

    if (hadActive) {
      _notify();
    }
    _activeModeController.add(_activeModeName);
  }

  /// Update / Edit Aksi atau Data Preset yang Sudah Ada
  void updatePreset(PresetSceneItem updatedPreset) {
    final idx = _presets.indexWhere((p) => p.id == updatedPreset.id);
    if (idx != -1) {
      _presets[idx] = updatedPreset;
      _notify();
    }
  }

  /// Tambah Preset Kustom Baru
  void addCustomPreset({
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required List<PresetDeviceAction> actions,
  }) {
    final newPreset = PresetSceneItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      icon: icon,
      accentColor: color,
      actions: actions,
      isDefault: false,
    );
    _presets.insert(0, newPreset);
    _notify();
  }

  /// Hapus Preset Kustom
  void deletePreset(String presetId) {
    _presets.removeWhere((p) => p.id == presetId && !p.isDefault);
    _notify();
  }

  void _notify() {
    _userPresetsDb[_activeUserKey] = List.from(_presets);
    _presetsController.add(List.unmodifiable(_presets));
  }
}
