<?php
/**
 * NEXORA / ALRISA CLOUD API — MULTI-ACCOUNT SYNC ENDPOINT
 * Endpoint: /api/sync.php
 * Method: GET / POST (?account_id=... or ?email=...)
 * Mengembalikan profil hardware, prefix MQTT, daftar perangkat, dan kamera CCTV spesifik akun tersebut.
 */

require_once __DIR__ . '/../config.php';

$accountId = trim($_GET['account_id'] ?? $_POST['account_id'] ?? '');
$email = strtolower(trim($_GET['email'] ?? $_POST['email'] ?? ''));

if (empty($accountId) && empty($email)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Parameter account_id atau email wajib disertakan.'
    ]);
    exit();
}

$accountData = null;
$devicesList = [];
$cctvList = [];

// 1. Coba ambil dari Database MySQL jika aktif
try {
    $pdo = getDbConnection();
    
    // Ambil Data Akun
    if (!empty($accountId)) {
        $stmt = $pdo->prepare("SELECT id, name, email, role, hardware_type, mqtt_prefix, mqtt_broker, mqtt_port FROM nexora_accounts WHERE id = ? LIMIT 1");
        $stmt->execute([$accountId]);
    } else {
        $stmt = $pdo->prepare("SELECT id, name, email, role, hardware_type, mqtt_prefix, mqtt_broker, mqtt_port FROM nexora_accounts WHERE LOWER(email) = ? LIMIT 1");
        $stmt->execute([$email]);
    }
    $acc = $stmt->fetch();

    if ($acc) {
        $accountId = $acc['id'];
        $accountData = $acc;

        // Ambil Perangkat Akun
        $stmtDev = $pdo->prepare("SELECT id, name, category, type, state, value, plc_address FROM nexora_devices WHERE account_id = ? ORDER BY id ASC");
        $stmtDev->execute([$accountId]);
        $rowsDev = $stmtDev->fetchAll();
        foreach ($rowsDev as $r) {
            // Mapping tipe ke index integer (gate=0, light=1, slidingDoor=2, curtain=3, waterPump=4)
            $typeIdx = 0;
            if ($r['type'] === 'light') $typeIdx = 1;
            else if ($r['type'] === 'slidingDoor') $typeIdx = 2;
            else if ($r['type'] === 'curtain') $typeIdx = 3;
            else if ($r['type'] === 'waterPump') $typeIdx = 4;

            $devicesList[] = [
                'id' => $r['id'],
                'name' => $r['name'],
                'category' => $r['category'] ?? 'Umum',
                'type' => $typeIdx,
                'hardwarePin' => $r['plc_address'] ?? 'GPIO 2',
                'isActive' => in_array(strtoupper($r['state']), ['ON', 'TERBUKA']),
                'value' => (float)$r['value'],
                'statusText' => $r['state']
            ];
        }

        // Ambil CCTV Akun
        $stmtCctv = $pdo->prepare("SELECT id, name, location, rtsp_url, onvif_host, onvif_port, bound_gate_id, fps, resolution FROM nexora_cctv WHERE account_id = ? ORDER BY id ASC");
        $stmtCctv->execute([$accountId]);
        $rowsCctv = $stmtCctv->fetchAll();
        foreach ($rowsCctv as $c) {
            $cctvList[] = [
                'id' => $c['id'],
                'name' => $c['name'],
                'location' => $c['location'],
                'rtspUrl' => $c['rtsp_url'],
                'onvifHost' => $c['onvif_host'] ?? '192.168.1.50',
                'onvifPort' => (int)($c['onvif_port'] ?? 80),
                'boundGateId' => $c['bound_gate_id'],
                'fps' => (float)($c['fps'] ?? 25.0),
                'resolution' => $c['resolution'] ?? '1080P FHD (H.264)',
                'isOnline' => true
            ];
        }
    }
} catch (Exception $e) {
    // Database tidak aktif, fallback ke settings.json
}

// 2. Fallback ke settings.json
if (!$accountData) {
    $jsonPath = __DIR__ . '/../settings.json';
    if (file_exists($jsonPath)) {
        $content = file_get_contents($jsonPath);
        $data = json_decode($content, true);
        if (!empty($data['accounts']) && is_array($data['accounts'])) {
            foreach ($data['accounts'] as $acc) {
                if ((!empty($accountId) && $acc['id'] === $accountId) || (!empty($email) && strtolower($acc['email'] ?? '') === $email)) {
                    $accountData = [
                        'id' => $acc['id'],
                        'name' => $acc['name'],
                        'email' => $acc['email'],
                        'role' => $acc['role'] ?? 'user',
                        'hardware_type' => $acc['hardware_type'] ?? 'Raspberry Pi 4',
                        'hardware_desc' => $acc['hardware_desc'] ?? '',
                        'mqtt_prefix' => $acc['mqtt_prefix'] ?? 'alrisa/client',
                        'mqtt_broker' => $acc['mqtt_broker'] ?? ($data['system']['mqtt_default_broker'] ?? 'broker.emqx.io'),
                        'mqtt_port' => intval($acc['mqtt_port'] ?? ($data['system']['mqtt_default_port'] ?? 1883))
                    ];
                    $devicesList = $acc['devices'] ?? [];
                    $cctvList = $acc['cctv'] ?? [];
                    break;
                }
            }
        }
    }
}

if (!$accountData) {
    http_response_code(404);
    echo json_encode([
        'success' => false,
        'message' => 'Akun tidak ditemukan pada server Cloud.'
    ]);
    exit();
}

echo json_encode([
    'success' => true,
    'timestamp' => date('Y-m-d H:i:s'),
    'account' => $accountData,
    'total_devices' => count($devicesList),
    'devices' => $devicesList,
    'total_cctv' => count($cctvList),
    'cctv' => $cctvList
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
