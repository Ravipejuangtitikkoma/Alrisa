<?php
/**
 * ============================================================================
 * ALRISA CLOUD HUB — PHP + MYSQL API GATEWAY (LARAGON WWW & CPANEL HOSTING)
 * ============================================================================
 * File ini memungkinkan `backend_cloud_js` berjalan langsung di Laragon (`www`)
 * maupun di Web Hosting (cPanel / Apache / LiteSpeed) menggunakan database
 * MySQL (`alrisa_cloud`) yang sama persis dengan `server.js` (Node.js).
 * ============================================================================
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, x-admin-id, x-account-id');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 1. Baca konfigurasi dari file .env agar 100% sinkron dengan Node.js
$envFile = __DIR__ . '/.env';
$env = [
    'DB_HOST' => '127.0.0.1',
    'DB_PORT' => '3306',
    'DB_USER' => 'root',
    'DB_PASSWORD' => '',
    'DB_NAME' => 'alrisa_cloud',
];

if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || strpos($line, '#') === 0) continue;
        $parts = explode('=', $line, 2);
        if (count($parts) === 2) {
            $env[trim($parts[0])] = trim($parts[1]);
        }
    }
}

$dbHost = $env['DB_HOST'] ?: '127.0.0.1';
$dbPort = $env['DB_PORT'] ?: '3306';
$dbUser = $env['DB_USER'] ?: 'root';
$dbPass = $env['DB_PASSWORD'] ?? '';
$dbName = $env['DB_NAME'] ?: 'alrisa_cloud';

// 2. Koneksi PDO ke MySQL Laragon / Hosting & Auto-Import jika belum ada database
$pdo = null;
$dbConnected = false;
$dbError = null;

try {
    $pdoInit = new PDO("mysql:host={$dbHost};port={$dbPort};charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5,
    ]);
    $pdoInit->exec("CREATE DATABASE IF NOT EXISTS `{$dbName}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdoInit = null;

    $pdo = new PDO("mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $dbConnected = true;

    // Cek apakah tabel `accounts` sudah ada; jika belum, jalankan database_nexora.sql
    $checkTable = $pdo->query("SHOW TABLES LIKE 'accounts'")->fetchAll();
    if (count($checkTable) === 0) {
        $sqlFile = __DIR__ . '/database_nexora.sql';
        if (file_exists($sqlFile)) {
            $sqlContent = file_get_contents($sqlFile);
            $pdo->exec($sqlContent);
        }
    }
} catch (Exception $e) {
    $dbConnected = false;
    $dbError = $e->getMessage();
}

// Helper: Muat seluruh data dari MySQL (atau fallback settings.json jika MySQL mati)
function loadAllSettings($pdo, $dbConnected) {
    $settingsPath = __DIR__ . '/settings.json';
    if (!$dbConnected || !$pdo) {
        if (file_exists($settingsPath)) {
            return json_decode(file_get_contents($settingsPath), true);
        }
        return ['active_account_id' => 'acc_superadmin', 'system' => [], 'accounts' => []];
    }

    $sys = $pdo->query("SELECT * FROM `system_settings` WHERE `id` = 1 LIMIT 1")->fetch();
    if (!$sys) {
        $sys = [
            'active_account_id' => 'acc_superadmin',
            'app_name' => 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
            'mqtt_default_broker' => 'broker.emqx.io',
            'mqtt_default_port' => 1883,
            'api_secret_key' => 'ALRISA_SUPERADMIN_KEY_2026',
        ];
    }

    $accRows = $pdo->query("SELECT * FROM `accounts` ORDER BY `created_at` ASC, `id` ASC")->fetchAll();
    $devRows = $pdo->query("SELECT * FROM `devices` ORDER BY `uid` ASC")->fetchAll();
    $cctvRows = $pdo->query("SELECT * FROM `cctv_cameras` ORDER BY `uid` ASC")->fetchAll();

    $devicesByAcc = [];
    foreach ($devRows as $d) {
        $accId = $d['account_id'];
        if (!isset($devicesByAcc[$accId])) $devicesByAcc[$accId] = [];
        $devicesByAcc[$accId][] = [
            'id' => $d['id'],
            'name' => $d['name'],
            'type' => (int)$d['type'],
            'category' => $d['category'] ?: 'Keamanan',
            'hardwarePin' => $d['hardware_pin'] ?: 'GPIO 2 (%QX0.0)',
            'isActive' => (bool)$d['is_active'],
            'value' => (int)$d['value'],
            'statusText' => $d['status_text'] ?: ($d['is_active'] ? 'Menyala' : 'Terkunci'),
        ];
    }

    $cctvByAcc = [];
    foreach ($cctvRows as $c) {
        $accId = $c['account_id'];
        if (!isset($cctvByAcc[$accId])) $cctvByAcc[$accId] = [];
        $cctvByAcc[$accId][] = [
            'id' => $c['id'],
            'name' => $c['name'],
            'location' => $c['location'] ?: 'Area Rumah',
            'rtspUrl' => $c['rtsp_url'] ?: '',
            'rtsp_url' => $c['rtsp_url'] ?: '',
            'onvifHost' => $c['onvif_host'] ?: '192.168.1.50',
            'onvif_host' => $c['onvif_host'] ?: '192.168.1.50',
            'onvifPort' => (int)($c['onvif_port'] ?: 80),
            'onvif_port' => (int)($c['onvif_port'] ?: 80),
            'boundGateId' => $c['bound_gate_id'] ?: null,
            'bound_gate' => $c['bound_gate_id'] ?: null,
            'isOnline' => (bool)$c['is_online'],
            'fps' => (int)($c['fps'] ?: 25),
            'resolution' => $c['resolution'] ?: '1080P FHD (H.264)',
        ];
    }

    $accounts = [];
    foreach ($accRows as $a) {
        $id = $a['id'];
        $accounts[] = [
            'id' => $id,
            'name' => $a['name'],
            'email' => $a['email'],
            'password' => $a['password'],
            'role' => $a['role'] ?: 'user',
            'division' => $a['division'] ?: '',
            'created_at' => $a['created_at'] ?: '2026-10-24',
            'hardware_type' => $a['hardware_type'] ?: 'ESP32 Smart Automation Hub',
            'hardware_desc' => $a['hardware_desc'] ?: '',
            'mqtt_broker' => $a['mqtt_broker'] ?: 'broker.emqx.io',
            'mqtt_port' => (int)($a['mqtt_port'] ?: 1883),
            'mqtt_ws_port' => (int)($a['mqtt_ws_port'] ?: 8083),
            'mqtt_prefix' => $a['mqtt_prefix'] ?: ('alrisa/' . $id),
            'mqtt_user' => $a['mqtt_user'] ?: '',
            'mqtt_pass' => $a['mqtt_pass'] ?: '',
            'plc_ip' => $a['plc_ip'] ?: '192.168.1.100',
            'plc_port' => (int)($a['plc_port'] ?: 502),
            'plc_type' => $a['plc_type'] ?: 'Mitsubishi FX5U (Modbus TCP)',
            'wifi_ssid' => $a['wifi_ssid'] ?: '',
            'wifi_password' => $a['wifi_password'] ?: '',
            'devices' => $devicesByAcc[$id] ?? [],
            'cctv' => $cctvByAcc[$id] ?? [],
        ];
    }

    return [
        'active_account_id' => $sys['active_account_id'] ?: 'acc_superadmin',
        'system' => [
            'app_name' => $sys['app_name'] ?: 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
            'mqtt_default_broker' => $sys['mqtt_default_broker'] ?: 'broker.emqx.io',
            'mqtt_default_port' => (int)($sys['mqtt_default_port'] ?: 1883),
            'api_secret_key' => $sys['api_secret_key'] ?: 'ALRISA_SUPERADMIN_KEY_2026',
        ],
        'accounts' => $accounts,
    ];
}

function saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData) {
    $settingsPath = __DIR__ . '/settings.json';
    @file_put_contents($settingsPath, json_encode($settingsData, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

    if (!$dbConnected || !$pdo) return;

    try {
        $pdo->beginTransaction();

        $sys = $settingsData['system'] ?? [];
        $stmtSys = $pdo->prepare("
            INSERT INTO `system_settings` (`id`, `active_account_id`, `app_name`, `mqtt_default_broker`, `mqtt_default_port`, `api_secret_key`)
            VALUES (1, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              `active_account_id` = VALUES(`active_account_id`),
              `app_name` = VALUES(`app_name`),
              `mqtt_default_broker` = VALUES(`mqtt_default_broker`),
              `mqtt_default_port` = VALUES(`mqtt_default_port`),
              `api_secret_key` = VALUES(`api_secret_key`)
        ");
        $stmtSys->execute([
            $settingsData['active_account_id'] ?? 'acc_superadmin',
            $sys['app_name'] ?? 'ALRISA Smart Home & Gate Hub (Multi-Account Edition)',
            $sys['mqtt_default_broker'] ?? 'broker.emqx.io',
            (int)($sys['mqtt_default_port'] ?? 1883),
            $sys['api_secret_key'] ?? 'ALRISA_SUPERADMIN_KEY_2026',
        ]);

        $accounts = $settingsData['accounts'] ?? [];
        $accIds = array_values(array_filter(array_map(fn($a) => $a['id'] ?? null, $accounts)));

        if (count($accIds) > 0) {
            $placeholders = implode(',', array_fill(0, count($accIds), '?'));
            $stmtDelAcc = $pdo->prepare("DELETE FROM `accounts` WHERE `id` NOT IN ({$placeholders})");
            $stmtDelAcc->execute($accIds);
        } else {
            $pdo->exec("DELETE FROM `accounts`");
        }

        $stmtAcc = $pdo->prepare("
            INSERT INTO `accounts` (
              `id`, `name`, `email`, `password`, `role`, `division`,
              `hardware_type`, `hardware_desc`,
              `mqtt_broker`, `mqtt_port`, `mqtt_ws_port`, `mqtt_prefix`, `mqtt_user`, `mqtt_pass`,
              `plc_ip`, `plc_port`, `plc_type`, `wifi_ssid`, `wifi_password`, `created_at`
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              `name` = VALUES(`name`),
              `email` = VALUES(`email`),
              `password` = VALUES(`password`),
              `role` = VALUES(`role`),
              `division` = VALUES(`division`),
              `hardware_type` = VALUES(`hardware_type`),
              `hardware_desc` = VALUES(`hardware_desc`),
              `mqtt_broker` = VALUES(`mqtt_broker`),
              `mqtt_port` = VALUES(`mqtt_port`),
              `mqtt_ws_port` = VALUES(`mqtt_ws_port`),
              `mqtt_prefix` = VALUES(`mqtt_prefix`),
              `mqtt_user` = VALUES(`mqtt_user`),
              `mqtt_pass` = VALUES(`mqtt_pass`),
              `plc_ip` = VALUES(`plc_ip`),
              `plc_port` = VALUES(`plc_port`),
              `plc_type` = VALUES(`plc_type`),
              `wifi_ssid` = VALUES(`wifi_ssid`),
              `wifi_password` = VALUES(`wifi_password`)
        ");

        $stmtDev = $pdo->prepare("
            INSERT INTO `devices` (`id`, `account_id`, `name`, `type`, `category`, `hardware_pin`, `is_active`, `value`, `status_text`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              `name` = VALUES(`name`),
              `type` = VALUES(`type`),
              `category` = VALUES(`category`),
              `hardware_pin` = VALUES(`hardware_pin`),
              `is_active` = VALUES(`is_active`),
              `value` = VALUES(`value`),
              `status_text` = VALUES(`status_text`)
        ");

        $stmtCctv = $pdo->prepare("
            INSERT INTO `cctv_cameras` (`id`, `account_id`, `name`, `location`, `rtsp_url`, `onvif_host`, `onvif_port`, `bound_gate_id`, `is_online`, `fps`, `resolution`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              `name` = VALUES(`name`),
              `location` = VALUES(`location`),
              `rtsp_url` = VALUES(`rtsp_url`),
              `onvif_host` = VALUES(`onvif_host`),
              `onvif_port` = VALUES(`onvif_port`),
              `bound_gate_id` = VALUES(`bound_gate_id`),
              `is_online` = VALUES(`is_online`),
              `fps` = VALUES(`fps`),
              `resolution` = VALUES(`resolution`)
        ");

        foreach ($accounts as $acc) {
            $accId = $acc['id'];
            $createdAt = isset($acc['created_at']) && preg_match('/^\d{4}-\d{2}-\d{2}/', $acc['created_at'])
                ? substr($acc['created_at'], 0, 10)
                : date('Y-m-d');

            $stmtAcc->execute([
                $accId,
                $acc['name'] ?? 'Pengguna Alrisa',
                $acc['email'] ?? ($accId . '@alrisa.id'),
                $acc['password'] ?? '123456',
                $acc['role'] ?? 'user',
                $acc['division'] ?? '',
                $acc['hardware_type'] ?? 'ESP32 Smart Automation Hub',
                $acc['hardware_desc'] ?? '',
                $acc['mqtt_broker'] ?? 'broker.emqx.io',
                (int)($acc['mqtt_port'] ?? 1883),
                (int)($acc['mqtt_ws_port'] ?? 8083),
                $acc['mqtt_prefix'] ?? ('alrisa/' . $accId),
                $acc['mqtt_user'] ?? '',
                $acc['mqtt_pass'] ?? '',
                $acc['plc_ip'] ?? '192.168.1.100',
                (int)($acc['plc_port'] ?? 502),
                $acc['plc_type'] ?? 'Mitsubishi FX5U (Modbus TCP)',
                $acc['wifi_ssid'] ?? '',
                $acc['wifi_password'] ?? '',
                $createdAt,
            ]);

            $devs = $acc['devices'] ?? [];
            $devIds = array_values(array_filter(array_map(fn($d) => $d['id'] ?? null, $devs)));
            if (count($devIds) > 0) {
                $ph = implode(',', array_fill(0, count($devIds), '?'));
                $delD = $pdo->prepare("DELETE FROM `devices` WHERE `account_id` = ? AND `id` NOT IN ({$ph})");
                $delD->execute(array_merge([$accId], $devIds));
            } else {
                $delD = $pdo->prepare("DELETE FROM `devices` WHERE `account_id` = ?");
                $delD->execute([$accId]);
            }

            foreach ($devs as $d) {
                $stmtDev->execute([
                    $d['id'],
                    $accId,
                    $d['name'] ?? $d['id'],
                    (int)($d['type'] ?? 0),
                    $d['category'] ?? 'Keamanan',
                    $d['hardwarePin'] ?? 'GPIO 2 (%QX0.0)',
                    !empty($d['isActive']) ? 1 : 0,
                    (int)($d['value'] ?? 0),
                    $d['statusText'] ?? (!empty($d['isActive']) ? 'Menyala' : 'Terkunci'),
                ]);
            }

            $cams = $acc['cctv'] ?? [];
            $camIds = array_values(array_filter(array_map(fn($c) => $c['id'] ?? null, $cams)));
            if (count($camIds) > 0) {
                $ph = implode(',', array_fill(0, count($camIds), '?'));
                $delC = $pdo->prepare("DELETE FROM `cctv_cameras` WHERE `account_id` = ? AND `id` NOT IN ({$ph})");
                $delC->execute(array_merge([$accId], $camIds));
            } else {
                $delC = $pdo->prepare("DELETE FROM `cctv_cameras` WHERE `account_id` = ?");
                $delC->execute([$accId]);
            }

            foreach ($cams as $c) {
                $rtsp = $c['rtspUrl'] ?? ($c['rtsp_url'] ?? '');
                $host = $c['onvifHost'] ?? ($c['onvif_host'] ?? '192.168.1.50');
                $port = (int)($c['onvifPort'] ?? ($c['onvif_port'] ?? 80));
                $bound = $c['boundGateId'] ?? ($c['bound_gate'] ?? null);
                $stmtCctv->execute([
                    $c['id'],
                    $accId,
                    $c['name'] ?? $c['id'],
                    $c['location'] ?? 'Area Rumah',
                    $rtsp,
                    $host,
                    $port,
                    $bound,
                    (!isset($c['isOnline']) || $c['isOnline']) ? 1 : 0,
                    (int)($c['fps'] ?? 25),
                    $c['resolution'] ?? '1080P FHD (H.264)',
                ]);
            }
        }

        $pdo->commit();
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
    }
}

function addActivityLog($pdo, $dbConnected, $deviceId, $action, $origin = 'WEB', $accountId = 'acc_superadmin') {
    if (!$dbConnected || !$pdo) return;
    try {
        $stmt = $pdo->prepare("INSERT INTO `activity_logs` (`timestamp`, `device_id`, `action`, `origin`, `account_id`) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([date('H.i.s'), $deviceId, $action, $origin, $accountId]);
    } catch (Exception $e) {}
}

function &findAccByIdOrEmail(&$settingsData, $identifier) {
    $null = null;
    if (!isset($settingsData['accounts']) || !is_array($settingsData['accounts'])) return $null;
    $clean = strtolower(trim((string)$identifier));
    foreach ($settingsData['accounts'] as &$acc) {
        if (strtolower($acc['id'] ?? '') === $clean || strtolower($acc['email'] ?? '') === $clean || strtolower($acc['name'] ?? '') === $clean) {
            return $acc;
        }
    }
    return $null;
}

// 3. Parse Request Body & Route Path
$rawBody = file_get_contents('php://input');
$body = json_decode($rawBody, true);
if (!is_array($body)) $body = $_POST;

$requestUri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$endpoint = $_GET['endpoint'] ?? '';
if (!$endpoint) {
    if (preg_match('#/api/(.+)$#', $requestUri, $m)) {
        $endpoint = $m[1];
    }
}
$endpoint = trim($endpoint, '/');
$method = $_SERVER['REQUEST_METHOD'];

$settingsData = loadAllSettings($pdo, $dbConnected);

// Route 1: /api/health & /api/db-status
if ($endpoint === 'health' || $endpoint === 'db-status') {
    echo json_encode([
        'status' => 'ONLINE',
        'success' => true,
        'system' => $settingsData['system']['app_name'] ?? 'ALRISA Cloud Smart Systems',
        'version' => '3.2.0 (Laragon PHP + MySQL Edition)',
        'database' => [
            'engine' => 'MySQL',
            'connected' => $dbConnected,
            'host' => $dbHost,
            'port' => (int)$dbPort,
            'database' => $dbName,
            'error' => $dbError,
        ],
        'mqttConnected' => true,
        'active_account' => $settingsData['active_account_id'] ?? 'acc_superadmin',
        'timestamp' => gmdate('c'),
    ]);
    exit;
}

// Route 2: /api/login
if ($endpoint === 'login' && $method === 'POST') {
    $identifier = $body['email'] ?? ($body['username'] ?? ($body['identifier'] ?? ''));
    $password = trim((string)($body['password'] ?? ''));
    $portal = $body['portal'] ?? '';
    $isWebLogin = ($portal === 'web_admin' || $portal === 'web');

    $acc = &findAccByIdOrEmail($settingsData, $identifier);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun / Email belum terdaftar di database MySQL ALRISA.']);
        exit;
    }
    if (($acc['password'] ?? '') !== $password) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Kata sandi yang Anda masukkan salah!']);
        exit;
    }

    $isAdmin = ($acc['role'] === 'superadmin' || $acc['role'] === 'admin' || $acc['role'] === 0);
    if ($isWebLogin && !$isAdmin) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Akses Ditolak: Halaman Dash Admin khusus untuk Administrator! Pelanggan silakan login di Aplikasi Mobile HP.',
        ]);
        exit;
    }

    addActivityLog($pdo, $dbConnected, $acc['name'], 'Login via ' . ($isWebLogin ? 'Web Dash Admin' : 'Aplikasi Mobile'), 'WEB_AUTH', $acc['id']);

    $roleDisplayName = $acc['role'] === 'superadmin' ? 'Super Admin' : ($acc['role'] === 'admin' ? 'Admin Operasional' : 'Pelanggan Aplikasi Mobile');
    echo json_encode([
        'success' => true,
        'message' => 'Selamat datang, ' . $acc['name'] . '!',
        'token' => 'alrisa_tk_' . base64_encode($acc['id'] . ':' . time()),
        'user' => [
            'id' => $acc['id'],
            'name' => $acc['name'],
            'email' => $acc['email'],
            'role' => $isAdmin ? 0 : 1,
            'rawRole' => $acc['role'],
            'roleName' => $roleDisplayName,
            'division' => $acc['division'] ?? '',
            'isAdmin' => $isAdmin,
            'isSuperAdmin' => ($acc['role'] === 'superadmin'),
            'hardwareType' => $acc['hardware_type'] ?? 'ESP32 Smart Automation Hub',
            'mqttPrefix' => $acc['mqtt_prefix'] ?? ('alrisa/' . $acc['id']),
            'mqttBroker' => $acc['mqtt_broker'] ?? 'broker.emqx.io',
            'mqttPort' => (int)($acc['mqtt_port'] ?? 1883),
            'devices' => $acc['devices'] ?? [],
            'cctv' => $acc['cctv'] ?? [],
        ],
    ]);
    exit;
}

// Route 3: /api/admins
if ($endpoint === 'admins' && $method === 'GET') {
    $admins = [];
    foreach ($settingsData['accounts'] as $a) {
        if ($a['role'] === 'superadmin' || $a['role'] === 'admin' || $a['role'] === 0) {
            $admins[] = [
                'id' => $a['id'],
                'name' => $a['name'],
                'email' => $a['email'],
                'role' => $a['role'],
                'roleLabel' => $a['role'] === 'superadmin' ? 'Super Admin' : 'Admin Operasional',
                'division' => $a['division'] ?: ($a['role'] === 'superadmin' ? 'Head / Super Admin' : 'Admin Sistem'),
                'created_at' => $a['created_at'] ?: '2026-10-24',
                'total_devices' => count($a['devices'] ?? []),
            ];
        }
    }
    echo json_encode(['success' => true, 'total_admins' => count($admins), 'admins' => $admins]);
    exit;
}

// Route 3b: /api/admins/{id} (GET atau DELETE)
if (preg_match('#^admins/([^/]+)$#', $endpoint, $m)) {
    $targetId = $m[1];
    if ($method === 'GET' && $targetId !== 'create' && $targetId !== 'update') {
        $target = &findAccByIdOrEmail($settingsData, $targetId);
        if (!$target) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Administrator tidak ditemukan!']);
            exit;
        }
        echo json_encode([
            'success' => true,
            'admin' => [
                'id' => $target['id'],
                'name' => $target['name'],
                'email' => $target['email'],
                'role' => $target['role'],
                'roleLabel' => $target['role'] === 'superadmin' ? 'Super Admin' : 'Admin Operasional',
                'division' => $target['division'] ?: 'Admin Sistem',
                'created_at' => $target['created_at'] ?: '2026-10-24',
                'total_devices' => count($target['devices'] ?? []),
                'hardware_type' => $target['hardware_type'] ?? 'ESP32 Smart Automation Hub',
            ],
        ]);
        exit;
    }
    if ($method === 'DELETE') {
        $settingsData['accounts'] = array_values(array_filter($settingsData['accounts'], fn($a) => $a['id'] !== $targetId));
        saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
        addActivityLog($pdo, $dbConnected, $targetId, 'Akun Administrator dihapus', 'WEB_AUTH', $targetId);
        echo json_encode(['success' => true, 'message' => 'Administrator berhasil dihapus dari database MySQL!', 'deleted_id' => $targetId]);
        exit;
    }
}

// Route 3c: /api/admins/create
if ($endpoint === 'admins/create' && $method === 'POST') {
    $name = trim($body['name'] ?? '');
    $email = strtolower(trim($body['email'] ?? ''));
    $password = trim($body['password'] ?? '');
    $role = ($body['role'] ?? 'admin') === 'superadmin' ? 'superadmin' : 'admin';
    $division = trim($body['division'] ?? ($role === 'superadmin' ? 'Super Admin' : 'Admin Operasional'));

    $slug = preg_replace('/[^a-z0-9_]/', '', explode('@', $email)[0]) ?: 'admin';
    $newId = 'acc_admin_' . $slug . '_' . substr(md5(uniqid()), 0, 4);

    $newAdmin = [
        'id' => $newId,
        'name' => $name,
        'email' => $email,
        'password' => $password,
        'role' => $role,
        'division' => $division,
        'created_at' => date('Y-m-d'),
        'hardware_type' => 'ESP32 Smart Automation Hub',
        'hardware_desc' => 'Sistem Kontrol Administrator Alrisa Dash',
        'mqtt_broker' => 'broker.emqx.io',
        'mqtt_port' => 1883,
        'mqtt_ws_port' => 8083,
        'mqtt_prefix' => 'alrisa/admin_' . $slug,
        'mqtt_user' => '',
        'mqtt_pass' => '',
        'plc_ip' => '192.168.1.100',
        'plc_port' => 502,
        'plc_type' => 'Mitsubishi FX5U (Modbus TCP)',
        'wifi_ssid' => 'ALRISA_ADMIN_HQ',
        'wifi_password' => '',
        'devices' => [],
        'cctv' => [],
    ];
    $settingsData['accounts'][] = $newAdmin;
    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $name, 'Tambah Admin baru di MySQL', 'WEB_AUTH', $newId);
    echo json_encode(['success' => true, 'message' => "Administrator \"{$name}\" berhasil disimpan ke MySQL!", 'admin' => $newAdmin]);
    exit;
}

// Route 3d: /api/admins/update
if ($endpoint === 'admins/update' && $method === 'POST') {
    $targetId = $body['id'] ?? ($body['target_admin_id'] ?? ($body['account_id'] ?? ''));
    $target = &findAccByIdOrEmail($settingsData, $targetId);
    if (!$target) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Administrator tidak ditemukan!']);
        exit;
    }
    if (!empty($body['name'])) $target['name'] = trim($body['name']);
    if (!empty($body['email'])) $target['email'] = strtolower(trim($body['email']));
    if (!empty($body['password'])) $target['password'] = trim($body['password']);
    if (!empty($body['division'])) $target['division'] = trim($body['division']);
    if (!empty($body['role'])) $target['role'] = $body['role'] === 'superadmin' ? 'superadmin' : 'admin';

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    echo json_encode(['success' => true, 'message' => 'Data administrator berhasil diperbarui di MySQL!', 'admin' => $target]);
    exit;
}

// Route 4: /api/customers
if ($endpoint === 'customers' && $method === 'GET') {
    $customers = [];
    foreach ($settingsData['accounts'] as $a) {
        if ($a['role'] !== 'superadmin' && $a['role'] !== 'admin' && $a['role'] !== 0) {
            $customers[] = [
                'id' => $a['id'],
                'name' => $a['name'],
                'email' => $a['email'],
                'role' => $a['role'] ?: 'user',
                'hardware_type' => $a['hardware_type'] ?: 'ESP32 Smart Automation Hub',
                'mqtt_prefix' => $a['mqtt_prefix'],
                'total_devices' => count($a['devices'] ?? []),
                'total_cctv' => count($a['cctv'] ?? []),
            ];
        }
    }
    echo json_encode(['success' => true, 'total_customers' => count($customers), 'customers' => $customers]);
    exit;
}

// Route 5: /api/accounts & /api/accounts/sync & /api/accounts/switch & /api/accounts/create & /api/accounts/update & /api/accounts/{id}
if ($endpoint === 'accounts' && $method === 'GET') {
    $safe = array_map(fn($a) => [
        'id' => $a['id'],
        'name' => $a['name'],
        'email' => $a['email'],
        'role' => $a['role'],
        'hardware_type' => $a['hardware_type'],
        'mqtt_prefix' => $a['mqtt_prefix'],
        'total_devices' => count($a['devices'] ?? []),
        'total_cctv' => count($a['cctv'] ?? []),
    ], $settingsData['accounts']);
    echo json_encode(['success' => true, 'active_account_id' => $settingsData['active_account_id'], 'accounts' => $safe]);
    exit;
}

if ($endpoint === 'accounts/sync') {
    $list = array_map(fn($a) => [
        'id' => $a['id'],
        'name' => $a['name'],
        'email' => $a['email'],
        'password' => $a['password'],
        'role' => $a['role'] === 'superadmin' ? 0 : 1,
        'hardwareType' => $a['hardware_type'] ?: 'ESP32 Smart Automation Hub',
        'mqttPrefix' => $a['mqtt_prefix'] ?: ('alrisa/' . $a['id']),
        'mqttBroker' => $a['mqtt_broker'] ?: 'broker.emqx.io',
        'mqttPort' => (int)($a['mqtt_port'] ?: 1883),
        'devices' => $a['devices'] ?? [],
        'cctv' => $a['cctv'] ?? [],
    ], $settingsData['accounts']);
    echo json_encode(['success' => true, 'accounts' => $list]);
    exit;
}

if ($endpoint === 'accounts/switch' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $acc = &findAccByIdOrEmail($settingsData, $accId);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }
    $settingsData['active_account_id'] = $acc['id'];
    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    echo json_encode(['success' => true, 'message' => 'Akun aktif berganti ke ' . $acc['name'], 'active_account' => $acc]);
    exit;
}

if ($endpoint === 'accounts/create' && $method === 'POST') {
    $name = trim($body['name'] ?? '');
    $email = strtolower(trim($body['email'] ?? ''));
    $password = trim($body['password'] ?? '');
    $slug = preg_replace('/[^a-z0-9_]/', '', explode('@', $email)[0]) ?: 'user';
    $newId = 'acc_' . $slug . '_' . substr(md5(uniqid()), 0, 4);
    $cleanPrefix = !empty($body['mqtt_prefix']) ? trim($body['mqtt_prefix']) : ('alrisa/' . $slug);

    $newAcc = [
        'id' => $newId,
        'name' => $name,
        'email' => $email,
        'password' => $password,
        'role' => 'user',
        'division' => '',
        'created_at' => date('Y-m-d'),
        'hardware_type' => $body['hardware_type'] ?? 'ESP32 Smart Automation Hub',
        'hardware_desc' => 'Modul Otomasi Cerdas Alrisa Cloud IoT',
        'mqtt_broker' => 'broker.emqx.io',
        'mqtt_port' => 1883,
        'mqtt_ws_port' => 8083,
        'mqtt_prefix' => $cleanPrefix,
        'mqtt_user' => '',
        'mqtt_pass' => '',
        'plc_ip' => $body['plc_ip'] ?? '192.168.1.100',
        'plc_port' => 502,
        'plc_type' => 'Mitsubishi FX5U (Modbus TCP)',
        'wifi_ssid' => $body['wifi_ssid'] ?? 'ALRISA_SMART_WIFI',
        'wifi_password' => '',
        'devices' => [
            ['id' => $slug . '_pagar', 'name' => 'Gerbang Utama', 'type' => 0, 'category' => 'Keamanan', 'hardwarePin' => 'GPIO 2 (%QX0.0)', 'isActive' => false, 'value' => 0, 'statusText' => 'Terkunci'],
            ['id' => $slug . '_lampu', 'name' => 'Lampu Teras & Luar', 'type' => 1, 'category' => 'Pencahayaan', 'hardwarePin' => 'GPIO 4 (%QX0.3)', 'isActive' => false, 'value' => 0, 'statusText' => 'Mati'],
            ['id' => $slug . '_pintu', 'name' => 'Pintu Akses Tamu', 'type' => 2, 'category' => 'Akses', 'hardwarePin' => 'GPIO 5 (%QX0.1)', 'isActive' => false, 'value' => 0, 'statusText' => 'Terkunci'],
        ],
        'cctv' => [],
    ];
    $settingsData['accounts'][] = $newAcc;
    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $name, 'Pelanggan baru didaftarkan ke MySQL', 'WEB_AUTH', $newId);
    echo json_encode(['success' => true, 'message' => "Akun \"{$name}\" berhasil disimpan ke database MySQL!", 'account' => $newAcc]);
    exit;
}

if ($endpoint === 'accounts/update' && $method === 'POST') {
    $targetId = $body['id'] ?? ($body['target_account_id'] ?? ($body['account_id'] ?? ''));
    $target = &findAccByIdOrEmail($settingsData, $targetId);
    if (!$target) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun pelanggan tidak ditemukan!']);
        exit;
    }
    if (!empty($body['name'])) $target['name'] = trim($body['name']);
    if (!empty($body['email'])) $target['email'] = strtolower(trim($body['email']));
    if (!empty($body['password'])) $target['password'] = trim($body['password']);
    if (!empty($body['hardware_type'])) $target['hardware_type'] = $body['hardware_type'];
    if (!empty($body['mqtt_prefix'])) $target['mqtt_prefix'] = trim($body['mqtt_prefix']);
    if (isset($body['wifi_ssid'])) $target['wifi_ssid'] = $body['wifi_ssid'];
    if (isset($body['plc_ip'])) $target['plc_ip'] = $body['plc_ip'];

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    echo json_encode(['success' => true, 'message' => "Data pelanggan \"{$target['name']}\" berhasil disimpan ke MySQL!", 'account' => $target]);
    exit;
}

if (preg_match('#^accounts/([^/]+)$#', $endpoint, $m)) {
    $targetId = $m[1];
    if ($method === 'GET') {
        $target = &findAccByIdOrEmail($settingsData, $targetId);
        if (!$target) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan!']);
            exit;
        }
        echo json_encode(['success' => true, 'account' => $target]);
        exit;
    }
    if ($method === 'DELETE') {
        $settingsData['accounts'] = array_values(array_filter($settingsData['accounts'], fn($a) => $a['id'] !== $targetId));
        saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
        echo json_encode(['success' => true, 'message' => 'Akun berhasil dihapus dari database MySQL!', 'deleted_id' => $targetId]);
        exit;
    }
}

// Route 6: /api/sync
if ($endpoint === 'sync') {
    $accId = $_GET['account_id'] ?? ($body['account_id'] ?? '');
    $email = $_GET['email'] ?? ($body['email'] ?? '');
    $acc = null;
    if ($accId) $acc = &findAccByIdOrEmail($settingsData, $accId);
    if (!$acc && $email) $acc = &findAccByIdOrEmail($settingsData, $email);
    if (!$acc) $acc = &findAccByIdOrEmail($settingsData, $settingsData['active_account_id'] ?? 'acc_superadmin');
    if (!$acc && count($settingsData['accounts']) > 0) $acc = &$settingsData['accounts'][0];

    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    echo json_encode([
        'success' => true,
        'timestamp' => gmdate('c'),
        'account' => [
            'id' => $acc['id'],
            'name' => $acc['name'],
            'email' => $acc['email'],
            'role' => $acc['role'] ?? 'user',
            'hardware_type' => $acc['hardware_type'] ?? 'ESP32 Smart Automation Hub',
            'hardware_desc' => $acc['hardware_desc'] ?? '',
            'mqtt_prefix' => $acc['mqtt_prefix'] ?? 'alrisa/client',
            'mqtt_broker' => $acc['mqtt_broker'] ?? 'broker.emqx.io',
            'mqtt_port' => (int)($acc['mqtt_port'] ?? 1883),
            'mqtt_ws_port' => (int)($acc['mqtt_ws_port'] ?? 8083),
            'wifi_ssid' => $acc['wifi_ssid'] ?? '',
        ],
        'total_devices' => count($acc['devices'] ?? []),
        'devices' => $acc['devices'] ?? [],
        'total_cctv' => count($acc['cctv'] ?? []),
        'cctv' => $acc['cctv'] ?? [],
    ]);
    exit;
}

// Route 7: /api/sync_devices (Sinkronisasi dari HP ke MySQL)
if ($endpoint === 'sync_devices' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $email = $body['email'] ?? '';
    $acc = null;
    if ($accId) $acc = &findAccByIdOrEmail($settingsData, $accId);
    if (!$acc && $email) $acc = &findAccByIdOrEmail($settingsData, $email);
    if (!$acc) $acc = &findAccByIdOrEmail($settingsData, $settingsData['active_account_id'] ?? 'acc_superadmin');

    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    if (isset($body['devices']) && is_array($body['devices'])) {
        $acc['devices'] = $body['devices'];
    }
    if (isset($body['cctv']) && is_array($body['cctv'])) {
        $acc['cctv'] = $body['cctv'];
    }

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, 'SYSTEM_SYNC', 'Sinkronisasi perangkat & CCTV dari HP ke MySQL', 'MOBILE_APP', $acc['id']);
    echo json_encode([
        'success' => true,
        'message' => 'Perangkat dan CCTV berhasil disimpan ke database MySQL!',
        'account_id' => $acc['id'],
        'total_devices' => count($acc['devices'] ?? []),
        'total_cctv' => count($acc['cctv'] ?? []),
    ]);
    exit;
}

// Route 8: /api/device/save
if ($endpoint === 'device/save' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $email = $body['email'] ?? '';
    $device = $body['device'] ?? null;
    if (!$device || empty($device['name'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Nama perangkat wajib diisi']);
        exit;
    }

    $acc = &findAccByIdOrEmail($settingsData, $accId ?: $email ?: $settingsData['active_account_id']);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    $devId = trim($device['id'] ?? '') ?: ('dev_' . uniqid());
    $updatedDev = [
        'id' => $devId,
        'name' => trim($device['name']),
        'type' => (int)($device['type'] ?? 0),
        'category' => $device['category'] ?? 'Keamanan',
        'hardwarePin' => trim($device['hardwarePin'] ?? 'GPIO 2 (%QX0.0)'),
        'isActive' => !empty($device['isActive']),
        'value' => (int)($device['value'] ?? 0),
        'statusText' => $device['statusText'] ?? (!empty($device['isActive']) ? 'Menyala' : 'Terkunci'),
    ];

    $foundIdx = -1;
    foreach ($acc['devices'] as $idx => $d) {
        if ($d['id'] === $devId) {
            $foundIdx = $idx;
            break;
        }
    }
    if ($foundIdx !== -1) {
        $acc['devices'][$foundIdx] = $updatedDev;
    } else {
        $acc['devices'][] = $updatedDev;
    }

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $devId, "Simpan PIN/Perangkat ke MySQL: {$updatedDev['name']} ({$updatedDev['hardwarePin']})", 'WEB_STUDIO', $acc['id']);
    echo json_encode([
        'success' => true,
        'message' => "Perangkat \"{$updatedDev['name']}\" berhasil disimpan ke MySQL!",
        'device' => $updatedDev,
        'total_devices' => count($acc['devices']),
        'account_id' => $acc['id'],
    ]);
    exit;
}

// Route 9: /api/device/delete
if ($endpoint === 'device/delete' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $devId = $body['device_id'] ?? '';
    $acc = &findAccByIdOrEmail($settingsData, $accId ?: $settingsData['active_account_id']);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }
    $acc['devices'] = array_values(array_filter($acc['devices'], fn($d) => $d['id'] !== $devId));
    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $devId, "Hapus perangkat dari MySQL: {$devId}", 'WEB_STUDIO', $acc['id']);
    echo json_encode(['success' => true, 'message' => 'Perangkat berhasil dihapus dari MySQL!', 'device_id' => $devId]);
    exit;
}

// Route 10: /api/cctv/save
if ($endpoint === 'cctv/save' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $cctv = $body['cctv'] ?? null;
    if (!$cctv || empty($cctv['name'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Nama CCTV wajib diisi']);
        exit;
    }
    $acc = &findAccByIdOrEmail($settingsData, $accId ?: $settingsData['active_account_id']);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }

    $cctvId = trim($cctv['id'] ?? '') ?: ('cctv_' . time());
    $rtsp = trim($cctv['rtspUrl'] ?? ($cctv['rtsp_url'] ?? ''));
    $bound = trim($cctv['boundGateId'] ?? ($cctv['bound_gate'] ?? 'pagar'));
    $updatedCam = [
        'id' => $cctvId,
        'name' => trim($cctv['name']),
        'location' => trim($cctv['location'] ?? 'Area Rumah'),
        'rtspUrl' => $rtsp,
        'rtsp_url' => $rtsp,
        'onvifHost' => $cctv['onvifHost'] ?? '192.168.1.50',
        'onvif_host' => $cctv['onvifHost'] ?? '192.168.1.50',
        'onvifPort' => (int)($cctv['onvifPort'] ?? 80),
        'onvif_port' => (int)($cctv['onvifPort'] ?? 80),
        'boundGateId' => $bound,
        'bound_gate' => $bound,
        'isOnline' => true,
        'fps' => 25,
        'resolution' => $cctv['resolution'] ?? '1080P FHD (H.264)',
    ];

    $foundIdx = -1;
    foreach ($acc['cctv'] as $idx => $c) {
        if ($c['id'] === $cctvId) {
            $foundIdx = $idx;
            break;
        }
    }
    if ($foundIdx !== -1) {
        $acc['cctv'][$foundIdx] = $updatedCam;
    } else {
        $acc['cctv'][] = $updatedCam;
    }

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $cctvId, "Simpan CCTV ke MySQL: {$updatedCam['name']}", 'WEB_STUDIO', $acc['id']);
    echo json_encode(['success' => true, 'message' => "Kamera CCTV \"{$updatedCam['name']}\" berhasil disimpan ke MySQL!", 'cctv' => $updatedCam]);
    exit;
}

// Route 11: /api/cctv/delete
if ($endpoint === 'cctv/delete' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $cctvId = $body['cctv_id'] ?? '';
    $acc = &findAccByIdOrEmail($settingsData, $accId ?: $settingsData['active_account_id']);
    if (!$acc) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }
    $acc['cctv'] = array_values(array_filter($acc['cctv'], fn($c) => $c['id'] !== $cctvId));
    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    addActivityLog($pdo, $dbConnected, $cctvId, "Hapus CCTV dari MySQL: {$cctvId}", 'WEB_STUDIO', $acc['id']);
    echo json_encode(['success' => true, 'message' => 'Kamera CCTV berhasil dihapus dari MySQL!', 'cctv_id' => $cctvId]);
    exit;
}

// Route 12: /api/devices/{id}/control & /api/control
if (preg_match('#^devices/([^/]+)/control$#', $endpoint, $m) || $endpoint === 'control') {
    $deviceId = $m[1] ?? ($body['device_id'] ?? '');
    $accId = $body['account_id'] ?? $settingsData['active_account_id'];
    $state = $body['state'] ?? ($body['action'] ?? false);
    $isStateOn = is_bool($state) ? $state : in_array(strtoupper(trim((string)$state)), ['ON', 'OPEN', 'BUKA', 'TRUE', '1']);
    $val = $body['value'] ?? null;

    $acc = &findAccByIdOrEmail($settingsData, $accId);
    if ($acc && isset($acc['devices'])) {
        foreach ($acc['devices'] as &$d) {
            if ($d['id'] === $deviceId) {
                $d['isActive'] = $isStateOn;
                $d['statusText'] = $isStateOn ? (($d['type'] === 0 || $d['type'] === 2) ? 'Terbuka' : 'Menyala') : (($d['type'] === 0 || $d['type'] === 2) ? 'Terkunci' : 'Mati');
                if ($val !== null) $d['value'] = (int)$val;
                break;
            }
        }
        saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    }
    $cmdStr = $isStateOn ? 'OPEN' : 'CLOSE';
    addActivityLog($pdo, $dbConnected, $deviceId, "Perintah: {$cmdStr}", 'WEB_DASHBOARD', $acc['id'] ?? 'acc_superadmin');
    echo json_encode(['success' => true, 'device_id' => $deviceId, 'action' => $cmdStr, 'state' => $isStateOn, 'value' => $val]);
    exit;
}

// Route 13: /api/mqtt/update-user
if ($endpoint === 'mqtt/update-user' && $method === 'POST') {
    $accId = $body['account_id'] ?? '';
    $target = &findAccByIdOrEmail($settingsData, $accId);
    if (!$target) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
        exit;
    }
    if (isset($body['mqtt_broker'])) $target['mqtt_broker'] = trim($body['mqtt_broker']);
    if (isset($body['mqtt_port'])) $target['mqtt_port'] = (int)$body['mqtt_port'];
    if (isset($body['mqtt_ws_port'])) $target['mqtt_ws_port'] = (int)$body['mqtt_ws_port'];
    if (isset($body['mqtt_prefix'])) $target['mqtt_prefix'] = trim($body['mqtt_prefix']);
    if (isset($body['mqtt_user'])) $target['mqtt_user'] = $body['mqtt_user'];
    if (isset($body['mqtt_pass'])) $target['mqtt_pass'] = $body['mqtt_pass'];
    if (isset($body['wifi_ssid'])) $target['wifi_ssid'] = $body['wifi_ssid'];
    if (isset($body['wifi_pass'])) $target['wifi_password'] = $body['wifi_pass'];

    saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
    echo json_encode(['success' => true, 'message' => "Konfigurasi MQTT untuk \"{$target['name']}\" berhasil disimpan ke MySQL!"]);
    exit;
}

// Route 14: /api/logs
if ($endpoint === 'logs') {
    $logs = [];
    if ($dbConnected && $pdo) {
        $logs = $pdo->query("SELECT `timestamp`, `device_id` AS `deviceId`, `action`, `origin`, `account_id` AS `accountId` FROM `activity_logs` ORDER BY `id` DESC LIMIT 50")->fetchAll();
    }
    echo json_encode(['success' => true, 'logs' => $logs]);
    exit;
}

// Route 15: /api/settings
if ($endpoint === 'settings') {
    if ($method === 'GET') {
        echo json_encode(['success' => true, 'data' => $settingsData]);
        exit;
    }
    if ($method === 'POST') {
        if (!empty($body['accounts']) && is_array($body['accounts'])) {
            $settingsData['accounts'] = $body['accounts'];
        }
        saveAllSettingsToMySQL($pdo, $dbConnected, $settingsData);
        echo json_encode(['success' => true, 'message' => 'Data konfigurasi berhasil disimpan ke MySQL!', 'data' => $settingsData]);
        exit;
    }
}

echo json_encode(['success' => false, 'message' => 'Endpoint API tidak ditemukan: ' . $endpoint]);

