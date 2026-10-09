-- ============================================================================
-- NEXORA SMART IOT - DATABASE SCHEMA UNTUK CPANEL MYSQL
-- Import file ini di menu "phpMyAdmin" pada cPanel Alfa
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+07:00';

-- 1. TABEL STATUS PERANGKAT (DEVICES)
CREATE TABLE IF NOT EXISTS `nexora_devices` (
  `id` VARCHAR(50) NOT NULL PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `category` VARCHAR(50) NOT NULL DEFAULT 'Umum',
  `state` VARCHAR(50) NOT NULL DEFAULT 'OFF',
  `value` INT NOT NULL DEFAULT 0,
  `pending_command` VARCHAR(50) DEFAULT NULL,
  `pending_value` INT DEFAULT NULL,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `plc_address` VARCHAR(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Inisialisasi 6 Perangkat Utama NEXORA
INSERT INTO `nexora_devices` (`id`, `name`, `category`, `state`, `value`, `pending_command`, `pending_value`, `plc_address`) VALUES
('pagar', 'Pagar Utama Rumah', 'Keamanan', 'TERTUTUP', 0, NULL, NULL, '%QX0.0'),
('pintu_geser', 'Pintu Geser Ruang Tamu', 'Akses', 'TERTUTUP', 0, NULL, NULL, '%QX0.1'),
('gorden', 'Gorden Otomatis', 'Interior', 'TERTUTUP', 0, NULL, NULL, '%QX0.2'),
('lampu_teras', 'Lampu Teras Depan', 'Pencahayaan', 'OFF', 0, NULL, NULL, '%QX0.3'),
('pompa_toren', 'Pompa Pengisi Toren Air', 'Air', 'OFF', 0, NULL, NULL, '%QX0.4'),
('pompa_kolam', 'Pompa Sirkulasi Kolam', 'Air', 'OFF', 0, NULL, NULL, '%QX0.5')
ON DUPLICATE KEY UPDATE `name`=VALUES(`name`);

-- 2. TABEL LOG RIWAYAT AKTIVITAS
CREATE TABLE IF NOT EXISTS `nexora_logs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `device_id` VARCHAR(50) NOT NULL,
  `action` VARCHAR(100) NOT NULL,
  `source` VARCHAR(50) NOT NULL DEFAULT 'App', -- 'App', 'Web', 'PLC', 'Otomasi'
  `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (`device_id`),
  INDEX (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catatan pertama
INSERT INTO `nexora_logs` (`device_id`, `action`, `source`) VALUES
('system', 'Sistem Cloud NEXORA berhasil diinisialisasi di cPanel Alfa', 'System');
