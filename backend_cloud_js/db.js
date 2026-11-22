/**
 * ============================================================================
 * ALRISA CLOUD HUB — MYSQL DATABASE ENGINE (Laragon & Cloud Hosting Ready)
 * ============================================================================
 * Modul ini menangani:
 * 1. Auto-Create Database `alrisa_cloud` & 5 Tabel Utama jika belum ada di MySQL
 * 2. Auto-Migrate / Seed data awal dari settings.json ke MySQL saat pertama jalan
 * 3. Load & Sinkronisasi Real-Time seluruh tabel:
 *    - system_settings
 *    - accounts
 *    - devices
 *    - cctv_cameras
 *    - activity_logs
 * ============================================================================
 */

import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

export const DB_CONFIG = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '3306', 10),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD !== undefined ? process.env.DB_PASSWORD : '',
  database: process.env.DB_NAME || 'alrisa_cloud',
};

let pool = null;
let dbConnected = false;
let lastDbError = null;
let isSyncing = false;
let pendingSyncData = null;

export function getDbStatus() {
  return {
    engine: 'MySQL',
    connected: dbConnected,
    host: DB_CONFIG.host,
    port: DB_CONFIG.port,
    database: DB_CONFIG.database,
    user: DB_CONFIG.user,
    error: lastDbError,
  };
}

/**
 * Inisialisasi koneksi MySQL, buat database & tabel otomatis jika belum ada,
 * lalu muat atau seed data dari fallbackData.
 */
