-- ============================================================================
-- NEXORA SMART IOT & SURVEILLANCE — MULTI-TENANT DATABASE SCHEMA CPANEL
-- Multi-Akun (1 Akun = 1 HP / 1 Lokasi Hardware / 1 Klien Berbeda)
-- Import file ini di phpMyAdmin cPanel Alfa atau MySQL Server
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+07:00';

-- 1. TABEL AKUN KLIEN / PENGGUNA (MULTI-ACCOUNT)
CREATE TABLE IF NOT EXISTS `nexora_accounts` (
  `id` VARCHAR(50) NOT NULL PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `role` VARCHAR(20) NOT NULL DEFAULT 'user', -- 'superadmin', 'admin', 'user'
  `hardware_type` VARCHAR(100) NOT NULL DEFAULT 'Raspberry Pi 4', -- 'Raspberry Pi 4', 'ESP32 Gateway', 'Mitsubishi FX5U PLC'
  `mqtt_prefix` VARCHAR(50) NOT NULL DEFAULT 'nexora/client1',
  `mqtt_broker` VARCHAR(100) NOT NULL DEFAULT 'broker.emqx.io',
  `mqtt_port` INT NOT NULL DEFAULT 1883,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. TABEL STATUS PERANGKAT (DEVICES PER AKUN)
CREATE TABLE IF NOT EXISTS `nexora_devices` (
  `id` VARCHAR(50) NOT NULL,
  `account_id` VARCHAR(50) NOT NULL DEFAULT 'acc_superadmin',
  `name` VARCHAR(100) NOT NULL,
  `category` VARCHAR(50) NOT NULL DEFAULT 'Umum',
  `type` VARCHAR(30) NOT NULL DEFAULT 'gate', -- 'gate', 'light', 'slidingDoor', 'curtain', 'waterPump'
  `state` VARCHAR(50) NOT NULL DEFAULT 'OFF',
  `value` INT NOT NULL DEFAULT 0,
  `pending_command` VARCHAR(50) DEFAULT NULL,
  `pending_value` INT DEFAULT NULL,
  `plc_address` VARCHAR(50) DEFAULT 'GPIO 2 (%QX0.0)',
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`, `account_id`),
  INDEX (`account_id`),
  CONSTRAINT `fk_device_account` FOREIGN KEY (`account_id`) REFERENCES `nexora_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. TABEL KAMERA CCTV (CCTV PER AKUN)
CREATE TABLE IF NOT EXISTS `nexora_cctv` (
  `id` VARCHAR(50) NOT NULL,
  `account_id` VARCHAR(50) NOT NULL DEFAULT 'acc_superadmin',
  `name` VARCHAR(100) NOT NULL,
  `location` VARCHAR(100) NOT NULL,
  `rtsp_url` VARCHAR(255) NOT NULL,
  `onvif_host` VARCHAR(100) DEFAULT '192.168.1.50',
  `onvif_port` INT DEFAULT 80,
  `bound_gate_id` VARCHAR(50) DEFAULT 'pagar',
  `fps` FLOAT DEFAULT 25.0,
  `resolution` VARCHAR(50) DEFAULT '1080P FHD (H.264)',
  `status` VARCHAR(20) DEFAULT 'online',
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`, `account_id`),
  INDEX (`account_id`),
  CONSTRAINT `fk_cctv_account` FOREIGN KEY (`account_id`) REFERENCES `nexora_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. TABEL LOG RIWAYAT AKTIVITAS
CREATE TABLE IF NOT EXISTS `nexora_logs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `account_id` VARCHAR(50) DEFAULT 'acc_superadmin',
  `device_id` VARCHAR(50) NOT NULL,
  `action` VARCHAR(100) NOT NULL,
  `source` VARCHAR(50) NOT NULL DEFAULT 'App', -- 'App', 'Web', 'PLC', 'Otomasi'
  `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (`account_id`),
  INDEX (`device_id`),
  INDEX (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- DATA INISIALISASI AKUN-AKUN RESMI (Akun Bos, Akun Pi 4, Akun Klien Lain)
-- ============================================================================

-- Inisialisasi Akun Super Admin & Akun-akun Klien Berbeda Hardware
INSERT INTO `nexora_accounts` (`id`, `name`, `email`, `password`, `role`, `hardware_type`, `mqtt_prefix`) VALUES
('acc_superadmin', 'Ravi Armanza (Super Admin)', 'raviarmanza149@gmail.com', 'ravi18', 'superadmin', 'Raspberry Pi 4 (Master Controller)', 'alrisa/admin'),
('acc_bos_01', 'Bpk. Bos (Head Office)', 'bos@nexora.id', 'bos2026', 'admin', 'Mitsubishi FX5U PLC (Industrial Hub)', 'alrisa/bos'),
('acc_client_villa', 'Klien Bpk. Budi (Villa Puncak)', 'villa.budi@nexora.id', 'villa123', 'user', 'Raspberry Pi 4 (Quad-Core Gateway)', 'alrisa/villa_budi'),
('acc_client_home', 'Klien Ibu Maya (Rumah Minimalis)', 'user@nexora.id', 'user123', 'user', 'ESP32 Smart Automation Hub', 'alrisa/maya_home')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi Perangkat untuk Akun Super Admin (Ravi Armanza)
INSERT INTO `nexora_devices` (`id`, `account_id`, `name`, `category`, `type`, `state`, `value`, `plc_address`) VALUES
('pagar', 'acc_superadmin', 'Pagar Utama Gerbang', 'Keamanan', 'gate', 'TERTUTUP', 0, '%QX0.0 (Relay 1)'),
('pintu_geser', 'acc_superadmin', 'Pintu Geser Ruang Tamu', 'Akses', 'slidingDoor', 'TERTUTUP', 0, '%QX0.1 (Relay 2)'),
('gorden', 'acc_superadmin', 'Gorden Otomatis', 'Interior', 'curtain', 'TERTUTUP', 0, '%QX0.2 (PWM Pin 4)'),
('lampu_teras', 'acc_superadmin', 'Lampu Teras Depan', 'Pencahayaan', 'light', 'OFF', 0, '%QX0.3 (Relay 3)'),
('pompa_toren', 'acc_superadmin', 'Pompa Toren Utama', 'Air', 'waterPump', 'OFF', 0, '%QX0.4 (Relay 4)'),
('pompa_kolam', 'acc_superadmin', 'Pompa Kolam Ikan', 'Air', 'waterPump', 'OFF', 0, '%QX0.5 (Relay 5)')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi Perangkat untuk Akun Bpk. Budi (Raspberry Pi 4)
INSERT INTO `nexora_devices` (`id`, `account_id`, `name`, `category`, `type`, `state`, `value`, `plc_address`) VALUES
('pagar_villa', 'acc_client_villa', 'Gerbang Utama Villa', 'Keamanan', 'gate', 'TERTUTUP', 0, 'Pi4 GPIO 17'),
('lampu_taman', 'acc_client_villa', 'Lampu Taman & Kolam', 'Pencahayaan', 'light', 'OFF', 0, 'Pi4 GPIO 27'),
('pompa_air_villa', 'acc_client_villa', 'Pompa Sumber Air Pegunungan', 'Air', 'waterPump', 'OFF', 0, 'Pi4 GPIO 22')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi Perangkat untuk Akun Ibu Maya (ESP32)
INSERT INTO `nexora_devices` (`id`, `account_id`, `name`, `category`, `type`, `state`, `value`, `plc_address`) VALUES
('pagar_maya', 'acc_client_home', 'Pagar Minimalis Depan', 'Keamanan', 'gate', 'TERTUTUP', 0, 'ESP32 GPIO 2'),
('lampu_teras_maya', 'acc_client_home', 'Lampu Teras Otomatis', 'Pencahayaan', 'light', 'OFF', 0, 'ESP32 GPIO 4'),
('pintu_depan_maya', 'acc_client_home', 'Pintu Depan Elektrik', 'Akses', 'slidingDoor', 'TERTUTUP', 0, 'ESP32 GPIO 5')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi CCTV untuk Akun Super Admin
INSERT INTO `nexora_cctv` (`id`, `account_id`, `name`, `location`, `rtsp_url`, `onvif_host`, `onvif_port`, `bound_gate_id`) VALUES
('cctv_gate_01', 'acc_superadmin', 'CCTV Pagar Utama', 'Gerbang Depan', 'rtsp://admin:admin123@192.168.1.10:554/ch1/main', '192.168.1.10', 80, 'pagar'),
('cctv_garage_02', 'acc_superadmin', 'CCTV Garasi & Teras', 'Garasi Samping', 'rtsp://admin:admin123@192.168.1.11:554/ch1/main', '192.168.1.11', 80, 'pagar')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi CCTV untuk Akun Klien Villa (Raspberry Pi 4)
INSERT INTO `nexora_cctv` (`id`, `account_id`, `name`, `location`, `rtsp_url`, `onvif_host`, `onvif_port`, `bound_gate_id`) VALUES
('cctv_villa_gate', 'acc_client_villa', 'Kamera Gerbang Villa', 'Pos Keamanan Villa', 'rtsp://admin:villa2026@192.168.1.100:554/stream1', '192.168.1.100', 80, 'pagar_villa'),
('cctv_villa_pool', 'acc_client_villa', 'Kamera Kolam Renang', 'Area Belakang Villa', 'rtsp://admin:villa2026@192.168.1.101:554/stream1', '192.168.1.101', 80, 'pagar_villa')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Inisialisasi CCTV untuk Akun Maya (ESP32 Hub)
INSERT INTO `nexora_cctv` (`id`, `account_id`, `name`, `location`, `rtsp_url`, `onvif_host`, `onvif_port`, `bound_gate_id`) VALUES
('cctv_maya_carport', 'acc_client_home', 'CCTV Carport Depan', 'Depan Garasi', 'rtsp://user:maya123@192.168.1.200:554/live', '192.168.1.200', 80, 'pagar_maya')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- Catatan pertama log sistem
INSERT INTO `nexora_logs` (`account_id`, `device_id`, `action`, `source`) VALUES
('acc_superadmin', 'system', 'Sistem Multi-Akun Cloud NEXORA diinisialisasi sukses di cPanel Alfa', 'System');
