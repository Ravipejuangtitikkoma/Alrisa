<?php
require_once __DIR__ . '/../config.php';

// Endpoint ini bisa diakses publik (atau butuh key jika diinginkan)
$pdo = getDbConnection();

try {
    // Ambil semua perangkat
    $stmt = $pdo->query("SELECT id, name, category, state, value, pending_command, pending_value, last_updated, plc_address FROM nexora_devices ORDER BY id ASC");
    $devices = $stmt->fetchAll();

    // Map ke dictionary berdasar ID untuk kemudahan akses client
    $deviceMap = [];
    foreach ($devices as $d) {
        $deviceMap[$d['id']] = $d;
    }

    // Ambil 10 log aktivitas terbaru
    $stmtLogs = $pdo->query("SELECT id, device_id, action, source, timestamp FROM nexora_logs ORDER BY id DESC LIMIT 10");
    $recentLogs = $stmtLogs->fetchAll();

    echo json_encode([
        'success' => true,
        'timestamp' => date('Y-m-d H:i:s'),
        'total_devices' => count($devices),
        'devices' => $deviceMap,
        'list' => $devices,
        'recent_logs' => $recentLogs
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan sistem: ' . $e->getMessage()
    ]);
}
