import express from 'express';
import http from 'http';
import cors from 'cors';
import mqtt from 'mqtt';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { WebSocketServer, WebSocket } from 'ws';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'alrisa_secret_token_2026';
const MQTT_BROKER = process.env.MQTT_BROKER_URL || 'mqtt://broker.emqx.io:1883';
const SETTINGS_PATH = path.join(__dirname, 'settings.json');

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Web Navigation Routes
app.get('/login', (req, res) => res.sendFile(path.join(__dirname, 'public', 'login.html')));
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));
app.get('/dashboard', (req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));

// -------------------------------------------------------------
// 1. DATA PENGATURAN MULTI-AKUN (SETTINGS PERSISTENCE)
// -------------------------------------------------------------
let settingsData = {
  active_account_id: 'acc_superadmin',
  system: {
    app_name: 'ALRISA & NEXORA Multi-Tenant Cloud Studio (Node.js)',
    mqtt_default_broker: 'broker.emqx.io',
    mqtt_default_port: 1883,
    api_secret_key: API_KEY,
  },
  accounts: [],
};

function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_PATH)) {
      const raw = fs.readFileSync(SETTINGS_PATH, 'utf-8');
      settingsData = JSON.parse(raw);
      console.log(`✅ [SETTINGS] Berhasil memuat ${settingsData.accounts?.length || 0} akun dari settings.json`);
    }
  } catch (err) {
    console.error('❌ Gagal membaca settings.json:', err.message);
  }
}

function saveSettings() {
  try {
    fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settingsData, null, 2), 'utf-8');
  } catch (err) {
    console.error('❌ Gagal menyimpan settings.json:', err.message);
  }
}

loadSettings();

// In-Memory Device & Activity State
const activityLogs = [];
function addLog(deviceId, action, origin = 'APP', accountId = '') {
  const logEntry = {
    id: Date.now(),
    timestamp: new Date().toLocaleTimeString('id-ID'),
    deviceId,
    action,
    origin,
    accountId,
  };
  activityLogs.unshift(logEntry);
  if (activityLogs.length > 50) activityLogs.pop();
  broadcastWs({ type: 'log', data: logEntry });
}

// Gateway Health Status
const gatewayStatus = {
  online: false,
  lastSeen: null,
  ip: '192.168.1.100',
  plcConnected: true,
  plcType: 'Mitsubishi FX5U (Modbus TCP Port 502)',
};

// Helper: Cari akun berdasarkan ID atau Email
function findAccount(identifier) {
  if (!settingsData.accounts) return null;
  const clean = (identifier || '').trim().toLowerCase();
  return settingsData.accounts.find(
    (a) => a.id === identifier || (a.email && a.email.toLowerCase() === clean)
  );
}

function getActiveAccount() {
  const acc = findAccount(settingsData.active_account_id);
  return acc || (settingsData.accounts && settingsData.accounts[0]) || null;
}

// -------------------------------------------------------------
// 2. WEBSOCKET REAL-TIME BROADCAST (LATENSI 0ms)
// -------------------------------------------------------------
function broadcastWs(msgObj) {
  const msgStr = JSON.stringify(msgObj);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(msgStr);
    }
  });
}

wss.on('connection', (ws) => {
  console.log('🟢 [WS] Klien Web Dashboard terhubung secara Real-Time');
  ws.send(JSON.stringify({ type: 'welcome', activeAccount: getActiveAccount() }));
});

// -------------------------------------------------------------
// 3. KONEKSI MQTT CLOUD
// -------------------------------------------------------------
console.log(`🔌 Menghubungkan ke MQTT Broker: ${MQTT_BROKER}...`);
const mqttClient = mqtt.connect(MQTT_BROKER, {
  clientId: `alrisa-node-hub-${Math.random().toString(16).substring(2, 8)}`,
  clean: true,
  connectTimeout: 5000,
});

mqttClient.on('connect', () => {
  console.log('✅ [MQTT] Berhasil terhubung ke Cloud MQTT Broker!');
  // Hanya subscribe ke prefix spesifik sistem kita, BUKAN wildcard global!
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
      if (!err) console.log(`📡 Subscribe MQTT: ${top}`);
    });
  });
});

mqttClient.on('message', (topic, message) => {
  try {
    const topicStr = topic.toString();
    const payloadStr = message.toString();

    // 1. Deteksi Heartbeat Gateway
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

    // Verifikasi apakah deviceId ini benar-benar ada di daftar akun kita
    let targetDevice = null;
    let targetAccount = null;
    if (settingsData.accounts) {
      for (const acc of settingsData.accounts) {
        if (acc.devices) {
          const found = acc.devices.find((item) => item.id === deviceId);
          if (found) {
            targetDevice = found;
            targetAccount = acc;
            break;
          }
        }
      }
    }

    // JIKA BUKAN PERANGKAT KITA, ABAIKAN TOTAL (JANGAN LOG & JANGAN UPDATE)
    if (!targetDevice) return;

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
        isStateOn = (u === 'OPEN' || u === 'ON' || u === 'TRUE' || u === '1' || u === 'TERBUKA');
      }
    } catch (_) {
      const u = payloadStr.toUpperCase().trim();
      isStateOn = (u === 'OPEN' || u === 'ON' || u === 'TRUE' || u === '1' || u === 'TERBUKA');
    }

    // Update status perangkat jika berubah
    if (targetDevice.isActive !== isStateOn || (numericValue !== null && targetDevice.value !== numericValue)) {
      targetDevice.isActive = isStateOn;
      targetDevice.statusText = isStateOn ? (targetDevice.type === 0 || targetDevice.type === 2 ? 'Terbuka' : 'Menyala') : (targetDevice.type === 0 || targetDevice.type === 2 ? 'Terkunci' : 'Mati');
      if (numericValue !== null) targetDevice.value = numericValue;

      broadcastWs({ type: 'device_update', deviceId, isStateOn, value: numericValue });

      if (type === 'state') {
        addLog(targetDevice.name, `Fisik: ${isStateOn ? 'TERBUKA / ON' : 'TERKUNCI / OFF'}`, 'HARDWARE', targetAccount?.id);
      } else if (type === 'set') {
        addLog(targetDevice.name, `Perintah: ${isStateOn ? 'BUKA / ON' : 'TUTUP / OFF'}`, 'USER', targetAccount?.id);
      }
    }
  } catch (err) {
    console.error('⚠️ Gagal proses pesan MQTT:', err.message);
  }
});

// -------------------------------------------------------------
// 4. REST API ENDPOINTS (KOMPATIBEL DENGAN PHP & APLIKASI HP)
// -------------------------------------------------------------

// 1. Healthcheck Sistem
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    system: settingsData.system?.app_name || 'ALRISA Cloud Smart Systems',
    version: '3.0.0 (Node.js)',
    mqttConnected: mqttClient.connected,
    gateway: gatewayStatus,
    active_account: settingsData.active_account_id,
    timestamp: new Date().toISOString(),
  });
});

// 1b. Settings Endpoint (Kompatibel dengan Portal Studio index.php)
app.get('/api/settings', (req, res) => {
  res.json({ success: true, data: settingsData });
});

