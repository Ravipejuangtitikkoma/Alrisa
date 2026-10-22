<?php
/**
 * NEXORA / ALRISA CLOUD API — AUTHENTICATION ENDPOINT
 * Endpoint: /api/auth.php
 * Method: POST (email, password)
 */

require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Hanya menerima request method POST'
    ]);
    exit();
}

$rawInput = file_get_contents('php://input');
$input = json_decode($rawInput, true) ?: $_POST;

$email = strtolower(trim($input['email'] ?? ''));
$password = trim($input['password'] ?? '');

if (empty($email) || empty($password)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Email dan password wajib diisi.'
    ]);
    exit();
}

// 1. Coba verifikasi via Database MySQL (Jika DB aktif)
$matchedAccount = null;
try {
    $pdo = getDbConnection();
    $stmt = $pdo->prepare("SELECT id, name, email, password, role, hardware_type, mqtt_prefix, mqtt_broker, mqtt_port FROM nexora_accounts WHERE LOWER(email) = ? AND status = 'active' LIMIT 1");
    $stmt->execute([$email]);
    $account = $stmt->fetch();

    if ($account && ($password === $account['password'] || password_verify($password, $account['password']))) {
        unset($account['password']);
        $matchedAccount = $account;
    }
} catch (Exception $e) {
    // Database tidak aktif / error koneksi, lanjut ke fallback JSON
}

// 2. Fallback ke settings.json jika DB belum disetup / offline
if (!$matchedAccount) {
    $jsonPath = __DIR__ . '/../settings.json';
    if (file_exists($jsonPath)) {
        $content = file_get_contents($jsonPath);
        $data = json_decode($content, true);
        if (!empty($data['accounts']) && is_array($data['accounts'])) {
            foreach ($data['accounts'] as $acc) {
                if (strtolower($acc['email'] ?? '') === $email && ($acc['password'] ?? '') === $password) {
                    $matchedAccount = [
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
                    break;
                }
            }
        }
    }
}

if ($matchedAccount) {
    $token = 'nexora_token_' . bin2hex(random_bytes(16));
    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil!',
        'token' => $token,
        'account' => $matchedAccount
    ]);
} else {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Email atau kata sandi tidak cocok. Silakan periksa kembali akun Anda.'
    ]);
}
