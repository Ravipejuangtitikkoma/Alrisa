<?php
/**
 * NEXORA IOT - CPANEL CONFIGURATION FILE
 * Sesuaikan informasi DB dengan database yang dibuat di cPanel Alfa
 */

// Aktifkan error reporting jika sedang debugging (nonaktifkan jika produksi)
error_reporting(E_ALL);
ini_set('display_errors', 0);

// Set header JSON default & CORS agar Flutter dan Web bisa mengakses dengan aman
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-KEY');

// Tangani Preflight Request OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// -------------------------------------------------------------
// KONFIGURASI DATABASE MYSQL CPANEL
// Ganti dengan username, password, dan nama DB dari cPanel Anda
// -------------------------------------------------------------
define('DB_HOST', 'localhost');
define('DB_USER', 'root');              // Contoh di cPanel: 'u123456_nexora'
define('DB_PASS', '');                  // Password database cPanel
define('DB_NAME', 'nexora_iot');        // Contoh di cPanel: 'u123456_nexoradb'

// Kunci Keamanan API (Harus sama di Flutter dan Python Gateway)
define('NEXORA_API_KEY', 'nexora_secret_token_2026');

/**
 * Helper untuk koneksi PDO MySQL
 */
function getDbConnection() {
    static $pdo = null;
    if ($pdo === null) {
        try {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
            $options = [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ];
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'message' => 'Gagal koneksi database MySQL: ' . $e->getMessage()
            ]);
            exit();
        }
    }
    return $pdo;
}

/**
 * Validasi API Key keamanan dari Request Header atau Query Param
 */
function requireApiKey() {
    $headers = getallheaders();
    $providedKey = $headers['X-API-KEY'] ?? $headers['x-api-key'] ?? $_GET['api_key'] ?? $_POST['api_key'] ?? '';
    
    if ($providedKey !== NEXORA_API_KEY) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Akses ditolak: API Key tidak valid atau tidak disertakan.'
        ]);
        exit();
    }
}
