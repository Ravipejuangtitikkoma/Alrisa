import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:nexora/core/config/mqtt_config.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/preset_manager_service.dart';
import 'package:nexora/services/cloud_sync_service.dart';

/// Model payload pesan MQTT NEXORA: {"state": bool, "value": num?, "pin": int?, "hardwarePin": String?}
class DevicePayload {
  final bool state;
  final num? value;
  final int? pin;
  final String? hardwarePin;

  const DevicePayload({
    required this.state,
    this.value,
    this.pin,
    this.hardwarePin,
  });

  factory DevicePayload.fromJson(Map<String, dynamic> json) {
    return DevicePayload(
      state: json['state'] as bool? ?? false,
      value: json['value'] as num?,
      pin: json['pin'] as int?,
      hardwarePin: json['hardwarePin'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'state': state};
    if (value != null) {
      map['value'] = value;
    }
    if (pin != null) {
      map['pin'] = pin;
    }
    if (hardwarePin != null) {
      map['hardwarePin'] = hardwarePin;
    }
    return map;
  }

  @override
  String toString() => 'DevicePayload(state: $state, value: $value, pin: $pin, hardwarePin: $hardwarePin)';
}

/// Event update status perangkat dari broker
class DeviceStateEvent {
  final String deviceId;
  final DevicePayload payload;
  final DateTime timestamp;

  DeviceStateEvent({
    required this.deviceId,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// MqttService Singleton: Mengelola koneksi broker, auto-reconnect,
/// publish perintah ke /set, dan subscribe status dari /state.
class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;

  MqttService._internal() {
    _clientId = 'nexora-fi-${_generateRandomSuffix()}';
    _initAndConnect();
  }

  MqttServerClient? _client;
  late final String _clientId;

  // Stream status koneksi (true = terhubung, false = terputus/banner offline)
  final _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = false;

  // Stream pembaruan status perangkat (/state)
  final _stateController = StreamController<DeviceStateEvent>.broadcast();

  // Cache status perangkat terkini (single source of truth)
  final Map<String, DevicePayload> _deviceStates = {
    'pagar': const DevicePayload(state: false),
    'pintu_geser': const DevicePayload(state: false),
    'gorden': const DevicePayload(state: false),
    'lampu_teras': const DevicePayload(state: false, value: 0),
    'pompa_toren': const DevicePayload(state: false, value: 82),
    'pompa_kolam': const DevicePayload(state: false),
  };

  // Log pesan terakhir untuk halaman Pengaturan
  String _lastMessage = 'Belum ada pesan';
  DateTime? _lastMessageTime;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isManualDisconnect = false;

  // Getters
  String get clientId => _clientId;
  String get broker => MqttConfig.broker;
  int get port => MqttConfig.port;
  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<DeviceStateEvent> get stateStream => _stateController.stream;
  String get lastMessage => _lastMessage;
  DateTime? get lastMessageTime => _lastMessageTime;

  DevicePayload? getDeviceState(String deviceId) => _deviceStates[deviceId];

  String _generateRandomSuffix() {
    final rand = Random();
    return List.generate(5, (_) => rand.nextInt(36).toRadixString(36)).join();
  }

  /// Inisialisasi klien dan mulai koneksi
  Future<void> _initAndConnect() async {
    _isManualDisconnect = false;
    _client = MqttServerClient.withPort(MqttConfig.broker, _clientId, MqttConfig.port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.setProtocolV311();
    _client!.autoReconnect = false; // Kita kelola sendiri dengan exponential backoff

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    var connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean();

    if (MqttConfig.username != null && MqttConfig.password != null) {
      connMessage = connMessage.authenticateAs(MqttConfig.username!, MqttConfig.password!);
    }
    _client!.connectionMessage = connMessage;

    await connect();
  }

  /// Ganti konfigurasi broker secara instan dan sambungkan ulang (untuk Super Admin)
  Future<bool> updateBrokerAndReconnect({
    required String newBroker,
    required int newPort,
    String? newPrefix,
    String? newUsername,
    String? newPassword,
  }) async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    try {
      if (_client != null) {
        _client!.disconnect();
      }
    } catch (_) {}

    _isConnected = false;
    _connectionController.add(false);

    // Update config global
    MqttConfig.updateConfig(
      newBroker: newBroker,
      newPort: newPort,
      newPrefix: newPrefix,
      newUsername: newUsername,
      newPassword: newPassword,
    );

    // Inisialisasi ulang client dengan host baru
    await _initAndConnect();
    return _isConnected;
  }

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  /// Hubungkan ke Broker
  Future<void> connect() async {
    if (_isConnected && _client?.connectionStatus?.state == MqttConnectionState.connected) return;

    try {
      debugPrint('🔌 [MQTT] Menghubungkan ke ${MqttConfig.broker}:${MqttConfig.port} sebagai $_clientId...');
      _lastMessage = 'Sedang menghubungkan ke ${MqttConfig.broker}...';
      final status = await _client?.connect();
      if (status?.state == MqttConnectionState.connected ||
          _client?.connectionStatus?.state == MqttConnectionState.connected) {
        if (!_isConnected) {
          _onConnected();
        }
      } else {
        _lastMessage = 'Gagal: status = ${status?.state}';
        _handleDisconnect();
      }
    } catch (e) {
      debugPrint('❌ [MQTT] Koneksi gagal: $e');
      _lastMessage = 'Error koneksi: $e';
      _handleDisconnect();
    }
  }

  void _onConnected() {
    debugPrint('✅ [MQTT] Berhasil terhubung ke ${MqttConfig.broker}!');
    _isConnected = true;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connectionController.add(true);

    // Subscribe ke semua status perangkat: alrisa/+/state, alrisa/+/+/state, dan nexora/+/state
    final topic = MqttConfig.allStateTopics();
    debugPrint('📡 [MQTT] Subscribe ke topik: $topic');
    _client?.subscribe(topic, MqttQos.atLeastOnce);
    _client?.subscribe('alrisa/+/state', MqttQos.atLeastOnce);
    _client?.subscribe('alrisa/+/+/state', MqttQos.atLeastOnce);
    _client?.subscribe('nexora/+/state', MqttQos.atLeastOnce);

    // Subscribe ke topik sinkronisasi Cloud (2-arah dinamis antara Website & HP)
    _client?.subscribe('alrisa/sync', MqttQos.atLeastOnce);
    _client?.subscribe('nexora/sync', MqttQos.atLeastOnce);
    _client?.subscribe('alrisa/+/sync', MqttQos.atLeastOnce);
    _client?.subscribe('nexora/+/sync', MqttQos.atLeastOnce);

    // Dengarkan pesan masuk dari broker secara aman tanpa duplicate listener
    _updatesSub?.cancel();
    _updatesSub = _client?.updates?.listen(_onMessageReceived);
  }

  void _onSubscribed(String topic) {
    debugPrint(' Subscribed ke topik: $topic');
  }

  void _onDisconnected() {
    debugPrint('⚠️ [MQTT] Terputus dari broker');
    _isConnected = false;
    _connectionController.add(false);

    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// Auto-reconnect dengan Exponential Backoff (1s, 2s, 4s, 8s ... maks 30s)
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
    _reconnectAttempts++;

    debugPrint('🔄 [MQTT] Menjadwalkan reconnect dalam $delaySeconds detik (percobaan ke-$_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isConnected && !_isManualDisconnect) {
        connect();
      }
    });
  }