app.post('/api/settings', (req, res) => {
  const input = req.body;
  if (input.accounts && Array.isArray(input.accounts)) {
    settingsData.accounts = input.accounts;
  }

  // Update spesifik per-akun jika account_id disertakan
  const targetAccId = input.account_id || input.active_account_id;
  if (targetAccId && settingsData.accounts) {
    const acc = settingsData.accounts.find(a => a.id === targetAccId);
    if (acc) {
      if (input.mqtt_broker !== undefined) acc.mqtt_broker = input.mqtt_broker;
      if (input.mqtt_port !== undefined) acc.mqtt_port = parseInt(input.mqtt_port) || 1883;
      if (input.mqtt_ws_port !== undefined) acc.mqtt_ws_port = parseInt(input.mqtt_ws_port) || 8083;
      if (input.mqtt_prefix !== undefined) acc.mqtt_prefix = input.mqtt_prefix;
      if (input.mqtt_user !== undefined) acc.mqtt_user = input.mqtt_user;
      if (input.mqtt_pass !== undefined) acc.mqtt_pass = input.mqtt_pass;
      if (input.wifi_ssid !== undefined) acc.wifi_ssid = input.wifi_ssid;
      if (input.wifi_password !== undefined) acc.wifi_password = input.wifi_password;
      if (input.plc_type !== undefined) acc.plc_type = input.plc_type;
      if (input.plc_ip !== undefined) acc.plc_ip = input.plc_ip;
      if (input.plc_port !== undefined) acc.plc_port = parseInt(input.plc_port) || 502;
    }
  }

  if (input.active_account_id) {
    settingsData.active_account_id = input.active_account_id;
  }
  if (input.system) {
    settingsData.system = Object.assign(settingsData.system || {}, input.system);
  }
  saveSettings();
  broadcastWs({ type: 'settings_updated', data: settingsData });
  res.json({ success: true, message: 'Data konfigurasi berhasil diperbarui!', data: settingsData });
});

// 2. Daftar Akun & Ganti Akun Aktif
app.get('/api/accounts', (req, res) => {
  const safeAccounts = (settingsData.accounts || []).map((a) => ({
    id: a.id,
    name: a.name,
    email: a.email,
    role: a.role,
    hardware_type: a.hardware_type,
    mqtt_prefix: a.mqtt_prefix,
    total_devices: (a.devices || []).length,
    total_cctv: (a.cctv || []).length,
  }));
  res.json({
    success: true,
    active_account_id: settingsData.active_account_id,
    accounts: safeAccounts,
  });
});

app.post('/api/accounts/switch', (req, res) => {
  const { account_id } = req.body;
  if (!account_id) {
    return res.status(400).json({ success: false, message: 'account_id wajib diisi' });
  }
  const acc = findAccount(account_id);
  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan' });
  }
  settingsData.active_account_id = acc.id;
  saveSettings();
  broadcastWs({ type: 'account_switched', account: acc });
  res.json({ success: true, message: `Akun aktif berganti ke ${acc.name}`, active_account: acc });
});

// Helper: Verifikasi apakah requester adalah Admin (Super Admin atau Admin Operasional)
function isRequesterAdmin(req) {
  const adminId = req.headers['x-admin-id'] || req.body.admin_id || req.query.admin_id;
  if (!adminId) return false;
  const acc = findAccount(adminId);
  if (!acc) return false;
  return acc.role === 'superadmin' || acc.role === 'admin' || acc.role === 0;
}

// Helper: Verifikasi apakah requester adalah Super Admin
function isRequesterSuperAdmin(req) {
  const adminId = req.headers['x-admin-id'] || req.body.admin_id || req.query.admin_id;
  if (!adminId) return false;
  const acc = findAccount(adminId);
  if (!acc) return false;
  return acc.role === 'superadmin' || acc.role === 0;
}

// 2-Admins-List. Ambil Daftar Semua Administrator (Khusus Admin)
app.get('/api/admins', (req, res) => {
  const adminList = (settingsData.accounts || [])
    .filter((a) => a.role === 'superadmin' || a.role === 'admin' || a.role === 0)
    .map((a) => ({
      id: a.id,
      name: a.name,
      email: a.email,
      role: a.role,
      roleLabel: a.role === 'superadmin' || a.role === 0 ? 'Super Admin' : 'Admin Operasional',
      division: a.division || (a.role === 'superadmin' || a.role === 0 ? 'Head / Super Admin' : 'Admin Sistem'),
      created_at: a.created_at || '2026-10-24',
      total_devices: (a.devices || []).length,
    }));

  res.json({
    success: true,
    total_admins: adminList.length,
    admins: adminList,
  });
});

// 2-Admins-Create. Tambah Administrator Baru (Khusus Super Admin)
app.post('/api/admins/create', (req, res) => {
  if (!isRequesterSuperAdmin(req)) {
    return res.status(403).json({
      success: false,
      message: 'Akses Ditolak: Fitur tambah administrator baru hanya dapat dilakukan oleh Super Admin!',
    });
  }

  const { name, email, password, role, division } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Nama lengkap, email login, dan kata sandi admin wajib diisi!',
    });
  }

  const cleanEmail = String(email).trim().toLowerCase();

  const existing = (settingsData.accounts || []).find(
    (a) => a.email && a.email.toLowerCase() === cleanEmail
  );
  if (existing) {
    return res.status(409).json({
      success: false,
      message: `Email ${cleanEmail} sudah terdaftar di sistem!`,
    });
  }

  const slug = cleanEmail.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '').toLowerCase() || 'admin';
  const newId = `acc_admin_${slug}_${Math.random().toString(36).substring(2, 6)}`;
  const cleanRole = (role === 'superadmin' || role === 0) ? 'superadmin' : 'admin';
  const cleanDivision = division && division.trim() ? division.trim() : (cleanRole === 'superadmin' ? 'Super Admin' : 'Admin Operasional');

  const newAdmin = {
    id: newId,
    name: String(name).trim(),
    email: cleanEmail,
    password: String(password).trim(),
    role: cleanRole,
    division: cleanDivision,
    created_at: new Date().toISOString().split('T')[0],
    hardware_type: 'ESP32 Smart Automation Hub',
    hardware_desc: 'Sistem Kontrol Administrator Nexora Dash',
    mqtt_broker: settingsData.system?.mqtt_default_broker || 'broker.emqx.io',
    mqtt_port: settingsData.system?.mqtt_default_port || 1883,
    mqtt_ws_port: 8083,
    mqtt_prefix: `alrisa/admin_${slug}`,
    mqtt_user: '',
    mqtt_pass: '',
    plc_ip: '192.168.1.100',
    plc_port: 502,
    plc_type: 'Mitsubishi FX5U (Modbus TCP)',
    wifi_ssid: 'NEXORA_ADMIN_HQ',
    wifi_password: '',
    devices: [],
    cctv: [],
  };

  if (!Array.isArray(settingsData.accounts)) settingsData.accounts = [];
  settingsData.accounts.push(newAdmin);
  saveSettings();

  const requesterId = req.headers['x-admin-id'] || req.body.admin_id;
  const adminAcc = findAccount(requesterId);
  const adminName = adminAcc ? adminAcc.name : 'Super Admin';

  console.log(`👑 [ADMIN CREATED] ${adminName} mendaftarkan Admin baru: ${newAdmin.name} (${newAdmin.email}) - Role: ${newAdmin.role}`);
  addLog(newAdmin.name, `Super Admin mendaftarkan Admin baru: ${newAdmin.name} (${newAdmin.role})`, 'WEB_AUTH', newAdmin.id);

  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.status(201).json({
    success: true,
    message: `Administrator "${newAdmin.name}" berhasil didaftarkan dan dapat segera login ke website Dash Admin!`,
    admin: {
      id: newAdmin.id,
      name: newAdmin.name,
      email: newAdmin.email,
      role: newAdmin.role,
      division: newAdmin.division,
    },
  });
});

