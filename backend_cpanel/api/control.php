<?php
require_once __DIR__ . '/../config.php';

// Validasi Keamanan API Key
requireApiKey();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Hanya menerima request method POST']);
    exit();
}

// Ambil input JSON
$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);

if (!$data) {
    $data = $_POST;
}

$deviceId = trim($data['device_id'] ?? '');
$action = trim($data['action'] ?? '');
$value = isset($data['value']) ? intval($data['value']) : null;
$source = trim($data['source'] ?? 'Flutter App');

if (empty($deviceId) || empty($action)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Parameter device_id dan action wajib diisi.'
    ]);
    exit();
}

$pdo = getDbConnection();

try {
    // Cek apakah perangkat terdaftar
    $checkStmt = $pdo->prepare("SELECT id, name FROM nexora_devices WHERE id = ?");
    $checkStmt->execute([$deviceId]);
    $device = $checkStmt->fetch();

    if (!$device) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Perangkat dengan ID '$deviceId' tidak ditemukan."
        ]);
        exit();
    }

    // Set status sementara & tandai pending command untuk ditarik oleh Gateway/PLC
    if ($value !== null) {
        $updateStmt = $pdo->prepare("UPDATE nexora_devices SET pending_command = ?, pending_value = ?, value = ? WHERE id = ?");
        $updateStmt->execute([$action, $value, $value, $deviceId]);
    } else {
        $updateStmt = $pdo->prepare("UPDATE nexora_devices SET pending_command = ? WHERE id = ?");
        $updateStmt->execute([$action, $deviceId]);
    }

    // Simpan ke Log Aktivitas
    $logStmt = $pdo->prepare("INSERT INTO nexora_logs (device_id, action, source) VALUES (?, ?, ?)");
    $logActionText = "Perintah: $action" . ($value !== null ? " ($value%)" : "");
    $logStmt->execute([$deviceId, $logActionText, $source]);

    echo json_encode([
        'success' => true,
        'message' => "Perintah '$action' berhasil dikirim ke antrean Cloud NEXORA.",
        'device' => $deviceId,
        'pending_command' => $action,
        'value' => $value
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal memproses kontrol: ' . $e->getMessage()
    ]);
}
