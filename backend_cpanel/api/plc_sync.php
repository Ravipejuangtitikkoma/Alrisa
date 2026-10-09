<?php
require_once __DIR__ . '/../config.php';

// Validasi Keamanan API Key
requireApiKey();

$pdo = getDbConnection();

// Gateway mengirimkan status sensor/coil fisik PLC terbaru via POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $rawInput = file_get_contents('php://input');
    $data = json_decode($rawInput, true);

    if ($data && isset($data['current_states']) && is_array($data['current_states'])) {
        foreach ($data['current_states'] as $deviceId => $state) {
            $val = isset($data['values'][$deviceId]) ? intval($data['values'][$deviceId]) : null;

            if ($val !== null) {
                $upd = $pdo->prepare("UPDATE nexora_devices SET state = ?, value = ?, pending_command = NULL WHERE id = ?");
                $upd->execute([$state, $val, $deviceId]);
            } else {
                $upd = $pdo->prepare("UPDATE nexora_devices SET state = ?, pending_command = NULL WHERE id = ?");
                $upd->execute([$state, $deviceId]);
            }
        }
    }
}

// Kembalikan semua perintah yang sedang antre (pending commands) untuk dieksekusi oleh PLC
try {
    $stmt = $pdo->query("SELECT id, name, pending_command, pending_value, plc_address FROM nexora_devices WHERE pending_command IS NOT NULL AND pending_command != ''");
    $pending = $stmt->fetchAll();

    echo json_encode([
        'success' => true,
        'timestamp' => time(),
        'has_commands' => count($pending) > 0,
        'commands' => $pending
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil pending commands: ' . $e->getMessage()
    ]);
}
