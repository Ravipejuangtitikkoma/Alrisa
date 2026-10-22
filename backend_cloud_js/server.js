import express from 'express';
import http from 'http';
import cors from 'cors';
import mqtt from 'mqtt';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const server = http.createServer(app);

const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'alrisa_secret_token_2026';
const MQTT_BROKER = process.env.MQTT_BROKER_URL || 'mqtt://broker.emqx.io:1883';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// In-Memory Device State (Status Real-time Perangkat ALRISA)
const devices = {
  pagar: { id: 'pagar', name: 'Pintu Gerbang Utama', state: false, value: 0, lastUpdated: new Date() },
  pagar_belakang: { id: 'pagar_belakang', name: 'Gerbang Belakang', state: false, value: 0, lastUpdated: new Date() },
  pintu_geser: { id: 'pintu_geser', name: 'Pintu Geser Utama', state: false, value: 0, lastUpdated: new Date() },
  gorden: { id: 'gorden', name: 'Gorden Ruang Tengah', state: false, value: 0, lastUpdated: new Date() },
  lampu_teras: { id: 'lampu_teras', name: 'Lampu Teras Depan', state: false, value: 0, lastUpdated: new Date() },
  pompa_toren: { id: 'pompa_toren', name: 'Pompa Toren Otomatis', state: false, value: 0, lastUpdated: new Date() },
  pompa_kolam: { id: 'pompa_kolam', name: 'Pompa Kolam Ikan', state: false, value: 0, lastUpdated: new Date() },
};

// Mini PC / PLC Gateway Health Status
const gatewayStatus = {
  online: false,
  lastSeen: null,
  ip: '192.168.1.100',
  plcConnected: true,
  plcType: 'Mitsubishi FX5U (Modbus TCP Port 502)',
};

// Activity Logs
const activityLogs = [];
function addLog(deviceId, action, origin = 'APP') {
  const logEntry = {
    id: Date.now(),
    timestamp: new Date().toLocaleTimeString('id-ID'),
    deviceId,
    action,
    origin,
  };
  activityLogs.unshift(logEntry);
  if (activityLogs.length > 50) activityLogs.pop();
}

// -------------------------------------------------------------
// KONEKSI MQTT CLOUD (Jembatan Flutter <-> Cloud <-> Mini PC)
// -------------------------------------------------------------
console.log(`🔌 Menghubungkan ke MQTT Broker: ${MQTT_BROKER}...`);
const mqttClient = mqtt.connect(MQTT_BROKER, {
  clientId: `alrisa-cloud-hub-${Math.random().toString(16).substring(2, 8)}`,
  clean: true,
  connectTimeout: 5000,
});

mqttClient.on('connect', () => {
  console.log('✅ Berhasil terhubung ke Cloud MQTT Broker!');
  
  // Subscribe ke topik alrisa dan nexora (kompatibilitas ganda)
  const topics = [
    'alrisa/+/state',
    'nexora/+/state',
    'alrisa/+/set',
    'nexora/+/set',
    'alrisa/gateway/heartbeat',
    'nexora/gateway/heartbeat',
  ];

  topics.forEach((top) => {
    mqttClient.subscribe(top, (err) => {
      if (!err) console.log(`📡 Berhasil subscribe: ${top}`);
    });
  });
});

