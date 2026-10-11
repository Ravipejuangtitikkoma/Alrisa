import express from 'express';
import http from 'http';
import cors from 'cors';
import mqtt from 'mqtt';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const server = http.createServer(app);

const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'nexora_secret_token_2026';
const MQTT_BROKER = process.env.MQTT_BROKER_URL || 'mqtt://broker.emqx.io:1883';
const MQTT_PREFIX = process.env.MQTT_PREFIX || 'nexora';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// In-Memory Device State (Status Real-time Perangkat)
const devices = {
  pagar: { id: 'pagar', name: 'Pintu Gerbang Utama', state: false, value: 0, lastUpdated: new Date() },
  pintu_geser: { id: 'pintu_geser', name: 'Pintu Geser', state: false, value: 0, lastUpdated: new Date() },
  gorden: { id: 'gorden', name: 'Gorden Ruang Utama', state: false, value: 0, lastUpdated: new Date() },
  lampu_teras: { id: 'lampu_teras', name: 'Lampu Teras Depan', state: false, value: 0, lastUpdated: new Date() },
  pompa_toren: { id: 'pompa_toren', name: 'Pompa Toren Air', state: false, value: 0, lastUpdated: new Date() },
  pompa_kolam: { id: 'pompa_kolam', name: 'Pompa Kolam Ikan', state: false, value: 0, lastUpdated: new Date() },
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
// KONEKSI MQTT (Koneksi ke Flutter & Raspberry Pi / Gateway PLC)
// -------------------------------------------------------------
console.log(`🔌 Menghubungkan ke MQTT Broker: ${MQTT_BROKER}...`);
const mqttClient = mqtt.connect(MQTT_BROKER, {
  clientId: `nexora-cloud-hub-${Math.random().toString(16).substring(2, 8)}`,
  clean: true,
  connectTimeout: 5000,
});

mqttClient.on('connect', () => {
  console.log('✅ Berhasil terhubung ke Cloud MQTT Broker!');
  // Subscribe ke semua update status dari Raspberry Pi / PLC
  mqttClient.subscribe(`${MQTT_PREFIX}/+/state`, (err) => {
    if (!err) {
      console.log(`📡 Berhasil subscribe: ${MQTT_PREFIX}/+/state`);
    }
  });
  // Subscribe juga ke set command (untuk logging jika ada perintah dari app)
  mqttClient.subscribe(`${MQTT_PREFIX}/+/set`);
});

mqttClient.on('message', (topic, message) => {
  try {
    const parts = topic.split('/');
    if (parts.length < 3) return;
    const deviceId = parts[1];
    const type = parts[2]; // 'state' atau 'set'
    const payload = JSON.parse(message.toString());

    if (type === 'state' && devices[deviceId]) {
      devices[deviceId].state = Boolean(payload.state);
      if (payload.value !== undefined) devices[deviceId].value = payload.value;
      devices[deviceId].lastUpdated = new Date();
      addLog(deviceId, `Status fisik berubah -> ${payload.state ? 'AKTIF' : 'NONAKTIF'}`, 'PLC/GATEWAY');
    } else if (type === 'set') {
      addLog(deviceId, `Perintah kontrol -> ${payload.state ? 'ON / BUKA' : 'OFF / TUTUP'}`, 'FLUTTER_APP');
    }
  } catch (err) {
    console.error('⚠️ Gagal parse MQTT message:', err.message);
  }
});

mqttClient.on('error', (err) => {
  console.error('❌ MQTT Error:', err.message);
});

// -------------------------------------------------------------
// REST API ENDPOINTS
// -------------------------------------------------------------

// 1. Healthcheck / Info
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    system: 'NEXORA Cloud Backend',
    version: '1.0.0',
    mqttConnected: mqttClient.connected,
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

// 4. Kirim Perintah Kontrol (Bisa dipanggil oleh Flutter lewat HTTP jika tidak lewat MQTT langsung)
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

  // Publish ke MQTT agar ditangkap Raspberry Pi / PLC Gateway
  const topic = `${MQTT_PREFIX}/${deviceId}/set`;
  mqttClient.publish(topic, JSON.stringify(payload), { qos: 1 }, (err) => {
    if (err) {
      return res.status(500).json({ success: false, message: 'Gagal kirim perintah ke MQTT' });
    }

    addLog(deviceId, `Perintah via REST API -> ${state ? 'ON' : 'OFF'}`, 'REST_API');

    res.json({
      success: true,
      message: `Perintah ke ${deviceId} berhasil diteruskan ke Cloud Broker`,
      payloadSent: payload,
    });
  });
});

// 5. Ambil Log Aktivitas Terakhir
app.get('/api/logs', (req, res) => {
  res.json({
    success: true,
    total: activityLogs.length,
    data: activityLogs,
  });
});

// Jalankan Server
server.listen(PORT, () => {
  console.log('='.repeat(55));
  console.log(`🚀 NEXORA Cloud Backend Berjalan di Port: ${PORT}`);
  console.log(`🌐 Dashboard Monitoring: http://localhost:${PORT}`);
  console.log(`📡 API Devices: http://localhost:${PORT}/api/devices`);
  console.log('='.repeat(55));
});