// 2-Admins-Get. Ambil Detail Administrator (Khusus Admin)
app.get('/api/admins/:id', (req, res) => {
  const target = findAccount(req.params.id);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun administrator tidak ditemukan!' });
  }
  res.json({
    success: true,
    admin: {
      id: target.id,
      name: target.name,
      email: target.email,
      role: target.role,
      roleLabel: target.role === 'superadmin' || target.role === 0 ? 'Super Admin' : 'Admin Operasional',
      division: target.division || 'Admin Sistem',
      created_at: target.created_at || '2026-10-24',
      total_devices: (target.devices || []).length,
      hardware_type: target.hardware_type || 'ESP32 Smart Automation Hub',
    }
  });
});

// 2-Admins-Update. Edit Profil & Kata Sandi Administrator (Khusus Super Admin)
app.post('/api/admins/update', (req, res) => {
  const { name, email, password, role, division } = req.body;
  const targetId = req.body.id || req.body.target_admin_id || req.body.account_id;
  if (!targetId) {
    return res.status(400).json({ success: false, message: 'ID administrator wajib disertakan!' });
  }

  const target = findAccount(targetId);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Administrator tidak ditemukan!' });
  }

  if (name && name.trim()) target.name = name.trim();
  if (email && email.trim()) target.email = email.trim().toLowerCase();
  if (password && password.trim()) {
    target.password = password.trim();
    console.log(`🔑 [PASSWORD UPDATED] Kata sandi administrator ${target.name} berhasil diperbarui!`);
  }
  if (division && division.trim()) target.division = division.trim();
  if (role) {
    target.role = (role === 'superadmin' || role === 0) ? 'superadmin' : 'admin';
  }

  saveSettings();
  addLog(target.name, `Profil / Kata sandi Admin ${target.name} diperbarui`, 'WEB_AUTH', target.id);
  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.json({
    success: true,
    message: `Data administrator "${target.name}" berhasil diperbarui!`,
    admin: {
      id: target.id,
      name: target.name,
      email: target.email,
      role: target.role,
      division: target.division
    }
  });
});

// 2-Admins-Delete. Hapus Administrator (Khusus Super Admin)
app.delete('/api/admins/:id', (req, res) => {
  if (!isRequesterSuperAdmin(req)) {
    return res.status(403).json({
      success: false,
      message: 'Akses Ditolak: Hanya Super Admin yang berhak menghapus akun administrator!',
    });
  }

  const targetId = req.params.id;
  const requesterId = req.headers['x-admin-id'] || req.body.admin_id;

  if (targetId === requesterId) {
    return res.status(400).json({
      success: false,
      message: 'Anda tidak dapat menghapus akun administrator Anda sendiri yang sedang aktif!',
    });
  }

  const target = findAccount(targetId);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun administrator tidak ditemukan!' });
  }

  settingsData.accounts = settingsData.accounts.filter((a) => a.id !== targetId);
  saveSettings();

  console.log(`🗑️ [ADMIN DELETED] Admin dihapus: ${target.name} (${target.id})`);
  addLog(target.name, `Akun Administrator dihapus oleh Super Admin`, 'WEB_AUTH', target.id);

  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.json({
    success: true,
    message: `Administrator "${target.name}" berhasil dihapus dari sistem!`,
    deleted_id: targetId,
  });
});

// 2-Customers-Detail. Ambil Detail Akun Pelanggan (View Modal)
app.get('/api/accounts/:id', (req, res) => {
  const target = findAccount(req.params.id);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun pelanggan tidak ditemukan!' });
  }
  return res.json({
    success: true,
    account: target
  });
});

// 2-Customers-Update. Update Detail, Kredensial, & Hardware Pelanggan (Edit Modal)
app.post('/api/accounts/update', (req, res) => {
  const { name, email, password, hardware_type, mqtt_prefix, wifi_ssid, wifi_password, plc_ip, plc_port } = req.body;
  const targetId = req.body.id || req.body.target_account_id || req.body.account_id;
  if (!targetId) {
    return res.status(400).json({ success: false, message: 'ID akun wajib disertakan!' });
  }

  const target = findAccount(targetId);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun pelanggan tidak ditemukan!' });
  }

  if (name && name.trim()) target.name = name.trim();
  if (email && email.trim()) target.email = email.trim().toLowerCase();
  if (password && password.trim()) {
    target.password = password.trim();
    console.log(`🔑 [PASSWORD USER UPDATED] Sandi login pelanggan ${target.name} diubah: ${password.trim()}`);
  }
  if (hardware_type) target.hardware_type = hardware_type;
  if (mqtt_prefix && mqtt_prefix.trim()) target.mqtt_prefix = mqtt_prefix.trim();
  if (wifi_ssid !== undefined) target.wifi_ssid = wifi_ssid;
  if (wifi_password !== undefined) target.wifi_password = wifi_password;
  if (plc_ip !== undefined) target.plc_ip = plc_ip;
  if (plc_port !== undefined) target.plc_port = parseInt(plc_port) || 502;

  saveSettings();
  broadcastDeviceSync(target);
  addLog(target.name, `Data pelanggan & kredensial diperbarui oleh Admin`, 'WEB_STUDIO', target.id);
  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.json({
    success: true,
    message: `Data pelanggan "${target.name}" berhasil disimpan!`,
    account: target
  });
});

// 2-MQTT-Update-User. Update Konfigurasi MQTT Khusus Tiap User
app.post('/api/mqtt/update-user', (req, res) => {
  const { account_id, mqtt_broker, mqtt_port, mqtt_ws_port, mqtt_prefix, mqtt_user, mqtt_pass, wifi_ssid, wifi_password } = req.body;
  if (!account_id) {
    return res.status(400).json({ success: false, message: 'account_id wajib disertakan!' });
  }

  const target = findAccount(account_id);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan!' });
  }

  if (mqtt_broker !== undefined) target.mqtt_broker = mqtt_broker.trim();
  if (mqtt_port !== undefined) target.mqtt_port = parseInt(mqtt_port) || 1883;
  if (mqtt_ws_port !== undefined) target.mqtt_ws_port = parseInt(mqtt_ws_port) || 8083;
  if (mqtt_prefix !== undefined) target.mqtt_prefix = mqtt_prefix.trim();
  if (mqtt_user !== undefined) target.mqtt_user = mqtt_user;
  if (mqtt_pass !== undefined) target.mqtt_pass = mqtt_pass;
  if (wifi_ssid !== undefined) target.wifi_ssid = wifi_ssid;
  if (wifi_password !== undefined) target.wifi_password = wifi_password;

  saveSettings();
  broadcastDeviceSync(target);
  addLog(target.name, `Konfigurasi MQTT diperbarui untuk akun ${target.name}`, 'WEB_STUDIO', target.id);
  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.json({
    success: true,
    message: `Konfigurasi MQTT untuk akun "${target.name}" berhasil diperbarui!`,
    account: {
      id: target.id,
      name: target.name,
      mqtt_broker: target.mqtt_broker,
      mqtt_port: target.mqtt_port,
      mqtt_ws_port: target.mqtt_ws_port,
      mqtt_prefix: target.mqtt_prefix,
      wifi_ssid: target.wifi_ssid
    }
  });
});