export async function initMySQLDatabase(fallbackData) {
  try {
    // 1. Koneksi awal tanpa nama database untuk memastikan database `alrisa_cloud` dibuat
    const bootstrapConn = await mysql.createConnection({
      host: DB_CONFIG.host,
      port: DB_CONFIG.port,
      user: DB_CONFIG.user,
      password: DB_CONFIG.password,
      connectTimeout: 5000,
    });

    await bootstrapConn.query(
      `CREATE DATABASE IF NOT EXISTS \`${DB_CONFIG.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
    );
    await bootstrapConn.end();

    // 2. Buat Connection Pool ke database `alrisa_cloud`
    pool = mysql.createPool({
      host: DB_CONFIG.host,
      port: DB_CONFIG.port,
      user: DB_CONFIG.user,
      password: DB_CONFIG.password,
      database: DB_CONFIG.database,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      charset: 'utf8mb4',
    });

    // 3. Buat 5 tabel utama secara otomatis jika belum ada
    await createTablesIfNotExist();

    dbConnected = true;
    lastDbError = null;
    console.log(`🗄️ [MYSQL CONNECTED] Terhubung ke MySQL (${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database})`);

    // 4. Cek apakah tabel accounts masih kosong. Jika kosong, seed dari fallbackData (settings.json)
    const [accCountRows] = await pool.query('SELECT COUNT(*) AS total FROM `accounts`');
    const totalAccounts = accCountRows[0]?.total || 0;

    if (totalAccounts === 0 && fallbackData && Array.isArray(fallbackData.accounts) && fallbackData.accounts.length > 0) {
      console.log('🌱 [MYSQL AUTO-SEED] Tabel MySQL masih kosong, menyalin data awal ke MySQL...');
      await syncToMySQL(fallbackData);
      console.log(`✅ [MYSQL AUTO-SEED] Berhasil menyimpan ${fallbackData.accounts.length} akun ke MySQL!`);
    }

    // 5. Muat data terbaru dari MySQL
    const loadedData = await loadFromMySQL();
    const loadedLogs = await loadLogsFromMySQL();

    return {
      connected: true,
      settingsData: loadedData || fallbackData,
      activityLogs: loadedLogs,
    };
  } catch (err) {
    dbConnected = false;
    lastDbError = err.message;
    console.warn(`⚠️ [MYSQL WARNING] Belum terhubung ke MySQL (${err.message}). Menggunakan fallback lokal sementara & akan mencoba konek ulang otomatis saat MySQL Laragon menyala.`);
    scheduleReconnect(fallbackData);
    return {
      connected: false,
      settingsData: fallbackData,
      activityLogs: null,
    };
  }
}

let reconnectTimer = null;
function scheduleReconnect(fallbackData) {
  if (reconnectTimer) return;
  reconnectTimer = setInterval(async () => {
    if (dbConnected) {
      clearInterval(reconnectTimer);
      reconnectTimer = null;
      return;
    }
    try {
      const testConn = await mysql.createConnection({
        host: DB_CONFIG.host,
        port: DB_CONFIG.port,
        user: DB_CONFIG.user,
        password: DB_CONFIG.password,
        connectTimeout: 3000,
      });
      await testConn.end();
      clearInterval(reconnectTimer);
      reconnectTimer = null;
      await initMySQLDatabase(fallbackData);
    } catch (_) {}
  }, 5000);
}

async function createTablesIfNotExist() {
  if (!pool) return;

  await pool.query(`
    CREATE TABLE IF NOT EXISTS \`system_settings\` (
      \`id\` INT UNSIGNED NOT NULL DEFAULT 1,
      \`active_account_id\` VARCHAR(64) NOT NULL DEFAULT 'acc_superadmin',
      \`app_name\` VARCHAR(150) NOT NULL DEFAULT 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
      \`mqtt_default_broker\` VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
      \`mqtt_default_port\` INT NOT NULL DEFAULT 1883,
      \`api_secret_key\` VARCHAR(150) NOT NULL DEFAULT 'ALRISA_SUPERADMIN_KEY_2026',
      \`updated_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (\`id\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS \`accounts\` (
      \`id\` VARCHAR(64) NOT NULL,
      \`name\` VARCHAR(150) NOT NULL,
      \`email\` VARCHAR(150) NOT NULL,
      \`password\` VARCHAR(255) NOT NULL,
      \`role\` VARCHAR(32) NOT NULL DEFAULT 'user',
      \`division\` VARCHAR(100) DEFAULT '',
      \`hardware_type\` VARCHAR(150) NOT NULL DEFAULT 'ESP32 Smart Automation Hub',
      \`hardware_desc\` VARCHAR(255) DEFAULT '',
      \`mqtt_broker\` VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
      \`mqtt_port\` INT NOT NULL DEFAULT 1883,
      \`mqtt_ws_port\` INT NOT NULL DEFAULT 8083,
      \`mqtt_prefix\` VARCHAR(150) NOT NULL DEFAULT 'alrisa/client',
      \`mqtt_user\` VARCHAR(100) DEFAULT '',
      \`mqtt_pass\` VARCHAR(150) DEFAULT '',
      \`plc_ip\` VARCHAR(64) DEFAULT '192.168.1.100',
      \`plc_port\` INT DEFAULT 502,
      \`plc_type\` VARCHAR(100) DEFAULT 'Mitsubishi FX5U (Modbus TCP)',
      \`wifi_ssid\` VARCHAR(100) DEFAULT '',
      \`wifi_password\` VARCHAR(150) DEFAULT '',
      \`created_at\` DATE DEFAULT '2026-10-24',
      \`updated_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (\`id\`),
      UNIQUE KEY \`idx_accounts_email\` (\`email\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS \`devices\` (
      \`uid\` INT UNSIGNED NOT NULL AUTO_INCREMENT,
      \`id\` VARCHAR(64) NOT NULL,
      \`account_id\` VARCHAR(64) NOT NULL,
      \`name\` VARCHAR(150) NOT NULL,
      \`type\` INT NOT NULL DEFAULT 0,
      \`category\` VARCHAR(64) NOT NULL DEFAULT 'Keamanan',
      \`hardware_pin\` VARCHAR(100) NOT NULL DEFAULT 'GPIO 2 (%QX0.0)',
      \`is_active\` TINYINT(1) NOT NULL DEFAULT 0,
      \`value\` INT NOT NULL DEFAULT 0,
      \`status_text\` VARCHAR(64) NOT NULL DEFAULT 'Terkunci',
      \`updated_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (\`uid\`),
      UNIQUE KEY \`idx_account_device\` (\`account_id\`, \`id\`),
      CONSTRAINT \`fk_devices_account\` FOREIGN KEY (\`account_id\`) REFERENCES \`accounts\` (\`id\`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS \`cctv_cameras\` (
      \`uid\` INT UNSIGNED NOT NULL AUTO_INCREMENT,
      \`id\` VARCHAR(64) NOT NULL,
      \`account_id\` VARCHAR(64) NOT NULL,
      \`name\` VARCHAR(150) NOT NULL,
      \`location\` VARCHAR(150) DEFAULT 'Area Rumah',
      \`rtsp_url\` VARCHAR(500) NOT NULL DEFAULT '',
      \`onvif_host\` VARCHAR(100) DEFAULT '192.168.1.50',
      \`onvif_port\` INT DEFAULT 80,
      \`bound_gate_id\` VARCHAR(64) DEFAULT NULL,
      \`is_online\` TINYINT(1) NOT NULL DEFAULT 1,
      \`fps\` INT NOT NULL DEFAULT 25,
      \`resolution\` VARCHAR(64) DEFAULT '1080P FHD (H.264)',
      \`updated_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (\`uid\`),
      UNIQUE KEY \`idx_account_cctv\` (\`account_id\`, \`id\`),
      CONSTRAINT \`fk_cctv_account\` FOREIGN KEY (\`account_id\`) REFERENCES \`accounts\` (\`id\`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS \`activity_logs\` (
      \`id\` INT UNSIGNED NOT NULL AUTO_INCREMENT,
      \`timestamp\` VARCHAR(32) NOT NULL,
      \`device_id\` VARCHAR(150) NOT NULL,
      \`action\` VARCHAR(255) NOT NULL,
      \`origin\` VARCHAR(64) NOT NULL DEFAULT 'SYSTEM',
      \`account_id\` VARCHAR(64) DEFAULT 'acc_superadmin',
      \`created_at\` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (\`id\`),
      KEY \`idx_logs_account\` (\`account_id\`),
      KEY \`idx_logs_created\` (\`created_at\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `);
}

/**
 * Muat seluruh struktur data (system_settings, accounts, devices, cctv_cameras) dari MySQL
 */
export async function loadFromMySQL() {
  if (!pool || !dbConnected) return null;

  const [sysRows] = await pool.query('SELECT * FROM `system_settings` WHERE `id` = 1 LIMIT 1');
  const sys = sysRows[0] || {
    active_account_id: 'acc_superadmin',
    app_name: 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
    mqtt_default_broker: 'broker.emqx.io',
    mqtt_default_port: 1883,
    api_secret_key: 'ALRISA_SUPERADMIN_KEY_2026',
  };

  const [accRows] = await pool.query('SELECT * FROM `accounts` ORDER BY `created_at` ASC, `id` ASC');
  const [devRows] = await pool.query('SELECT * FROM `devices` ORDER BY `uid` ASC');
  const [cctvRows] = await pool.query('SELECT * FROM `cctv_cameras` ORDER BY `uid` ASC');

  const devicesByAcc = {};
  for (const d of devRows) {
    if (!devicesByAcc[d.account_id]) devicesByAcc[d.account_id] = [];
    devicesByAcc[d.account_id].push({
      id: d.id,
      name: d.name,
      type: Number(d.type),
      category: d.category || 'Keamanan',
      hardwarePin: d.hardware_pin || 'GPIO 2 (%QX0.0)',
      isActive: Boolean(d.is_active),
      value: Number(d.value || 0),
      statusText: d.status_text || (d.is_active ? 'Menyala' : 'Terkunci'),
    });
  }

  const cctvByAcc = {};
  for (const c of cctvRows) {
    if (!cctvByAcc[c.account_id]) cctvByAcc[c.account_id] = [];
    cctvByAcc[c.account_id].push({
      id: c.id,
      name: c.name,
      location: c.location || 'Area Rumah',
      rtspUrl: c.rtsp_url || '',
      rtsp_url: c.rtsp_url || '',
      onvifHost: c.onvif_host || '192.168.1.50',
      onvif_host: c.onvif_host || '192.168.1.50',
      onvifPort: Number(c.onvif_port || 80),
      onvif_port: Number(c.onvif_port || 80),
      boundGateId: c.bound_gate_id || null,
      bound_gate: c.bound_gate_id || null,
      isOnline: Boolean(c.is_online),
      fps: Number(c.fps || 25),
      resolution: c.resolution || '1080P FHD (H.264)',
    });
  }

  const accounts = accRows.map((a) => ({
    id: a.id,
    name: a.name,
    email: a.email,
    password: a.password,
    role: a.role || 'user',
    division: a.division || '',
    created_at: a.created_at instanceof Date ? a.created_at.toISOString().split('T')[0] : String(a.created_at || '2026-10-24'),
    hardware_type: a.hardware_type || 'ESP32 Smart Automation Hub',
    hardware_desc: a.hardware_desc || '',
    mqtt_broker: a.mqtt_broker || 'broker.emqx.io',
    mqtt_port: Number(a.mqtt_port || 1883),
    mqtt_ws_port: Number(a.mqtt_ws_port || 8083),
    mqtt_prefix: a.mqtt_prefix || `alrisa/${a.id}`,
    mqtt_user: a.mqtt_user || '',
    mqtt_pass: a.mqtt_pass || '',
    plc_ip: a.plc_ip || '192.168.1.100',
    plc_port: Number(a.plc_port || 502),
    plc_type: a.plc_type || 'Mitsubishi FX5U (Modbus TCP)',
    wifi_ssid: a.wifi_ssid || '',
    wifi_password: a.wifi_password || '',
    devices: devicesByAcc[a.id] || [],
    cctv: cctvByAcc[a.id] || [],
  }));

  return {
    active_account_id: sys.active_account_id || 'acc_superadmin',
    system: {
      app_name: sys.app_name || 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
      mqtt_default_broker: sys.mqtt_default_broker || 'broker.emqx.io',
      mqtt_default_port: Number(sys.mqtt_default_port || 1883),
      api_secret_key: sys.api_secret_key || 'ALRISA_SUPERADMIN_KEY_2026',
    },
    accounts,
  };
}

/**
 * Muat 50 riwayat log terbaru dari tabel `activity_logs` di MySQL
 */
export async function loadLogsFromMySQL() {
  if (!pool || !dbConnected) return null;
  try {
    const [rows] = await pool.query(
      'SELECT `timestamp`, `device_id` AS `deviceId`, `action`, `origin`, `account_id` AS `accountId` FROM `activity_logs` ORDER BY `id` DESC LIMIT 50'
    );
    return rows;
  } catch (err) {
    console.error('⚠️ Gagal memuat log dari MySQL:', err.message);
    return null;
  }
}

/**
 * Simpan satu baris log baru ke tabel `activity_logs` di MySQL
 */
export async function insertLogToMySQL(logItem) {
  if (!pool || !dbConnected || !logItem) return;
  try {
    await pool.query(
      'INSERT INTO `activity_logs` (`timestamp`, `device_id`, `action`, `origin`, `account_id`) VALUES (?, ?, ?, ?, ?)',
      [
        logItem.timestamp || new Date().toLocaleTimeString('id-ID'),
        logItem.deviceId || 'SYSTEM',
        logItem.action || '',
        logItem.origin || 'SYSTEM',
        logItem.accountId || 'acc_superadmin',
      ]
    );
  } catch (err) {
    console.error('⚠️ Gagal menyimpan log ke MySQL:', err.message);
  }
}

/**
 * Sinkronkan seluruh perubahan state (settingsData) ke tabel MySQL secara transaksional
 */
export async function syncToMySQL(settingsData) {
  if (!pool || !settingsData) return;

  if (isSyncing) {
    pendingSyncData = settingsData;
    return;
  }

  isSyncing = true;
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // 1. Upsert system_settings
    const sys = settingsData.system || {};
    await conn.query(
      `INSERT INTO \`system_settings\` (\`id\`, \`active_account_id\`, \`app_name\`, \`mqtt_default_broker\`, \`mqtt_default_port\`, \`api_secret_key\`)
       VALUES (1, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         \`active_account_id\` = VALUES(\`active_account_id\`),
         \`app_name\` = VALUES(\`app_name\`),
         \`mqtt_default_broker\` = VALUES(\`mqtt_default_broker\`),
         \`mqtt_default_port\` = VALUES(\`mqtt_default_port\`),
         \`api_secret_key\` = VALUES(\`api_secret_key\`)`,
      [
        settingsData.active_account_id || 'acc_superadmin',
        sys.app_name || 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
        sys.mqtt_default_broker || 'broker.emqx.io',
        Number(sys.mqtt_default_port || 1883),
        sys.api_secret_key || 'ALRISA_SUPERADMIN_KEY_2026',
      ]
    );

    const accounts = Array.isArray(settingsData.accounts) ? settingsData.accounts : [];
    const currentAccountIds = accounts.map((a) => a.id).filter(Boolean);

    // 2. Hapus akun yang sudah tidak ada di daftar
    if (currentAccountIds.length > 0) {
      await conn.query('DELETE FROM `accounts` WHERE `id` NOT IN (?)', [currentAccountIds]);
    } else {
      await conn.query('DELETE FROM `accounts`');
    }

    // 3. Upsert setiap akun beserta devices & cctv_cameras miliknya
    for (const acc of accounts) {
      const createdDate = acc.created_at && /^\d{4}-\d{2}-\d{2}/.test(String(acc.created_at))
        ? String(acc.created_at).substring(0, 10)
        : '2026-10-24';

      await conn.query(
        `INSERT INTO \`accounts\` (
          \`id\`, \`name\`, \`email\`, \`password\`, \`role\`, \`division\`,
          \`hardware_type\`, \`hardware_desc\`,
          \`mqtt_broker\`, \`mqtt_port\`, \`mqtt_ws_port\`, \`mqtt_prefix\`, \`mqtt_user\`, \`mqtt_pass\`,
          \`plc_ip\`, \`plc_port\`, \`plc_type\`, \`wifi_ssid\`, \`wifi_password\`, \`created_at\`
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          \`name\` = VALUES(\`name\`),
          \`email\` = VALUES(\`email\`),
          \`password\` = VALUES(\`password\`),
          \`role\` = VALUES(\`role\`),
          \`division\` = VALUES(\`division\`),
          \`hardware_type\` = VALUES(\`hardware_type\`),
          \`hardware_desc\` = VALUES(\`hardware_desc\`),
          \`mqtt_broker\` = VALUES(\`mqtt_broker\`),
          \`mqtt_port\` = VALUES(\`mqtt_port\`),
          \`mqtt_ws_port\` = VALUES(\`mqtt_ws_port\`),
          \`mqtt_prefix\` = VALUES(\`mqtt_prefix\`),
          \`mqtt_user\` = VALUES(\`mqtt_user\`),
          \`mqtt_pass\` = VALUES(\`mqtt_pass\`),
          \`plc_ip\` = VALUES(\`plc_ip\`),
          \`plc_port\` = VALUES(\`plc_port\`),
          \`plc_type\` = VALUES(\`plc_type\`),
          \`wifi_ssid\` = VALUES(\`wifi_ssid\`),
          \`wifi_password\` = VALUES(\`wifi_password\`)`,
        [
          acc.id,
          acc.name || 'Pengguna Alrisa',
          acc.email || `${acc.id}@alrisa.id`,
          acc.password || '123456',
          acc.role || 'user',
          acc.division || '',
          acc.hardware_type || 'ESP32 Smart Automation Hub',
          acc.hardware_desc || '',
          acc.mqtt_broker || 'broker.emqx.io',
          Number(acc.mqtt_port || 1883),
          Number(acc.mqtt_ws_port || 8083),
          acc.mqtt_prefix || `alrisa/${acc.id}`,
          acc.mqtt_user || '',
          acc.mqtt_pass || '',
          acc.plc_ip || '192.168.1.100',
          Number(acc.plc_port || 502),
          acc.plc_type || 'Mitsubishi FX5U (Modbus TCP)',
          acc.wifi_ssid || '',
          acc.wifi_password || '',
          createdDate,
        ]
      );

      // Sinkronkan perangkat (devices) milik akun ini
      const devs = Array.isArray(acc.devices) ? acc.devices : [];
      const devIds = devs.map((d) => d.id).filter(Boolean);
      if (devIds.length > 0) {
        await conn.query('DELETE FROM `devices` WHERE `account_id` = ? AND `id` NOT IN (?)', [acc.id, devIds]);
      } else {
        await conn.query('DELETE FROM `devices` WHERE `account_id` = ?', [acc.id]);
      }

      for (const d of devs) {
        await conn.query(
          `INSERT INTO \`devices\` (
            \`id\`, \`account_id\`, \`name\`, \`type\`, \`category\`, \`hardware_pin\`, \`is_active\`, \`value\`, \`status_text\`
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            \`name\` = VALUES(\`name\`),
            \`type\` = VALUES(\`type\`),
            \`category\` = VALUES(\`category\`),
            \`hardware_pin\` = VALUES(\`hardware_pin\`),
            \`is_active\` = VALUES(\`is_active\`),
            \`value\` = VALUES(\`value\`),
            \`status_text\` = VALUES(\`status_text\`)`,
          [
            d.id,
            acc.id,
            d.name || d.id,
            Number(d.type !== undefined ? d.type : 0),
            d.category || 'Keamanan',
            d.hardwarePin || 'GPIO 2 (%QX0.0)',
            d.isActive ? 1 : 0,
            Number(d.value || 0),
            d.statusText || (d.isActive ? 'Menyala' : 'Terkunci'),
          ]
        );
      }

      // Sinkronkan kamera CCTV (cctv_cameras) milik akun ini
      const cams = Array.isArray(acc.cctv) ? acc.cctv : [];
      const camIds = cams.map((c) => c.id).filter(Boolean);
      if (camIds.length > 0) {
        await conn.query('DELETE FROM `cctv_cameras` WHERE `account_id` = ? AND `id` NOT IN (?)', [acc.id, camIds]);
      } else {
        await conn.query('DELETE FROM `cctv_cameras` WHERE `account_id` = ?', [acc.id]);
      }

      for (const c of cams) {
        const rtsp = c.rtspUrl !== undefined ? c.rtspUrl : (c.rtsp_url || '');
        const host = c.onvifHost !== undefined ? c.onvifHost : (c.onvif_host || '192.168.1.50');
        const port = c.onvifPort !== undefined ? c.onvifPort : (c.onvif_port || 80);
        const boundGate = c.boundGateId !== undefined ? c.boundGateId : (c.bound_gate || null);

        await conn.query(
          `INSERT INTO \`cctv_cameras\` (
            \`id\`, \`account_id\`, \`name\`, \`location\`, \`rtsp_url\`, \`onvif_host\`, \`onvif_port\`, \`bound_gate_id\`, \`is_online\`, \`fps\`, \`resolution\`
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            \`name\` = VALUES(\`name\`),
            \`location\` = VALUES(\`location\`),
            \`rtsp_url\` = VALUES(\`rtsp_url\`),
            \`onvif_host\` = VALUES(\`onvif_host\`),
            \`onvif_port\` = VALUES(\`onvif_port\`),
            \`bound_gate_id\` = VALUES(\`bound_gate_id\`),
            \`is_online\` = VALUES(\`is_online\`),
            \`fps\` = VALUES(\`fps\`),
            \`resolution\` = VALUES(\`resolution\`)`,
          [
            c.id,
            acc.id,
            c.name || c.id,
            c.location || 'Area Rumah',
            rtsp,
            host,
            Number(port || 80),
            boundGate,
            c.isOnline !== false ? 1 : 0,
            Number(c.fps || 25),
            c.resolution || '1080P FHD (H.264)',
          ]
        );
      }
    }

    await conn.commit();
    dbConnected = true;
    lastDbError = null;
  } catch (err) {
    await conn.rollback();
    console.error('⚠️ Gagal sinkronisasi ke MySQL:', err.message);
    lastDbError = err.message;
  } finally {
    conn.release();
    isSyncing = false;
    if (pendingSyncData) {
      const nextData = pendingSyncData;
      pendingSyncData = null;
      syncToMySQL(nextData);
    }
  }
}

