-- =============================================================================
-- ALRISA CLOUD HUB — SUPABASE (POSTGRESQL) SCHEMA & SEED DATA
-- Project: supabase-aureolin-ocean (ID: wddrxahvkeptiotmlzyq)
-- =============================================================================

-- 1. TABEL PENGATURAN SISTEM GLOBAL (system_settings)
CREATE TABLE IF NOT EXISTS system_settings (
  id INT PRIMARY KEY DEFAULT 1,
  active_account_id VARCHAR(64) NOT NULL DEFAULT 'acc_superadmin',
  app_name VARCHAR(150) NOT NULL DEFAULT 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
  mqtt_default_broker VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
  mqtt_default_port INT NOT NULL DEFAULT 1883,
  api_secret_key VARCHAR(150) NOT NULL DEFAULT 'ALRISA_SUPERADMIN_KEY_2026',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO system_settings (id, active_account_id, app_name, mqtt_default_broker, mqtt_default_port, api_secret_key)
VALUES (
  1,
  'acc_superadmin',
  'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
  'broker.emqx.io',
  1883,
  'ALRISA_SUPERADMIN_KEY_2026'
)
ON CONFLICT (id) DO UPDATE SET
  active_account_id = EXCLUDED.active_account_id,
  app_name = EXCLUDED.app_name,
  mqtt_default_broker = EXCLUDED.mqtt_default_broker,
  mqtt_default_port = EXCLUDED.mqtt_default_port,
  api_secret_key = EXCLUDED.api_secret_key,
  updated_at = NOW();

-- 2. TABEL AKUN PENGGUNA & ADMINISTRATOR (accounts)
CREATE TABLE IF NOT EXISTS accounts (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'user',
  division VARCHAR(100) DEFAULT '',
  hardware_type VARCHAR(150) NOT NULL DEFAULT 'ESP32 Smart Automation Hub',
  hardware_desc VARCHAR(255) DEFAULT '',
  mqtt_broker VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
  mqtt_port INT NOT NULL DEFAULT 1883,
  mqtt_ws_port INT NOT NULL DEFAULT 8083,
  mqtt_prefix VARCHAR(150) NOT NULL DEFAULT 'alrisa/client',
  mqtt_user VARCHAR(100) DEFAULT '',
  mqtt_pass VARCHAR(150) DEFAULT '',
  plc_ip VARCHAR(64) DEFAULT '192.168.1.100',
  plc_port INT DEFAULT 502,
  plc_type VARCHAR(100) DEFAULT 'Mitsubishi FX5U (Modbus TCP)',
  wifi_ssid VARCHAR(100) DEFAULT '',
  wifi_password VARCHAR(150) DEFAULT '',
  created_at DATE DEFAULT '2026-10-24',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO accounts (
  id, name, email, password, role, division,
  hardware_type, hardware_desc,
  mqtt_broker, mqtt_port, mqtt_ws_port, mqtt_prefix, mqtt_user, mqtt_pass,
  plc_ip, plc_port, plc_type, wifi_ssid, wifi_password, created_at
) VALUES
(
  'acc_superadmin', 'Ravi Armanza (Super Admin)', 'raviarmanza149@gmail.com', 'ravi18', 'superadmin', 'Head / Super Admin',
  'Raspberry Pi 4 Model B + PLC Mitsubishi FX5U', 'Sistem Kontrol Industri & Smart Residence Utama (Full Access)',
  'broker.emqx.io', 1883, 8083, 'alrisa', '', '',
  '192.168.1.100', 502, 'Mitsubishi FX5U (Modbus TCP)', 'ALRISA_SMART_HOME_5G', 'admin12345', '2026-10-24'
),
(
  'acc_bos_01', 'Bpk. Bos (Head Office)', 'bos@alrisa.id', 'bos2026', 'superadmin', 'Head Office',
  'Raspberry Pi 5 + Industrial Relay Hat 8-Ch', 'Sistem Kontrol Kediaman Utama Bos & Ruang Kerja Eksekutif',
  'broker.emqx.io', 1883, 8083, 'alrisa/bos', '', '',
  '192.168.10.50', 502, 'Raspberry Pi 5 GPIO & Modbus Hub', 'BOS_RESIDENCE_VIP', 'vipbos2026', '2026-10-24'
),
(
  'acc_client_villa', 'Bpk. Budi (Klien Villa Puncak)', 'villa.budi@alrisa.id', 'villa123', 'user', '',
  'ESP32 WROOM-32 Dual Core + Relay 4-Ch', 'Paket Smart Gate & Penerangan Taman Villa Puncak',
  'broker.emqx.io', 1883, 8083, 'alrisa/villa_budi', '', '',
  '192.168.4.1', 502, 'ESP32 Direct Wi-Fi Controller', 'VILLA_PUNCAK_WIFI', 'puncak123', '2026-10-24'
),
(
  'acc_client_home', 'Ibu Maya (Rumah Minimalis)', 'user@alrisa.id', 'user123', 'user', '',
  'ESP8266 NodeMCU V3 + Smart Relay 2-Ch', 'Paket Hemat Kontrol Pagar Otomatis & Lampu Teras',
  'broker.emqx.io', 1883, 8083, 'alrisa/maya_home', '', '',
  '192.168.1.25', 80, 'ESP8266 NodeMCU Smart Relay', 'MAYA_HOME_NET', 'maya2026', '2026-10-24'
),
(
  'acc_mvpf4m17', 'suhendra', 'suhend@gmail.com', '123456', 'user', '',
  'ESP32 Smart Automation Hub', 'Modul Otomasi Cerdas Alrisa Cloud IoT',
  'broker.emqx.io', 1883, 8083, 'alrisa/suhend', '', '',
  '192.168.1.100', 502, 'Mitsubishi FX5U (Modbus TCP)', 'ALRISA_SMART_WIFI', '', '2026-10-24'
),
(
  'acc_hendra_mrm6', 'Bpk. Hendra Wijaya', 'hendra@alrisa.id', 'hendra2026', 'user', '',
  'ESP32 Smart Hub + Relay 4-Ch', 'Modul Otomasi Cerdas Alrisa Cloud IoT',
  'broker.emqx.io', 1883, 8083, 'alrisa/hendra', '', '',
  '192.168.1.100', 502, 'Mitsubishi FX5U (Modbus TCP)', 'ALRISA_SMART_WIFI', '', '2026-10-24'
),
(
  'acc_admin_ilham_0kv6', 'Bpk. Ilham Kurniawan', 'ilham@alrisa.id', 'ilham2026', 'admin', 'Divisi Monitoring IoT',
  'ESP32 Smart Automation Hub', 'Sistem Kontrol Administrator Alrisa Dash',
  'broker.emqx.io', 1883, 8083, 'alrisa/admin_ilham', '', '',
  '192.168.1.100', 502, 'Mitsubishi FX5U (Modbus TCP)', 'ALRISA_ADMIN_HQ', '', '2026-10-24'
),
(
  'acc_imah_ada2', 'Soimah', 'imah@gmail.com', '123456', 'user', '',
  'ESP32 WROOM-32 Dual Core + Relay 4-Ch', 'Modul Otomasi Cerdas Alrisa Cloud IoT',
  'broker.emqx.io', 1883, 8083, 'alrisa/imah', '', '',
  '192.168.1.100', 502, 'Mitsubishi FX5U (Modbus TCP)', 'ALRISA_SMART_WIFI', '', '2026-10-24'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  password = EXCLUDED.password,
  role = EXCLUDED.role,
  division = EXCLUDED.division,
  hardware_type = EXCLUDED.hardware_type,
  hardware_desc = EXCLUDED.hardware_desc,
  mqtt_broker = EXCLUDED.mqtt_broker,
  mqtt_port = EXCLUDED.mqtt_port,
  mqtt_ws_port = EXCLUDED.mqtt_ws_port,
  mqtt_prefix = EXCLUDED.mqtt_prefix,
  mqtt_user = EXCLUDED.mqtt_user,
  mqtt_pass = EXCLUDED.mqtt_pass,
  plc_ip = EXCLUDED.plc_ip,
  plc_port = EXCLUDED.plc_port,
  plc_type = EXCLUDED.plc_type,
  wifi_ssid = EXCLUDED.wifi_ssid,
  wifi_password = EXCLUDED.wifi_password,
  updated_at = NOW();

-- 3. TABEL PERANGKAT IOT & PIN HARDWARE (devices)
CREATE TABLE IF NOT EXISTS devices (
  uid SERIAL PRIMARY KEY,
  id VARCHAR(64) NOT NULL,
  account_id VARCHAR(64) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name VARCHAR(150) NOT NULL,
  type INT NOT NULL DEFAULT 0,
  category VARCHAR(64) NOT NULL DEFAULT 'Keamanan',
  hardware_pin VARCHAR(100) NOT NULL DEFAULT 'GPIO 2 (%QX0.0)',
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  value INT NOT NULL DEFAULT 0,
  status_text VARCHAR(64) NOT NULL DEFAULT 'Terkunci',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT idx_account_device UNIQUE (account_id, id)
);

INSERT INTO devices (id, account_id, name, type, category, hardware_pin, is_active, value, status_text) VALUES
('pagar', 'acc_superadmin', 'Gerbang Utama Depan', 0, 'Keamanan', 'GPIO 13 (%QX0.4)', FALSE, 100, 'Terkunci'),
('pintu', 'acc_superadmin', 'Pintu Akses Lobi Utama', 2, 'Akses', 'GPIO 5 (%QX0.2)', FALSE, 0, 'Terkunci'),
('garasi', 'acc_superadmin', 'Gerbang Belakang / Garasi', 0, 'Keamanan', 'GPIO 18 (%QX0.3)', FALSE, 0, 'Terkunci'),
('lampu_teras', 'acc_superadmin', 'Lampu Fasad & Taman Utama', 1, 'Pencahayaan', 'GPIO 4 (%QX0.1)', TRUE, 100, 'Menyala'),
('lampu_ruang_tamu', 'acc_superadmin', 'Ambient Light Ruang Utama', 1, 'Pencahayaan', 'GPIO 19 (%QX0.4)', TRUE, 80, 'Menyala'),
('pompa_air', 'acc_superadmin', 'Pompa Distribusi Air Utama', 4, 'Air', 'GPIO 21 (%QX0.5)', FALSE, 0, 'Mati'),
('bos_pagar_utama', 'acc_bos_01', 'Gerbang Utama Residence Bos', 0, 'Keamanan', 'GPIO 17 (Relay Ch-1)', FALSE, 0, 'Terkunci'),
('bos_garasi_mobil', 'acc_bos_01', 'Pintu Garasi Mobil Koleksi', 0, 'Keamanan', 'GPIO 27 (Relay Ch-2)', FALSE, 0, 'Terkunci'),
('bos_lampu_taman', 'acc_bos_01', 'Lampu Taman & Kolam Koi', 1, 'Pencahayaan', 'GPIO 22 (Relay Ch-3)', TRUE, 100, 'Menyala'),
('bos_pintu_kantor', 'acc_bos_01', 'Smart Lock Ruang Kerja Bos', 2, 'Akses', 'GPIO 23 (Relay Ch-4)', FALSE, 0, 'Terkunci'),
('villa_gate', 'acc_client_villa', 'Gerbang Kayu Villa Puncak', 0, 'Keamanan', 'ESP32 GPIO 12', FALSE, 0, 'Terkunci'),
('villa_lampu_kabut', 'acc_client_villa', 'Lampu Sorot Anti-Kabut', 1, 'Pencahayaan', 'ESP32 GPIO 14', TRUE, 100, 'Menyala'),
('villa_pemanas', 'acc_client_villa', 'Pemanas Air Kolam (Heater)', 4, 'Air', 'ESP32 GPIO 26', FALSE, 0, 'Mati'),
('maya_pagar', 'acc_client_home', 'Pagar Dorong Otomatis', 0, 'Keamanan', 'NodeMCU Pin D1 (GPIO 5)', TRUE, 0, 'Terbuka'),
('maya_lampu_teras', 'acc_client_home', 'Lampu Teras Depan', 1, 'Pencahayaan', 'NodeMCU Pin D2 (GPIO 4)', TRUE, 100, 'Menyala'),
('dev_mvpg2z5y', 'acc_client_home', 'Lampu kamar mandi', 1, 'Pencahayaan', 'GPIO 13 (%QX0.4)', FALSE, 0, 'Terkunci'),
('suhend_lampu', 'acc_mvpf4m17', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 12 (%QX0.3)', TRUE, 0, 'Menyala'),
('suhend_pintu', 'acc_mvpf4m17', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', TRUE, 0, 'Terbuka'),
('hendra_pagar', 'acc_hendra_mrm6', 'Gerbang Utama', 0, 'Keamanan', 'GPIO 2 (%QX0.0)', FALSE, 0, 'Terkunci'),
('hendra_lampu', 'acc_hendra_mrm6', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 4 (%QX0.3)', FALSE, 0, 'Mati'),
('hendra_pintu', 'acc_hendra_mrm6', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', FALSE, 0, 'Terkunci'),
('imah_pagar', 'acc_imah_ada2', 'Gerbang Utama', 0, 'Keamanan', 'GPIO 12 (%QX0.3)', FALSE, 100, 'Terkunci'),
('imah_lampu', 'acc_imah_ada2', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 13 (%QX0.4)', TRUE, 100, 'Menyala'),
('imah_pintu', 'acc_imah_ada2', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', FALSE, 0, 'Terkunci')
ON CONFLICT (account_id, id) DO UPDATE SET
  name = EXCLUDED.name,
  type = EXCLUDED.type,
  category = EXCLUDED.category,
  hardware_pin = EXCLUDED.hardware_pin,
  is_active = EXCLUDED.is_active,
  value = EXCLUDED.value,
  status_text = EXCLUDED.status_text,
  updated_at = NOW();

-- 4. TABEL KAMERA CCTV & STREAMING RTSP (cctv_cameras)
CREATE TABLE IF NOT EXISTS cctv_cameras (
  uid SERIAL PRIMARY KEY,
  id VARCHAR(64) NOT NULL,
  account_id VARCHAR(64) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name VARCHAR(150) NOT NULL,
  location VARCHAR(150) DEFAULT 'Area Rumah',
  rtsp_url VARCHAR(500) NOT NULL DEFAULT '',
  onvif_host VARCHAR(100) DEFAULT '192.168.1.50',
  onvif_port INT DEFAULT 80,
  bound_gate_id VARCHAR(64) DEFAULT NULL,
  is_online BOOLEAN NOT NULL DEFAULT TRUE,
  fps INT NOT NULL DEFAULT 25,
  resolution VARCHAR(64) DEFAULT '1080P FHD (H.264)',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT idx_account_cctv UNIQUE (account_id, id)
);

INSERT INTO cctv_cameras (id, account_id, name, location, rtsp_url, onvif_host, onvif_port, bound_gate_id, is_online, fps, resolution) VALUES
('cctv_gate_front', 'acc_superadmin', 'CCTV Gerbang Utama', 'Area Depan & Pos Jaga', 'rtsp://192.168.0.102:8554/mjpeg/1', '192.168.0.102', 80, 'pagar', TRUE, 30, '1080P FHD (H.264)'),
('cctv_backyard', 'acc_superadmin', 'CCTV Gerbang Belakang', 'Jalur Akses Belakang', 'rtsp://admin:admin123@192.168.1.51:554/stream1', '192.168.1.51', 80, 'garasi', TRUE, 25, '1080P FHD (H.264)'),
('cctv_lobby', 'acc_superadmin', 'CCTV Lobi & Teras', 'Teras Utama', 'rtsp://admin:admin123@192.168.1.52:554/stream1', '192.168.1.52', 80, 'pintu', TRUE, 25, '2K QHD (H.265)'),
('cctv_bos_depan', 'acc_bos_01', 'CCTV Pintu Gerbang Bos', 'Halaman Depan VIP', 'rtsp://bos:vip2026@192.168.10.60:554/live', '192.168.10.60', 80, 'bos_pagar_utama', TRUE, 30, '4K UHD (H.265+)'),
('cctv_bos_garasi', 'acc_bos_01', 'CCTV Garasi Koleksi', 'Garasi Dalam', 'rtsp://bos:vip2026@192.168.10.61:554/live', '192.168.10.61', 80, 'bos_garasi_mobil', TRUE, 30, '1080P FHD'),
('cctv_villa_1', 'acc_client_villa', 'Kamera Pintu Masuk Villa', 'Gerbang Depan Villa', 'rtsp://admin:villa123@192.168.4.10:554/ch1', '192.168.4.10', 80, 'villa_gate', TRUE, 25, '1080P FHD'),
('cctv_1776959326937', 'acc_client_villa', 'Cctv belakang', 'Belakang rumah', 'rtsp://admin:admin123@192.168.1.55:554/stream1', '192.168.1.55', 80, 'pagar', TRUE, 25, '1080P FHD (H.264)'),
('cctv_maya_1', 'acc_client_home', 'IP Cam Teras Rumah Maya', 'Carport & Pagar Depan', 'rtsp://admin:maya123@192.168.1.88:554/onvif1', '192.168.1.88', 80, 'maya_pagar', TRUE, 20, '720P HD'),
('cctv_1776957298641', 'acc_mvpf4m17', 'CCTV Belakang rumah', 'Area Belakang Rumah', 'rtsp://admin:123456@192.168.1.88:554/stream1', '192.168.1.88', 80, 'suhend_pintu', TRUE, 25, '1080P FHD (H.264)'),
('cctv_1776961165359', 'acc_imah_ada2', 'Cctv Gerbang depan', 'Depan rumah', 'rtsp://192.168.0.102:8554/mjpeg/1', '192.168.0.102', 80, 'imah_pagar', TRUE, 25, '1080P FHD (H.264)')
ON CONFLICT (account_id, id) DO UPDATE SET
  name = EXCLUDED.name,
  location = EXCLUDED.location,
  rtsp_url = EXCLUDED.rtsp_url,
  onvif_host = EXCLUDED.onvif_host,
  onvif_port = EXCLUDED.onvif_port,
  bound_gate_id = EXCLUDED.bound_gate_id,
  is_online = EXCLUDED.is_online,
  fps = EXCLUDED.fps,
  resolution = EXCLUDED.resolution,
  updated_at = NOW();

-- 5. TABEL RIWAYAT LOG AKTIVITAS & AUDIT (activity_logs)
CREATE TABLE IF NOT EXISTS activity_logs (
  id SERIAL PRIMARY KEY,
  timestamp VARCHAR(32) NOT NULL,
  device_id VARCHAR(150) NOT NULL,
  action VARCHAR(255) NOT NULL,
  origin VARCHAR(64) NOT NULL DEFAULT 'SYSTEM',
  account_id VARCHAR(64) DEFAULT 'acc_superadmin',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO activity_logs (timestamp, device_id, action, origin, account_id)
VALUES ('22.30.00', 'SYSTEM', 'Database Supabase PostgreSQL ALRISA Cloud siap & terhubung', 'SERVER', 'acc_superadmin');

-- Nonaktifkan RLS agar dapat dibaca & ditulis oleh backend API
ALTER TABLE system_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
ALTER TABLE cctv_cameras DISABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs DISABLE ROW LEVEL SECURITY;