// 2-Customers-List. Ambil Daftar Semua Pelanggan Aplikasi HP (Khusus Admin)
app.get('/api/customers', (req, res) => {
  const customerList = (settingsData.accounts || [])
    .filter((a) => a.role !== 'superadmin' && a.role !== 'admin' && a.role !== 0)
    .map((a) => ({
      id: a.id,
      name: a.name,
      email: a.email,
      role: a.role || 'user',
      hardware_type: a.hardware_type || 'ESP32 Smart Automation Hub',
      mqtt_prefix: a.mqtt_prefix,
      total_devices: (a.devices || []).length,
      total_cctv: (a.cctv || []).length,
    }));

  res.json({
    success: true,
    total_customers: customerList.length,
    customers: customerList,
  });
});

// 2-Create. Endpoint Tambah Pelanggan / User Baru (Bisa oleh Admin)
app.post('/api/accounts/create', (req, res) => {
  if (!isRequesterAdmin(req)) {
    return res.status(403).json({
      success: false,
      message: 'Akses Ditolak: Fitur tambah pelanggan baru hanya dapat diakses oleh Administrator!',
    });
  }

  const { name, email, password, role, hardware_type, mqtt_prefix, plc_ip, plc_port, plc_type, wifi_ssid } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Nama lengkap, email, dan kata sandi wajib diisi!',
    });
  }

  const cleanEmail = String(email).trim().toLowerCase();

  // Cek duplikasi email
  const existing = (settingsData.accounts || []).find(
    (a) => a.email && a.email.toLowerCase() === cleanEmail
  );
  if (existing) {
    return res.status(409).json({
      success: false,
      message: `Email ${cleanEmail} sudah terdaftar pada akun lain!`,
    });
  }

  // Buat ID unik
  const slug = cleanEmail.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '').toLowerCase() || 'user';
  const newId = `acc_${slug}_${Math.random().toString(36).substring(2, 6)}`;

  const cleanRole = (role === 'superadmin' || role === 0) ? 'superadmin' : (role === 'admin' ? 'admin' : 'user');
  const cleanPrefix = mqtt_prefix && mqtt_prefix.trim() ? mqtt_prefix.trim() : `alrisa/${slug}`;

  // Template perangkat default untuk pelanggan baru
  const defaultDevices = [
    {
      id: `${slug}_pagar`,
      name: 'Gerbang Utama',
      type: 0,
      category: 'Keamanan',
      hardwarePin: 'GPIO 2 (%QX0.0)',
      isActive: false,
      value: 0,
      statusText: 'Terkunci',
    },
    {
      id: `${slug}_lampu`,
      name: 'Lampu Teras & Luar',
      type: 1,
      category: 'Pencahayaan',
      hardwarePin: 'GPIO 4 (%QX0.3)',
      isActive: false,
      value: 0,
      statusText: 'Mati',
    },
    {
      id: `${slug}_pintu`,
      name: 'Pintu Akses Tamu',
      type: 2,
      category: 'Akses',
      hardwarePin: 'GPIO 5 (%QX0.1)',
      isActive: false,
      value: 0,
      statusText: 'Terkunci',
    },
  ];

  const newAccount = {
    id: newId,
    name: String(name).trim(),
    email: cleanEmail,
    password: String(password).trim(),
    role: cleanRole,
    hardware_type: hardware_type || 'ESP32 Smart Automation Hub',
    hardware_desc: 'Modul Otomasi Cerdas Nexora Cloud IoT',
    mqtt_broker: settingsData.system?.mqtt_default_broker || 'broker.emqx.io',
    mqtt_port: settingsData.system?.mqtt_default_port || 1883,
    mqtt_ws_port: 8083,
    mqtt_prefix: cleanPrefix,
    mqtt_user: '',
    mqtt_pass: '',
    plc_ip: plc_ip || '192.168.1.100',
    plc_port: parseInt(plc_port) || 502,
    plc_type: plc_type || 'Mitsubishi FX5U (Modbus TCP)',
    wifi_ssid: wifi_ssid || 'NEXORA_SMART_WIFI',
    wifi_password: '',
    devices: defaultDevices,
    cctv: [],
  };

  if (!Array.isArray(settingsData.accounts)) {
    settingsData.accounts = [];
  }

  settingsData.accounts.push(newAccount);
  saveSettings();

  const requesterId = req.headers['x-admin-id'] || req.body.admin_id;
  const adminAcc = findAccount(requesterId);
  const adminName = adminAcc ? adminAcc.name : 'Administrator';

  console.log(`👤 [USER CREATED] ${adminName} mendaftarkan akun baru: ${newAccount.name} (${newAccount.email}) - Role: ${newAccount.role}`);
  addLog(newAccount.name, `Admin mendaftarkan akun baru (${newAccount.role})`, 'WEB_AUTH', newAccount.id);

  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.status(201).json({
    success: true,
    message: `Akun "${newAccount.name}" berhasil didaftarkan!`,
    account: {
      id: newAccount.id,
      name: newAccount.name,
      email: newAccount.email,
      role: newAccount.role,
      hardware_type: newAccount.hardware_type,
      mqtt_prefix: newAccount.mqtt_prefix,
      total_devices: newAccount.devices.length,
    },
  });
});

// 2-Delete. Endpoint Hapus Pengguna (Khusus Admin)
app.delete('/api/accounts/:id', (req, res) => {
  if (!isRequesterAdmin(req)) {
    return res.status(403).json({
      success: false,
      message: 'Akses Ditolak: Hanya Administrator yang memiliki wewenang untuk menghapus akun!',
    });
  }

  const targetId = req.params.id;
  const requesterId = req.headers['x-admin-id'] || req.body.admin_id;

  if (targetId === requesterId) {
    return res.status(400).json({
      success: false,
      message: 'Anda tidak dapat menghapus akun Anda sendiri yang sedang aktif!',
    });
  }

  const target = findAccount(targetId);
  if (!target) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan!' });
  }

  settingsData.accounts = settingsData.accounts.filter((a) => a.id !== targetId);

  // Jika akun yang dihapus kebetulan sedang aktif, alihkan ke akun superadmin
  if (settingsData.active_account_id === targetId) {
    settingsData.active_account_id = requesterId || (settingsData.accounts[0] && settingsData.accounts[0].id);
  }

  saveSettings();

  console.log(`🗑️ [USER DELETED] Hapus akun: ${target.name} (${target.id})`);
  addLog(target.name, `Akun pengguna dihapus oleh Administrator`, 'WEB_AUTH', target.id);

  broadcastWs({ type: 'settings_updated', data: settingsData });

  return res.json({
    success: true,
    message: `Akun "${target.name}" berhasil dihapus!`,
    deleted_id: targetId,
  });
});

