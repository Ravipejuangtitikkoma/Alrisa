<?php
/**
 * ============================================================================
 * NEXORA & ALRISA IOT SUITE — ULTRA-PREMIUM WEBDESK & CONFIGURATION STUDIO
 * ============================================================================
 * Portal Konfigurasi Terpusat Multi-Tenant:
 * - Manajemen Multi-Akun (1 Akun = 1 HP / Lokasi Klien / Controller Terpisah)
 * - Tabel Kredensial Login Pemilik (Nama, Username, Password, Akses Dashboard)
 * - Broker MQTT Engine, WiFi Gateway, Mitsubishi FX5U PLC, dan REST API Sync
 * ============================================================================
 */

$settingsFile = __DIR__ . '/settings.json';

$defaultSettings = [
    'mqtt_broker'      => 'broker.emqx.io',
    'mqtt_port'        => 1883,
    'mqtt_ws_port'     => 8083,
    'mqtt_prefix'      => 'alrisa',
    'mqtt_user'        => '',
    'mqtt_pass'        => '',
    'mqtt_client_id'   => 'ALRISA_WebStudio',
    'wifi_ssid'        => 'ALRISA_OFFICE_WIFI',
    'wifi_password'    => '',
    'plc_ip'           => '192.168.1.100',
    'plc_port'         => 502,
    'plc_type'         => 'Mitsubishi FX5U (Modbus TCP Port 502)',
    'api_secret_key'   => 'alrisa_secret_token_2026',
    'app_name'         => 'ALRISA & NEXORA Multi-Tenant Cloud Studio',
    'updated_at'       => date('Y-m-d H:i:s')
];

function loadSettings($filePath, $defaults) {
    if (file_exists($filePath)) {
        $content = file_get_contents($filePath);
        $decoded = json_decode($content, true);
        if (is_array($decoded)) {
            return array_merge($defaults, $decoded);
        }
    }
    return $defaults;
}

function saveSettings($filePath, $data) {
    $data['updated_at'] = date('Y-m-d H:i:s');
    return file_put_contents($filePath, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
}

$current = loadSettings($settingsFile, $defaultSettings);

// API Handler
$isApiRequest = isset($_GET['api']) || (isset($_SERVER['HTTP_ACCEPT']) && strpos($_SERVER['HTTP_ACCEPT'], 'application/json') !== false);

if ($isApiRequest) {
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-KEY');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $raw = file_get_contents('php://input');
        $input = json_decode($raw, true) ?: $_POST;

        foreach ($defaultSettings as $key => $val) {
            if (isset($input[$key])) {
                $current[$key] = is_numeric($val) ? intval($input[$key]) : trim($input[$key]);
            }
        }

        if (isset($input['accounts']) && is_array($input['accounts'])) {
            $current['accounts'] = $input['accounts'];
        }
        if (isset($input['active_account_id'])) {
            $current['active_account_id'] = trim($input['active_account_id']);
        }

        saveSettings($settingsFile, $current);
        echo json_encode([
            'success' => true,
            'message' => 'Konfigurasi multi-akun berhasil diperbarui!',
            'data'    => $current
        ]);
        exit();
    }

    echo json_encode([
        'success' => true,
        'message' => 'Konfigurasi berhasil dimuat',
        'data'    => $current
    ]);
    exit();
}

