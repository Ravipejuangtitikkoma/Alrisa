-- =============================================================================
-- ALRISA SMART HOME & IOT CLOUD HUB — MYSQL DATABASE SCHEMA & SEED DATA
-- Kompatibel untuk Laragon (MySQL 8.0 / MariaDB) & Web Hosting (cPanel / VPS)
-- Database Name: alrisa_cloud
-- =============================================================================

--CREATE DATABASE IF NOT EXISTS `alrisa_cloud`
--CHARACTER SET utf8mb4
--COLLATE utf8mb4_unicode_ci;

--USE `alrisa_cloud`;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. TABEL PENGATURAN SISTEM GLOBAL (system_settings)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `system_settings`;
CREATE TABLE `system_settings` (
  `id` INT UNSIGNED NOT NULL DEFAULT 1,
  `active_account_id` VARCHAR(64) NOT NULL DEFAULT 'acc_superadmin',
  `app_name` VARCHAR(150) NOT NULL DEFAULT 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
  `mqtt_default_broker` VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
  `mqtt_default_port` INT NOT NULL DEFAULT 1883,
  `api_secret_key` VARCHAR(150) NOT NULL DEFAULT 'ALRISA_SUPERADMIN_KEY_2026',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `system_settings` (`id`, `active_account_id`, `app_name`, `mqtt_default_broker`, `mqtt_default_port`, `api_secret_key`)
VALUES (
  1,
  'acc_superadmin',
  'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
  'broker.emqx.io',
  1883,
  'ALRISA_SUPERADMIN_KEY_2026'
);

-- -----------------------------------------------------------------------------
-- 2. TABEL AKUN PENGGUNA & ADMINISTRATOR (accounts)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `accounts`;
CREATE TABLE `accounts` (
  `id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `role` VARCHAR(32) NOT NULL DEFAULT 'user',
  `division` VARCHAR(100) DEFAULT '',
  `hardware_type` VARCHAR(150) NOT NULL DEFAULT 'ESP32 Smart Automation Hub',
  `hardware_desc` VARCHAR(255) DEFAULT '',
  `mqtt_broker` VARCHAR(150) NOT NULL DEFAULT 'broker.emqx.io',
  `mqtt_port` INT NOT NULL DEFAULT 1883,
  `mqtt_ws_port` INT NOT NULL DEFAULT 8083,
  `mqtt_prefix` VARCHAR(150) NOT NULL DEFAULT 'alrisa/client',
  `mqtt_user` VARCHAR(100) DEFAULT '',
  `mqtt_pass` VARCHAR(150) DEFAULT '',
  `plc_ip` VARCHAR(64) DEFAULT '192.168.1.100',
  `plc_port` INT DEFAULT 502,
  `plc_type` VARCHAR(100) DEFAULT 'Mitsubishi FX5U (Modbus TCP)',
  `wifi_ssid` VARCHAR(100) DEFAULT '',
  `wifi_password` VARCHAR(150) DEFAULT '',
  `created_at` DATE DEFAULT '2026-10-24',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_accounts_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `accounts` (
  `id`, `name`, `email`, `password`, `role`, `division`,
  `hardware_type`, `hardware_desc`,
  `mqtt_broker`, `mqtt_port`, `mqtt_ws_port`, `mqtt_prefix`, `mqtt_user`, `mqtt_pass`,
  `plc_ip`, `plc_port`, `plc_type`, `wifi_ssid`, `wifi_password`, `created_at`
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
);

-- -----------------------------------------------------------------------------
-- 3. TABEL PERANGKAT IOT & PIN HARDWARE (devices)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `devices`;
CREATE TABLE `devices` (
  `uid` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id` VARCHAR(64) NOT NULL,
  `account_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `type` INT NOT NULL DEFAULT 0 COMMENT '0=Gerbang, 1=Lampu, 2=Pintu/Lock, 3=Gorden/Otomasi, 4=Pompa Air',
  `category` VARCHAR(64) NOT NULL DEFAULT 'Keamanan',
  `hardware_pin` VARCHAR(100) NOT NULL DEFAULT 'GPIO 2 (%QX0.0)',
  `is_active` TINYINT(1) NOT NULL DEFAULT 0,
  `value` INT NOT NULL DEFAULT 0,
  `status_text` VARCHAR(64) NOT NULL DEFAULT 'Terkunci',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  UNIQUE KEY `idx_account_device` (`account_id`, `id`),
  CONSTRAINT `fk_devices_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `devices` (`id`, `account_id`, `name`, `type`, `category`, `hardware_pin`, `is_active`, `value`, `status_text`) VALUES
-- Akun 1: acc_superadmin (Ravi Armanza)
('pagar', 'acc_superadmin', 'Gerbang Utama Depan', 0, 'Keamanan', 'GPIO 13 (%QX0.4)', 0, 100, 'Terkunci'),
('pintu', 'acc_superadmin', 'Pintu Akses Lobi Utama', 2, 'Akses', 'GPIO 5 (%QX0.2)', 0, 0, 'Terkunci'),
('garasi', 'acc_superadmin', 'Gerbang Belakang / Garasi', 0, 'Keamanan', 'GPIO 18 (%QX0.3)', 0, 0, 'Terkunci'),
('lampu_teras', 'acc_superadmin', 'Lampu Fasad & Taman Utama', 1, 'Pencahayaan', 'GPIO 4 (%QX0.1)', 1, 100, 'Menyala'),
('lampu_ruang_tamu', 'acc_superadmin', 'Ambient Light Ruang Utama', 1, 'Pencahayaan', 'GPIO 19 (%QX0.4)', 1, 80, 'Menyala'),
('pompa_air', 'acc_superadmin', 'Pompa Distribusi Air Utama', 4, 'Air', 'GPIO 21 (%QX0.5)', 0, 0, 'Mati'),

-- Akun 2: acc_bos_01 (Bpk. Bos)
('bos_pagar_utama', 'acc_bos_01', 'Gerbang Utama Residence Bos', 0, 'Keamanan', 'GPIO 17 (Relay Ch-1)', 0, 0, 'Terkunci'),
('bos_garasi_mobil', 'acc_bos_01', 'Pintu Garasi Mobil Koleksi', 0, 'Keamanan', 'GPIO 27 (Relay Ch-2)', 0, 0, 'Terkunci'),
('bos_lampu_taman', 'acc_bos_01', 'Lampu Taman & Kolam Koi', 1, 'Pencahayaan', 'GPIO 22 (Relay Ch-3)', 1, 100, 'Menyala'),
('bos_pintu_kantor', 'acc_bos_01', 'Smart Lock Ruang Kerja Bos', 2, 'Akses', 'GPIO 23 (Relay Ch-4)', 0, 0, 'Terkunci'),

-- Akun 3: acc_client_villa (Bpk. Budi)
('villa_gate', 'acc_client_villa', 'Gerbang Kayu Villa Puncak', 0, 'Keamanan', 'ESP32 GPIO 12', 0, 0, 'Terkunci'),
('villa_lampu_kabut', 'acc_client_villa', 'Lampu Sorot Anti-Kabut', 1, 'Pencahayaan', 'ESP32 GPIO 14', 1, 100, 'Menyala'),
('villa_pemanas', 'acc_client_villa', 'Pemanas Air Kolam (Heater)', 4, 'Air', 'ESP32 GPIO 26', 0, 0, 'Mati'),

-- Akun 4: acc_client_home (Ibu Maya)
('maya_pagar', 'acc_client_home', 'Pagar Dorong Otomatis', 0, 'Keamanan', 'NodeMCU Pin D1 (GPIO 5)', 1, 0, 'Terbuka'),
('maya_lampu_teras', 'acc_client_home', 'Lampu Teras Depan', 1, 'Pencahayaan', 'NodeMCU Pin D2 (GPIO 4)', 1, 100, 'Menyala'),
('dev_mvpg2z5y', 'acc_client_home', 'Lampu kamar mandi', 1, 'Pencahayaan', 'GPIO 13 (%QX0.4)', 0, 0, 'Terkunci'),

-- Akun 5: acc_mvpf4m17 (suhendra)
('suhend_lampu', 'acc_mvpf4m17', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 12 (%QX0.3)', 1, 0, 'Menyala'),
('suhend_pintu', 'acc_mvpf4m17', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', 1, 0, 'Terbuka'),

-- Akun 6: acc_hendra_mrm6 (Bpk. Hendra Wijaya)
('hendra_pagar', 'acc_hendra_mrm6', 'Gerbang Utama', 0, 'Keamanan', 'GPIO 2 (%QX0.0)', 0, 0, 'Terkunci'),
('hendra_lampu', 'acc_hendra_mrm6', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 4 (%QX0.3)', 0, 0, 'Mati'),
('hendra_pintu', 'acc_hendra_mrm6', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', 0, 0, 'Terkunci'),

-- Akun 8: acc_imah_ada2 (Soimah)
('imah_pagar', 'acc_imah_ada2', 'Gerbang Utama', 0, 'Keamanan', 'GPIO 12 (%QX0.3)', 0, 100, 'Terkunci'),
('imah_lampu', 'acc_imah_ada2', 'Lampu Teras & Luar', 1, 'Pencahayaan', 'GPIO 13 (%QX0.4)', 1, 100, 'Menyala'),
('imah_pintu', 'acc_imah_ada2', 'Pintu Akses Tamu', 2, 'Akses', 'GPIO 5 (%QX0.1)', 0, 0, 'Terkunci');

-- -----------------------------------------------------------------------------
-- 4. TABEL KAMERA CCTV & STREAMING RTSP (cctv_cameras)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `cctv_cameras`;
CREATE TABLE `cctv_cameras` (
  `uid` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id` VARCHAR(64) NOT NULL,
  `account_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `location` VARCHAR(150) DEFAULT 'Area Rumah',
  `rtsp_url` VARCHAR(500) NOT NULL DEFAULT '',
  `onvif_host` VARCHAR(100) DEFAULT '192.168.1.50',
  `onvif_port` INT DEFAULT 80,
  `bound_gate_id` VARCHAR(64) DEFAULT NULL,
  `is_online` TINYINT(1) NOT NULL DEFAULT 1,
  `fps` INT NOT NULL DEFAULT 25,
  `resolution` VARCHAR(64) DEFAULT '1080P FHD (H.264)',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  UNIQUE KEY `idx_account_cctv` (`account_id`, `id`),
  CONSTRAINT `fk_cctv_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `cctv_cameras` (`id`, `account_id`, `name`, `location`, `rtsp_url`, `onvif_host`, `onvif_port`, `bound_gate_id`, `is_online`, `fps`, `resolution`) VALUES
-- Akun 1: acc_superadmin
('cctv_gate_front', 'acc_superadmin', 'CCTV Gerbang Utama', 'Area Depan & Pos Jaga', 'rtsp://192.168.0.102:8554/mjpeg/1', '192.168.0.102', 80, 'pagar', 1, 30, '1080P FHD (H.264)'),
('cctv_backyard', 'acc_superadmin', 'CCTV Gerbang Belakang', 'Jalur Akses Belakang', 'rtsp://admin:admin123@192.168.1.51:554/stream1', '192.168.1.51', 80, 'garasi', 1, 25, '1080P FHD (H.264)'),
('cctv_lobby', 'acc_superadmin', 'CCTV Lobi & Teras', 'Teras Utama', 'rtsp://admin:admin123@192.168.1.52:554/stream1', '192.168.1.52', 80, 'pintu', 1, 25, '2K QHD (H.265)'),

-- Akun 2: acc_bos_01
('cctv_bos_depan', 'acc_bos_01', 'CCTV Pintu Gerbang Bos', 'Halaman Depan VIP', 'rtsp://bos:vip2026@192.168.10.60:554/live', '192.168.10.60', 80, 'bos_pagar_utama', 1, 30, '4K UHD (H.265+)'),
('cctv_bos_garasi', 'acc_bos_01', 'CCTV Garasi Koleksi', 'Garasi Dalam', 'rtsp://bos:vip2026@192.168.10.61:554/live', '192.168.10.61', 80, 'bos_garasi_mobil', 1, 30, '1080P FHD'),

-- Akun 3: acc_client_villa
('cctv_villa_1', 'acc_client_villa', 'Kamera Pintu Masuk Villa', 'Gerbang Depan Villa', 'rtsp://admin:villa123@192.168.4.10:554/ch1', '192.168.4.10', 80, 'villa_gate', 1, 25, '1080P FHD'),
('cctv_1776959326937', 'acc_client_villa', 'Cctv belakang', 'Belakang rumah', 'rtsp://admin:admin123@192.168.1.55:554/stream1', '192.168.1.55', 80, 'pagar', 1, 25, '1080P FHD (H.264)'),

-- Akun 4: acc_client_home
('cctv_maya_1', 'acc_client_home', 'IP Cam Teras Rumah Maya', 'Carport & Pagar Depan', 'rtsp://admin:maya123@192.168.1.88:554/onvif1', '192.168.1.88', 80, 'maya_pagar', 1, 20, '720P HD'),

-- Akun 5: acc_mvpf4m17 (suhendra)
('cctv_1776957298641', 'acc_mvpf4m17', 'CCTV Belakang rumah', 'Area Belakang Rumah', 'rtsp://admin:123456@192.168.1.88:554/stream1', '192.168.1.88', 80, 'suhend_pintu', 1, 25, '1080P FHD (H.264)'),

-- Akun 8: acc_imah_ada2 (Soimah)
('cctv_1776961165359', 'acc_imah_ada2', 'Cctv Gerbang depan', 'Depan rumah', 'rtsp://192.168.0.102:8554/mjpeg/1', '192.168.0.102', 80, 'imah_pagar', 1, 25, '1080P FHD (H.264)');

-- -----------------------------------------------------------------------------
-- 5. TABEL RIWAYAT LOG AKTIVITAS & AUDIT (activity_logs)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `activity_logs`;
CREATE TABLE `activity_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `timestamp` VARCHAR(32) NOT NULL,
  `device_id` VARCHAR(150) NOT NULL,
  `action` VARCHAR(255) NOT NULL,
  `origin` VARCHAR(64) NOT NULL DEFAULT 'SYSTEM',
  `account_id` VARCHAR(64) DEFAULT 'acc_superadmin',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_logs_account` (`account_id`),
  KEY `idx_logs_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `activity_logs` (`timestamp`, `device_id`, `action`, `origin`, `account_id`)
VALUES ('22.30.00', 'SYSTEM', 'Database MySQL ALRISA Cloud siap & terhubung', 'SERVER', 'acc_superadmin');

SET FOREIGN_KEY_CHECKS = 1;

