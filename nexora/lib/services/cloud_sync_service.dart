import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';

import 'package:path_provider/path_provider.dart';

/// Service Sinkronisasi Cloud Dua Arah (Flutter Mobile App <-> Node.js / PHP Web Cloud)
/// Memastikan nama alat, gerbang, dan CCTV yang ditambahkan user di HP 100% sama dengan di website.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal() {
    initBaseUrl();
  }

  // URL Backend Node.js
  // Default diatur ke IP Laptop (192.168.1.8:3000) agar HP fisik Android dapat langsung terhubung.
  String _baseUrl = 'http://192.168.1.8:3000';
  String get baseUrl => _baseUrl;

  Future<void> initBaseUrl() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alrisa_server_ip.txt');
      if (await file.exists()) {
        final saved = await file.readAsString();
        if (saved.trim().isNotEmpty) {
          _baseUrl = saved.trim().replaceAll(RegExp(r'/+$'), '');
        }
      }
    } catch (_) {}
    startPeriodicSync();
  }

  Future<void> setBaseUrl(String newUrl) async {
    _baseUrl = newUrl.replaceAll(RegExp(r'/+$'), '');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alrisa_server_ip.txt');
      await file.writeAsString(_baseUrl);
    } catch (_) {}
  }

  bool _isSyncing = false;
  Timer? _debounceTimer;
  Timer? _periodicPollTimer;

  /// Sinkronisasi latar belakang otomatis tiap 10 detik agar perubahan PIN & RTSP CCTV di Website
  /// langsung ter-update di Aplikasi Mobile secara real-time tanpa mengganggu interaksi UI
  void startPeriodicSync() {
    _periodicPollTimer?.cancel();
    _periodicPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (AuthService().currentUser != null && !_isSyncing) {
        fetchFromCloud(isBackgroundPoll: true);
      }
    });
  }

  /// Jadwalkan sinkronisasi otomatis ke server (Debounced agar hemat kuota)
  void scheduleSyncToCloud() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      syncToCloud();
    });
  }

  /// Simpan atau perbarui satu perangkat ke Website Cloud (Dua Arah: HP -> Website)
  Future<bool> pushDeviceToCloud(CustomDeviceItem dev) async {
    final user = AuthService().currentUser;
    final email = user?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    final accountId = user?.id ?? 'acc_superadmin';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl/api/device/save');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(json.encode({
        'account_id': accountId,
        'email': email,
        'device': dev.toJson(),
      }));
      final res = await req.close().timeout(const Duration(seconds: 5));
      await res.drain();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [CLOUD SYNC] Gagal push device ke cloud: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Hapus satu perangkat dari Website Cloud (Dua Arah: HP -> Website)
  Future<bool> deleteDeviceFromCloud(String deviceId) async {
    final user = AuthService().currentUser;
    final email = user?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    final accountId = user?.id ?? 'acc_superadmin';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl/api/device/delete');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(json.encode({
        'account_id': accountId,
        'email': email,
        'device_id': deviceId,
      }));
      final res = await req.close().timeout(const Duration(seconds: 5));
      await res.drain();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [CLOUD SYNC] Gagal delete device dari cloud: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Simpan atau perbarui satu kamera CCTV ke Website Cloud (Dua Arah: HP -> Website)
  Future<bool> pushCctvToCloud(CctvCameraItem cam) async {
    final user = AuthService().currentUser;
    final email = user?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    final accountId = user?.id ?? 'acc_superadmin';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl/api/cctv/save');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(json.encode({
        'account_id': accountId,
        'email': email,
        'cctv': cam.toJson(),
      }));
      final res = await req.close().timeout(const Duration(seconds: 5));
      await res.drain();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [CLOUD SYNC] Gagal push CCTV ke cloud: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Hapus satu kamera CCTV dari Website Cloud (Dua Arah: HP -> Website)
  Future<bool> deleteCctvFromCloud(String cctvId) async {
    final user = AuthService().currentUser;
    final email = user?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
    final accountId = user?.id ?? 'acc_superadmin';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl/api/cctv/delete');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(json.encode({
        'account_id': accountId,
        'email': email,
        'cctv_id': cctvId,
      }));
      final res = await req.close().timeout(const Duration(seconds: 5));
      await res.drain();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [CLOUD SYNC] Gagal delete CCTV dari cloud: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Unggah daftar perangkat & CCTV saat ini ke server Node.js
  Future<bool> syncToCloud() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final user = AuthService().currentUser;
      final email = user?.email.toLowerCase() ?? 'raviarmanza149@gmail.com';
      final accountId = user?.id ?? 'acc_superadmin';

      final devices = DeviceManagerService().allDevices.map((d) => d.toJson()).toList();
      final cctv = CctvManagerService().allCameras.map((c) => c.toJson()).toList();

      final payload = {
        'account_id': accountId,
        'email': email,
        'devices': devices,
        'cctv': cctv,
      };

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      // Coba kirim ke Node.js server
      final uri = Uri.parse('$_baseUrl/api/sync_devices');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));

      final response = await request.close();
      await response.drain();
      client.close();

      if (response.statusCode == 200) {
        debugPrint('✅ [CLOUD SYNC] Berhasil sinkronisasi ${devices.length} alat & ${cctv.length} CCTV ke server website.');
        _isSyncing = false;
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [CLOUD SYNC] Server web lokal tidak terjangkau (offline / beda jaringan). Data tetap aman di memori HP.');
    }

    _isSyncing = false;
    return false;
  }

  /// Tarik data terbaru dari server website saat aplikasi dibuka atau saat ada pembaruan di Web
  /// (Termasuk perubahan PIN GPIO, penambahan/penghapusan alat, dan URL RTSP CCTV!)
  Future<bool> fetchFromCloud({
    String? targetEmail,
    String? targetAccountId,
    bool isBackgroundPoll = false,
  }) async {
    final user = AuthService().currentUser;
    final email = (targetEmail ?? user?.email ?? 'raviarmanza149@gmail.com').toLowerCase().trim();
    final accountId = (targetAccountId ?? user?.id ?? 'acc_superadmin').trim();

    final candidateUrls = isBackgroundPoll
        ? <String>[_baseUrl]
        : <String>{
            _baseUrl,
            'http://192.168.1.8:3000',
            'http://10.0.2.2:3000',
            'http://localhost:3000',
          }.toList();

    for (final candidateBase in candidateUrls) {
      final client = HttpClient();
      client.connectionTimeout = Duration(milliseconds: isBackgroundPoll ? 1500 : 2500);
      try {
        final uri = Uri.parse(
          '$candidateBase/api/sync?account_id=${Uri.encodeComponent(accountId)}&email=${Uri.encodeComponent(email)}',
        );
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          if (candidateBase != _baseUrl) {
            _baseUrl = candidateBase;
          }
          final body = await response.transform(utf8.decoder).join();
          final data = json.decode(body);

          if (data['success'] == true) {
            // 1. Sinkronkan daftar Perangkat & PIN GPIO dari Website ke HP
            if (data['devices'] is List) {
              final rawList = data['devices'] as List<dynamic>;
              final parsedDevices = <CustomDeviceItem>[];

              for (final item in rawList) {
                if (item is Map) {
                  final m = Map<String, dynamic>.from(item);
                  final id = (m['id'] ?? 'dev_${parsedDevices.length}').toString();
                  final name = (m['name'] ?? 'Perangkat').toString();

                  int typeIdx = 0;
                  if (m['type'] is int) {
                    typeIdx = m['type'];
                  } else if (m['type'] != null) {
                    typeIdx = int.tryParse(m['type'].toString()) ?? 0;
                  }
                  if (typeIdx < 0 || typeIdx >= DeviceType.values.length) typeIdx = 0;
                  final type = DeviceType.values[typeIdx];

                  final pin = (m['hardwarePin'] ?? m['plc_address'] ?? 'GPIO 2 (%QX0.0)').toString();
                  final isActive = m['isActive'] == true || m['state'] == 'ON' || m['state'] == 'BUKA';
                  final val = (m['value'] ?? 0.0) is num ? (m['value'] as num).toDouble() : 0.0;
                  final statusText = (m['statusText'] ?? (isActive ? 'Aktif' : 'Terkunci')).toString();

                  parsedDevices.add(CustomDeviceItem(
                    id: id,
                    name: name,
                    type: type,
                    hardwarePin: pin,
                    isActive: isActive,
                    value: val,
                    statusText: statusText,
                  ));
                }
              }

              DeviceManagerService().setDevicesFromRemote(parsedDevices, targetUserKey: email);
            }

            // 2. Sinkronkan daftar Kamera CCTV & URL RTSP dari Website ke HP
            if (data['cctv'] is List) {
              final rawCctv = data['cctv'] as List<dynamic>;
              final parsedCameras = <CctvCameraItem>[];

              for (final item in rawCctv) {
                if (item is Map) {
                  final m = Map<String, dynamic>.from(item);
                  final id = (m['id'] ?? 'cctv_${parsedCameras.length}').toString();
                  final name = (m['name'] ?? 'Kamera CCTV').toString();
                  final location = (m['location'] ?? 'Area Rumah').toString();
                  final rtsp = (m['rtspUrl'] ?? m['rtsp_url'] ?? '').toString().trim();
                  final host = (m['onvifHost'] ?? m['onvif_host'] ?? '192.168.1.50').toString().trim();
                  final portVal = m['onvifPort'] ?? m['onvif_port'] ?? 80;
                  final port = portVal is num ? portVal.toInt() : (int.tryParse(portVal.toString()) ?? 80);
                  final boundRaw = (m['boundGateId'] ?? m['bound_gate'])?.toString().trim();
                  final boundGateId = (boundRaw != null && boundRaw.isNotEmpty) ? boundRaw : null;
                  final resolution = (m['resolution'] ?? '1080P FHD (H.264)').toString();
                  final fpsVal = m['fps'] ?? 25.0;
                  final fps = fpsVal is num ? fpsVal.toDouble() : 25.0;

                  parsedCameras.add(CctvCameraItem(
                    id: id,
                    name: name,
                    location: location,
                    rtspUrl: rtsp,
                    onvifHost: host,
                    onvifPort: port,
                    boundGateId: boundGateId,
                    isOnline: m['isOnline'] != false,
                    fps: fps,
                    resolution: resolution,
                  ));
                }
              }

              CctvManagerService().setCamerasFromRemote(parsedCameras, targetUserKey: email);
            }

            client.close();
            return true;
          }
        }
      } catch (e) {
        // Coba URL kandidat berikutnya jika gagal
      } finally {
        client.close();
      }
    }
    return false;
  }
}