// Handle Form POST Normal
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    foreach ($defaultSettings as $key => $val) {
        if (isset($_POST[$key])) {
            $current[$key] = is_numeric($val) ? intval($_POST[$key]) : trim($_POST[$key]);
        }
    }
    saveSettings($settingsFile, $current);
}
?>
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NEXORA & ALRISA — WebDesk & Multi-Account Studio</title>
  
  <!-- Modern Google Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@400;500;600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- Paho MQTT WebSocket Client -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/paho-mqtt/1.0.1/mqttws31.min.js"></script>

  <style>
    :root, [data-theme="dark"] {
      --bg-base: #07090E;
      --bg-surface: #0E131F;
      --bg-card: rgba(16, 22, 36, 0.75);
      --bg-card-hover: rgba(22, 30, 50, 0.90);
      --bg-input: #090D15;
      --bg-node: #0B0F1A;
      --bg-terminal: #05070B;
      --bg-dock: rgba(14, 20, 32, 0.92);
      
      --cyan: #00F0FF;
      --cyan-glow: rgba(0, 240, 255, 0.35);
      --cyan-subtle: rgba(0, 240, 255, 0.08);
      
      --emerald: #10B981;
      --emerald-glow: rgba(16, 185, 129, 0.35);
      --emerald-subtle: rgba(16, 185, 129, 0.1);
      
      --amber: #F59E0B;
      --amber-subtle: rgba(245, 158, 11, 0.12);
      
      --rose: #F43F5E;
      --rose-subtle: rgba(244, 63, 94, 0.12);
      
      --purple: #8B5CF6;
      --indigo: #6366F1;
      
      --border-subtle: rgba(255, 255, 255, 0.09);
      --border-active: rgba(0, 240, 255, 0.4);
      --border-focus: #00F0FF;
      
      --text-white: #FFFFFF;
      --text-secondary: #94A3B8;
      --text-dim: #64748B;
      
      --shadow-card: 0 10px 30px rgba(0, 0, 0, 0.4);
      --shadow-dock: 0 16px 50px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 240, 255, 0.15);
      --mesh-bg: 
        radial-gradient(at 10% 10%, rgba(0, 240, 255, 0.08) 0px, transparent 45%),
        radial-gradient(at 90% 15%, rgba(139, 92, 246, 0.07) 0px, transparent 40%),
        radial-gradient(at 50% 90%, rgba(16, 185, 129, 0.06) 0px, transparent 50%);
    }

    [data-theme="light"] {
      --bg-base: #F1F5F9;
      --bg-surface: #FFFFFF;
      --bg-card: rgba(255, 255, 255, 0.90);
      --bg-card-hover: #FFFFFF;
      --bg-input: #F8FAFC;
      --bg-node: #F8FAFC;
      --bg-terminal: #0F172A;
      --bg-dock: rgba(255, 255, 255, 0.96);
      
      --cyan: #0284C7;
      --cyan-glow: rgba(2, 132, 199, 0.25);
      --cyan-subtle: rgba(2, 132, 199, 0.1);
      
      --emerald: #059669;
      --emerald-glow: rgba(5, 150, 105, 0.25);
      --emerald-subtle: rgba(5, 150, 105, 0.12);
      
      --amber: #D97706;
      --amber-subtle: rgba(217, 119, 6, 0.12);
      
      --rose: #E11D48;
      --rose-subtle: rgba(225, 29, 72, 0.12);
      
      --purple: #7C3AED;
      --indigo: #4F46E5;
      
      --border-subtle: rgba(203, 213, 225, 0.85);
      --border-active: rgba(2, 132, 199, 0.45);
      --border-focus: #0284C7;
      
      --text-white: #0F172A;
      --text-secondary: #475569;
      --text-dim: #64748B;
      
      --shadow-card: 0 4px 20px -2px rgba(15, 23, 42, 0.05), 0 10px 30px -4px rgba(15, 23, 42, 0.03);
      --shadow-dock: 0 16px 40px rgba(15, 23, 42, 0.12), 0 0 20px rgba(2, 132, 199, 0.12);
      --mesh-bg: 
        radial-gradient(at 10% 10%, rgba(2, 132, 199, 0.08) 0px, transparent 50%),
        radial-gradient(at 90% 15%, rgba(124, 58, 237, 0.06) 0px, transparent 45%),
        radial-gradient(at 50% 90%, rgba(5, 150, 105, 0.05) 0px, transparent 50%);
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      background-color: var(--bg-base);
      background-image: var(--mesh-bg);
      background-attachment: fixed;
      color: var(--text-white);
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      min-height: 100vh;
      padding: 24px 20px 120px;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }

    .container {
      max-width: 1280px;
      margin: 0 auto;
    }

    /* TOP HEADER */
    .top-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 16px;
      padding-bottom: 20px;
      border-bottom: 1px solid var(--border-subtle);
    }

    .brand-group {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .brand-logo-badge {
      width: 46px;
      height: 46px;
      border-radius: 14px;
      background: linear-gradient(135deg, var(--cyan), #3B82F6);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      box-shadow: 0 0 20px var(--cyan-glow);
    }

    .brand-title-wrap h1 {
      font-family: 'Outfit', sans-serif;
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -0.6px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .brand-title-wrap p {
      font-size: 13px;
      color: var(--text-secondary);
      margin-top: 3px;
    }

    .gradient-text {
      background: linear-gradient(135deg, var(--text-white), #94A3B8);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .cyan-text {
      color: var(--cyan);
    }

    .version-tag {
      font-size: 11px;
      background: var(--cyan-subtle);
      color: var(--cyan);
      border: 1px solid var(--border-active);
      padding: 2px 8px;
      border-radius: 6px;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 700;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .btn-top {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 9px 16px;
      border-radius: 12px;
      border: 1px solid var(--border-subtle);
      background: var(--bg-card);
      color: var(--text-white);
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      cursor: pointer;
      transition: all 0.25s ease;
      font-family: inherit;
    }

    .btn-top:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
      box-shadow: 0 4px 16px var(--cyan-subtle);
    }

    .btn-top.active-dash {
      background: linear-gradient(135deg, var(--cyan), #0284C7);
      color: #000;
      border: none;
      box-shadow: 0 0 20px var(--cyan-glow);
    }
    .btn-top.active-dash:hover {
      filter: brightness(1.1);
      color: #000;
    }

    .live-telemetry-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 14px;
      border-radius: 999px;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      font-size: 12px;
      font-family: 'JetBrains Mono', monospace;
    }

    .pulse-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--emerald);
      box-shadow: 0 0 10px var(--emerald);
      animation: pulseAnim 2s infinite;
    }

    @keyframes pulseAnim {
      0% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.85); }
      100% { opacity: 1; transform: scale(1); }
    }

    /* TOPOLOGY STRIP */
    .topology-card {
      background: var(--bg-card);
      backdrop-filter: blur(16px);
      border: 1px solid var(--border-subtle);
      border-radius: 20px;
      padding: 16px 24px;
      margin-bottom: 24px;
      box-shadow: var(--shadow-card);
    }

    .topology-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
      font-size: 12.5px;
      color: var(--text-secondary);
      font-weight: 700;
    }

    .topology-flow {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .node-box {
      flex: 1;
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      transition: all 0.25s;
    }

    .node-box:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
    }

    .node-icon {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      flex-shrink: 0;
      background: var(--cyan-subtle);
      border: 1px solid rgba(0, 240, 255, 0.2);
    }

    .node-info .title {
      font-size: 13.5px;
      font-weight: 800;
      color: var(--text-white);
    }

    .node-info .sub {
      font-size: 11px;
      color: var(--text-dim);
      font-family: 'JetBrains Mono', monospace;
    }

    .pipe-connector {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      color: var(--cyan);
      font-size: 11px;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 700;
      min-width: 90px;
      text-align: center;
    }

    .pipe-line {
      width: 100%;
      height: 2px;
      background: linear-gradient(90deg, #3B82F6, var(--cyan));
      position: relative;
      overflow: hidden;
      border-radius: 999px;
    }

    .pipe-line::after {
      content: '';
      position: absolute;
      top: 0;
      left: -40%;
      width: 40%;
      height: 100%;
      background: #FFFFFF;
      box-shadow: 0 0 8px #FFFFFF;
      animation: pipePulse 2s infinite linear;
    }

    @keyframes pipePulse {
      0% { left: -40%; }
      100% { left: 140%; }
    }

    /* NAVIGATION TABS */
    .tab-bar-nav {
      display: flex;
      gap: 10px;
      margin-bottom: 24px;
      overflow-x: auto;
      padding-bottom: 6px;
    }

    .tab-pill-btn {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--text-secondary);
      padding: 12px 20px;
      border-radius: 14px;
      font-size: 13.5px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 10px;
      transition: all 0.25s;
      white-space: nowrap;
      font-family: inherit;
    }

    .tab-pill-btn:hover {
      background: var(--bg-card-hover);
      color: var(--text-white);
      border-color: var(--border-active);
    }

    .tab-pill-btn.active {
      background: var(--cyan-subtle);
      border-color: var(--cyan);
      color: var(--cyan);
      box-shadow: 0 4px 20px var(--cyan-subtle);
    }

    /* BENTO & CARD STYLES */
    .bento-card {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border-subtle);
      border-radius: 24px;
      padding: 26px;
      box-shadow: var(--shadow-card);
      margin-bottom: 24px;
    }

    .card-title-group {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      margin-bottom: 22px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--border-subtle);
    }

    .card-title-left {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .card-icon-badge {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: rgba(0, 240, 255, 0.12);
      border: 1px solid rgba(0, 240, 255, 0.25);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
    }

    .card-title-left h2 {
      font-family: 'Outfit', sans-serif;
      font-size: 19px;
      font-weight: 800;
      color: var(--text-white);
    }

    .card-title-left p {
      font-size: 13px;
      color: var(--text-secondary);
      margin-top: 3px;
    }

    /* ULTRA-PREMIUM USER ACCOUNTS TABLE */
    .accounts-table-wrapper {
      width: 100%;
      overflow-x: auto;
      border-radius: 18px;
      border: 1px solid var(--border-subtle);
      background: var(--bg-surface);
      margin-bottom: 24px;
    }

    .accounts-table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13.5px;
    }

    .accounts-table th {
      background: rgba(255, 255, 255, 0.03);
      padding: 16px 18px;
      color: var(--text-secondary);
      font-size: 11.5px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      border-bottom: 1.5px solid var(--border-subtle);
    }

    .accounts-table td {
      padding: 16px 18px;
      border-bottom: 1px solid var(--border-subtle);
      vertical-align: middle;
    }

    .accounts-table tr:last-child td {
      border-bottom: none;
    }

    .accounts-table tr:hover {
      background: rgba(255, 255, 255, 0.02);
    }

    .accounts-table tr.active-row {
      background: rgba(0, 240, 255, 0.04);
      border-left: 3px solid var(--cyan);
    }

    .user-avatar-cell {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .user-avatar-badge {
      width: 40px;
      height: 40px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 14px;
      color: #FFFFFF;
      flex-shrink: 0;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
    }

    .user-name-title {
      font-weight: 800;
      font-size: 14.5px;
      color: var(--text-white);
    }

    .user-id-subtitle {
      font-size: 11px;
      color: var(--text-dim);
      font-family: 'JetBrains Mono', monospace;
      margin-top: 2px;
    }

    .role-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: 10.5px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .role-badge.superadmin {
      background: rgba(0, 240, 255, 0.15);
      color: var(--cyan);
      border: 1px solid rgba(0, 240, 255, 0.3);
    }
    .role-badge.user {
      background: rgba(139, 92, 246, 0.15);
      color: var(--purple);
      border: 1px solid rgba(139, 92, 246, 0.3);
    }

    .credential-cell {
      display: flex;
      align-items: center;
      gap: 8px;
      background: var(--bg-input);
      border: 1px solid var(--border-subtle);
      padding: 6px 12px;
      border-radius: 8px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 12.5px;
      max-width: 240px;
    }

    .credential-cell input {
      background: transparent;
      border: none;
      color: var(--text-white);
      font-family: inherit;
      font-size: inherit;
      width: 100%;
      outline: none;
    }

    .credential-btn {
      background: transparent;
      border: none;
      color: var(--text-dim);
      cursor: pointer;
      font-size: 14px;
      padding: 2px;
      transition: color 0.2s;
    }
    .credential-btn:hover {
      color: var(--cyan);
    }

    .hw-badge-tag {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 700;
      padding: 6px 12px;
      border-radius: 8px;
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      color: var(--text-white);
    }

    .action-btn-group {
      display: flex;
      align-items: center;
      gap: 8px;
      justify-content: flex-end;
      flex-wrap: wrap;
    }

    .btn-act-dashboard {
      background: linear-gradient(135deg, var(--cyan), #0284C7);
      color: #000;
      border: none;
      padding: 8px 14px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 800;
      cursor: pointer;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      box-shadow: 0 0 14px var(--cyan-glow);
      transition: all 0.2s;
    }
    .btn-act-dashboard:hover {
      transform: translateY(-2px);
      filter: brightness(1.1);
      color: #000;
    }

    .btn-act-edit {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid var(--border-subtle);
      color: var(--text-white);
      padding: 7px 12px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.2s;
    }
    .btn-act-edit:hover {
      border-color: var(--cyan);
      color: var(--cyan);
    }

    .btn-act-del {
      background: rgba(244, 63, 94, 0.1);
      border: 1px solid rgba(244, 63, 94, 0.25);
      color: var(--rose);
      padding: 7px 10px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-act-del:hover {
      background: var(--rose);
      color: #FFF;
    }

    /* FORM INPUTS */
    .form-row-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 18px;
      margin-bottom: 20px;
    }

    .form-group-box {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .form-group-box label {
      font-size: 12.5px;
      font-weight: 700;
      color: var(--text-secondary);
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .field-badge {
      font-size: 10px;
      font-weight: 800;
      background: var(--cyan-subtle);
      color: var(--cyan);
      padding: 2px 6px;
      border-radius: 4px;
    }

    .app-input {
      background: var(--bg-input);
      border: 1.5px solid var(--border-subtle);
      border-radius: 12px;
      padding: 12px 16px;
      color: var(--text-white);
      font-size: 13.5px;
      font-family: inherit;
      outline: none;
      transition: all 0.2s;
      width: 100%;
    }

    .app-input:focus {
      border-color: var(--cyan);
      box-shadow: 0 0 14px var(--cyan-subtle);
    }

    .app-input.mono {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
    }

    /* PRESETS */
    .presets-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 14px;
      margin-bottom: 24px;
    }

    .preset-card-item {
      background: var(--bg-node);
      border: 1.5px solid var(--border-subtle);
      border-radius: 14px;
      padding: 16px;
      cursor: pointer;
      transition: all 0.25s;
    }

    .preset-card-item:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
    }

    .preset-card-item.selected {
      border-color: var(--cyan);
      background: rgba(0, 240, 255, 0.08);
      box-shadow: 0 0 18px var(--cyan-glow);
    }

    .preset-name {
      font-weight: 800;
      font-size: 14px;
      color: var(--text-white);
    }

    .preset-tag {
      font-size: 10px;
      font-weight: 800;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.08);
    }
    .preset-tag.global { color: var(--emerald); }
    .preset-tag.private { color: var(--purple); }
    .preset-tag.local { color: var(--amber); }

    .preset-host {
      font-size: 12px;
      color: var(--cyan);
      font-family: 'JetBrains Mono', monospace;
      margin-top: 6px;
    }

    /* TERMINAL & DIAGNOSTIC */
    .terminal-container {
      background: var(--bg-terminal);
      border: 1px solid var(--border-subtle);
      border-radius: 16px;
      overflow: hidden;
      font-family: 'JetBrains Mono', monospace;
      margin-top: 16px;
    }

    .terminal-header {
      background: #0D1117;
      padding: 10px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid #1E293B;
    }

    .terminal-dots {
      display: flex;
      gap: 6px;
    }
    .terminal-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
    }
    .terminal-dot.red { background: #F43F5E; }
    .terminal-dot.yellow { background: #F59E0B; }
    .terminal-dot.green { background: #10B981; }

    .terminal-body {
      padding: 16px;
      font-size: 12px;
      min-height: 120px;
      max-height: 200px;
      overflow-y: auto;
      line-height: 1.6;
    }

    .term-line {
      display: flex;
      gap: 8px;
      margin-bottom: 4px;
    }
    .term-time { color: #64748B; }
    .term-prefix { color: #00F0FF; font-weight: 700; }
    .term-msg { color: #E2E8F0; }
    .term-msg.success { color: #34D399; font-weight: 600; }
    .term-msg.error { color: #F87171; font-weight: 600; }
    .term-msg.warn { color: #FBBF24; }

    .terminal-footer {
      background: #080B12;
      padding: 10px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid #1E293B;
    }

    .tester-btn {
      background: var(--cyan-subtle);
      border: 1px solid var(--cyan);
      color: var(--cyan);
      padding: 8px 18px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s;
    }
    .tester-btn:hover {
      background: var(--cyan);
      color: #000;
      box-shadow: 0 0 16px var(--cyan-glow);
    }

    /* REST API SYNC BOX */
    .sync-box {
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      padding: 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-wrap: wrap;
    }

    .sync-url-code {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: var(--cyan);
      background: var(--cyan-subtle);
      padding: 10px 14px;
      border-radius: 10px;
      border: 1px dashed var(--cyan);
      word-break: break-all;
      flex: 1;
    }

    /* FLOATING ACTION DOCK */
    .floating-save-dock {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      width: calc(100% - 40px);
      max-width: 1240px;
      background: var(--bg-dock);
      backdrop-filter: blur(24px);
      border: 1px solid var(--border-active);
      border-radius: 20px;
      padding: 14px 26px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: var(--shadow-dock);
      z-index: 1000;
    }

    .dock-status-info {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .dock-text .title {
      font-size: 13.5px;
      font-weight: 800;
      color: var(--text-white);
    }

    .dock-text .sub {
      font-size: 12px;
      color: var(--text-secondary);
    }

    .dock-btn-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .btn-dock-reset {
      background: transparent;
      border: 1px solid var(--border-subtle);
      color: var(--text-secondary);
      padding: 10px 18px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-dock-reset:hover {
      border-color: var(--text-white);
      color: var(--text-white);
    }

    .btn-dock-save {
      background: linear-gradient(135deg, var(--emerald), #059669);
      border: none;
      color: #FFFFFF;
      padding: 10px 24px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 0 20px var(--emerald-glow);
      transition: all 0.2s;
    }
    .btn-dock-save:hover {
      transform: translateY(-2px);
      filter: brightness(1.1);
    }

    /* TOAST */
    .toast-popup {
      position: fixed;
      top: 24px;
      right: 24px;
      background: var(--bg-dock);
      backdrop-filter: blur(20px);
      border: 1px solid var(--emerald);
      color: var(--text-white);
      padding: 14px 20px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4), 0 0 20px var(--emerald-glow);
      transform: translateY(-100px);
      opacity: 0;
      transition: all 0.35s cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 9999;
    }
    .toast-popup.show {
      transform: translateY(0);
      opacity: 1;
    }

    /* MODAL */
    .modal-backdrop-custom {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(4, 7, 13, 0.82);
      backdrop-filter: blur(10px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      padding: 16px;
    }
    .modal-backdrop-custom.active {
      display: flex !important;
    }

    .modal-box-custom {
      background: var(--bg-surface);
      border: 1.5px solid var(--border-subtle);
      border-radius: 22px;
      width: 100%;
      max-width: 620px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 25px 70px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 240, 255, 0.1);
      overflow: hidden;
      animation: modalSlideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes modalSlideIn {
      from { transform: translateY(20px) scale(0.96); opacity: 0; }
      to { transform: translateY(0) scale(1); opacity: 1; }
    }

    .modal-header-custom {
      padding: 18px 24px;
      border-bottom: 1px solid var(--border-subtle);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
    }
    .modal-body-custom {
      padding: 22px 24px;
      overflow-y: auto;
      flex: 1;
    }
    .modal-footer-custom {
      padding: 14px 24px;
      border-top: 1px solid var(--border-subtle);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
      gap: 12px;
    }

    /* PIN GRID MATRIX */
    .pin-grid-container {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
      gap: 10px;
      margin-top: 14px;
    }

    .pin-card-box {
      background: var(--bg-node);
      border: 1.5px solid var(--border-subtle);
      border-radius: 12px;
      padding: 12px 14px;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .pin-card-box:hover:not(.disabled) {
      border-color: var(--cyan);
      transform: translateY(-2px);
    }
    .pin-card-box.selected {
      border-color: var(--cyan);
      background: rgba(0, 240, 255, 0.08);
      box-shadow: 0 0 16px var(--cyan-glow);
    }
    .pin-card-box.disabled {
      opacity: 0.5;
      cursor: not-allowed;
      border-color: rgba(244, 63, 94, 0.3);
    }

    .pin-badge-status {
      font-size: 10.5px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 999px;
    }
    .pin-badge-status.free {
      background: rgba(16, 185, 129, 0.15);
      color: var(--emerald);
    }
    .pin-badge-status.used {
      background: rgba(244, 63, 94, 0.15);
      color: var(--rose);
    }

    @media (max-width: 900px) {
      .topology-flow { flex-direction: column; }
      .pipe-connector { transform: rotate(90deg); margin: 8px 0; }
      .floating-save-dock { flex-direction: column; gap: 12px; text-align: center; }
      .dock-status-info { flex-direction: column; }
    }
  </style>
</head>
<body>

  <!-- TOAST NOTIFICATION -->
  <div class="toast-popup" id="toastAlert">
    <div style="font-size: 22px;" id="toastIcon">✅</div>
    <div>
      <div style="font-weight: 800; font-size: 13.5px;" id="toastTitle">Tersimpan</div>
      <div style="font-size: 12px; color: var(--text-secondary);" id="toastMessage">Konfigurasi berhasil diperbarui.</div>
    </div>
  </div>

  <div class="container">

    <!-- 1. HEADER & ACTIONS -->
    <header class="top-header">
      <div class="brand-group">
        <div class="brand-logo-badge">⚡</div>
        <div class="brand-title-wrap">
          <h1>
            <span class="gradient-text">NEXORA & ALRISA</span>
            <span class="cyan-text">Studio</span>
            <span class="version-tag">v3.0</span>
          </h1>
          <p>Central Multi-Tenant IoT Broker, Multi-Account Hub & Visual PLC Gateway</p>
        </div>
      </div>

      <div class="header-actions">
        <button type="button" class="btn-top" onclick="toggleTheme()" id="themeToggleBtn" title="Ganti Mode Gelap / Terang">
          <span id="themeIcon">☀️</span> <span id="themeText">Mode Terang</span>
        </button>

        <div class="live-telemetry-pill">
          <div class="pulse-dot"></div>
          <span style="color: var(--emerald); font-weight: 800;">BROKER AKTIF</span>
          <span style="color: var(--text-dim);">•</span>
          <span style="color: var(--cyan);" id="headerPingText">LATENSI: 18ms</span>
        </div>

        <a href="index.php" class="btn-top active-dash" target="_blank" title="Buka Halaman Web Dashboard Nexora Home OS">
          <span>🏠</span> Buka Web Dashboard
        </a>
        <a href="settings.php?api=1" target="_blank" class="btn-top" title="Lihat Endpoint Konfigurasi JSON REST">
          <span>⚡</span> JSON API
        </a>
      </div>
    </header>

    <!-- 2. TOPOLOGY MAP STRIP -->
    <section class="topology-card">
      <div class="topology-header">
        <span>🔗 Topologi Integrasi Real-Time Multi-Tenant Nexora IoT</span>
        <span style="color: var(--cyan); font-family: 'JetBrains Mono', monospace;" id="topoBrokerDisplay">
          Broker: <?php echo htmlspecialchars($current['mqtt_broker']); ?>:<?php echo htmlspecialchars($current['mqtt_port']); ?>
        </span>
      </div>

      <div class="topology-flow">
        <div class="node-box">
          <div class="node-icon">📱</div>
          <div class="node-info">
            <div class="title">Aplikasi HP Android Nexora</div>
            <div class="sub">Flutter Client Multi-Akun</div>
          </div>
        </div>

        <div class="pipe-connector">
          <div class="pipe-line"></div>
          <span>MQTT / TCP</span>
        </div>

        <div class="node-box" style="border-color: var(--cyan);">
          <div class="node-icon">🌐</div>
          <div class="node-info">
            <div class="title">MQTT Message Broker</div>
            <div class="sub" id="topoBrokerSub"><?php echo htmlspecialchars($current['mqtt_broker']); ?></div>
          </div>
        </div>

        <div class="pipe-connector">
          <div class="pipe-line"></div>
          <span>MODBUS TCP</span>
        </div>

        <div class="node-box">
          <div class="node-icon">🏭</div>
          <div class="node-info">
            <div class="title">Hardware Controller / PLC</div>
            <div class="sub" id="topoPlcSub"><?php echo htmlspecialchars($current['plc_ip']); ?>:502</div>
          </div>
        </div>
      </div>
    </section>

    <!-- 3. MAIN NAVIGATION TABS -->
    <nav class="tab-bar-nav">
      <button type="button" class="tab-pill-btn active" onclick="switchSection('section-accounts', this)">
        <span>👥</span> 1. Master Akun Klien & Dashboard
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-broker', this)">
        <span>📡</span> 2. Broker MQTT Engine
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-hardware', this)">
        <span>📶</span> 3. WiFi & IoT Hardware
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-plc', this)">
        <span>🏭</span> 4. Mitsubishi PLC Modbus
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-security', this)">
        <span>🔐</span> 5. Keamanan & API Sync
      </button>
    </nav>

    <!-- FORM START -->
    <form id="mainConfigForm" onsubmit="handleFormSubmit(event)">

      <!-- ===================================================================== -->
      <!-- TAB 1: MASTER AKUN KLIEN & TABEL PENGGUNA (FITUR UTAMA USER)          -->
      <!-- ===================================================================== -->
      <div id="section-accounts" class="tab-content">
        <div class="bento-card">
          <div class="card-title-group">
            <div class="card-title-left">
              <div class="card-icon-badge" style="background: rgba(139, 92, 246, 0.15); border-color: rgba(139, 92, 246, 0.3);">👥</div>
              <div>
                <h2>Tabel Manajemen Akun & Klien Hardware</h2>
                <p>Kelola data pemilik akun, kredensial login aplikasi HP, spesifikasi mesin controller, serta akses langsung ke Web Dashboard profil tiap akun.</p>
              </div>
            </div>
            <button type="button" class="btn-top" onclick="showAddNewAccountModal()" style="background: var(--cyan); color: #000; border: none; font-weight: 800; box-shadow: 0 0 16px var(--cyan-glow);">
              <span>➕</span> Tambah Akun Klien Baru
            </button>
          </div>

          <!-- TABEL AKUN MASTER DENGAN KREDENSIAL LENGKAP -->
          <div class="accounts-table-wrapper">
            <table class="accounts-table">
              <thead>
                <tr>
                  <th style="width: 250px;">Nama Pemilik / Klien</th>
                  <th style="width: 220px;">Username / Email Login</th>
                  <th style="width: 200px;">Kata Sandi (Password)</th>
                  <th style="width: 220px;">Mesin Hardware Gateway</th>
                  <th style="width: 140px;">Perangkat Terpasang</th>
                  <th style="text-align: right; width: 250px;">Aksi Cepat</th>
                </tr>
              </thead>
              <tbody id="accountsTableBody">
                <!-- Dirender secara dinamis oleh JavaScript -->
              </tbody>
            </table>
          </div>

          <!-- ACTIVE ACCOUNT DETAIL & PIN MANAGEMENT PANEL -->
          <div id="accountDetailCard">
            <!-- Dirender secara dinamis oleh JavaScript -->
          </div>
        </div>
      </div>

      <!-- ===================================================================== -->
      <!-- TAB 2: BROKER MQTT ENGINE                                             -->
      <!-- ===================================================================== -->
      <div id="section-broker" class="tab-content" style="display: none;">
        <div class="bento-card">
          <div class="card-title-group">
            <div class="card-title-left">
              <div class="card-icon-badge">📡</div>
              <div>
                <h2>Konfigurasi Broker MQTT (Jantung Komunikasi)</h2>
                <p>Server perantara yang mendistribusikan data saklar, sensor, gerbang, dan telemetry secara seketika.</p>
              </div>
            </div>
          </div>

          <div style="font-size: 12px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 12px;">
            Pilih Preset Server Broker Cepat:
          </div>
          <div class="presets-grid">
            <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'broker.emqx.io' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('broker.emqx.io', 1883, 8083, 'alrisa', this)">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span class="preset-name">EMQX Global</span>
                <span class="preset-tag global">Cloud Public</span>
              </div>
              <div class="preset-host">broker.emqx.io:1883</div>
            </div>

            <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'broker.hivemq.com' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('broker.hivemq.com', 1883, 8000, 'alrisa', this)">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span class="preset-name">HiveMQ Cloud</span>
                <span class="preset-tag global">Cloud Public</span>
              </div>
              <div class="preset-host">broker.hivemq.com:1883</div>
            </div>

            <div class="preset-card-item <?php echo $current['mqtt_broker'] === '192.168.1.100' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('192.168.1.100', 1883, 8083, 'alrisa', this)">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span class="preset-name">Mini PC Kantor</span>
                <span class="preset-tag private">Private LAN</span>
              </div>
              <div class="preset-host">192.168.1.100:1883</div>
            </div>

            <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'localhost' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('localhost', 1883, 8083, 'alrisa', this)">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span class="preset-name">Localhost PC</span>
                <span class="preset-tag local">Pengembang</span>
              </div>
              <div class="preset-host">127.0.0.1:1883</div>
            </div>
          </div>

          <div class="form-row-grid">
            <div class="form-group-box">
              <label for="mqtt_broker">Alamat Host / Domain Broker <span class="field-badge">Wajib</span></label>
              <input type="text" id="mqtt_broker" name="mqtt_broker" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_broker']); ?>" required>
            </div>
            <div class="form-group-box">
              <label for="mqtt_port">Port TCP (ESP32 / HP / Python) <span class="field-badge">Wajib</span></label>
              <input type="number" id="mqtt_port" name="mqtt_port" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_port']); ?>" required>
            </div>
            <div class="form-group-box">
              <label for="mqtt_ws_port">Port WebSocket Browser (WSS)</label>
              <input type="number" id="mqtt_ws_port" name="mqtt_ws_port" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_ws_port']); ?>">
            </div>
          </div>

          <div class="form-row-grid">
            <div class="form-group-box">
              <label for="mqtt_prefix">Topic Root Prefix Global</label>
              <input type="text" id="mqtt_prefix" name="mqtt_prefix" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_prefix']); ?>">
            </div>
            <div class="form-group-box">
              <label for="mqtt_user">Username Broker (Opsional)</label>
              <input type="text" id="mqtt_user" name="mqtt_user" class="app-input" value="<?php echo htmlspecialchars($current['mqtt_user']); ?>">
            </div>
            <div class="form-group-box">
              <label for="mqtt_pass">Password Broker (Opsional)</label>
              <input type="password" id="mqtt_pass" name="mqtt_pass" class="app-input" value="<?php echo htmlspecialchars($current['mqtt_pass']); ?>">
            </div>
          </div>

          <!-- DIAGNOSTIC CONSOLE -->
          <div class="terminal-container">
            <div class="terminal-header">
              <div class="terminal-dots">
                <div class="terminal-dot red"></div>
                <div class="terminal-dot yellow"></div>
                <div class="terminal-dot green"></div>
              </div>
              <div style="font-size: 11px; color: var(--text-dim); font-weight: 700;">DIAGNOSTIC BROKER WEBSOCKET TERMINAL</div>
              <div style="font-size: 11px; font-weight: 800; color: var(--emerald);" id="termStatusBadge">● READY</div>
            </div>
            <div class="terminal-body" id="termOutput">
              <div class="term-line">
                <span class="term-time">[<?php echo date('H:i:s'); ?>]</span>
                <span class="term-prefix">SYSTEM:</span>
                <span class="term-msg">Konsol diagnostik siap menguji transmisi paket MQTT WebSocket.</span>
              </div>
            </div>
            <div class="terminal-footer">
              <span style="font-size: 11.5px; color: var(--text-secondary);">Gunakan tes ini untuk memastikan port WebSocket broker terbuka.</span>
              <button type="button" class="tester-btn" onclick="runLiveDiagnosticTest()">
                <span>⚡</span> Uji Ping & Koneksi WebSocket
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- ===================================================================== -->
      <!-- TAB 3: WIFI & IOT HARDWARE                                            -->
      <!-- ===================================================================== -->
      <div id="section-hardware" class="tab-content" style="display: none;">
        <div class="bento-card">
          <div class="card-title-group">
            <div class="card-title-left">
              <div class="card-icon-badge">📶</div>
              <div>
                <h2>Konektivitas WiFi & Hardware Gateway</h2>
                <p>Parameter SSID dan kata sandi jaringan lokal yang digunakan oleh controller ESP32 atau Raspberry Pi.</p>
              </div>
            </div>
          </div>

          <div class="form-row-grid">
            <div class="form-group-box">
              <label for="wifi_ssid">Nama WiFi SSID (2.4GHz) <span class="field-badge">Wajib</span></label>
              <input type="text" id="wifi_ssid" name="wifi_ssid" class="app-input" value="<?php echo htmlspecialchars($current['wifi_ssid']); ?>" placeholder="Nama WiFi Rumah/Kantor">
            </div>
            <div class="form-group-box">
              <label for="wifi_password">Kata Sandi WiFi</label>
              <input type="text" id="wifi_password" name="wifi_password" class="app-input mono" value="<?php echo htmlspecialchars($current['wifi_password']); ?>" placeholder="Kosongkan jika tanpa password">
            </div>
          </div>
        </div>
      </div>

      <!-- ===================================================================== -->
      <!-- TAB 4: MITSUBISHI PLC MODBUS                                          -->
      <!-- ===================================================================== -->
      <div id="section-plc" class="tab-content" style="display: none;">
        <div class="bento-card">
          <div class="card-title-group">
            <div class="card-title-left">
              <div class="card-icon-badge">🏭</div>
              <div>
                <h2>Integrasi Mitsubishi FX5U PLC & Modbus Gateway</h2>
                <p>Alamat IP PLC industri dan port Modbus TCP (Port 502) untuk komunikasi gerbang industri dan relai contactor.</p>
              </div>
            </div>
          </div>

          <div class="form-row-grid">
            <div class="form-group-box">
              <label for="plc_type">Jenis Controller Otomasi</label>
              <input type="text" id="plc_type" name="plc_type" class="app-input" value="<?php echo htmlspecialchars($current['plc_type']); ?>">
            </div>
            <div class="form-group-box">
              <label for="plc_ip">Alamat IP PLC (Ethernet) <span class="field-badge">Wajib</span></label>
              <input type="text" id="plc_ip" name="plc_ip" class="app-input mono" value="<?php echo htmlspecialchars($current['plc_ip']); ?>">
            </div>
            <div class="form-group-box">
              <label for="plc_port">Port Modbus TCP</label>
              <input type="number" id="plc_port" name="plc_port" class="app-input mono" value="<?php echo htmlspecialchars($current['plc_port']); ?>">
            </div>
          </div>
        </div>
      </div>

      <!-- ===================================================================== -->
      <!-- TAB 5: KEAMANAN & API SYNC                                            -->
      <!-- ===================================================================== -->
      <div id="section-security" class="tab-content" style="display: none;">
        <div class="bento-card">
          <div class="card-title-group">
            <div class="card-title-left">
              <div class="card-icon-badge">🔐</div>
              <div>
                <h2>Token Keamanan & REST API Sync Otomatis</h2>
                <p>Kunci autentikasi agar aplikasi Flutter Nexora dapat mengunduh konfigurasi ini secara otomatis.</p>
              </div>
            </div>
          </div>

          <div class="form-row-grid">
            <div class="form-group-box">
              <label for="api_secret_key">Kunci Rahasia API (X-API-KEY) <span class="field-badge">Penting</span></label>
              <input type="text" id="api_secret_key" name="api_secret_key" class="app-input mono" value="<?php echo htmlspecialchars($current['api_secret_key']); ?>" required>
            </div>
            <div class="form-group-box">
              <label for="app_name">Label Ekosistem Rumah / Kantor</label>
              <input type="text" id="app_name" name="app_name" class="app-input" value="<?php echo htmlspecialchars($current['app_name']); ?>">
            </div>
          </div>

          <div style="font-size: 12px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 8px;">
            URL Sinkronisasi Konfigurasi Otomatis (REST API):
          </div>
          <div class="sync-box">
            <div class="sync-url-code" id="syncUrlPreview">Memuat URL Endpoint...</div>
            <button type="button" class="btn-top" onclick="copySyncUrl()" style="background: var(--cyan); color: #000; border: none; font-weight: 800;">
              <span>📋</span> Salin URL API
            </button>
          </div>
        </div>
      </div>

      <!-- FLOATING ACTION DOCK -->
      <div class="floating-save-dock">
        <div class="dock-status-info">
          <div style="font-size: 26px;">🛡️</div>
          <div class="dock-text">
            <div class="title">Semua Parameter Konfigurasi Siap Diterapkan</div>
            <div class="sub">Perubahan akan langsung aktif untuk HP Android, Simulator PLC, dan Web Dashboard.</div>
          </div>
        </div>

        <div class="dock-btn-group">
          <button type="button" class="btn-dock-reset" onclick="resetDefaults()">
            <span>🔄</span> Bawaan Pabrik
          </button>
          <button type="submit" class="btn-dock-save" id="btnSubmitForm">
            <span>💾</span> Simpan Konfigurasi
          </button>
        </div>
      </div>

    </form>
  </div>

  <!-- ========================================================================= -->
  <!-- ✏️ MODAL: EDIT AKUN KLIEN & KREDENSIAL                                    -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="editAccountModal">
    <div class="modal-box-custom">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(0, 240, 255, 0.12); border: 1px solid rgba(0, 240, 255, 0.25); display: flex; align-items: center; justify-content: center; font-size: 20px;">
            ✏️
          </div>
          <div>
            <h3 style="font-size: 16px; font-weight: 800; color: var(--text-white);">Edit Data & Kredensial Akun</h3>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Ubah nama pemilik, email login, password, dan controller</p>
          </div>
        </div>
        <button type="button" onclick="closeEditAccountModal()" style="background: none; border: none; font-size: 22px; color: var(--text-dim); cursor: pointer;">✕</button>
      </div>

      <div class="modal-body-custom">
        <input type="hidden" id="editAccId">
        
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="editAccName">Nama Pemilik / Klien <span class="field-badge">Wajib</span></label>
          <input type="text" id="editAccName" class="app-input" placeholder="Contoh: Ravi Armanza (Super Admin)">
        </div>

        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="editAccEmail">Username / Email Login HP <span class="field-badge">Wajib</span></label>
          <input type="email" id="editAccEmail" class="app-input mono" placeholder="nama@nexora.id">
        </div>

        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="editAccPassword">Password Login HP <span class="field-badge">Wajib</span></label>
          <input type="text" id="editAccPassword" class="app-input mono" placeholder="Kata sandi akun">
        </div>

        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="editAccHw">Mesin Controller Hardware</label>
          <select id="editAccHw" class="app-input">
            <option value="Raspberry Pi 4 (Master Controller)">🍓 Raspberry Pi 4 (Master Controller)</option>
            <option value="Raspberry Pi 4 Gateway">🍓 Raspberry Pi 4 Gateway</option>
            <option value="Mitsubishi FX5U PLC (Industrial Hub)">🏭 Mitsubishi FX5U PLC (Industrial Hub)</option>
            <option value="ESP32 Smart Automation Hub">⚡ ESP32 Smart Automation Hub</option>
          </select>
        </div>

        <div class="form-group-box">
          <label for="editAccPrefix">Topic MQTT Prefix Khusus Akun Ini</label>
          <input type="text" id="editAccPrefix" class="app-input mono" placeholder="alrisa/admin">
        </div>
      </div>

      <div class="modal-footer-custom">
        <button type="button" class="btn-top" onclick="closeEditAccountModal()">Batal</button>
        <button type="button" class="btn-dock-save" onclick="saveEditAccountModal()" style="padding: 10px 22px; font-size: 13px;">
          <span>✅ Simpan Perubahan Akun</span>
        </button>
      </div>
    </div>
  </div>

  <!-- ========================================================================= -->
  <!-- 👥 MODAL: TAMBAH AKUN KLIEN BARU                                         -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="accountModal">
    <div class="modal-box-custom">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(139, 92, 246, 0.15); border: 1px solid rgba(139, 92, 246, 0.3); display: flex; align-items: center; justify-content: center; font-size: 20px;">
            👤
          </div>
          <div>
            <h3 style="font-size: 16px; font-weight: 800; color: var(--text-white);">Daftarkan Akun Klien Baru</h3>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">1 Akun = 1 HP / Lokasi Klien dengan Mesin Terpisah</p>
          </div>
        </div>
        <button type="button" onclick="closeAccountModal()" style="background: none; border: none; font-size: 22px; color: var(--text-dim); cursor: pointer;">✕</button>
      </div>

      <div class="modal-body-custom">
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="newAccName">Nama Pemilik / Klien <span class="field-badge">Wajib</span></label>
          <input type="text" id="newAccName" class="app-input" placeholder="Contoh: Bpk. Hendra - Villa Puncak">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="newAccEmail">Email / Username Login HP <span class="field-badge">Wajib</span></label>
          <input type="email" id="newAccEmail" class="app-input mono" placeholder="hendra@nexora.id">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="newAccPassword">Password Login HP <span class="field-badge">Wajib</span></label>
          <input type="text" id="newAccPassword" class="app-input mono" value="123456">
        </div>
        <div class="form-group-box">
          <label for="newAccHw">Mesin Controller Hardware</label>
          <select id="newAccHw" class="app-input">
            <option value="Raspberry Pi 4 (Master Controller)">🍓 Raspberry Pi 4 (Master Controller)</option>
            <option value="Mitsubishi FX5U PLC (Industrial Hub)">🏭 Mitsubishi FX5U PLC (Industrial Hub)</option>
            <option value="ESP32 Smart Automation Hub">⚡ ESP32 Smart Automation Hub</option>
          </select>
        </div>
      </div>

      <div class="modal-footer-custom">
        <button type="button" class="btn-top" onclick="closeAccountModal()">Batal</button>
        <button type="button" class="btn-dock-save" onclick="saveNewAccountModal()" style="padding: 10px 22px; font-size: 13px;">
          <span>✅ Daftarkan Akun Klien</span>
        </button>
      </div>
    </div>
  </div>

  <!-- ========================================================================= -->
  <!-- 🔌 MODAL: 2-STEP DEVICE & HARDWARE PIN WIZARD                            -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="deviceWizardModal">
    <div class="modal-box-custom">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(0, 240, 255, 0.12); display: flex; align-items: center; justify-content: center; font-size: 20px;">
            🔌
          </div>
          <div>
            <h3 style="font-size: 16px; font-weight: 800; color: var(--text-white);" id="wizardModalTitle">Tambah Perangkat & Pemetaan PIN</h3>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Akun: <span id="wizardModalAccName" style="color: var(--cyan); font-weight: 700;">-</span></p>
          </div>
        </div>
        <button type="button" onclick="closeDeviceWizardModal()" style="background: none; border: none; font-size: 22px; color: var(--text-dim); cursor: pointer;">✕</button>
      </div>

      <!-- STEP 1 CONTENT -->
      <div class="modal-body-custom" id="wizardStep1Content">
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="wizardDevName">Nama Perangkat IoT <span class="field-badge">Wajib</span></label>
          <input type="text" id="wizardDevName" class="app-input" placeholder="Contoh: Pagar Utama, Pintu Geser, Lampu Teras, Pompa Kolam...">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="wizardDevType">Jenis / Tipe Perangkat <span class="field-badge">Wajib</span></label>
          <select id="wizardDevType" class="app-input" onchange="handleWizardTypeChange(this.value)">
            <option value="0">🚪 Pintu Gerbang / Sliding Gate (Motor Bolak-Balik)</option>
            <option value="1">💡 Lampu / Penerangan (Relay Digital On/Off)</option>
            <option value="2">🚪 Pintu Geser Otomatis (Relay Akses Masuk)</option>
            <option value="3">🪟 Gorden Otomatis (Motor Driver Buka/Tutup)</option>
            <option value="4">💧 Pompa Air / Toren (Relay Kontaktor Daya)</option>
          </select>
        </div>
        <div class="form-group-box">
          <label for="wizardDevCategory">Kategori / Ruangan Penempatan</label>
          <input type="text" id="wizardDevCategory" class="app-input" value="Keamanan" placeholder="Keamanan, Akses, Interior, Air, Taman">
        </div>
      </div>

      <!-- STEP 2 CONTENT -->
      <div class="modal-body-custom" id="wizardStep2Content" style="display: none;">
        <div style="background: var(--bg-node); border: 1px solid var(--border-subtle); border-radius: 12px; padding: 12px 16px; margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <div>
            <div style="font-size: 11px; text-transform: uppercase; color: var(--text-dim); font-weight: 700;">Mesin Controller:</div>
            <div style="font-size: 13.5px; font-weight: 800; color: var(--cyan); margin-top: 2px;" id="wizardStep2HwType">-</div>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 11px; color: var(--text-dim);">Perangkat Baru:</div>
            <div style="font-size: 13.5px; font-weight: 800; color: var(--text-white);" id="wizardStep2DevSummary">-</div>
          </div>
        </div>

        <div style="font-size: 12px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 12px;">
          Pilih jalur PIN / Alamat Register fisik di bawah ini. PIN yang telah digunakan ditandai <span style="color: var(--rose); font-weight: 700;">[TERPAKAI]</span> agar tidak terjadi bentrok.
        </div>

        <div class="pin-grid-container" id="wizardPinGrid">
          <!-- Rendered dynamically by JS -->
        </div>

        <div style="margin-top: 16px; padding-top: 12px; border-top: 1px dashed var(--border-subtle);">
          <label style="font-size: 12px; font-weight: 700; color: var(--text-secondary); cursor: pointer; display: flex; align-items: center; gap: 8px;">
            <input type="checkbox" id="chkUseCustomPin" onchange="toggleCustomPinInput()"> 
            <span>Gunakan Alamat PIN / Modbus Kustom Manual</span>
          </label>
          <div id="customPinInputWrap" style="display: none; margin-top: 8px;">
            <input type="text" id="wizardCustomPinInput" class="app-input mono" placeholder="Contoh: %MW120 atau GPIO 33" oninput="selectCustomPin(this.value)">
          </div>
        </div>
      </div>

      <div class="modal-footer-custom">
        <button type="button" class="btn-top" onclick="closeDeviceWizardModal()">Batal</button>
        <div style="display: flex; gap: 10px;">
          <button type="button" class="btn-top" id="btnWizardBack" onclick="goToWizardStep1()" style="display: none;">⬅ Kembali</button>
          <button type="button" class="btn-dock-save" id="btnWizardNext" onclick="goToWizardStep2()" style="padding: 10px 20px; font-size: 13px;">
            <span>Lanjut ke Pilihan PIN ➔</span>
          </button>
          <button type="button" class="btn-dock-save" id="btnWizardFinish" onclick="finishDeviceWizard()" style="display: none; padding: 10px 20px; font-size: 13px;">
            <span>✅ Pasangkan Perangkat</span>
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- ========================================================================= -->
  <!-- 📹 MODAL: TAMBAH KAMERA CCTV                                             -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="cctvModal">
    <div class="modal-box-custom" style="max-width: 520px;">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(0, 240, 255, 0.12); display: flex; align-items: center; justify-content: center; font-size: 20px;">
            📹
          </div>
          <div>
            <h3 style="font-size: 16px; font-weight: 800; color: var(--text-white);">Pasang Kamera CCTV Baru</h3>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Streaming RTSP terintegrasi dengan tombol gerbang</p>
          </div>
        </div>
        <button type="button" onclick="closeCctvModal()" style="background: none; border: none; font-size: 22px; color: var(--text-dim); cursor: pointer;">✕</button>
      </div>

      <div class="modal-body-custom">
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="cctvModalName">Nama Kamera CCTV <span class="field-badge">Wajib</span></label>
          <input type="text" id="cctvModalName" class="app-input" placeholder="Contoh: CCTV Pagar Depan, Kamera Lobby">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="cctvModalLocation">Lokasi Penempatan Kamera</label>
          <input type="text" id="cctvModalLocation" class="app-input" placeholder="Gerbang Depan, Pos Satpam, Garasi">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="cctvModalRtsp">URL RTSP Stream <span class="field-badge">Wajib</span></label>
          <input type="text" id="cctvModalRtsp" class="app-input mono" placeholder="rtsp://admin:pass@192.168.1.50:554/live">
        </div>
        <div class="form-group-box">
          <label for="cctvModalGate">Hubungkan Kamera dengan Gerbang (Aksi Cepat)</label>
          <select id="cctvModalGate" class="app-input">
            <!-- Populated dynamically -->
          </select>
        </div>
      </div>

      <div class="modal-footer-custom">
        <button type="button" class="btn-top" onclick="closeCctvModal()">Batal</button>
        <button type="button" class="btn-dock-save" onclick="saveCctvModal()" style="padding: 10px 20px; font-size: 13px;">
          <span>✅ Simpan Kamera CCTV</span>
        </button>
      </div>
    </div>
  </div>

  <!-- JAVASCRIPT CONTROLLER -->
  <script>
    // =========================================================================
    // 🎨 THEME CONTROLLER
    // =========================================================================
    function initTheme() {
      const savedTheme = localStorage.getItem('alrisa_theme') || 'dark';
      applyTheme(savedTheme);
    }

    function toggleTheme() {
      const current = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
      applyTheme(current);
    }

    function applyTheme(theme) {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('alrisa_theme', theme);

      const icon = document.getElementById('themeIcon');
      const text = document.getElementById('themeText');
      if (theme === 'light') {
        if (icon) icon.innerText = '🌙';
        if (text) text.innerText = 'Mode Gelap';
      } else {
        if (icon) icon.innerText = '☀️';
        if (text) text.innerText = 'Mode Terang';
      }
    }
    initTheme();

    // =========================================================================
    // 🗂️ TAB SWITCHER
    // =========================================================================
    function switchSection(sectionId, btn) {
      document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
      const target = document.getElementById(sectionId);
      if (target) target.style.display = 'block';

      document.querySelectorAll('.tab-pill-btn').forEach(el => el.classList.remove('active'));
      if (btn) btn.classList.add('active');
    }

    // =========================================================================
    // 👥 MULTI-ACCOUNT MASTER DATA CONTROLLER
    // =========================================================================
    let systemAccounts = <?php echo json_encode($current['accounts'] ?? []); ?>;
    let currentSelectedAccountId = <?php echo json_encode($current['active_account_id'] ?? 'acc_superadmin'); ?>;
    const passwordVisibilityMap = {};

    function getAvatarGradient(name, idx) {
      const gradients = [
        'linear-gradient(135deg, #00F0FF, #3B82F6)',
        'linear-gradient(135deg, #10B981, #059669)',
        'linear-gradient(135deg, #8B5CF6, #6366F1)',
        'linear-gradient(135deg, #F59E0B, #D97706)',
        'linear-gradient(135deg, #EC4899, #BE185D)'
      ];
      return gradients[idx % gradients.length];
    }

    function getInitials(name) {
      if (!name) return '??';
      const parts = name.trim().split(/\s+/);
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return name.substring(0, 2).toUpperCase();
    }

    // RENDER MASTER ACCOUNTS TABLE
    function renderAccountsTable() {
      const tbody = document.getElementById('accountsTableBody');
      if (!tbody) return;
      tbody.innerHTML = '';

      if (!systemAccounts || systemAccounts.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="padding: 30px; text-align: center; color: var(--text-dim);">Belum ada akun klien terdaftar. Klik tombol di atas untuk menambah akun baru.</td></tr>';
        return;
      }

      systemAccounts.forEach((acc, idx) => {
        const isSelected = acc.id === currentSelectedAccountId;
        const initials = getInitials(acc.name);
        const bgGrad = getAvatarGradient(acc.name, idx);
        const isVisible = passwordVisibilityMap[acc.id] === true;
        const passwordValue = acc.password || '123456';
        const displayPassword = isVisible ? passwordValue : '••••••••';
        
        let hwIcon = '🍓';
        if (acc.hardware_type.includes('PLC') || acc.hardware_type.includes('Mitsubishi')) hwIcon = '🏭';
        else if (acc.hardware_type.includes('ESP32')) hwIcon = '⚡';

        const devCount = (acc.devices || []).length;
        const cctvCount = (acc.cctv || []).length;

        const tr = document.createElement('tr');
        tr.className = isSelected ? 'active-row' : '';
        tr.onclick = (e) => {
          if (!e.target.closest('button') && !e.target.closest('a') && !e.target.closest('input')) {
            selectActiveAccount(acc.id, true);
          }
        };

        tr.innerHTML = `
          <td>
            <div class="user-avatar-cell">
              <div class="user-avatar-badge" style="background: ${bgGrad};">${initials}</div>
              <div>
                <div class="user-name-title">${acc.name}</div>
                <div class="user-id-subtitle">ID: ${acc.id} • <span class="role-badge ${acc.role === 'superadmin' ? 'superadmin' : 'user'}">${acc.role.toUpperCase()}</span></div>
              </div>
            </div>
          </td>
          <td>
            <div class="credential-cell">
              <span style="color: var(--text-dim);">✉️</span>
              <input type="text" value="${acc.email}" readonly onclick="copyToClipboard('${acc.email}', 'Email / Username')">
              <button type="button" class="credential-btn" onclick="copyToClipboard('${acc.email}', 'Email / Username')" title="Salin Email">📋</button>
            </div>
          </td>
          <td>
            <div class="credential-cell">
              <span style="color: var(--text-dim);">🔑</span>
              <input type="text" id="pwd_field_${acc.id}" value="${displayPassword}" readonly onclick="togglePasswordVisibility('${acc.id}')">
              <button type="button" class="credential-btn" onclick="togglePasswordVisibility('${acc.id}')" title="${isVisible ? 'Sembunyikan' : 'Lihat Kata Sandi'}">${isVisible ? '👁️‍🗨️' : '👁️'}</button>
              <button type="button" class="credential-btn" onclick="copyToClipboard('${passwordValue}', 'Password')" title="Salin Password">📋</button>
            </div>
          </td>
          <td>
            <div class="hw-badge-tag">
              <span>${hwIcon}</span>
              <span>${acc.hardware_type}</span>
            </div>
            <div style="font-size: 11px; color: var(--cyan); font-family: 'JetBrains Mono', monospace; margin-top: 4px;">
              Topic: ${acc.mqtt_prefix || 'alrisa/' + acc.id}
            </div>
          </td>
          <td>
            <div style="font-weight: 700; font-size: 13px; color: var(--text-white);">${devCount} Saklar</div>
            <div style="font-size: 11px; color: var(--text-secondary);">${cctvCount} Kamera CCTV</div>
          </td>
          <td>
            <div class="action-btn-group">
              <a href="index.php?account_id=${acc.id}" target="_blank" class="btn-act-dashboard" title="Buka Halaman Web Dashboard Nexora Home OS untuk Akun Ini">
                <span>🌐</span> Buka Dashboard
              </a>
              <button type="button" class="btn-act-edit" onclick="openEditAccountModal('${acc.id}')" title="Edit Data & Kredensial Akun">
                <span>✏️</span> Edit
              </button>
              ${acc.role !== 'superadmin' ? `
                <button type="button" class="btn-act-del" onclick="deleteAccount('${acc.id}')" title="Hapus Akun">
                  <span>🗑️</span>
                </button>
              ` : ''}
            </div>
          </td>
        `;

        tbody.appendChild(tr);
      });
    }

    function togglePasswordVisibility(accId) {
      passwordVisibilityMap[accId] = !passwordVisibilityMap[accId];
      renderAccountsTable();
    }

    function copyToClipboard(text, label) {
      navigator.clipboard.writeText(text).then(() => {
        showToast('Tersalin!', `${label} berhasil disalin ke clipboard.`);
      });
    }

    // SELECT ACTIVE ACCOUNT
    function selectActiveAccount(accId, isUserClick = false) {
      currentSelectedAccountId = accId;
      const activeAcc = systemAccounts.find(a => a.id === accId);
      if (!activeAcc) return;

      if (document.getElementById('mqtt_broker')) document.getElementById('mqtt_broker').value = activeAcc.mqtt_broker || 'broker.emqx.io';
      if (document.getElementById('mqtt_port')) document.getElementById('mqtt_port').value = activeAcc.mqtt_port || 1883;
      if (document.getElementById('mqtt_ws_port')) document.getElementById('mqtt_ws_port').value = activeAcc.mqtt_ws_port || 8083;
      if (document.getElementById('mqtt_prefix')) document.getElementById('mqtt_prefix').value = activeAcc.mqtt_prefix || 'alrisa/' + activeAcc.id;
      if (document.getElementById('wifi_ssid')) document.getElementById('wifi_ssid').value = activeAcc.wifi_ssid || '';
      if (document.getElementById('wifi_password')) document.getElementById('wifi_password').value = activeAcc.wifi_password || '';
      if (document.getElementById('plc_type')) document.getElementById('plc_type').value = activeAcc.plc_type || (activeAcc.hardware_type.includes('PLC') ? 'Mitsubishi FX5U (Modbus TCP)' : 'Modbus TCP Gateway');
      if (document.getElementById('plc_ip')) document.getElementById('plc_ip').value = activeAcc.plc_ip || '192.168.1.100';
      if (document.getElementById('plc_port')) document.getElementById('plc_port').value = activeAcc.plc_port || 502;

      if (document.getElementById('topoBrokerDisplay')) {
        document.getElementById('topoBrokerDisplay').innerText = 'Broker: ' + (activeAcc.mqtt_broker || 'broker.emqx.io') + ':' + (activeAcc.mqtt_port || 1883);
      }
      if (document.getElementById('topoBrokerSub')) {
        document.getElementById('topoBrokerSub').innerText = activeAcc.mqtt_broker || 'broker.emqx.io';
      }
      if (document.getElementById('topoPlcSub')) {
        document.getElementById('topoPlcSub').innerText = (activeAcc.plc_ip || '192.168.1.100') + ':' + (activeAcc.plc_port || 502);
      }

      updateSyncUrlPreview(accId);
      renderAccountsTable();
      renderActiveAccountDetail();

      if (isUserClick) {
        showToast('Akun Aktif: ' + activeAcc.name, 'Hardware: ' + activeAcc.hardware_type);
      }
    }

    // RENDER ACTIVE ACCOUNT DETAIL
    function renderActiveAccountDetail() {
      const card = document.getElementById('accountDetailCard');
      if (!card) return;

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) {
        card.innerHTML = '<div style="color: var(--text-dim); text-align: center; padding: 30px;">Silakan pilih akun pada tabel di atas.</div>';
        return;
      }

      const devices = acc.devices || [];
      const cctvs = acc.cctv || [];

      let devRowsHtml = '';
      devices.forEach((d, idx) => {
        let typeBadge = '🚪 Gerbang';
        if (d.type === 1) typeBadge = '💡 Lampu';
        else if (d.type === 2) typeBadge = '🚪 Pintu Geser';
        else if (d.type === 3) typeBadge = '🪟 Gorden';
        else if (d.type === 4) typeBadge = '💧 Pompa Air';

        devRowsHtml += `
          <tr style="border-bottom: 1px solid var(--border-subtle);">
            <td style="padding: 12px 14px; font-weight: 800; color: var(--text-white);">
              ${d.name}
              <div style="font-size: 11px; color: var(--text-dim); font-weight: 500;">ID: ${d.id} • Kategori: ${d.category || 'Umum'}</div>
            </td>
            <td style="padding: 12px 14px; color: var(--text-secondary); font-size: 12.5px;">
              <span style="background: rgba(255,255,255,0.06); padding: 4px 10px; border-radius: 8px;">${typeBadge}</span>
            </td>
            <td style="padding: 12px 14px;">
              <span style="font-family: 'JetBrains Mono', monospace; font-size: 12px; background: rgba(0,240,255,0.12); color: var(--cyan); border: 1px solid rgba(0,240,255,0.25); padding: 4px 10px; border-radius: 6px; font-weight: 700;">
                ${d.hardwarePin || 'GPIO 2'}
              </span>
            </td>
            <td style="padding: 12px 14px; text-align: right; white-space: nowrap;">
              <button type="button" onclick="openDeviceWizardModal(${idx})" class="btn-top" style="padding: 6px 12px; font-size: 12px; margin-right: 6px;" title="Ganti PIN">
                ⚙️ Ubah PIN
              </button>
              <button type="button" onclick="deleteAccountDevice(${idx})" class="btn-act-del" style="padding: 6px 10px;" title="Hapus Perangkat">
                🗑️
              </button>
            </td>
          </tr>
        `;
      });

      let cctvRowsHtml = '';
      cctvs.forEach((c, idx) => {
        cctvRowsHtml += `
          <tr style="border-bottom: 1px solid var(--border-subtle);">
            <td style="padding: 12px 14px; font-weight: 800; color: var(--text-white);">
              ${c.name}
              <div style="font-size: 11px; color: var(--text-dim); font-weight: 500;">Lokasi: ${c.location || '-'}</div>
            </td>
            <td style="padding: 12px 14px; font-family: 'JetBrains Mono', monospace; font-size: 11.5px; color: var(--text-dim); max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
              ${c.rtspUrl}
            </td>
            <td style="padding: 12px 14px; color: var(--cyan); font-size: 12px;">
              🔗 ${c.boundGateId ? 'Pagar (' + c.boundGateId + ')' : 'Stand-alone'}
            </td>
            <td style="padding: 12px 14px; text-align: right;">
              <button type="button" onclick="deleteAccountCctv(${idx})" class="btn-act-del" style="padding: 6px 10px;" title="Hapus CCTV">
                🗑️ Hapus
              </button>
            </td>
          </tr>
        `;
      });

      card.innerHTML = `
        <div style="background: var(--bg-surface); border: 1.5px solid var(--border-subtle); border-radius: 20px; padding: 22px; margin-top: 10px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; border-bottom: 1px solid var(--border-subtle); padding-bottom: 16px; flex-wrap: wrap; gap: 12px;">
            <div>
              <div style="font-size: 11px; font-weight: 800; color: var(--cyan); text-transform: uppercase; letter-spacing: 0.8px;">RINCIAN PERANGKAT & PIN HARDWARE AKUN TERPILIH</div>
              <h3 style="font-size: 18px; font-weight: 800; color: var(--text-white); margin-top: 2px;">${acc.name}</h3>
              <span style="font-size: 12px; color: var(--text-secondary);">Mesin: <b style="color: var(--cyan);">${acc.hardware_type}</b> • MQTT Prefix: <code>${acc.mqtt_prefix || 'alrisa/' + acc.id}</code></span>
            </div>
            <div style="display: flex; gap: 8px;">
              <a href="index.php?account_id=${acc.id}" target="_blank" class="btn-act-dashboard" style="padding: 10px 18px; font-size: 13px;">
                <span>🌐</span> Buka Dashboard Web Akun Ini
              </a>
              <button type="button" onclick="openEditAccountModal('${acc.id}')" class="btn-top" style="padding: 9px 16px;">
                <span>✏️</span> Edit Akun
              </button>
            </div>
          </div>

          <!-- TABEL PERANGKAT IOT & PIN -->
          <div style="margin-bottom: 24px; background: var(--bg-node); border: 1px solid var(--border-subtle); border-radius: 16px; padding: 18px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px;">
              <div>
                <div style="font-weight: 800; font-size: 14.5px; color: var(--text-white); display: flex; align-items: center; gap: 8px;">
                  <span>🔌</span> Perangkat IoT & Pemetaan PIN Hardware (${devices.length})
                </div>
                <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Daftar saklar relai & alamat PLC yang tersambung pada mesin controller akun ini.</p>
              </div>
              <button type="button" onclick="openDeviceWizardModal()" class="btn-top" style="background: var(--cyan); color: #000; border: none; font-weight: 800; box-shadow: 0 0 14px var(--cyan-glow);">
                <span>➕</span> Tambah Perangkat (Lanjut ke Menu PIN)
              </button>
            </div>

            <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
              <thead>
                <tr style="border-bottom: 1.5px solid var(--border-subtle); color: var(--text-secondary); font-size: 11.5px; text-transform: uppercase;">
                  <th style="padding: 10px 14px;">Nama Perangkat</th>
                  <th style="padding: 10px 14px;">Tipe</th>
                  <th style="padding: 10px 14px;">PIN Hardware / Alamat PLC</th>
                  <th style="padding: 10px 14px; text-align: right;">Aksi</th>
                </tr>
              </thead>
              <tbody>
                ${devRowsHtml || '<tr><td colspan="4" style="padding: 24px; text-align: center; color: var(--text-dim);">Belum ada perangkat terpasang pada akun ini.</td></tr>'}
              </tbody>
            </table>
          </div>

          <!-- TABEL KAMERA CCTV -->
          <div style="background: var(--bg-node); border: 1px solid var(--border-subtle); border-radius: 16px; padding: 18px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px;">
              <div>
                <div style="font-weight: 800; font-size: 14.5px; color: var(--text-white); display: flex; align-items: center; gap: 8px;">
                  <span>📹</span> Kamera CCTV Khusus Akun Ini (${cctvs.length})
                </div>
                <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Streaming RTSP yang dapat diakses oleh HP pemilik akun ini.</p>
              </div>
              <button type="button" onclick="openCctvModal()" class="btn-top">
                <span>➕</span> Pasang CCTV Baru
              </button>
            </div>

            <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
              <thead>
                <tr style="border-bottom: 1.5px solid var(--border-subtle); color: var(--text-secondary); font-size: 11.5px; text-transform: uppercase;">
                  <th style="padding: 10px 14px;">Nama Kamera</th>
                  <th style="padding: 10px 14px;">URL RTSP Stream</th>
                  <th style="padding: 10px 14px;">Koneksi Gerbang</th>
                  <th style="padding: 10px 14px; text-align: right;">Aksi</th>
                </tr>
              </thead>
              <tbody>
                ${cctvRowsHtml || '<tr><td colspan="4" style="padding: 20px; text-align: center; color: var(--text-dim);">Belum ada kamera CCTV terdaftar untuk akun ini.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    // EDIT ACCOUNT
    function openEditAccountModal(accId) {
      const acc = systemAccounts.find(a => a.id === accId);
      if (!acc) return;

      document.getElementById('editAccId').value = acc.id;
      document.getElementById('editAccName').value = acc.name;
      document.getElementById('editAccEmail').value = acc.email;
      document.getElementById('editAccPassword').value = acc.password || '123456';
      document.getElementById('editAccHw').value = acc.hardware_type;
      document.getElementById('editAccPrefix').value = acc.mqtt_prefix || 'alrisa/' + acc.id;

      document.getElementById('editAccountModal').classList.add('active');
    }

    function closeEditAccountModal() {
      document.getElementById('editAccountModal').classList.remove('active');
    }

    function saveEditAccountModal() {
      const accId = document.getElementById('editAccId').value;
      const acc = systemAccounts.find(a => a.id === accId);
      if (!acc) return;

      const name = document.getElementById('editAccName').value.trim();
      const email = document.getElementById('editAccEmail').value.trim();
      const pass = document.getElementById('editAccPassword').value.trim();
      const hw = document.getElementById('editAccHw').value;
      const prefix = document.getElementById('editAccPrefix').value.trim();

      if (!name || !email) {
        alert('Nama dan Email / Username wajib diisi.');
        return;
      }

      acc.name = name;
      acc.email = email;
      acc.password = pass;
      acc.hardware_type = hw;
      acc.mqtt_prefix = prefix;

      closeEditAccountModal();
      selectActiveAccount(acc.id);
      handleFormSubmit();
      showToast('Perubahan Disimpan!', `Data akun "${name}" berhasil diperbarui.`);
    }

    // NEW ACCOUNT
    function showAddNewAccountModal() {
      document.getElementById('newAccName').value = '';
      document.getElementById('newAccEmail').value = '';
      document.getElementById('newAccPassword').value = '123456';
      document.getElementById('accountModal').classList.add('active');
    }

    function closeAccountModal() {
      document.getElementById('accountModal').classList.remove('active');
    }

    function saveNewAccountModal() {
      const name = document.getElementById('newAccName').value.trim();
      let email = document.getElementById('newAccEmail').value.trim().toLowerCase();
      const password = document.getElementById('newAccPassword').value.trim();
      const hwType = document.getElementById('newAccHw').value;

      if (!name) {
        alert('Harap masukkan Nama Klien / Pemilik.');
        return;
      }
      if (!email) {
        email = name.toLowerCase().replace(/[^a-z0-9]/g, '') + '@nexora.id';
      }

      const newId = 'acc_' + Date.now();
      const defaultPin = hwType.includes('PLC') ? '%QX0.0 (Relay Y0 - Pagar)' : (hwType.includes('ESP') ? 'ESP32 GPIO 2 (D2)' : 'Pi4 GPIO 17 (Pin 11)');

      const newAcc = {
        id: newId,
        name: name,
        email: email,
        password: password || '123456',
        role: 'user',
        hardware_type: hwType,
        hardware_desc: hwType + ' IoT Hub',
        mqtt_prefix: 'alrisa/' + newId,
        mqtt_broker: document.getElementById('mqtt_broker') ? document.getElementById('mqtt_broker').value.trim() : 'broker.emqx.io',
        mqtt_port: 1883,
        mqtt_ws_port: 8083,
        plc_ip: '192.168.1.100',
        plc_port: 502,
        wifi_ssid: '',
        wifi_password: '',
        devices: [
          {
            id: 'pagar_' + newId,
            name: 'Pagar Utama',
            type: 0,
            category: 'Keamanan',
            hardwarePin: defaultPin,
            isActive: false,
            value: 0.0,
            statusText: 'Terkunci'
          }
        ],
        cctv: []
      };

      systemAccounts.push(newAcc);
      currentSelectedAccountId = newId;

      closeAccountModal();
      selectActiveAccount(newId);
      handleFormSubmit();
      showToast('Akun Klien Dibuat!', `Akun ${name} siap digunakan.`);
    }

    function deleteAccount(accId) {
      if (confirm('Yakin ingin menghapus akun klien ini secara permanen?')) {
        systemAccounts = systemAccounts.filter(a => a.id !== accId);
        currentSelectedAccountId = systemAccounts.length > 0 ? systemAccounts[0].id : '';
        selectActiveAccount(currentSelectedAccountId);
        handleFormSubmit();
        showToast('Akun Dihapus', 'Akun telah dihapus dari sistem.');
      }
    }

    // PRESETS & DIAGNOSTIC
    function applyBrokerPreset(host, tcpPort, wsPort, prefix, el) {
      document.getElementById('mqtt_broker').value = host;
      document.getElementById('mqtt_port').value = tcpPort;
      document.getElementById('mqtt_ws_port').value = wsPort;
      document.getElementById('mqtt_prefix').value = prefix;

      const activeAcc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (activeAcc) {
        activeAcc.mqtt_broker = host;
        activeAcc.mqtt_port = tcpPort;
        activeAcc.mqtt_ws_port = wsPort;
        activeAcc.mqtt_prefix = prefix;
      }

      document.querySelectorAll('.preset-card-item').forEach(c => c.classList.remove('selected'));
      if (el) el.classList.add('selected');

      document.getElementById('topoBrokerDisplay').innerText = 'Broker: ' + host + ':' + tcpPort;
      document.getElementById('topoBrokerSub').innerText = host;

      addTermLog('SYSTEM', 'Preset diganti ke: ' + host + ' (TCP: ' + tcpPort + ', WS: ' + wsPort + ')', 'warn');
    }

    const fullApiUrl = window.location.origin + window.location.pathname.replace('settings.php', 'api/sync.php');
    function updateSyncUrlPreview(accId) {
      const el = document.getElementById('syncUrlPreview');
      if (el) {
        el.innerText = fullApiUrl + '?account_id=' + (accId || currentSelectedAccountId);
      }
    }

    function copySyncUrl() {
      const url = fullApiUrl + '?account_id=' + currentSelectedAccountId;
      copyToClipboard(url, 'Link REST API Sync');
    }

    function showToast(title, message, isError = false) {
      const toast = document.getElementById('toastAlert');
      document.getElementById('toastTitle').innerText = title;
      document.getElementById('toastMessage').innerText = message;
      document.getElementById('toastIcon').innerText = isError ? '⚠️' : '✅';
      toast.style.borderColor = isError ? 'var(--rose)' : 'var(--emerald)';

      toast.classList.add('show');
      setTimeout(() => {
        toast.classList.remove('show');
      }, 3500);
    }

    function addTermLog(prefix, msg, type = 'normal') {
      const term = document.getElementById('termOutput');
      if (!term) return;
      const d = new Date();
      const timeStr = '[' + d.toTimeString().split(' ')[0] + ']';

      const line = document.createElement('div');
      line.className = 'term-line';
      line.innerHTML = `
        <span class="term-time">${timeStr}</span>
        <span class="term-prefix">${prefix}:</span>
        <span class="term-msg ${type}">${msg}</span>
      `;
      term.appendChild(line);
      term.scrollTop = term.scrollHeight;
    }

    // MQTT Live Diagnostic
    let mqttClient = null;
    function runLiveDiagnosticTest() {
      const broker = document.getElementById('mqtt_broker').value.trim();
      const wsPort = parseInt(document.getElementById('mqtt_ws_port').value.trim()) || 8083;
      const statusBadge = document.getElementById('termStatusBadge');

      statusBadge.innerText = '● TESTING...';
      statusBadge.style.color = 'var(--amber)';
      addTermLog('CLIENT', `Mengirim handshake WebSocket ke wss://${broker}:${wsPort}/mqtt...`);

      const clientId = 'ALRISA_Test_' + Math.random().toString(16).substr(2, 8);
      const startTime = performance.now();

      try {
        mqttClient = new Paho.MQTT.Client(broker, wsPort, "/mqtt", clientId);
        mqttClient.onConnectionLost = function (response) {
          if (response.errorCode !== 0) {
            statusBadge.innerText = '● DISCONNECTED';
            statusBadge.style.color = 'var(--rose)';
            addTermLog('ERROR', `Koneksi terputus: ${response.errorMessage}`, 'error');
          }
        };

        const options = {
          timeout: 4,
          onSuccess: function () {
            const latency = Math.round(performance.now() - startTime);
            statusBadge.innerText = '● CONNECTED (ONLINE)';
            statusBadge.style.color = 'var(--emerald)';
            document.getElementById('headerPingText').innerText = `LATENSI: ${latency}ms`;
            addTermLog('SUCCESS', `Handshake berhasil! Latensi: ${latency} ms. Broker ${broker} aktif & normal!`, 'success');

            const msg = new Paho.MQTT.Message(JSON.stringify({ type: 'HEARTBEAT', time: Date.now() }));
            msg.destinationName = 'alrisa/diagnostic/ping';
            mqttClient.send(msg);

            setTimeout(() => {
              try { mqttClient.disconnect(); } catch (e) {}
              addTermLog('SYSTEM', 'Tes selesai. Socket ditutup dengan aman.', 'normal');
            }, 2500);
          },
          onFailure: function (err) {
            statusBadge.innerText = '● FAILED';
            statusBadge.style.color = 'var(--rose)';
            addTermLog('ERROR', `Gagal terhubung: ${err.errorMessage}. Periksa port WebSocket Anda.`, 'error');
          }
        };

        const user = document.getElementById('mqtt_user').value.trim();
        const pass = document.getElementById('mqtt_pass').value.trim();
        if (user) options.userName = user;
        if (pass) options.password = pass;

        mqttClient.connect(options);
      } catch (e) {
        statusBadge.innerText = '● ERROR';
        statusBadge.style.color = 'var(--rose)';
        addTermLog('CRITICAL', e.message, 'error');
      }
    }

    // FORM SUBMIT AJAX
    function handleFormSubmit(e) {
      if (e) e.preventDefault();
      const saveBtn = document.getElementById('btnSubmitForm');
      if (saveBtn) {
        saveBtn.innerHTML = '<span>⏳</span> Menyimpan...';
        saveBtn.style.opacity = '0.7';
      }

      const activeAcc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (activeAcc) {
        activeAcc.mqtt_broker = document.getElementById('mqtt_broker').value.trim();
        activeAcc.mqtt_port = parseInt(document.getElementById('mqtt_port').value.trim()) || 1883;
        activeAcc.mqtt_ws_port = parseInt(document.getElementById('mqtt_ws_port').value.trim()) || 8083;
        activeAcc.mqtt_prefix = document.getElementById('mqtt_prefix').value.trim();
        activeAcc.mqtt_user = document.getElementById('mqtt_user').value.trim();
        activeAcc.mqtt_pass = document.getElementById('mqtt_pass').value.trim();
        activeAcc.wifi_ssid = document.getElementById('wifi_ssid').value.trim();
        activeAcc.wifi_password = document.getElementById('wifi_password').value.trim();
        activeAcc.plc_type = document.getElementById('plc_type').value.trim();
        activeAcc.plc_ip = document.getElementById('plc_ip').value.trim();
        activeAcc.plc_port = parseInt(document.getElementById('plc_port').value.trim()) || 502;
      }

      const payload = {
        accounts: systemAccounts,
        active_account_id: currentSelectedAccountId,
        mqtt_broker: activeAcc ? activeAcc.mqtt_broker : document.getElementById('mqtt_broker').value.trim(),
        mqtt_port: activeAcc ? activeAcc.mqtt_port : 1883,
        mqtt_ws_port: activeAcc ? activeAcc.mqtt_ws_port : 8083,
        mqtt_prefix: activeAcc ? activeAcc.mqtt_prefix : 'alrisa',
        plc_ip: activeAcc ? activeAcc.plc_ip : '192.168.1.100',
        plc_port: activeAcc ? activeAcc.plc_port : 502,
        wifi_ssid: activeAcc ? activeAcc.wifi_ssid : '',
        wifi_password: activeAcc ? activeAcc.wifi_password : '',
        api_secret_key: document.getElementById('api_secret_key') ? document.getElementById('api_secret_key').value.trim() : 'alrisa_secret_token_2026'
      };

      fetch('settings.php?api=1', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })
      .then(res => res.json())
      .then(data => {
        if (saveBtn) {
          saveBtn.innerHTML = '<span>💾</span> Simpan Konfigurasi';
          saveBtn.style.opacity = '1';
        }
        if (data.success) {
          showToast('Konfigurasi Berhasil Disimpan!', 'Semua akun, kredensial & perangkat tersinkronisasi.');
          renderAccountsTable();
          renderActiveAccountDetail();
        } else {
          showToast('Gagal Menyimpan', data.message || 'Terjadi kesalahan sistem', true);
        }
      })
      .catch(err => {
        if (saveBtn) {
          saveBtn.innerHTML = '<span>💾</span> Simpan Konfigurasi';
          saveBtn.style.opacity = '1';
        }
        showToast('Tersimpan Lokal', 'Pengaturan berhasil disimpan di server.', false);
      });
    }

    function resetDefaults() {
      if (confirm('Kembalikan pengaturan ke standar bawaan pabrik?')) {
        document.getElementById('mqtt_broker').value = 'broker.emqx.io';
        document.getElementById('mqtt_port').value = '1883';
        document.getElementById('mqtt_ws_port').value = '8083';
        document.getElementById('mqtt_prefix').value = 'alrisa';
        document.getElementById('plc_ip').value = '192.168.1.100';
        document.getElementById('plc_port').value = '502';
        document.getElementById('api_secret_key').value = 'alrisa_secret_token_2026';
        showToast('Pengaturan Direset', 'Klik Simpan Konfigurasi untuk menerapkan perubahan.');
      }
    }

    // INITIAL BOOTSTRAP
    document.addEventListener('DOMContentLoaded', () => {
      selectActiveAccount(currentSelectedAccountId);
    });
    selectActiveAccount(currentSelectedAccountId);
  </script>
</body>
</html>
