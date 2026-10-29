<?php
/**
 * NEXORA / ALRISA CLOUD API — DEVICES STATUS ENDPOINT
 * Endpoint: /api/devices.php?account_id=...
 */

require_once __DIR__ . '/../config.php';

$accountId = trim($_GET['account_id'] ?? $_POST['account_id'] ?? '');

$devices = [];
$deviceMap = [];
$recentLogs = [];

// 1. Coba ambil dari Database MySQL jika aktif
try {
    $pdo = getDbConnection();
    
    if (!empty($accountId)) {
        $stmt = $pdo->prepare("SELECT id, name, category, state, value, pending_command, pending_value, last_updated, plc_address FROM nexora_devices WHERE account_id = ? ORDER BY id ASC");
        $stmt->execute([$accountId]);
    } else {
        $stmt = $pdo->query("SELECT id, name, category, state, value, pending_command, pending_value, last_updated, plc_address FROM nexora_devices ORDER BY id ASC");
    }
    $devices = $stmt->fetchAll();

    foreach ($devices as $d) {
        $deviceMap[$d['id']] = $d;
    }

    if (!empty($accountId)) {
        $stmtLogs = $pdo->prepare("SELECT id, device_id, action, source, timestamp FROM nexora_logs WHERE account_id = ? ORDER BY id DESC LIMIT 10");
        $stmtLogs->execute([$accountId]);
    } else {
        $stmtLogs = $pdo->query("SELECT id, device_id, action, source, timestamp FROM nexora_logs ORDER BY id DESC LIMIT 10");
    }
    $recentLogs = $stmtLogs->fetchAll();

} catch (Exception $e) {
    // Database tidak aktif, fallback ke settings.json
    $jsonPath = __DIR__ . '/../settings.json';
    if (file_exists($jsonPath)) {
        $content = file_get_contents($jsonPath);
        $data = json_decode($content, true);
        $targetAccount = null;
        if (!empty($data['accounts'])) {
            foreach ($data['accounts'] as $acc) {
                if (empty($accountId) || $acc['id'] === $accountId) {
                    $targetAccount = $acc;
                    break;
                }
            }
        }
        if ($targetAccount && !empty($targetAccount['devices'])) {
            foreach ($targetAccount['devices'] as $d) {
                $item = [
                    'id' => $d['id'],
                    'name' => $d['name'],
                    'category' => $d['category'] ?? 'Umum',
                    'type' => $d['type'] ?? 0,
                    'state' => ($d['isActive'] ?? false) ? 'ON' : 'OFF',
                    'value' => intval($d['value'] ?? 0),
                    'pending_command' => null,
                    'pending_value' => null,
                    'last_updated' => date('Y-m-d H:i:s'),
                    'plc_address' => $d['hardwarePin'] ?? 'GPIO 2'
                ];
                $devices[] = $item;
                $deviceMap[$d['id']] = $item;
            }
        }
    }
}

echo json_encode([
    'success' => true,
    'timestamp' => date('Y-m-d H:i:s'),
    'account_id' => $accountId,
    'total_devices' => count($devices),
    'devices' => $deviceMap,
    'list' => $devices,
    'recent_logs' => $recentLogs
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
