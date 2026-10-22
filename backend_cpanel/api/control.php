<?php
/**
 * NEXORA / ALRISA CLOUD API — DEVICE CONTROL ENDPOINT
 * Endpoint: /api/control.php
 * Method: POST (device_id, action, value, account_id, source)
 */

require_once __DIR__ . '/../config.php';

// Validasi Keamanan API Key (Opsional lewat header / query jika diset)
// requireApiKey();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Hanya menerima request method POST']);
    exit();
}

$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true) ?: $_POST;

$deviceId = trim($data['device_id'] ?? '');
$action = trim($data['action'] ?? '');
$value = isset($data['value']) ? intval($data['value']) : null;
$accountId = trim($data['account_id'] ?? 'acc_superadmin');
$source = trim($data['source'] ?? 'Flutter App');

if (empty($deviceId) || empty($action)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Parameter device_id dan action wajib diisi.'
    ]);
    exit();
}

// 1. Coba update via Database MySQL
$dbUpdated = false;
try {
    $pdo = getDbConnection();
    
    // Cek apakah perangkat terdaftar pada akun tersebut
    $checkStmt = $pdo->prepare("SELECT id, name FROM nexora_devices WHERE id = ? AND account_id = ?");
    $checkStmt->execute([$deviceId, $accountId]);
    $device = $checkStmt->fetch();

    if ($device) {
        $newState = ($action === 'BUKA' || $action === 'ON') ? 'ON' : (($action === 'TUTUP' || $action === 'OFF') ? 'OFF' : $action);
        if ($value !== null) {
            $updateStmt = $pdo->prepare("UPDATE nexora_devices SET pending_command = ?, pending_value = ?, value = ?, state = ? WHERE id = ? AND account_id = ?");
            $updateStmt->execute([$action, $value, $value, $newState, $deviceId, $accountId]);
        } else {
            $updateStmt = $pdo->prepare("UPDATE nexora_devices SET pending_command = ?, state = ? WHERE id = ? AND account_id = ?");
            $updateStmt->execute([$action, $newState, $deviceId, $accountId]);
        }

        // Catat ke Log
        $logStmt = $pdo->prepare("INSERT INTO nexora_logs (account_id, device_id, action, source) VALUES (?, ?, ?, ?)");
        $logActionText = "Perintah: $action" . ($value !== null ? " ($value%)" : "");
        $logStmt->execute([$accountId, $deviceId, $logActionText, $source]);
        $dbUpdated = true;
    }
} catch (Exception $e) {
    // Database tidak aktif, lanjut ke fallback JSON
}

// 2. Update di settings.json jika mode file / fallback
$jsonPath = __DIR__ . '/../settings.json';
if (file_exists($jsonPath)) {
    $content = file_get_contents($jsonPath);
    $dataJson = json_decode($content, true);
    if (!empty($dataJson['accounts'])) {
        foreach ($dataJson['accounts'] as &$acc) {
            if ($acc['id'] === $accountId && !empty($acc['devices'])) {
                foreach ($acc['devices'] as &$dev) {
                    if ($dev['id'] === $deviceId) {
                        $isActive = in_array(strtoupper($action), ['BUKA', 'ON', 'TERBUKA', 'RUN']);
                        $dev['isActive'] = $isActive;
                        if ($value !== null) {
                            $dev['value'] = (float)$value;
                        }
                        $dev['statusText'] = $isActive ? ($dev['type'] == 0 ? 'Terbuka' : 'Menyala') : ($dev['type'] == 0 ? 'Terkunci' : 'Padam');
                        break;
                    }
                }
            }
        }
        file_put_contents($jsonPath, json_encode($dataJson, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }
}

echo json_encode([
    'success' => true,
    'message' => "Perintah '$action' berhasil dikirim ke akun '$accountId'.",
    'account_id' => $accountId,
    'device' => $deviceId,
    'pending_command' => $action,
    'value' => $value
]);