  /// Memproses pesan masuk dari topik state apa pun:
  /// - nexora/<device_id>/state
  /// - alrisa/<device_id>/state
  /// - alrisa/<prefix>/<device_id>/state
  /// - alrisa/sync atau nexora/sync (Sinyal sinkronisasi perangkat dari Website)
  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final recMess = message.payload as MqttPublishMessage;
      final payloadString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = message.topic;

      debugPrint('📥 [MQTT DITERIMA] Topik: $topic | Payload: $payloadString');

      _lastMessage = '$topic: $payloadString';
      _lastMessageTime = DateTime.now();

      // Sinyal sinkronisasi perangkat dari website (tambah/hapus/ubah PIN di web)
      if (topic.endsWith('/sync') || payloadString.contains('SYNC_DEVICES')) {
        debugPrint('🔔 [MQTT SYNC] Sinyal pembaruan perangkat diterima dari Website! Menarik data terbaru...');
        CloudSyncService().fetchFromCloud();
        continue;
      }

      // Ekstrak device_id dari topik yang berakhiran /state
      final parts = topic.split('/');
      if (parts.length >= 3 && parts.last == 'state') {
        final deviceId = parts[parts.length - 2];
        final cleanPayload = payloadString.trim();
        DevicePayload? payload;

        // 1. Coba parse JSON payload: {"state": true, "value": 50}
        if (cleanPayload.startsWith('{') && cleanPayload.endsWith('}')) {
          try {
            final jsonMap = jsonDecode(cleanPayload) as Map<String, dynamic>;
            payload = DevicePayload.fromJson(jsonMap);
          } catch (_) {}
        }

        // 2. Parse Plain String payload (dari Web Server, ESP32, PLC: "ON", "OFF", "OPEN", "LOCKED", "85")
        if (payload == null) {
          final upper = cleanPayload.toUpperCase();
          final isTrue = upper == 'ON' || upper == 'BUKA' || upper == 'TERBUKA' || upper == 'OPEN' || upper == '1' || upper == 'TRUE';
          final isFalse = upper == 'OFF' || upper == 'TUTUP' || upper == 'TERTUTUP' || upper == 'LOCKED' || upper == 'CLOSE' || upper == '0' || upper == 'FALSE';

          num? numVal;
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(cleanPayload)) {
            numVal = num.tryParse(cleanPayload);
          }

          bool finalState = isTrue;
          if (!isTrue && !isFalse && numVal != null) {
            finalState = numVal > 0;
          }

          payload = DevicePayload(
            state: finalState,
            value: numVal,
          );
        }