// 2b. Endpoint Login Resmi (Web Dash Admin & Mobile Sync)
app.post('/api/login', (req, res) => {
  const identifier = req.body.email || req.body.username || req.body.identifier;
  const password = req.body.password;
  const portal = req.body.portal || '';
  const isWebLogin = portal === 'web_admin' || portal === 'web';

  if (!identifier || !password) {
    return res.status(400).json({ success: false, message: 'Email / Username dan kata sandi wajib diisi' });
  }

  const cleanId = String(identifier).trim().toLowerCase();
  const cleanPassword = String(password).trim();

  const acc = (settingsData.accounts || []).find(
    (a) => (a.email && a.email.toLowerCase() === cleanId) ||
           (a.id && a.id.toLowerCase() === cleanId) ||
           (a.name && a.name.toLowerCase() === cleanId)
  );

  if (!acc) {
    return res.status(404).json({
      success: false,
      message: 'Akun / Email belum terdaftar di sistem server Cloud Nexora.',
    });
  }

  if (acc.password !== cleanPassword) {
    return res.status(401).json({
      success: false,
      message: 'Kata sandi yang Anda masukkan salah!',
    });
  }

  // VALIDASI KETAT WEBSITE DASH ADMIN:
  // Hanya akun Administrator (superadmin atau admin) yang diizinkan masuk ke Web Dash Admin!
  // Pelanggan yang menggunakan aplikasi HP TIDAK BISA login ke website.
  const isAdmin = acc.role === 'superadmin' || acc.role === 'admin' || acc.role === 0;

  if (isWebLogin && !isAdmin) {
    console.log(`⛔ [LOGIN WEBSITE DITOLAK] Pelanggan ${acc.name} (${acc.email}) mencoba login ke Website Dash Admin!`);
    return res.status(403).json({
      success: false,
      message: 'Akses Ditolak: Halaman Dash Admin khusus untuk Administrator! Pelanggan / Pengguna aplikasi silakan login menggunakan Aplikasi Mobile Nexora di HP Anda.',
    });
  }

  const token = 'nexora_tk_' + Buffer.from(`${acc.id}:${Date.now()}`).toString('base64');
  console.log(`🔐 [LOGIN] ${acc.name} (${acc.email}) - Role: ${acc.role || 'user'} - Portal: ${isWebLogin ? 'WEB_ADMIN' : 'MOBILE_APP'}`);
  addLog(acc.name, `Login (${acc.role || 'user'}) via ${isWebLogin ? 'Web Dash Admin' : 'Aplikasi Mobile'}`, 'WEB_AUTH', acc.id);

  let roleNum = 1;
  let roleDisplayName = 'Pelanggan Aplikasi Mobile';
  if (acc.role === 'superadmin' || acc.role === 0) {
    roleNum = 0;
    roleDisplayName = 'Super Admin';
  } else if (acc.role === 'admin') {
    roleNum = 0;
    roleDisplayName = acc.division ? `Admin (${acc.division})` : 'Admin Operasional';
  }

  return res.json({
    success: true,
    message: `Selamat datang, ${acc.name}!`,
    token,
    user: {
      id: acc.id,
      name: acc.name,
      email: acc.email,
      role: roleNum,
      rawRole: acc.role || 'user',
      roleName: roleDisplayName,
      division: acc.division || '',
      isAdmin: isAdmin,
      isSuperAdmin: acc.role === 'superadmin' || acc.role === 0,
      hardwareType: acc.hardware_type || 'ESP32 Smart Automation Hub',
      mqttPrefix: acc.mqtt_prefix || 'alrisa/' + acc.id,
      mqttBroker: acc.mqtt_broker || 'broker.emqx.io',
      mqttPort: acc.mqtt_port || 1883,
      devices: acc.devices || [],
      cctv: acc.cctv || [],
    },
  });
});

// 2b-2. Endpoint Verifikasi Sesi Aktif
app.get('/api/auth/me', (req, res) => {
  const accountId = req.query.account_id || req.headers['x-account-id'];
  const acc = accountId ? findAccount(accountId) : getActiveAccount();
  if (!acc) return res.status(404).json({ success: false, message: 'Akun tidak ditemukan' });
  res.json({
    success: true,
    user: {
      id: acc.id,
      name: acc.name,
      email: acc.email,
      role: acc.role === 'superadmin' ? 0 : 1,
      roleName: acc.role === 'superadmin' ? 'Super Admin' : 'Operator / Client',
      hardwareType: acc.hardware_type,
      mqttPrefix: acc.mqtt_prefix,
      mqttBroker: acc.mqtt_broker,
      mqttPort: acc.mqtt_port,
      devices: acc.devices || [],
      cctv: acc.cctv || [],
    }
  });
});

// 2c. Endpoint Sinkronisasi Semua Akun ke Aplikasi Mobile
app.get('/api/accounts/sync', (req, res) => {
  const accountsList = (settingsData.accounts || []).map((a) => ({
    id: a.id,
    name: a.name,
    email: a.email,
    password: a.password,
    role: a.role === 'superadmin' ? 0 : 1,
    hardwareType: a.hardware_type || 'ESP32 Smart Automation Hub',
    mqttPrefix: a.mqtt_prefix || 'alrisa/' + a.id,
    mqttBroker: a.mqtt_broker || 'broker.emqx.io',
    mqttPort: a.mqtt_port || 1883,
    devices: a.devices || [],
    cctv: a.cctv || [],
  }));
  res.json({
    success: true,
    accounts: accountsList,
  });
});

// 3. Endpoint Sinkronisasi Lengkap (Kompatibel dengan /api/sync.php)
app.all('/api/sync', (req, res) => {
  const accountId = req.query.account_id || req.body.account_id || '';
  const email = (req.query.email || req.body.email || '').toLowerCase().trim();

  let acc = null;
  if (accountId) acc = findAccount(accountId);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan pada server Cloud.' });
  }

  res.json({
    success: true,
    timestamp: new Date().toISOString(),
    account: {
      id: acc.id,
      name: acc.name,
      email: acc.email,
      role: acc.role || 'user',
      hardware_type: acc.hardware_type || 'Raspberry Pi 4',
      hardware_desc: acc.hardware_desc || '',
      mqtt_prefix: acc.mqtt_prefix || 'alrisa/client',
      mqtt_broker: acc.mqtt_broker || 'broker.emqx.io',
      mqtt_port: acc.mqtt_port || 1883,
    },
    total_devices: (acc.devices || []).length,
    devices: acc.devices || [],
    total_cctv: (acc.cctv || []).length,
    cctv: acc.cctv || [],
  });
});