mqttClient.on('message', (topic, message) => {
  try {
    const topicStr = topic.toString();
    const payloadStr = message.toString();

    // 1. Deteksi Heartbeat Mini PC Gateway
    if (topicStr.includes('/gateway/heartbeat')) {
      gatewayStatus.online = true;
      gatewayStatus.lastSeen = new Date();
      try {
        const hbData = JSON.parse(payloadStr);
        if (hbData.plcConnected !== undefined) gatewayStatus.plcConnected = hbData.plcConnected;
        if (hbData.ip) gatewayStatus.ip = hbData.ip;
      } catch (_) {}
      return;
    }

    // 2. Deteksi Pesan Status / Kontrol Perangkat
    const parts = topicStr.split('/');
    if (parts.length < 3) return;

    const deviceId = parts[1];
    const type = parts[2]; // 'state' atau 'set'

    // Parsing fleksibel: String (OPEN/LOCKED/ON/OFF/1/0), Boolean (true/false), atau JSON ({state: true})
    let isStateOn = false;
    let numericValue = null;

    try {
      const parsed = JSON.parse(payloadStr);
      if (typeof parsed === 'object' && parsed !== null) {
        isStateOn = Boolean(parsed.state !== undefined ? parsed.state : (parsed.open !== undefined ? parsed.open : parsed.status));
        if (parsed.value !== undefined) numericValue = Number(parsed.value);
      } else if (typeof parsed === 'boolean') {
        isStateOn = parsed;
      } else if (typeof parsed === 'number') {
        isStateOn = parsed === 1;
      } else if (typeof parsed === 'string') {
        const u = parsed.toUpperCase().trim();
        isStateOn = (u === 'OPEN' || u === 'ON' || u === 'TRUE' || u === '1');
      }
    } catch (_) {
      const u = payloadStr.toUpperCase().trim();
      isStateOn = (u === 'OPEN' || u === 'ON' || u === 'TRUE' || u === '1');
    }

    // Pastikan perangkat terdaftar di memory
    if (!devices[deviceId]) {
      devices[deviceId] = {
        id: deviceId,
        name: deviceId.replace(/_/g, ' ').toUpperCase(),
        state: false,
        value: 0,
        lastUpdated: new Date(),
      };
    }

    // UPDATE STATUS PERANGKAT LANGSUNG (Agar Dashboard Web Langsung Berubah 🟢 / ⚪)
    devices[deviceId].state = isStateOn;
    if (numericValue !== null) devices[deviceId].value = numericValue;
    devices[deviceId].lastUpdated = new Date();

    if (type === 'state') {
      addLog(deviceId, `Status fisik diperbarui -> ${isStateOn ? 'AKTIF / TERBUKA' : 'NONAKTIF / TERTUTUP'}`, 'ESP32_RELAY');
      console.log(`🔄 [STATE DITERIMA] ${deviceId} -> ${isStateOn ? 'TERBUKA / ON' : 'TERTUTUP / OFF'}`);
    } else if (type === 'set') {
      addLog(deviceId, `Perintah kontrol -> ${isStateOn ? 'BUKA / ON' : 'TUTUP / OFF'}`, 'CLIENT_APP');
      console.log(`⚡ [PERINTAH DITERIMA] ${deviceId} -> ${isStateOn ? 'BUKA / ON' : 'TUTUP / OFF'}`);
    }
  } catch (err) {
    console.error('⚠️ Gagal memproses pesan MQTT:', err.message);
  }
});

mqttClient.on('error', (err) => {
  console.error('❌ MQTT Error:', err.message);
});

// Timer cek liveness gateway (jika > 25 detik tidak ada heartbeat, anggap offline)
setInterval(() => {
  if (gatewayStatus.lastSeen) {
    const diffSec = (new Date() - new Date(gatewayStatus.lastSeen)) / 1000;
    gatewayStatus.online = diffSec < 25;
  }
}, 5000);

// -------------------------------------------------------------
// REST API ENDPOINTS
// -------------------------------------------------------------

// 1. Healthcheck Sistem
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    system: 'ALRISA Cloud Smart Systems',
    company: 'Alfatech Solutions IDN.',
    version: '2.5.0',
    mqttConnected: mqttClient.connected,
    gateway: gatewayStatus,
    timestamp: new Date().toISOString(),
  });
});

// 2. Ambil Semua Status Perangkat
app.get('/api/devices', (req, res) => {
  res.json({
    success: true,
    data: Object.values(devices),
  });
});

// 3. Ambil Status Satu Perangkat
app.get('/api/devices/:id', (req, res) => {
  const dev = devices[req.params.id];
  if (!dev) return res.status(404).json({ success: false, message: 'Device tidak ditemukan' });
  res.json({ success: true, data: dev });
});

// 4. Kirim Perintah Kontrol (Dipanggil Web Dashboard atau REST API)
app.post('/api/devices/:id/control', (req, res) => {
  const deviceId = req.params.id;
  const { state, value } = req.body;

  if (state === undefined) {
    return res.status(400).json({ success: false, message: 'Parameter state (boolean) wajib disertakan' });
  }

  const payload = {
    state: Boolean(state),
    value: value !== undefined ? Number(value) : null,
  };

  // Publish ke MQTT ke prefix ALRISA dan NEXORA (Kirim perintah OPEN/CLOSE standar & JSON)
  const cmdStr = Boolean(state) ? 'OPEN' : 'CLOSE';
  mqttClient.publish(`alrisa/${deviceId}/set`, cmdStr, { qos: 1 });
  mqttClient.publish(`nexora/${deviceId}/set`, cmdStr, { qos: 1 });
  console.log(`📤 [WEB DASHBOARD PUBLISH] alrisa/${deviceId}/set -> ${cmdStr}`);

  // Update in-memory state sementara untuk feedback instan
  if (devices[deviceId]) {
    devices[deviceId].state = Boolean(state);
    if (value !== undefined) devices[deviceId].value = Number(value);
    devices[deviceId].lastUpdated = new Date();
  }

  addLog(deviceId, `Perintah dari Web Dashboard -> ${state ? 'BUKA / ON' : 'TUTUP / OFF'}`, 'WEB_DASHBOARD');

  res.json({
    success: true,
    message: `Perintah ke ${deviceId} berhasil dikirim ke Mini PC & PLC`,
    payloadSent: payload,
  });
});