        // Update cache state (Single Source of Truth)
        _deviceStates[deviceId] = payload;

        // Siarkan event ke listener UI
        _stateController.add(DeviceStateEvent(deviceId: deviceId, payload: payload));

        // Sinkronkan ke DeviceManagerService
        DeviceManagerService().updateState(
          deviceId,
          isActive: payload.state,
          value: payload.value?.toDouble(),
          statusText: (deviceId.contains('pagar') || deviceId.contains('gate') || deviceId.contains('pintu'))
              ? (payload.state ? 'Terbuka' : 'Terkunci')
              : (payload.state ? 'Menyala' : 'Mati'),
        );
      }
    }
  }

  /// Publish perintah ke broker MQTT
  /// Payload: {"state": bool, "value": num?, "pin": int?, "hardwarePin": String?}
  void publishSet(
    String deviceId, {
    required bool state,
    num? value,
    String? hardwarePin,
    bool fromPreset = false,
  }) {
    if (!fromPreset) {
      // Jika dipicu manual dari tombol Home / Switch individu -> Otomatis beralih ke Mode Manual!
      PresetManagerService().setManualMode();
    }

    // Ambil hardwarePin dari parameter atau dari database perangkat
    String? resolvedHardwarePin = hardwarePin;
    if (resolvedHardwarePin == null || resolvedHardwarePin.trim().isEmpty) {
      final dev = DeviceManagerService().getDevice(deviceId);
      resolvedHardwarePin = dev?.hardwarePin;
    }

    // Ekstrak angka GPIO (misal: "GPIO 2", "GPIO 4", "Pin 23" -> 2, 4, 23)
    int? pinNumber;
    if (resolvedHardwarePin != null) {
      final match = RegExp(r'(?:gpio\s*|pin\s*|#)?(\d+)', caseSensitive: false).firstMatch(resolvedHardwarePin);
      if (match != null) {
        pinNumber = int.tryParse(match.group(1)!);
      }
    }

    final topic = MqttConfig.setTopic(deviceId);
    final payload = DevicePayload(
      state: state,
      value: value,
      pin: pinNumber,
      hardwarePin: resolvedHardwarePin,
    );
    _deviceStates[deviceId] = payload;
    final jsonString = jsonEncode(payload.toJson());

    debugPrint('🚀 [MQTT PUBLISH] Topik: $topic | Payload: $jsonString');

    // 1. Siarkan langsung ke seluruh listener UI di seluruh aplikasi SEKETIKA (Zero-delay Optimistic UI)
    _stateController.add(DeviceStateEvent(deviceId: deviceId, payload: payload));

    // 2. Sinkronkan ke DeviceManagerService seketika agar semua tab (Beranda, Ruangan, CCTV) langsung terupdate
    DeviceManagerService().updateState(
      deviceId,
      isActive: state,
      value: value?.toDouble(),
      statusText: (deviceId.contains('pagar') || deviceId.contains('gate') || deviceId.contains('pintu'))
          ? (state ? 'Terbuka' : 'Terkunci')
          : (state ? 'Menyala' : 'Mati'),
    );

    // 3. Teruskan ke broker MQTT jika terhubung
    if (_client == null || _client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('⚠️ [MQTT] Status: Belum terhubung (state: ${_client?.connectionStatus?.state}). Mencoba connect ulang...');
      connect();
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonString);

      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      // Siarkan juga ke nexora/<deviceId>/set agar ESP32 & Web Server lokal langsung sinkron
      if (topic != 'nexora/$deviceId/set') {
        final nexoraBuilder = MqttClientPayloadBuilder();
        final rawAction = state
            ? (deviceId.contains('pagar') || deviceId.contains('pintu') || deviceId.contains('gorden') ? 'BUKA' : 'ON')
            : (deviceId.contains('pagar') || deviceId.contains('pintu') || deviceId.contains('gorden') ? 'TUTUP' : 'OFF');
        nexoraBuilder.addString(rawAction);
        _client!.publishMessage(
          'nexora/$deviceId/set',
          MqttQos.atLeastOnce,
          nexoraBuilder.payload!,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [MQTT] Gagal publish: $e');
    }
  }

  /// Reconnect manual untuk tombol di Halaman Pengaturan
  Future<void> reconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    if (_client != null && _isConnected) {
      _client!.disconnect();
    }
    await _initAndConnect();
  }

  void dispose() {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _connectionController.close();
    _stateController.close();
  }
}