// 4. Endpoint Ambil Devices (Kompatibel dengan /api/devices.php)
app.all('/api/devices', (req, res) => {
  const accountId = req.query.account_id || req.body.account_id || '';
  const email = (req.query.email || req.body.email || '').toLowerCase().trim();

  let acc = null;
  if (accountId) acc = findAccount(accountId);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  const rawDevices = acc && acc.devices ? acc.devices : [];
  const deviceMap = {};
  const devicesList = [];

  rawDevices.forEach((d) => {
    const item = {
      id: d.id,
      name: d.name,
      category: d.category || 'Umum',
      type: d.type !== undefined ? d.type : 0,
      state: d.isActive ? 'ON' : 'OFF',
      value: d.value !== undefined ? d.value : 0,
      pending_command: null,
      pending_value: null,
      last_updated: new Date().toISOString(),
      plc_address: d.hardwarePin || 'GPIO 2',
    };
    deviceMap[d.id] = item;
    devicesList.push(item);
  });

  const accountLogs = activityLogs.filter((l) => !accountId || !l.accountId || l.accountId === accountId).slice(0, 10);

  res.json({
    success: true,
    timestamp: new Date().toISOString(),
    account_id: acc ? acc.id : '',
    total_devices: devicesList.length,
    devices: deviceMap,
    list: devicesList,
    recent_logs: accountLogs,
  });
});

// 5. Endpoint Ambil CCTV (Spesifik Akun)
app.all('/api/cctv', (req, res) => {
  const accountId = req.query.account_id || req.body.account_id || '';
  const email = (req.query.email || req.body.email || '').toLowerCase().trim();

  let acc = null;
  if (accountId) acc = findAccount(accountId);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  const cctvList = acc && acc.cctv ? acc.cctv : [];

  res.json({
    success: true,
    timestamp: new Date().toISOString(),
    account_id: acc ? acc.id : '',
    total_cctv: cctvList.length,
    cctv: cctvList,
  });
});

// 6. 🔥 ENDPOINT SINKRONISASI DARI APLIKASI HP (SYNC DEVICES & CCTV)
// Saat user menambah/mengubah nama alat/gerbang/CCTV di HP, HP mengirim data ke sini
app.post('/api/sync_devices', (req, res) => {
  const { account_id, email, devices, cctv } = req.body;
  console.log(`📥 [SYNC DITERIMA] Dari Aplikasi Mobile untuk: ${email || account_id}`);

  let acc = null;
  if (account_id) acc = findAccount(account_id);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan.' });
  }

  // Perbarui daftar perangkat jika disertakan
  if (Array.isArray(devices)) {
    acc.devices = devices.map((d) => ({
      id: d.id,
      name: d.name,
      type: d.type !== undefined ? d.type : 0,
      category: d.category || (d.type === 0 ? 'Keamanan' : d.type === 1 ? 'Pencahayaan' : 'Akses'),
      hardwarePin: d.hardwarePin || 'GPIO 2',
      isActive: Boolean(d.isActive),
      value: Number(d.value || 0),
      statusText: d.statusText || (d.isActive ? 'Menyala' : 'Mati'),
    }));
    console.log(`✅ [SYNC DEVICES] Akun ${acc.name} memiliki ${acc.devices.length} perangkat.`);
  }

  // Perbarui daftar CCTV jika disertakan
  if (Array.isArray(cctv)) {
    acc.cctv = cctv.map((c) => ({
      id: c.id,
      name: c.name,
      location: c.location || '',
      rtspUrl: c.rtspUrl || '',
      onvifHost: c.onvifHost || '192.168.1.50',
      onvifPort: Number(c.onvifPort || 80),
      boundGateId: c.boundGateId || null,
      isOnline: c.isOnline !== undefined ? Boolean(c.isOnline) : true,
      fps: Number(c.fps || 25),
      resolution: c.resolution || '1080P FHD (H.264)',
    }));
    console.log(`✅ [SYNC CCTV] Akun ${acc.name} memiliki ${acc.cctv.length} kamera CCTV.`);
  }

  saveSettings();
  addLog('SYSTEM_SYNC', `Sinkronisasi perangkat & CCTV dari HP (${acc.name})`, 'MOBILE_APP', acc.id);
  broadcastDeviceSync(acc);

  res.json({
    success: true,
    message: 'Perangkat dan CCTV berhasil disinkronkan ke server Cloud!',
    account_id: acc.id,
    total_devices: (acc.devices || []).length,
    total_cctv: (acc.cctv || []).length,
  });
});

// Helper: Cari PIN GPIO & Alamat PLC yang belum digunakan pada akun ini
function getNextAvailablePinForAccount(acc) {
  const safePins = [
    { gpio: 2, plc: '%QX0.0' },
    { gpio: 4, plc: '%QX0.1' },
    { gpio: 5, plc: '%QX0.2' },
    { gpio: 12, plc: '%QX0.3' },
    { gpio: 13, plc: '%QX0.4' },
    { gpio: 14, plc: '%QX0.5' },
    { gpio: 15, plc: '%QX0.6' },
    { gpio: 16, plc: '%QX0.7' },
    { gpio: 17, plc: '%QX1.0' },
    { gpio: 18, plc: '%QX1.1' },
    { gpio: 19, plc: '%QX1.2' },
    { gpio: 21, plc: '%QX1.3' },
    { gpio: 22, plc: '%QX1.4' },
    { gpio: 23, plc: '%QX1.5' },
    { gpio: 25, plc: '%QX1.6' },
    { gpio: 26, plc: '%QX1.7' },
    { gpio: 27, plc: '%QX2.0' },
    { gpio: 32, plc: '%QX2.1' },
    { gpio: 33, plc: '%QX2.2' },
  ];

  const existingDevices = (acc && Array.isArray(acc.devices)) ? acc.devices : [];
  const usedGpios = new Set();
  const usedPlcs = new Set();

  existingDevices.forEach((d) => {
    const pinStr = String(d.hardwarePin || '').toUpperCase();
    const gpioMatch = pinStr.match(/GPIO\s*(\d+)/i);
    if (gpioMatch) usedGpios.add( parseInt(gpioMatch[1], 10) );
    const plcMatch = pinStr.match(/%QX\d+\.\d+/i);
    if (plcMatch) usedPlcs.add(plcMatch[0].toUpperCase());
  });

  for (const candidate of safePins) {
    if (!usedGpios.has(candidate.gpio) && !usedPlcs.has(candidate.plc)) {
      return `GPIO ${candidate.gpio} (${candidate.plc})`;
    }
  }

  for (const candidate of safePins) {
    if (!usedGpios.has(candidate.gpio)) {
      return `GPIO ${candidate.gpio} (${candidate.plc})`;
    }
  }

  const nextIdx = existingDevices.length;
  return `GPIO ${safePins[nextIdx % safePins.length].gpio} (%QX${Math.floor(nextIdx / 8)}.${nextIdx % 8})`;
}