// 5. Status Mini PC Gateway
app.get('/api/gateway', (req, res) => {
  res.json({
    success: true,
    data: gatewayStatus,
  });
});

// 6. Endpoint Heartbeat Mini PC Gateway via HTTP (Alternatif jika MQTT tertutup firewall)
app.post('/api/gateway/heartbeat', (req, res) => {
  gatewayStatus.online = true;
  gatewayStatus.lastSeen = new Date();
  if (req.body.ip) gatewayStatus.ip = req.body.ip;
  if (req.body.plcConnected !== undefined) gatewayStatus.plcConnected = req.body.plcConnected;

  res.json({ success: true, message: 'Heartbeat diterima' });
});

// 7. Ambil Log Aktivitas Terakhir
app.get('/api/logs', (req, res) => {
  res.json({
    success: true,
    total: activityLogs.length,
    data: activityLogs,
  });
});

// 8. Konfigurasi CCTV Streams (Live Streaming Feeds)
app.get('/api/cctv', (req, res) => {
  res.json({
    success: true,
    storagePolicy: 'LOCAL_NVR_STORAGE_WITH_CLOUD_LIVE_STREAM',
    note: 'Video 24 jam tersimpan aman di Harddisk NVR / Mini PC lokal. Cloud menyediakan live view stream.',
    cameras: [
      {
        id: 'cam_gate',
        name: 'CCTV Gerbang & Pagar Utama',
        location: 'Depan Rumah',
        status: 'ONLINE',
        rtspStream: 'rtsp://admin:admin123@192.168.1.50:554/stream1',
        hlsStream: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      },
      {
        id: 'cam_carport',
        name: 'CCTV Carport & Garasi',
        location: 'Samping',
        status: 'ONLINE',
        rtspStream: 'rtsp://admin:admin123@192.168.1.51:554/stream1',
        hlsStream: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      },
      {
        id: 'cam_backyard',
        name: 'CCTV Halaman Belakang & Kolam',
        location: 'Belakang',
        status: 'ONLINE',
        rtspStream: 'rtsp://admin:admin123@192.168.1.52:554/stream1',
        hlsStream: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      },
    ],
  });
});

// 9. API Settings (Get & Save Configuration Terpusat)
const settingsFilePath = path.join(__dirname, 'settings.json');

const defaultSettings = {
  mqtt_broker: process.env.MQTT_BROKER_URL ? process.env.MQTT_BROKER_URL.replace('mqtt://', '').split(':')[0] : 'broker.emqx.io',
  mqtt_port: 1883,
  mqtt_ws_port: 8083,
  mqtt_prefix: 'alrisa',
  mqtt_user: '',
  mqtt_pass: '',
  mqtt_client_id: 'ALRISA_NodeWebClient',
  wifi_ssid: 'ALRISA_OFFICE_WIFI',
  wifi_password: '',
  plc_ip: '192.168.1.100',
  plc_port: 502,
  plc_type: 'Mitsubishi FX5U (Modbus TCP Port 502)',
  api_secret_key: process.env.API_KEY || 'alrisa_secret_token_2026',
  app_name: 'ALRISA Industrial IoT Suite',
  updated_at: new Date().toISOString()
};

function getSettings() {
  try {
    if (fs.existsSync(settingsFilePath)) {
      const data = fs.readFileSync(settingsFilePath, 'utf8');
      return { ...defaultSettings, ...JSON.parse(data) };
    }
  } catch (e) {
    console.error('Error reading settings.json:', e);
  }
  return defaultSettings;
}

app.get('/api/settings', (req, res) => {
  res.json({
    success: true,
    message: 'Konfigurasi ALRISA berhasil dimuat (Node.js)',
    data: getSettings()
  });
});

app.post('/api/settings', (req, res) => {
  try {
    const current = getSettings();
    const updated = { ...current, ...req.body, updated_at: new Date().toISOString() };
    fs.writeFileSync(settingsFilePath, JSON.stringify(updated, null, 2), 'utf8');
    console.log('💾 [NODE.JS CONFIG] Pengaturan sistem berhasil diperbarui via Node.js!');
    res.json({
      success: true,
      message: 'Konfigurasi berhasil disimpan di server Node.js!',
      data: updated
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Route alias /settings -> serve settings.html
app.get('/settings', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'settings.html'));
});

// Jalankan Server
server.listen(PORT, () => {
  console.log('='.repeat(60));
  console.log(`🚀 ALRISA Cloud Smart Systems Backend Berjalan di Port: ${PORT}`);
  console.log(`🏢 Alfatech Solutions IDN.`);
  console.log(`🌐 Dashboard Monitoring: http://localhost:${PORT}`);
  console.log(`📡 API Status: http://localhost:${PORT}/api/health`);
  console.log('='.repeat(60));
});