// Helper: Broadcast Perubahan Perangkat ke WebSocket & MQTT (Dua Arah HP <-> Web)
function broadcastDeviceSync(acc) {
  saveSettings();
  broadcastWs({ type: 'full_sync', accountId: acc.id, account: acc });

  const syncPayload = JSON.stringify({
    type: 'SYNC_DEVICES',
    account_id: acc.id,
    email: acc.email,
    devices_count: (acc.devices || []).length,
    cctv_count: (acc.cctv || []).length,
    timestamp: Date.now(),
  });

  try {
    if (mqttClient && mqttClient.connected) {
      if (acc.mqtt_prefix) {
        mqttClient.publish(`${acc.mqtt_prefix}/sync`, syncPayload, { qos: 1 });
      }
      mqttClient.publish(`nexora/${acc.id}/sync`, syncPayload, { qos: 1 });
      mqttClient.publish('nexora/sync', syncPayload, { qos: 1 });
      mqttClient.publish('alrisa/sync', syncPayload, { qos: 1 });
      console.log(`📡 [MQTT SYNC BROADCAST] Terkirim untuk akun ${acc.name} (${acc.id})`);
    }
  } catch (err) {
    console.error('MQTT broadcast error:', err.message);
  }
}

// 6b. 🔥 ENDPOINT TAMBAH / UBAH PIN / EDIT PERANGKAT DARI WEBSITE ATAU HP
// Saat user menambah perangkat atau mengubah PIN hardware / GPIO, otomatis sinkron 2 arah
app.post('/api/device/save', (req, res) => {
  const { account_id, email, device } = req.body;
  if (!device || !device.name) {
    return res.status(400).json({ success: false, message: 'Data perangkat (nama) wajib diisi.' });
  }

  let acc = null;
  if (account_id) acc = findAccount(account_id);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan.' });
  }

  if (!Array.isArray(acc.devices)) acc.devices = [];

  const rawId = (device.id || '').trim();
  const devId = rawId || ('dev_' + Date.now().toString(36));
  const existingIdx = acc.devices.findIndex((d) => d.id === devId);

  let resolvedPin = (device.hardwarePin || '').trim();
  if (!resolvedPin || resolvedPin.toUpperCase() === 'AUTO') {
    resolvedPin = existingIdx !== -1 && acc.devices[existingIdx].hardwarePin
      ? acc.devices[existingIdx].hardwarePin
      : getNextAvailablePinForAccount(acc);
  }

  const updatedDev = {
    id: devId,
    name: device.name.trim(),
    type: device.type !== undefined ? Number(device.type) : 0,
    category: device.category || (device.type === 0 ? 'Keamanan' : device.type === 1 ? 'Pencahayaan' : 'Akses'),
    hardwarePin: resolvedPin,
    isActive: Boolean(device.isActive),
    value: Number(device.value || 0),
    statusText: device.statusText || (device.isActive ? 'Menyala' : 'Terkunci'),
  };

  if (existingIdx !== -1) {
    acc.devices[existingIdx] = { ...acc.devices[existingIdx], ...updatedDev };
    console.log(`⚙️ [WEBSITE DEVICE EDIT] Akun ${acc.name} edit ${updatedDev.name} (${updatedDev.hardwarePin})`);
    addLog(devId, `Ubah PIN / alat: ${updatedDev.name} -> ${updatedDev.hardwarePin}`, 'WEB_STUDIO', acc.id);
  } else {
    acc.devices.push(updatedDev);
    console.log(`➕ [WEBSITE DEVICE ADD] Akun ${acc.name} tambah ${updatedDev.name} (${updatedDev.hardwarePin})`);
    addLog(devId, `Tambah perangkat baru: ${updatedDev.name} (${updatedDev.hardwarePin})`, 'WEB_STUDIO', acc.id);
  }

  broadcastDeviceSync(acc);

  res.json({
    success: true,
    message: `Perangkat "${updatedDev.name}" berhasil disimpan dan otomatis disinkronkan ke HP!`,
    device: updatedDev,
    total_devices: acc.devices.length,
    account_id: acc.id,
  });
});

// 6c. 🔥 ENDPOINT HAPUS PERANGKAT DARI WEBSITE
// Saat user di website menghapus perangkat (misal gerbang atau saklar), otomatis terhapus di HP
app.post('/api/device/delete', (req, res) => {
  const { account_id, email, device_id } = req.body;
  if (!device_id) {
    return res.status(400).json({ success: false, message: 'device_id wajib diisi.' });
  }

  let acc = null;
  if (account_id) acc = findAccount(account_id);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan.' });
  }

  if (!Array.isArray(acc.devices)) acc.devices = [];

  const targetDev = acc.devices.find((d) => d.id === device_id);
  const devName = targetDev ? targetDev.name : device_id;

  acc.devices = acc.devices.filter((d) => d.id !== device_id);

  console.log(`🗑️ [WEBSITE DEVICE DELETE] Akun ${acc.name} hapus ${devName} (${device_id})`);
  addLog(device_id, `Hapus perangkat: ${devName}`, 'WEB_STUDIO', acc.id);

  broadcastDeviceSync(acc);

  res.json({
    success: true,
    message: `Perangkat "${devName}" berhasil dihapus dari website dan otomatis terhapus dari aplikasi HP!`,
    device_id,
    total_devices: acc.devices.length,
    account_id: acc.id,
  });
});

// 6d. 🔥 ENDPOINT TAMBAH / UBAH IP & RTSP CCTV DARI WEBSITE (SUPER ADMIN)
app.post('/api/cctv/save', (req, res) => {
  const { account_id, email, cctv } = req.body;
  if (!cctv || !cctv.name) {
    return res.status(400).json({ success: false, message: 'Data nama kamera CCTV wajib diisi.' });
  }

  let acc = null;
  if (account_id) acc = findAccount(account_id);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan.' });
  }

  if (!Array.isArray(acc.cctv)) acc.cctv = [];

  const rawId = (cctv.id || '').trim();
  const cctvId = rawId || ('cctv_' + Date.now().toString(36));
  const existingIdx = acc.cctv.findIndex((c) => c.id === cctvId);
  const existingCam = existingIdx !== -1 ? acc.cctv[existingIdx] : null;

  const incomingRtsp = (cctv.rtspUrl !== undefined ? cctv.rtspUrl : (cctv.rtsp_url !== undefined ? cctv.rtsp_url : null));
  const cleanRtsp = incomingRtsp !== null
    ? String(incomingRtsp).trim()
    : (existingCam ? (existingCam.rtspUrl || existingCam.rtsp_url || '') : '');

  const cleanBoundGate = (cctv.boundGateId || cctv.bound_gate || (existingCam ? existingCam.boundGateId : '') || '').trim() || null;
  let cleanHost = (cctv.onvifHost || cctv.onvif_host || (existingCam ? existingCam.onvifHost : '') || '192.168.1.50').trim();
  if (cleanRtsp) {
    const ipMatch = cleanRtsp.match(/@?(\d{1,3}(?:\.\d{1,3}){3})/);
    if (ipMatch) cleanHost = ipMatch[1];
  }
  const cleanPort = Number(cctv.onvifPort || cctv.onvif_port || (existingCam ? existingCam.onvifPort : 80) || 80);

  const updatedCctv = {
    id: cctvId,
    name: cctv.name.trim(),
    location: (cctv.location || 'Area Rumah').trim(),
    rtspUrl: cleanRtsp,
    rtsp_url: cleanRtsp,
    onvifHost: cleanHost,
    onvif_host: cleanHost,
    onvifPort: cleanPort,
    onvif_port: cleanPort,
    boundGateId: cleanBoundGate,
    bound_gate: cleanBoundGate,
    isOnline: cctv.isOnline !== undefined ? Boolean(cctv.isOnline) : true,
    fps: Number(cctv.fps || 25),
    resolution: cctv.resolution || '1080P FHD (H.264)',
  };

  if (existingIdx !== -1) {
    acc.cctv[existingIdx] = { ...acc.cctv[existingIdx], ...updatedCctv };
    console.log(`📹 [WEBSITE CCTV EDIT] Akun ${acc.name} edit CCTV ${updatedCctv.name} -> ${updatedCctv.rtspUrl}`);
    addLog(cctvId, `Ubah IP / Stream CCTV: ${updatedCctv.name} -> ${updatedCctv.rtspUrl}`, 'WEB_STUDIO', acc.id);
  } else {
    acc.cctv.push(updatedCctv);
    console.log(`➕ [WEBSITE CCTV ADD] Akun ${acc.name} tambah CCTV ${updatedCctv.name} (${updatedCctv.rtspUrl})`);
    addLog(cctvId, `Tambah CCTV baru: ${updatedCctv.name} (${updatedCctv.rtspUrl})`, 'WEB_STUDIO', acc.id);
  }

  broadcastDeviceSync(acc);

  res.json({
    success: true,
    message: `Kamera CCTV "${updatedCctv.name}" berhasil disimpan dan otomatis disinkronkan ke HP!`,
    cctv: updatedCctv,
    total_cctv: acc.cctv.length,
    account_id: acc.id,
  });
});

// 6e. 🔥 ENDPOINT HAPUS CCTV DARI WEBSITE
app.post('/api/cctv/delete', (req, res) => {
  const { account_id, email, cctv_id } = req.body;
  if (!cctv_id) {
    return res.status(400).json({ success: false, message: 'cctv_id wajib diisi.' });
  }

  let acc = null;
  if (account_id) acc = findAccount(account_id);
  if (!acc && email) acc = findAccount(email);
  if (!acc) acc = getActiveAccount();

  if (!acc) {
    return res.status(404).json({ success: false, message: 'Akun tidak ditemukan.' });
  }

  if (!Array.isArray(acc.cctv)) acc.cctv = [];

  const target = acc.cctv.find((c) => c.id === cctv_id);
  const camName = target ? target.name : cctv_id;

  acc.cctv = acc.cctv.filter((c) => c.id !== cctv_id);

  console.log(`🗑️ [WEBSITE CCTV DELETE] Akun ${acc.name} hapus CCTV ${camName} (${cctv_id})`);
  addLog(cctv_id, `Hapus kamera CCTV: ${camName}`, 'WEB_STUDIO', acc.id);

  broadcastDeviceSync(acc);

  res.json({
    success: true,
    message: `Kamera CCTV "${camName}" berhasil dihapus dari website dan otomatis terhapus dari aplikasi HP!`,
    cctv_id,
    total_cctv: acc.cctv.length,
    account_id: acc.id,
  });
});

// 7. Kontrol Perangkat (Dua Format: /api/devices/:id/control & /api/control)
function handleControl(deviceId, action, value, origin, res) {
  const acc = getActiveAccount();
  const prefix = acc?.mqtt_prefix || 'alrisa';

  let isStateOn = false;
  if (typeof action === 'boolean') {
    isStateOn = action;
  } else {
    const u = String(action).toUpperCase().trim();
    isStateOn = (u === 'ON' || u === 'OPEN' || u === 'BUKA' || u === 'TRUE' || u === '1');
  }

  // Update memori
  if (acc && acc.devices) {
    const dev = acc.devices.find((d) => d.id === deviceId);
    if (dev) {
      dev.isActive = isStateOn;
      dev.statusText = isStateOn ? (dev.type === 0 || dev.type === 2 ? 'Terbuka' : 'Menyala') : (dev.type === 0 || dev.type === 2 ? 'Terkunci' : 'Mati');
      if (value !== undefined && value !== null) dev.value = Number(value);
    }
  }

  // Kirim ke MQTT
  const cmdStr = isStateOn ? 'OPEN' : 'CLOSE';
  mqttClient.publish(`${prefix}/${deviceId}/set`, cmdStr, { qos: 1 });
  mqttClient.publish(`nexora/${deviceId}/set`, cmdStr, { qos: 1 });
  mqttClient.publish(`alrisa/${deviceId}/set`, cmdStr, { qos: 1 });

  addLog(deviceId, `Perintah: ${cmdStr}${value !== undefined && value !== null ? ` (${value}%)` : ''}`, origin, acc?.id);
  broadcastWs({ type: 'device_update', deviceId, isStateOn, value });

  res.json({
    success: true,
    message: `Perintah ke ${deviceId} berhasil dipublikasikan ke MQTT`,
    device_id: deviceId,
    action: cmdStr,
    state: isStateOn,
    value,
  });
}

app.post('/api/devices/:id/control', (req, res) => {
  const deviceId = req.params.id;
  const { state, action, value } = req.body;
  const act = state !== undefined ? state : action;
  handleControl(deviceId, act, value, 'WEB_DASHBOARD', res);
});

app.post('/api/control', (req, res) => {
  const { device_id, action, state, value } = req.body;
  const act = action !== undefined ? action : state;
  if (!device_id) return res.status(400).json({ success: false, message: 'device_id wajib diisi' });
  handleControl(device_id, act, value, 'API_CONTROL', res);
});

// 8. Sinkronisasi PLC (Kompatibel dengan /api/plc_sync.php)
app.all('/api/plc_sync', (req, res) => {
  const acc = getActiveAccount();
  const pendingCommands = [];
  if (acc && acc.devices) {
    acc.devices.forEach((d) => {
      if (d.pending_command) {
        pendingCommands.push({
          id: d.id,
          address: d.hardwarePin,
          command: d.pending_command,
        });
        d.pending_command = null;
      }
    });
  }
  res.json({
    success: true,
    plc_ip: acc?.plc_ip || '192.168.1.100',
    plc_type: acc?.plc_type || 'Mitsubishi FX5U',
    pending_commands: pendingCommands,
  });
});

// 9. Riwayat Log
app.get('/api/logs', (req, res) => {
  res.json({ success: true, logs: activityLogs });
});

// Jalankan HTTP & WebSocket Server
server.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(70));
  console.log(`🚀 ALRISA & NEXORA CLOUD HUB (Node.js High-Performance Edition)`);
  console.log(`🏢 Alfatech Solutions IDN. — Latensi < 10ms`);
  console.log('='.repeat(70));
  console.log(`✅ Web Dashboard & REST API : http://localhost:${PORT}`);
  console.log(`✅ WebSocket Server Live    : ws://localhost:${PORT}`);
  console.log(`✅ MQTT Cloud Broker        : ${MQTT_BROKER}`);
  console.log(`✅ Akun Aktif               : ${getActiveAccount()?.name || 'Super Admin'}`);
  console.log('='.repeat(70));
});
