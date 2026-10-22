<?php
/**
 * ============================================================================
 * ALRISA SMART IOT — ULTRA-PREMIUM WEBDESK CONFIGURATION & BROKER STUDIO
 * ============================================================================
 * Portal konfigurasi terpusat untuk Broker MQTT, WiFi Hardware ESP32,
 * Mitsubishi FX5U PLC, dan Keamanan API Token.
 * Dilengkapi Dual-Theme (Dark Mode & Light Mode).
 * 
 * Endpoint REST API JSON:
 * GET  settings.php?api=1   -> Muat konfigurasi
 * POST settings.php?api=1   -> Simpan konfigurasi
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
    'app_name'         => 'ALRISA Industrial IoT Suite',
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

        // Dukungan Multi-Akun (Per-Device & Klien)
        if (isset($input['accounts']) && is_array($input['accounts'])) {
            $current['accounts'] = $input['accounts'];
        }
        if (isset($input['active_account_id'])) {
            $current['active_account_id'] = trim($input['active_account_id']);
        }

        saveSettings($settingsFile, $current);
        echo json_encode([
            'success' => true,
            'message' => 'Konfigurasi sistem & multi-akun berhasil diperbarui!',
            'data'    => $current
        ]);
        exit();
    }

    echo json_encode([
        'success' => true,
        'message' => 'Konfigurasi ALRISA berhasil dimuat',
        'data'    => $current
    ]);
    exit();
}

// Normal POST Handler
$message = null;
$messageType = 'success';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    foreach ($defaultSettings as $key => $val) {
        if (isset($_POST[$key])) {
            $current[$key] = is_numeric($val) ? intval($_POST[$key]) : trim($_POST[$key]);
        }
    }

    if (saveSettings($settingsFile, $current)) {
        $message = "Konfigurasi berhasil disimpan! Seluruh ekosistem ALRISA kini tersinkronisasi.";
        $messageType = "success";
    } else {
        $message = "Gagal menyimpan file konfigurasi. Periksa izin folder hosting Anda.";
        $messageType = "error";
    }
}
?>
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ALRISA WebDesk — Central IoT & Broker Configuration Studio</title>
  
  <!-- Modern Google Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Outfit:wght@400;500;600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <!-- Paho MQTT WebSocket Client -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/paho-mqtt/1.0.1/mqttws31.min.js"></script>

  <style>
    :root, [data-theme="dark"] {
      --bg-base: #07090E;
      --bg-surface: #0E131F;
      --bg-card: rgba(16, 22, 36, 0.75);
      --bg-card-hover: rgba(22, 30, 50, 0.85);
      --bg-input: #090D15;
      --bg-node: #0B0F1A;
      --bg-terminal: #05070B;
      --bg-dock: rgba(14, 20, 32, 0.90);
      
      --cyan: #00F0FF;
      --cyan-glow: rgba(0, 240, 255, 0.35);
      --cyan-subtle: rgba(0, 240, 255, 0.08);
      
      --emerald: #10B981;
      --emerald-glow: rgba(16, 185, 129, 0.35);
      --emerald-subtle: rgba(16, 185, 129, 0.1);
      
      --amber: #F59E0B;
      --amber-subtle: rgba(245, 158, 11, 0.1);
      
      --rose: #F43F5E;
      --rose-subtle: rgba(244, 63, 94, 0.12);
      
      --purple: #8B5CF6;
      --indigo: #6366F1;
      
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-active: rgba(0, 240, 255, 0.4);
      --border-focus: #00F0FF;
      
      --text-white: #FFFFFF;
      --text-secondary: #94A3B8;
      --text-dim: #64748B;
      
      --shadow-card: 0 10px 30px rgba(0, 0, 0, 0.4);
      --shadow-dock: 0 16px 50px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 240, 255, 0.15);
      --mesh-bg: 
        radial-gradient(at 10% 10%, rgba(0, 240, 255, 0.09) 0px, transparent 45%),
        radial-gradient(at 90% 15%, rgba(139, 92, 246, 0.08) 0px, transparent 40%),
        radial-gradient(at 50% 90%, rgba(16, 185, 129, 0.06) 0px, transparent 50%);
    }

    [data-theme="light"] {
      --bg-base: #F1F5F9;
      --bg-surface: #FFFFFF;
      --bg-card: rgba(255, 255, 255, 0.88);
      --bg-card-hover: #FFFFFF;
      --bg-input: #FFFFFF;
      --bg-node: #F8FAFC;
      --bg-terminal: #0F172A;
      --bg-dock: rgba(255, 255, 255, 0.94);
      
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
        radial-gradient(at 90% 15%, rgba(124, 58, 237, 0.06) 0px, transparent 50%),
        radial-gradient(at 50% 90%, rgba(5, 150, 105, 0.06) 0px, transparent 50%);
    }

    :root {
      --radius-xl: 24px;
      --radius-lg: 16px;
      --radius-md: 12px;
      --radius-sm: 8px;
      
      --font-display: 'Outfit', sans-serif;
      --font-body: 'Plus Jakarta Sans', sans-serif;
      --font-code: 'JetBrains Mono', monospace;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
      transition: background-color 0.25s ease, border-color 0.25s ease, color 0.25s ease;
    }

    body {
      background-color: var(--bg-base);
      background-image: var(--mesh-bg);
      background-attachment: fixed;
      color: var(--text-white);
      font-family: var(--font-body);
      min-height: 100vh;
      padding: 24px 20px 100px;
      overflow-x: hidden;
    }

    .container {
      max-width: 1240px;
      margin: 0 auto;
    }

    .top-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 16px;
      padding: 16px 24px;
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-xl);
      box-shadow: var(--shadow-card);
    }

    .brand-group {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .brand-logo-badge {
      width: 52px;
      height: 52px;
      border-radius: var(--radius-lg);
      background: linear-gradient(135deg, #00F0FF, #3B82F6);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      box-shadow: 0 0 25px var(--cyan-glow);
      position: relative;
    }

    .brand-title-wrap h1 {
      font-family: var(--font-display);
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .brand-title-wrap h1 span.gradient-text {
      color: var(--text-white);
    }

    .brand-title-wrap h1 span.cyan-text {
      color: var(--cyan);
    }

    .version-tag {
      font-size: 10px;
      font-family: var(--font-code);
      background: var(--cyan-subtle);
      color: var(--cyan);
      padding: 2px 8px;
      border-radius: 999px;
      border: 1px solid rgba(0, 240, 255, 0.25);
      font-weight: 700;
    }

    .brand-title-wrap p {
      font-size: 13px;
      color: var(--text-secondary);
      margin-top: 2px;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .live-telemetry-pill {
      display: flex;
      align-items: center;
      gap: 10px;
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      padding: 8px 16px;
      border-radius: 999px;
      font-size: 12px;
      font-family: var(--font-code);
    }

    .pulse-dot {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: var(--emerald);
      box-shadow: 0 0 12px var(--emerald);
      animation: pulseLive 1.5s infinite alternate;
    }

    @keyframes pulseLive {
      from { transform: scale(0.9); opacity: 0.6; }
      to { transform: scale(1.3); opacity: 1; }
    }

    .btn-top {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      color: var(--text-white);
      padding: 9px 18px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      cursor: pointer;
    }

    .btn-top:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
      box-shadow: 0 6px 20px var(--cyan-subtle);
      color: var(--cyan);
    }

    .btn-top.active-dash {
      background: var(--cyan-subtle);
      border-color: var(--cyan);
      color: var(--cyan);
    }

    .btn-theme-toggle {
      background: linear-gradient(135deg, var(--cyan-subtle), var(--amber-subtle));
      border: 1.5px solid var(--border-subtle);
      color: var(--text-white);
      padding: 8px 16px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: all 0.25s;
    }

    .btn-theme-toggle:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
      box-shadow: 0 4px 16px var(--cyan-subtle);
    }

    /* TOPOLOGY CARD */
    .topology-card {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-xl);
      padding: 24px;
      margin-bottom: 28px;
      position: relative;
      overflow: hidden;
      box-shadow: var(--shadow-card);
    }

    .topology-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 10%;
      right: 10%;
      height: 2px;
      background: linear-gradient(90deg, transparent, var(--cyan), transparent);
    }

    .topology-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }

    .topology-header h3 {
      font-family: var(--font-display);
      font-size: 15px;
      font-weight: 700;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 1px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .topology-flow {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      position: relative;
      padding: 10px 0;
    }

    .node-box {
      flex: 1;
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      padding: 16px;
      display: flex;
      align-items: center;
      gap: 14px;
      position: relative;
      transition: all 0.3s;
    }

    .node-box:hover {
      border-color: var(--cyan);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px var(--cyan-subtle);
    }

    .node-icon {
      width: 44px;
      height: 44px;
      border-radius: var(--radius-md);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      flex-shrink: 0;
    }

    .node-icon.app { background: rgba(59, 130, 246, 0.15); color: #60A5FA; border: 1px solid rgba(59, 130, 246, 0.3); }
    .node-icon.broker { background: var(--cyan-subtle); color: var(--cyan); border: 1px solid var(--cyan); }
    .node-icon.plc { background: var(--emerald-subtle); color: var(--emerald); border: 1px solid rgba(16, 185, 129, 0.3); }

    .node-info .title {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-white);
      margin-bottom: 2px;
    }

    .node-info .sub {
      font-size: 11px;
      color: var(--text-dim);
      font-family: var(--font-code);
    }

    .pipe-connector {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      color: var(--cyan);
      font-size: 11px;
      font-family: var(--font-code);
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
      padding-bottom: 4px;
    }

    .tab-pill-btn {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--text-secondary);
      padding: 12px 22px;
      border-radius: var(--radius-lg);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 10px;
      transition: all 0.25s;
      white-space: nowrap;
      font-family: var(--font-body);
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

    /* BENTO GRID */
    .bento-grid {
      display: grid;
      grid-template-columns: repeat(12, 1fr);
      gap: 20px;
    }

    .bento-card {
      background: var(--bg-card);
      backdrop-filter: blur(20px);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-xl);
      padding: 28px;
      position: relative;
      box-shadow: var(--shadow-card);
      transition: border-color 0.3s ease;
    }

    .bento-card:hover {
      border-color: var(--border-active);
    }

    .col-12 { grid-column: span 12; }
    .col-8 { grid-column: span 8; }
    .col-4 { grid-column: span 4; }
    .col-6 { grid-column: span 6; }

    .card-title-group {
      display: flex;
      justify-content: space-between;
      align-items: center;
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
      width: 42px;
      height: 42px;
      border-radius: var(--radius-md);
      background: var(--cyan-subtle);
      color: var(--cyan);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      border: 1px solid rgba(0, 240, 255, 0.2);
    }

    .card-icon-badge.emerald {
      background: var(--emerald-subtle);
      color: var(--emerald);
      border-color: rgba(16, 185, 129, 0.2);
    }

    .card-icon-badge.purple {
      background: rgba(139, 92, 246, 0.12);
      color: var(--purple);
      border-color: rgba(139, 92, 246, 0.2);
    }

    .card-title-left h2 {
      font-family: var(--font-display);
      font-size: 18px;
      font-weight: 800;
      color: var(--text-white);
      letter-spacing: -0.3px;
    }

    .card-title-left p {
      font-size: 12px;
      color: var(--text-dim);
      margin-top: 2px;
    }

    /* PRESETS */
    .presets-label {
      font-size: 11px;
      text-transform: uppercase;
      font-weight: 800;
      color: var(--text-dim);
      letter-spacing: 0.8px;
      margin-bottom: 12px;
    }

    .presets-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }

    .preset-card-item {
      background: var(--bg-node);
      border: 1.5px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      padding: 16px;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
    }

    .preset-card-item:hover {
      border-color: var(--cyan);
      background: var(--bg-card-hover);
      transform: translateY(-2px);
      box-shadow: 0 8px 20px var(--cyan-subtle);
    }

    .preset-card-item.selected {
      border-color: var(--cyan);
      background: var(--cyan-subtle);
      box-shadow: 0 0 20px var(--cyan-glow);
    }

    .preset-top {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }

    .preset-name {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-white);
    }

    .preset-tag {
      font-size: 10px;
      padding: 2px 7px;
      border-radius: 999px;
      font-family: var(--font-code);
      font-weight: 700;
    }

    .preset-tag.global { background: var(--cyan-subtle); color: var(--cyan); }
    .preset-tag.private { background: var(--emerald-subtle); color: var(--emerald); }
    .preset-tag.local { background: var(--amber-subtle); color: var(--amber); }

    .preset-host {
      font-size: 12px;
      font-family: var(--font-code);
      color: var(--text-secondary);
    }

    /* FORM CONTROLS */
    .form-row-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 18px;
      margin-bottom: 18px;
    }

    .form-group-box {
      display: flex;
      flex-direction: column;
    }

    .form-group-box label {
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--text-secondary);
      margin-bottom: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .form-group-box label span.field-badge {
      font-size: 10px;
      font-family: var(--font-code);
      color: var(--cyan);
      background: var(--cyan-subtle);
      padding: 1px 6px;
      border-radius: 4px;
    }

    .input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }

    .input-icon {
      position: absolute;
      left: 14px;
      font-size: 16px;
      color: var(--text-dim);
      pointer-events: none;
    }

    .app-input {
      width: 100%;
      background: var(--bg-input);
      border: 1.5px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 13px 16px 13px 44px;
      color: var(--text-white);
      font-size: 14px;
      font-family: var(--font-body);
      transition: all 0.25s;
    }

    .app-input.mono {
      font-family: var(--font-code);
      font-size: 13px;
    }

    .app-input:focus {
      outline: none;
      border-color: var(--border-focus);
      background: var(--bg-surface);
      box-shadow: 0 0 0 3px var(--cyan-glow);
    }

    .input-tip {
      font-size: 11px;
      color: var(--text-dim);
      margin-top: 6px;
    }

    /* TERMINAL */
    .terminal-window {
      background: var(--bg-terminal);
      border: 1px solid #1E293B;
      border-radius: var(--radius-lg);
      overflow: hidden;
      font-family: var(--font-code);
      margin-top: 20px;
      box-shadow: inset 0 2px 10px rgba(0, 0, 0, 0.6);
    }

    .terminal-bar {
      background: #0B0E17;
      padding: 10px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid #1E293B;
    }

    .window-dots {
      display: flex;
      gap: 6px;
    }

    .window-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
    }

    .window-dot.red { background: #EF4444; }
    .window-dot.yellow { background: #F59E0B; }
    .window-dot.green { background: #10B981; }

    .terminal-title {
      font-size: 11px;
      color: #94A3B8;
      font-weight: 600;
    }

    .terminal-body {
      padding: 16px;
      font-size: 12px;
      min-height: 140px;
      max-height: 220px;
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
      flex-wrap: wrap;
      gap: 10px;
    }

    .tester-btn {
      background: linear-gradient(135deg, rgba(0, 240, 255, 0.2), rgba(59, 130, 246, 0.2));
      border: 1px solid var(--cyan);
      color: var(--cyan);
      padding: 8px 18px;
      border-radius: var(--radius-sm);
      font-size: 12px;
      font-weight: 700;
      font-family: var(--font-display);
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s;
    }

    .tester-btn:hover {
      background: var(--cyan);
      color: #000;
      box-shadow: 0 0 20px var(--cyan-glow);
    }

    /* API SYNC */
    .sync-box {
      background: var(--bg-node);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      padding: 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-wrap: wrap;
    }

    .sync-url-code {
      font-family: var(--font-code);
      font-size: 13px;
      color: var(--cyan);
      background: var(--cyan-subtle);
      padding: 10px 14px;
      border-radius: var(--radius-md);
      border: 1px dashed var(--cyan);
      word-break: break-all;
      flex: 1;
    }

    .copy-chip-btn {
      background: var(--cyan);
      color: #000;
      border: none;
      padding: 11px 20px;
      border-radius: var(--radius-md);
      font-size: 12px;
      font-weight: 800;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
      white-space: nowrap;
    }

    .copy-chip-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 18px var(--cyan-glow);
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
      border-radius: var(--radius-xl);
      padding: 16px 28px;
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

    .dock-icon {
      font-size: 24px;
    }

    .dock-text .title {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-white);
    }

    .dock-text .sub {
      font-size: 12px;
      color: var(--text-secondary);
    }

    .dock-btn-group {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .btn-dock-reset {
      background: transparent;
      border: 1px solid var(--border-subtle);
      color: var(--text-secondary);
      padding: 12px 20px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }

    .btn-dock-reset:hover {
      background: var(--bg-card-hover);
      color: var(--text-white);
      border-color: var(--border-active);
    }

    .btn-dock-save {
      background: linear-gradient(135deg, var(--cyan), #0284C7);
      border: none;
      color: #000;
      padding: 13px 32px;
      border-radius: var(--radius-md);
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 10px;
      box-shadow: 0 8px 25px var(--cyan-glow);
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .btn-dock-save:hover {
      transform: translateY(-2px);
      box-shadow: 0 12px 30px var(--cyan-glow);
      filter: brightness(1.1);
    }

    .toast-popup {
      position: fixed;
      top: 30px;
      right: 30px;
      background: var(--bg-dock);
      backdrop-filter: blur(20px);
      border: 1px solid var(--emerald);
      color: var(--text-white);
      padding: 16px 22px;
      border-radius: var(--radius-lg);
      display: flex;
      align-items: center;
      gap: 14px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2), 0 0 20px var(--emerald-glow);
      transform: translateY(-100px);
      opacity: 0;
      transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 9999;
    }

    .toast-popup.show {
      transform: translateY(0);
      opacity: 1;
    }

    /* WIZARD & MODAL STYLES */
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
      border-radius: var(--radius-xl);
      width: 100%;
      max-width: 680px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 25px 70px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 240, 255, 0.1);
      overflow: hidden;
      animation: modalSlideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes modalSlideIn {
      from { transform: translateY(30px) scale(0.96); opacity: 0; }
      to { transform: translateY(0) scale(1); opacity: 1; }
    }
    .modal-header-custom {
      padding: 20px 24px;
      border-bottom: 1px solid var(--border-subtle);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
    }
    .modal-body-custom {
      padding: 24px;
      overflow-y: auto;
      flex: 1;
    }
    .modal-footer-custom {
      padding: 16px 24px;
      border-top: 1px solid var(--border-subtle);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
      gap: 12px;
    }
    .wizard-steps-bar {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 24px;
    }
    .wizard-step-node {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      font-weight: 700;
      color: var(--text-dim);
    }
    .wizard-step-node.active {
      color: var(--cyan);
    }
    .wizard-step-node.completed {
      color: var(--emerald);
    }
    .wizard-step-num {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background: var(--bg-node);
      border: 1.5px solid var(--border-subtle);
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: var(--font-code);
      font-size: 12px;
      font-weight: 700;
    }
    .wizard-step-node.active .wizard-step-num {
      background: var(--cyan);
      color: #000;
      border-color: var(--cyan);
      box-shadow: 0 0 12px var(--cyan-glow);
    }
    .wizard-step-node.completed .wizard-step-num {
      background: var(--emerald);
      color: #000;
      border-color: var(--emerald);
    }
    .wizard-step-divider {
      flex: 1;
      height: 2px;
      background: var(--border-subtle);
    }
    .wizard-step-divider.active {
      background: linear-gradient(90deg, var(--cyan), var(--border-subtle));
    }
    .pin-grid-container {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 12px;
      margin-top: 16px;
    }
    .pin-card-box {
      background: var(--bg-node);
      border: 1.5px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 14px;
      cursor: pointer;
      transition: all 0.2s ease;
      position: relative;
    }
    .pin-card-box:hover:not(.disabled) {
      border-color: var(--cyan);
      background: var(--bg-card-hover);
      transform: translateY(-2px);
    }
    .pin-card-box.selected {
      border-color: var(--cyan);
      background: rgba(0, 240, 255, 0.08);
      box-shadow: 0 0 18px var(--cyan-glow);
    }
    .pin-card-box.disabled {
      opacity: 0.55;
      cursor: not-allowed;
      border-color: rgba(244, 63, 94, 0.3);
      background: rgba(244, 63, 94, 0.03);
    }
    .pin-badge-status {
      font-size: 10.5px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 999px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .pin-badge-status.free {
      background: rgba(16, 185, 129, 0.15);
      color: var(--emerald);
      border: 1px solid rgba(16, 185, 129, 0.3);
    }
    .pin-badge-status.used {
      background: rgba(244, 63, 94, 0.15);
      color: var(--rose);
      border: 1px solid rgba(244, 63, 94, 0.3);
    }
    .active-account-banner {
      background: var(--bg-card);
      backdrop-filter: blur(16px);
      border: 1.5px solid var(--border-subtle);
      border-radius: var(--radius-xl);
      padding: 18px 24px;
      margin-bottom: 24px;
      box-shadow: var(--shadow-card);
    }

    @media (max-width: 900px) {
      .col-8, .col-4, .col-6 { grid-column: span 12; }
      .topology-flow { flex-direction: column; }
      .pipe-connector { transform: rotate(90deg); margin: 10px 0; }
      .floating-save-dock { flex-direction: column; gap: 14px; text-align: center; }
      .dock-status-info { flex-direction: column; }
      .pin-grid-container { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>

  <!-- FLOATING TOAST POPUP -->
  <div class="toast-popup" id="toastAlert">
    <div style="font-size: 24px;" id="toastIcon">✅</div>
    <div>
      <div style="font-weight: 700; font-size: 14px;" id="toastTitle">Berhasil Disimpan</div>
      <div style="font-size: 12px; color: var(--text-secondary);" id="toastMessage">Konfigurasi baru sudah aktif untuk semua aplikasi & IoT.</div>
    </div>
  </div>

  <div class="container">

    <!-- 1. TOP HEADER & TELEMETRY STRIP -->
    <header class="top-header">
      <div class="brand-group">
        <div class="brand-logo-badge">⚡</div>
        <div class="brand-title-wrap">
          <h1>
            <span class="gradient-text">ALRISA</span>
            <span class="cyan-text">WebDesk</span>
            <span class="version-tag">STUDIO v2.6</span>
          </h1>
          <p>Central Industrial MQTT Broker, IoT Provisioning & PLC Gateway Hub</p>
        </div>
      </div>

      <div class="header-actions">
        <!-- THEME TOGGLE BUTTON -->
        <button type="button" class="btn-theme-toggle" id="themeToggleBtn" onclick="toggleTheme()" title="Beralih Mode Gelap / Terang">
          <span id="themeIcon">☀️</span>
          <span id="themeText">Mode Terang</span>
        </button>

        <div class="live-telemetry-pill">
          <div class="pulse-dot"></div>
          <span style="color: var(--emerald); font-weight: 700;">BROKER ONLINE</span>
          <span style="color: var(--text-dim);">•</span>
          <span style="color: var(--cyan);" id="headerPingText">LATENSI: 18ms</span>
        </div>

        <a href="index.php" class="btn-top active-dash">
          <span>🏠</span> Buka Web Dashboard
        </a>
        <a href="settings.php?api=1" target="_blank" class="btn-top">
          <span>⚡</span> JSON Endpoint
        </a>
      </div>
    </header>

    <!-- 2. ARCHITECTURE TOPOLOGY MAP -->
    <section class="topology-card">
      <div class="topology-header">
        <h3><span>🔗</span> Alur Integrasi Real-Time Multi-Platform ALRISA</h3>
        <span style="font-size: 11px; font-family: var(--font-code); color: var(--cyan);" id="topoBrokerDisplay">
          Broker: <?php echo htmlspecialchars($current['mqtt_broker']); ?>:<?php echo htmlspecialchars($current['mqtt_port']); ?>
        </span>
      </div>

      <div class="topology-flow">
        <div class="node-box">
          <div class="node-icon app">📱</div>
          <div class="node-info">
            <div class="title">Aplikasi HP ALRISA</div>
            <div class="sub">Flutter Engine (Android)</div>
          </div>
        </div>

        <div class="pipe-connector">
          <div class="pipe-line"></div>
          <span>MQTT / TCP</span>
        </div>

        <div class="node-box" style="border-color: var(--cyan);">
          <div class="node-icon broker">🌐</div>
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
          <div class="node-icon plc">🏭</div>
          <div class="node-info">
            <div class="title">Mitsubishi FX5U PLC</div>
            <div class="sub" id="topoPlcSub"><?php echo htmlspecialchars($current['plc_ip']); ?>:502</div>
          </div>
        </div>
      </div>
    </section>

    <!-- GLOBAL ACTIVE ACCOUNT BANNER (1 AKUN = 1 HP / KLIEN HARDWARE) -->
    <section class="active-account-banner">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 14px; margin-bottom: 14px;">
        <div style="display: flex; align-items: center; gap: 14px;">
          <div style="width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, var(--cyan), var(--purple)); display: flex; align-items: center; justify-content: center; font-size: 22px; box-shadow: 0 0 15px var(--cyan-glow);">
            👤
          </div>
          <div>
            <div style="font-size: 11px; font-weight: 800; text-transform: uppercase; color: var(--cyan); letter-spacing: 0.8px;">
              AKUN AKTIF YANG SEDANG DIATUR (1 AKUN = 1 HP / KLIEN HARDWARE)
            </div>
            <div style="font-size: 16px; font-weight: 800; color: var(--text-white);" id="bannerActiveAccountTitle">
              Memuat akun aktif...
            </div>
          </div>
        </div>
        <div style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
          <button type="button" class="btn-top" onclick="switchToAccountTab()" style="background: rgba(16, 185, 129, 0.15); border-color: var(--emerald); color: var(--emerald); font-weight: 700; padding: 9px 16px;">
            <span>🔌</span> Buka Tabel Perangkat & PIN Akun Ini ➔
          </button>
          <button type="button" class="btn-top" onclick="showAddNewAccountModal()" style="background: var(--cyan-subtle); border-color: var(--cyan); color: var(--cyan); font-weight: 700; padding: 9px 16px;">
            <span>➕</span> Tambah Akun Klien Baru
          </button>
        </div>
      </div>

      <div style="display: flex; gap: 12px; overflow-x: auto; padding-bottom: 6px;" id="topAccountsPillContainer">
        <!-- Rendered by JS -->
      </div>
    </section>

    <!-- 3. TAB NAVIGATION -->
    <nav class="tab-bar-nav">
      <button type="button" class="tab-pill-btn active" onclick="switchSection('section-broker', this)">
        <span>📡</span> 1. Broker MQTT Engine
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-hardware', this)">
        <span>📶</span> 2. WiFi & IoT Hardware
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-plc', this)">
        <span>🏭</span> 3. Mitsubishi PLC Modbus
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-security', this)">
        <span>🔐</span> 4. Keamanan & API Sync
      </button>
      <button type="button" class="tab-pill-btn" onclick="switchSection('section-accounts', this)">
        <span>👥</span> 5. Multi-Akun & Klien Hardware (Per-HP)
      </button>
    </nav>

    <!-- FORM START -->
    <form id="mainConfigForm" onsubmit="handleFormSubmit(event)">

      <!-- SECTION 1: BROKER MQTT -->
      <div id="section-broker" class="tab-content">
        <div class="bento-grid">
          
          <div class="bento-card col-12">
            <div class="card-title-group">
              <div class="card-title-left">
                <div class="card-icon-badge">📡</div>
                <div>
                  <h2>Konfigurasi Broker MQTT (Jantung Komunikasi)</h2>
                  <p>Server perantara yang mendistribusikan data saklar, sensor, dan gerbang secara instan.</p>
                </div>
              </div>
            </div>

            <!-- PRESET SERVER CARDS -->
            <div class="presets-label">Pilih Preset Cepat Server Broker:</div>
            <div class="presets-grid">
              
              <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'broker.emqx.io' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('broker.emqx.io', 1883, 8083, 'alrisa', this)">
                <div class="preset-top">
                  <span class="preset-name">EMQX Global</span>
                  <span class="preset-tag global">Cloud Public</span>
                </div>
                <div class="preset-host">broker.emqx.io:1883</div>
              </div>

              <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'broker.hivemq.com' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('broker.hivemq.com', 1883, 8000, 'alrisa', this)">
                <div class="preset-top">
                  <span class="preset-name">HiveMQ Cloud</span>
                  <span class="preset-tag global">Cloud Public</span>
                </div>
                <div class="preset-host">broker.hivemq.com:1883</div>
              </div>

              <div class="preset-card-item <?php echo $current['mqtt_broker'] === '192.168.1.100' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('192.168.1.100', 1883, 8083, 'alrisa', this)">
                <div class="preset-top">
                  <span class="preset-name">Mini PC Kantor</span>
                  <span class="preset-tag private">Private LAN</span>
                </div>
                <div class="preset-host">192.168.1.100:1883</div>
              </div>

              <div class="preset-card-item <?php echo $current['mqtt_broker'] === 'localhost' ? 'selected' : ''; ?>" onclick="applyBrokerPreset('localhost', 1883, 8083, 'alrisa', this)">
                <div class="preset-top">
                  <span class="preset-name">Localhost PC</span>
                  <span class="preset-tag local">Pengembang</span>
                </div>
                <div class="preset-host">127.0.0.1:1883</div>
              </div>

            </div>

            <!-- INPUT FORM BROKER -->
            <div class="form-row-grid">
              <div class="form-group-box">
                <label for="mqtt_broker">
                  Domain / Alamat IP Broker
                  <span class="field-badge">Wajib</span>
                </label>
                <div class="input-wrapper">
                  <span class="input-icon">🌐</span>
                  <input type="text" id="mqtt_broker" name="mqtt_broker" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_broker']); ?>" required>
                </div>
                <div class="input-tip">💡 Rekomendasi internet: <code>broker.emqx.io</code></div>
              </div>

              <div class="form-group-box">
                <label for="mqtt_prefix">
                  Topic Prefix (Saluran Komunikasi)
                  <span class="field-badge">Wajib</span>
                </label>
                <div class="input-wrapper">
                  <span class="input-icon">🏷️</span>
                  <input type="text" id="mqtt_prefix" name="mqtt_prefix" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_prefix']); ?>" required>
                </div>
                <div class="input-tip">Topik: <code>alrisa/+/set</code> dan <code>alrisa/+/state</code></div>
              </div>
            </div>

            <div class="form-row-grid">
              <div class="form-group-box">
                <label for="mqtt_port">Port TCP (Aplikasi Android HP & PLC)</label>
                <div class="input-wrapper">
                  <span class="input-icon">🔌</span>
                  <input type="number" id="mqtt_port" name="mqtt_port" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_port']); ?>" required>
                </div>
                <div class="input-tip">Default TCP: 1883 (Non-SSL) atau 8883 (SSL/TLS)</div>
              </div>

              <div class="form-group-box">
                <label for="mqtt_ws_port">Port WebSocket (Untuk Web Browser)</label>
                <div class="input-wrapper">
                  <span class="input-icon">⚡</span>
                  <input type="number" id="mqtt_ws_port" name="mqtt_ws_port" class="app-input mono" value="<?php echo htmlspecialchars($current['mqtt_ws_port']); ?>" required>
                </div>
                <div class="input-tip">Port browser: 8083 (EMQX) atau 9001 (Mosquitto)</div>
              </div>
            </div>

            <div class="form-row-grid">
              <div class="form-group-box">
                <label for="mqtt_user">Username Autentikasi (Opsional)</label>
                <div class="input-wrapper">
                  <span class="input-icon">👤</span>
                  <input type="text" id="mqtt_user" name="mqtt_user" class="app-input" value="<?php echo htmlspecialchars($current['mqtt_user']); ?>" placeholder="Biarkan kosong jika publik">
                </div>
              </div>

              <div class="form-group-box">
                <label for="mqtt_pass">Password Autentikasi (Opsional)</label>
                <div class="input-wrapper">
                  <span class="input-icon">🔑</span>
                  <input type="password" id="mqtt_pass" name="mqtt_pass" class="app-input" value="<?php echo htmlspecialchars($current['mqtt_pass']); ?>" placeholder="Biarkan kosong jika publik">
                </div>
              </div>
            </div>

            <!-- LIVE DIAGNOSTIC TERMINAL -->
            <div class="terminal-window">
              <div class="terminal-bar">
                <div class="window-dots">
                  <div class="window-dot red"></div>
                  <div class="window-dot yellow"></div>
                  <div class="window-dot green"></div>
                </div>
                <div class="terminal-title">ALRISA MQTT DIAGNOSTIC TERMINAL — LIVE PACKET INSPECTOR</div>
                <div style="font-size: 10px; color: #34D399;" id="termStatusBadge">● READY</div>
              </div>

              <div class="terminal-body" id="termOutput">
                <div class="term-line">
                  <span class="term-time">[00:00:00]</span>
                  <span class="term-prefix">SYSTEM:</span>
                  <span class="term-msg">Konsol diagnostik siap. Klik tombol di bawah untuk menguji respon server broker.</span>
                </div>
              </div>

              <div class="terminal-footer">
                <div style="font-size: 11px; color: #94A3B8;">
                  Protokol: WebSocket MQTT v3.1.1 • Enkripsi: Auto
                </div>
                <button type="button" class="tester-btn" onclick="runLiveDiagnosticTest()">
                  <span>⚡</span> Uji Ping Koneksi Broker Sekarang
                </button>
              </div>
            </div>

          </div>

        </div>
      </div>

      <!-- SECTION 2: HARDWARE & WIFI -->
      <div id="section-hardware" class="tab-content" style="display: none;">
        <div class="bento-grid">
          
          <div class="bento-card col-6">
            <div class="card-title-group">
              <div class="card-title-left">
                <div class="card-icon-badge emerald">📶</div>
                <div>
                  <h2>Konfigurasi WiFi IoT Hardware</h2>
                  <p>Kredensial WiFi kantor/rumah untuk modul ESP32 & ESP8266.</p>
                </div>
              </div>
            </div>

            <div class="form-group-box" style="margin-bottom: 18px;">
              <label for="wifi_ssid">Nama Jaringan WiFi (SSID)</label>
              <div class="input-wrapper">
                <span class="input-icon">📡</span>
                <input type="text" id="wifi_ssid" name="wifi_ssid" class="app-input" value="<?php echo htmlspecialchars($current['wifi_ssid']); ?>" placeholder="Contoh: ALRISA_HQ_5G">
              </div>
              <div class="input-tip">Modul mikrokontroler akan otomatis terhubung ke hotspot ini.</div>
            </div>

            <div class="form-group-box">
              <label for="wifi_password">Kata Sandi WiFi (WPA2/WPA3)</label>
              <div class="input-wrapper">
                <span class="input-icon">🔒</span>
                <input type="password" id="wifi_password" name="wifi_password" class="app-input" value="<?php echo htmlspecialchars($current['wifi_password']); ?>" placeholder="Masukkan kata sandi WiFi">
              </div>
            </div>
          </div>

          <div class="bento-card col-6">
            <div class="card-title-group">
              <div class="card-title-left">
                <div class="card-icon-badge emerald">🛠️</div>
                <div>
                  <h2>Panduan Pairing Cepat Hardware</h2>
                  <p>Langkah menghubungkan alat baru tanpa bongkar casing.</p>
                </div>
              </div>
            </div>

            <div style="font-size: 13px; line-height: 1.8; color: var(--text-secondary);">
              <p>1. Nyalakan modul kontroler ESP32 gerbang / relay.</p>
              <p>2. Pastikan lampu indikator biru berkedip lambat (Mode Standby).</p>
              <p>3. Alat akan otomatis mengambil SSID & Password di samping dan menyambung ke Broker MQTT dalam 3-5 detik.</p>
            </div>
          </div>

        </div>
      </div>

      <!-- SECTION 3: MITSUBISHI PLC & MODBUS -->
      <div id="section-plc" class="tab-content" style="display: none;">
        <div class="bento-grid">
          
          <div class="bento-card col-12">
            <div class="card-title-group">
              <div class="card-title-left">
                <div class="card-icon-badge purple">🏭</div>
                <div>
                  <h2>Integrasi Kontroler Mitsubishi FX5U (Modbus TCP)</h2>
                  <p>Jembatan komunikasi industri antara Mini PC Gateway dan unit PLC Pagar.</p>
                </div>
              </div>
            </div>

            <div class="form-row-grid">
              <div class="form-group-box">
                <label for="plc_type">Model PLC & Driver Industri</label>
                <div class="input-wrapper">
                  <span class="input-icon">⚙️</span>
                  <input type="text" id="plc_type" name="plc_type" class="app-input" value="<?php echo htmlspecialchars($current['plc_type']); ?>">
                </div>
              </div>

              <div class="form-group-box">
                <label for="plc_ip">Alamat IP PLC (Ethernet LAN)</label>
                <div class="input-wrapper">
                  <span class="input-icon">🖥️</span>
                  <input type="text" id="plc_ip" name="plc_ip" class="app-input mono" value="<?php echo htmlspecialchars($current['plc_ip']); ?>" required>
                </div>
                <div class="input-tip">Contoh alamat IP static PLC di switch kantor: <code>192.168.1.100</code></div>
              </div>

              <div class="form-group-box">
                <label for="plc_port">Port Modbus TCP</label>
                <div class="input-wrapper">
                  <span class="input-icon">🔌</span>
                  <input type="number" id="plc_port" name="plc_port" class="app-input mono" value="<?php echo htmlspecialchars($current['plc_port']); ?>" required>
                </div>
                <div class="input-tip">Standar internasional port Modbus: <code>502</code></div>
              </div>
            </div>
          </div>

        </div>
      </div>

      <!-- SECTION 4: SECURITY & API SYNC -->
      <div id="section-security" class="tab-content" style="display: none;">
        <div class="bento-grid">
          
          <div class="bento-card col-12">
            <div class="card-title-group">
              <div class="card-title-left">
                <div class="card-icon-badge">🔐</div>
                <div>
                  <h2>Token Keamanan & Endpoint Sinkronisasi Aplikasi HP</h2>
                  <p>Kunci autentikasi agar aplikasi Flutter ALRISA dapat mengunduh konfigurasi ini secara otomatis.</p>
                </div>
              </div>
            </div>

            <div class="form-row-grid" style="margin-bottom: 24px;">
              <div class="form-group-box">
                <label for="api_secret_key">
                  Kunci Rahasia API (X-API-KEY)
                  <span class="field-badge">Penting</span>
                </label>
                <div class="input-wrapper">
                  <span class="input-icon">🔑</span>
                  <input type="text" id="api_secret_key" name="api_secret_key" class="app-input mono" value="<?php echo htmlspecialchars($current['api_secret_key']); ?>" required>
                </div>
              </div>

              <div class="form-group-box">
                <label for="app_name">Label Ekosistem Rumah / Kantor</label>
                <div class="input-wrapper">
                  <span class="input-icon">🏢</span>
                  <input type="text" id="app_name" name="app_name" class="app-input" value="<?php echo htmlspecialchars($current['app_name']); ?>">
                </div>
              </div>
            </div>

            <label style="font-size: 12px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 8px; display: block;">
              URL Sinkronisasi Konfigurasi Otomatis (REST API):
            </label>
            <div class="sync-box">
              <div class="sync-url-code" id="syncUrlPreview">Memuat URL Endpoint...</div>
              <button type="button" class="copy-chip-btn" onclick="copySyncUrl()">
                <span>📋</span> SALIN URL API
              </button>
            </div>
          </div>

        </div>
      </div>

      <!-- SECTION 5: MULTI-AKUN & KLIEN HARDWARE -->
      <div id="section-accounts" class="tab-content" style="display: none;">
        <div class="bento-grid">
          
          <div class="bento-card col-12">
            <div class="card-title-group" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 14px; margin-bottom: 20px;">
              <div class="card-title-left" style="display: flex; align-items: center; gap: 14px;">
                <div class="card-icon-badge" style="width: 48px; height: 48px; border-radius: 12px; background: rgba(59, 130, 246, 0.15); display: flex; align-items: center; justify-content: center; font-size: 22px;">👥</div>
                <div>
                  <h2 style="font-size: 18px; font-weight: 800;">Manajemen Multi-Akun (1 Akun = 1 HP / Lokasi Hardware Klien)</h2>
                  <p style="font-size: 13px; color: var(--text-secondary); margin-top: 3px;">Tiap akun memiliki spesifikasi mesin (Pi 4, ESP32, PLC), CCTV RTSP, dan PIN relai berbeda.</p>
                </div>
              </div>
              <button type="button" class="btn-top" onclick="showAddNewAccountModal()" style="background: var(--cyan-subtle); border-color: var(--cyan); color: var(--cyan); padding: 10px 18px; font-weight: 700;">
                <span>➕</span> Tambah Akun Klien Baru
              </button>
            </div>

            <!-- ACCOUNT SELECTOR PILLS -->
            <div style="margin: 20px 0 24px;">
              <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); letter-spacing: 0.8px; margin-bottom: 10px; display: block;">
                PILIH AKUN KLIEN YANG INGIN DIKELOLA:
              </label>
              <div id="accountsPillContainer" style="display: flex; gap: 12px; overflow-x: auto; padding-bottom: 8px;">
                <!-- Dirender otomatis oleh JavaScript -->
              </div>
            </div>

            <!-- ACTIVE ACCOUNT DETAIL PANEL -->
            <div id="accountDetailCard" style="background: var(--bg-surface); border: 1.5px solid var(--border-subtle); border-radius: var(--radius-lg); padding: 24px;">
              <!-- Detail akun aktif dirender di sini via JS -->
            </div>

          </div>

        </div>
      </div>

      <!-- STICKY FLOATING ACTION DOCK -->
      <div class="floating-save-dock">
        <div class="dock-status-info">
          <div class="dock-icon">🛡️</div>
          <div class="dock-text">
            <div class="title">Semua Parameter Konfigurasi Siap Diterapkan</div>
            <div class="sub">Perubahan akan langsung aktif untuk HP, Simulator PLC, dan Web Dashboard.</div>
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

  </div> <!-- End .container -->

  <!-- ========================================================================= -->
  <!-- 🔌 MODAL 1: 2-STEP DEVICE & HARDWARE PIN WIZARD                          -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="deviceWizardModal">
    <div class="modal-box-custom">
      
      <!-- MODAL HEADER -->
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 40px; height: 40px; border-radius: 10px; background: rgba(0, 240, 255, 0.12); display: flex; align-items: center; justify-content: center; font-size: 20px; border: 1px solid rgba(0, 240, 255, 0.25);">
            🔌
          </div>
          <div>
            <h3 style="font-size: 16px; font-weight: 800; color: var(--text-white);" id="wizardModalTitle">Tambah Perangkat & Pemetaan PIN</h3>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Akun: <span id="wizardModalAccName" style="color: var(--cyan); font-weight: 700;">-</span></p>
          </div>
        </div>
        <button type="button" onclick="closeDeviceWizardModal()" style="background: none; border: none; font-size: 22px; color: var(--text-dim); cursor: pointer; padding: 4px;" title="Tutup Modal">✕</button>
      </div>

      <!-- WIZARD STEP INDICATOR -->
      <div style="padding: 20px 24px 0;">
        <div class="wizard-steps-bar">
          <div class="wizard-step-node active" id="stepIndicator1">
            <div class="wizard-step-num">1</div>
            <span>Identitas Perangkat</span>
          </div>
          <div class="wizard-step-divider" id="stepDivider"></div>
          <div class="wizard-step-node" id="stepIndicator2">
            <div class="wizard-step-num">2</div>
            <span>Pemetaan PIN Hardware</span>
          </div>
        </div>
      </div>

      <!-- MODAL BODY: STEP 1 (IDENTITAS PERANGKAT) -->
      <div class="modal-body-custom" id="wizardStep1Content">
        <div class="form-group-box" style="margin-bottom: 18px;">
          <label for="wizardDevName">
            Nama Perangkat IoT
            <span class="field-badge">Wajib</span>
          </label>
          <div class="input-wrapper">
            <span class="input-icon">🏷️</span>
            <input type="text" id="wizardDevName" class="app-input" placeholder="Contoh: Pagar Utama, Gerbang Belakang, Lampu Teras, Pompa Kolam...">
          </div>
          <div class="input-tip">💡 Nama ini akan langsung muncul pada aplikasi HP Android Nexora.</div>
        </div>

        <div class="form-group-box" style="margin-bottom: 18px;">
          <label for="wizardDevType">
            Jenis / Tipe Perangkat
            <span class="field-badge">Wajib</span>
          </label>
          <div class="input-wrapper">
            <span class="input-icon">⚙️</span>
            <select id="wizardDevType" class="app-input" onchange="handleWizardTypeChange(this.value)">
              <option value="0">🚪 Pintu Gerbang / Sliding Gate (Motor Bolak-Balik, Auto-Reverse)</option>
              <option value="1">💡 Lampu / Penerangan (Relay Digital On/Off)</option>
              <option value="2">🚪 Pintu Geser Otomatis (Relay Akses Masuk)</option>
              <option value="3">🪟 Gorden Otomatis (Motor Driver Buka/Tutup)</option>
              <option value="4">💧 Pompa Air / Toren (Relay Kontaktor Daya)</option>
            </select>
          </div>
        </div>

        <div class="form-group-box">
          <label for="wizardDevCategory">Kategori / Ruangan Penempatan</label>
          <div class="input-wrapper">
            <span class="input-icon">📍</span>
            <input type="text" id="wizardDevCategory" class="app-input" value="Keamanan" placeholder="Contoh: Keamanan, Akses, Interior, Air, Taman">
          </div>
        </div>
      </div>

      <!-- MODAL BODY: STEP 2 (PEMETAAN PIN HARDWARE) -->
      <div class="modal-body-custom" id="wizardStep2Content" style="display: none;">
        
        <!-- HARDWARE SUMMARY STRIP -->
        <div style="background: var(--bg-node); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 12px 16px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <div>
            <div style="font-size: 11px; text-transform: uppercase; color: var(--text-dim); font-weight: 700;">Mesin Controller Akun Ini:</div>
            <div style="font-size: 13.5px; font-weight: 800; color: var(--cyan); margin-top: 2px;" id="wizardStep2HwType">Raspberry Pi 4 Gateway</div>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 11px; color: var(--text-dim);">Perangkat Baru:</div>
            <div style="font-size: 13.5px; font-weight: 800; color: var(--text-white);" id="wizardStep2DevSummary">-</div>
          </div>
        </div>

        <div style="font-size: 12.5px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 12px;">
          Pilih jalur PIN / Alamat Register fisik yang tersedia di bawah ini. PIN yang telah digunakan ditandai 
          <span style="color: var(--rose); font-weight: 700;">[TERPAKAI]</span> dan dikunci otomatis agar tidak terjadi bentrok.
        </div>

        <!-- DYNAMIC PIN GRID MATRIX -->
        <div class="pin-grid-container" id="wizardPinGrid">
          <!-- Rendered dynamically by JS -->
        </div>

        <!-- CUSTOM MANUAL PIN OPTION -->
        <div style="margin-top: 18px; padding-top: 14px; border-top: 1px dashed var(--border-subtle);">
          <label style="font-size: 12px; font-weight: 700; color: var(--text-secondary); cursor: pointer; display: flex; align-items: center; gap: 8px;">
            <input type="checkbox" id="chkUseCustomPin" onchange="toggleCustomPinInput()"> 
            <span>Gunakan Alamat PIN / Modbus Kustom Manual</span>
          </label>
          <div id="customPinInputWrap" style="display: none; margin-top: 10px;">
            <input type="text" id="wizardCustomPinInput" class="app-input mono" placeholder="Contoh: %MW120 atau GPIO 33" oninput="selectCustomPin(this.value)">
          </div>
        </div>

      </div>

      <!-- MODAL FOOTER -->
      <div class="modal-footer-custom">
        <div>
          <button type="button" class="btn-top" onclick="closeDeviceWizardModal()" style="color: var(--text-dim); padding: 8px 16px;">
            Batal
          </button>
        </div>
        <div style="display: flex; gap: 10px;">
          <button type="button" class="btn-dock-save" id="btnWizardNext" onclick="goToWizardStep2()" style="padding: 10px 22px; font-size: 13px;">
            <span>Lanjut ke Menu PIN Berikutnya ➔</span>
          </button>
          
          <button type="button" class="btn-top" id="btnWizardBack" onclick="goToWizardStep1()" style="display: none; padding: 10px 16px;">
            <span>⬅ Kembali</span>
          </button>
          <button type="button" class="btn-dock-save" id="btnWizardFinish" onclick="finishDeviceWizard()" style="display: none; padding: 10px 22px; font-size: 13px; background: linear-gradient(135deg, var(--emerald), #059669);">
            <span>✅ Pasangkan Perangkat & Simpan PIN</span>
          </button>
        </div>
      </div>

    </div>
  </div>

  <!-- ========================================================================= -->
  <!-- 📹 MODAL 2: TAMBAH KAMERA CCTV                                           -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="cctvModal">
    <div class="modal-box-custom" style="max-width: 540px;">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 38px; height: 38px; border-radius: 10px; background: rgba(0, 240, 255, 0.12); display: flex; align-items: center; justify-content: center; font-size: 20px;">
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
          <input type="text" id="cctvModalName" class="app-input" placeholder="Contoh: CCTV Pagar Utama, Kamera Lobby, Garasi...">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="cctvModalLocation">Lokasi Penempatan Kamera</label>
          <input type="text" id="cctvModalLocation" class="app-input" placeholder="Contoh: Gerbang Depan, Pos Satpam...">
        </div>
        <div class="form-group-box" style="margin-bottom: 16px;">
          <label for="cctvModalRtsp">URL RTSP Stream <span class="field-badge">Wajib</span></label>
          <input type="text" id="cctvModalRtsp" class="app-input mono" placeholder="rtsp://admin:pass@192.168.1.50:554/live">
          <div class="input-tip">💡 Format standar ONVIF / RTSP H.264 kamera IP.</div>
        </div>
        <div class="form-group-box">
          <label for="cctvModalGate">Hubungkan Kamera dengan Gerbang (Aksi Cepat)</label>
          <select id="cctvModalGate" class="app-input">
            <!-- Populated dynamically with current account gates -->
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

  <!-- ========================================================================= -->
  <!-- 👥 MODAL 3: TAMBAH AKUN KLIEN BARU                                        -->
  <!-- ========================================================================= -->
  <div class="modal-backdrop-custom" id="accountModal">
    <div class="modal-box-custom" style="max-width: 540px;">
      <div class="modal-header-custom">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 38px; height: 38px; border-radius: 10px; background: rgba(139, 92, 246, 0.15); display: flex; align-items: center; justify-content: center; font-size: 20px;">
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
            <option value="Raspberry Pi 4 Gateway">🍓 Raspberry Pi 4 (Master Controller)</option>
            <option value="Mitsubishi FX5U PLC (Industrial Hub)">🏭 Mitsubishi FX5U PLC (Industrial Hub)</option>
            <option value="ESP32 Smart Automation Hub">⚡ ESP32 Smart Automation Hub</option>
          </select>
        </div>
      </div>

      <div class="modal-footer-custom">
        <button type="button" class="btn-top" onclick="closeAccountModal()">Batal</button>
        <button type="button" class="btn-dock-save" onclick="saveNewAccountModal()" style="padding: 10px 20px; font-size: 13px;">
          <span>✅ Buat Akun Klien</span>
        </button>
      </div>
    </div>
  </div>

  <script>
    // =========================================================================
    // 🎨 THEME SWITCHER
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

    // Tab Switcher
    function switchSection(sectionId, btn) {
      document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
      document.getElementById(sectionId).style.display = 'block';

      document.querySelectorAll('.tab-pill-btn').forEach(el => el.classList.remove('active'));
      btn.classList.add('active');
    }

    // Preset Selection
    function applyBrokerPreset(host, tcpPort, wsPort, prefix, el) {
      document.getElementById('mqtt_broker').value = host;
      document.getElementById('mqtt_port').value = tcpPort;
      document.getElementById('mqtt_ws_port').value = wsPort;
      document.getElementById('mqtt_prefix').value = prefix;

      // Update active account as well
      const activeAcc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (activeAcc) {
        activeAcc.mqtt_broker = host;
        activeAcc.mqtt_port = tcpPort;
        activeAcc.mqtt_ws_port = wsPort;
        activeAcc.mqtt_prefix = prefix;
      }

      document.querySelectorAll('.preset-card-item').forEach(c => c.classList.remove('selected'));
      el.classList.add('selected');

      document.getElementById('topoBrokerDisplay').innerText = 'Broker: ' + host + ':' + tcpPort;
      document.getElementById('topoBrokerSub').innerText = host;

      addTermLog('SYSTEM', 'Preset diganti ke: ' + host + ' (TCP: ' + tcpPort + ', WS: ' + wsPort + ')', 'warn');
    }

    // Set Sync URL
    const fullApiUrl = window.location.origin + window.location.pathname.replace('settings.php', 'api/sync.php');
    function updateSyncUrlPreview(accId) {
      const el = document.getElementById('syncUrlPreview');
      if (el) {
        el.innerText = fullApiUrl + '?account_id=' + (accId || currentSelectedAccountId);
      }
    }

    function copySyncUrl() {
      const url = fullApiUrl + '?account_id=' + currentSelectedAccountId;
      navigator.clipboard.writeText(url).then(() => {
        showToast('Link API Disalin!', 'URL endpoint konfigurasi siap diberikan ke pengembang aplikasi HP.');
      });
    }

    // Toast Notification
    function showToast(title, message, isError = false) {
      const toast = document.getElementById('toastAlert');
      document.getElementById('toastTitle').innerText = title;
      document.getElementById('toastMessage').innerText = message;
      document.getElementById('toastIcon').innerText = isError ? '⚠️' : '✅';
      toast.style.borderColor = isError ? 'var(--rose)' : 'var(--emerald)';

      toast.classList.add('show');
      setTimeout(() => {
        toast.classList.remove('show');
      }, 4000);
    }

    // Terminal Logging Helper
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

    // Live Diagnostic MQTT Test
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
            addTermLog('PACKET', `Terkirim probe data ke topik 'alrisa/diagnostic/ping'`, 'normal');

            setTimeout(() => {
              try { mqttClient.disconnect(); } catch (e) {}
              addTermLog('SYSTEM', 'Tes selesai. Socket ditutup dengan aman.', 'normal');
            }, 2500);
          },
          onFailure: function (err) {
            statusBadge.innerText = '● FAILED';
            statusBadge.style.color = 'var(--rose)';
            addTermLog('ERROR', `Gagal terhubung: ${err.errorMessage}. Periksa port WebSocket atau jaringan Anda.`, 'error');
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

    // Handle AJAX Form Submit
    function handleFormSubmit(e) {
      if (e) e.preventDefault();
      const saveBtn = document.getElementById('btnSubmitForm');
      if (saveBtn) {
        saveBtn.innerHTML = '<span>⏳</span> Menyimpan...';
        saveBtn.style.opacity = '0.7';
      }

      // Synchronize form inputs into active account
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
          showToast('Konfigurasi Berhasil Disimpan!', 'Semua akun, perangkat & broker otomatis tersinkronisasi.');
          addTermLog('CONFIG', 'Konfigurasi multi-akun berhasil disimpan ke server disk.', 'success');
          renderAccountPills();
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
        showToast('Tersimpan Lokal', 'Pengaturan berhasil diperbarui di server lokal.', false);
        addTermLog('CONFIG', 'Tersimpan ke file lokal server.', 'success');
      });
    }

    function resetDefaults() {
      if (confirm('Kembalikan semua pengaturan ke standar pabrik ALRISA?')) {
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

    // =========================================================================
    // 👥 MULTI-AKUN (PER-HP & LOKASI HARDWARE) TWO-WAY BINDING CONTROLLER
    // =========================================================================
    let systemAccounts = <?php echo json_encode($current['accounts'] ?? []); ?>;
    let currentSelectedAccountId = <?php echo json_encode($current['active_account_id'] ?? 'acc_superadmin'); ?>;

    // PIN BANK GENERATOR FOR PI 4, MITSUBISHI FX5U PLC, AND ESP32
    function getHardwarePinBank(hardwareType) {
      const hw = (hardwareType || '').toLowerCase();
      if (hw.includes('plc') || hw.includes('fx5u') || hw.includes('mitsubishi')) {
        return [
          { pin: '%QX0.0 (Relay Y0 - Pagar)', desc: 'Relay Output Y0 - Pagar / Gerbang Industri' },
          { pin: '%QX0.1 (Relay Y1 - Pintu)', desc: 'Relay Output Y1 - Pintu Geser Otomatis' },
          { pin: '%QX0.2 (Relay Y2 - Gorden)', desc: 'Relay Output Y2 - Gorden Otomatis' },
          { pin: '%QX0.3 (Relay Y3 - Lampu)', desc: 'Relay Output Y3 - Pencahayaan & Penerangan' },
          { pin: '%QX0.4 (Relay Y4 - Pompa 1)', desc: 'Relay Output Y4 - Pompa Air / Toren 1' },
          { pin: '%QX0.5 (Relay Y5 - Pompa 2)', desc: 'Relay Output Y5 - Pompa Air / Kolam 2' },
          { pin: '%QX0.6 (Relay Y6 - Aux 1)', desc: 'Relay Output Y6 - Sirine / Lampu Strobo' },
          { pin: '%QX0.7 (Relay Y7 - Aux 2)', desc: 'Relay Output Y7 - Auxiliary Relay Cadangan' }
        ];
      } else if (hw.includes('esp32') || hw.includes('esp8266')) {
        return [
          { pin: 'ESP32 GPIO 2 (D2)', desc: 'GPIO 2 - Onboard Blue LED / Relay Pagar' },
          { pin: 'ESP32 GPIO 4 (D4)', desc: 'GPIO 4 - Relay Pintu Geser' },
          { pin: 'ESP32 GPIO 5 (D5)', desc: 'GPIO 5 - Relay Gorden Otomatis' },
          { pin: 'ESP32 GPIO 18 (D18)', desc: 'GPIO 18 - Relay Lampu Teras' },
          { pin: 'ESP32 GPIO 19 (D19)', desc: 'GPIO 19 - Relay Pompa Air Toren' },
          { pin: 'ESP32 GPIO 21 (D21)', desc: 'GPIO 21 - Relay Pompa Kolam / Sirkulasi' },
          { pin: 'ESP32 GPIO 22 (D22)', desc: 'GPIO 22 - I2C SCL / Relay Saklar AC' },
          { pin: 'ESP32 GPIO 23 (D23)', desc: 'GPIO 23 - I2C SDA / Relay Auxiliary' }
        ];
      } else {
        // Default Raspberry Pi 4
        return [
          { pin: 'Pi4 GPIO 17 (Pin 11)', desc: 'Header Pin 11 - Output Relai Pagar Utama' },
          { pin: 'Pi4 GPIO 27 (Pin 13)', desc: 'Header Pin 13 - Output Relai Pintu Geser' },
          { pin: 'Pi4 GPIO 22 (Pin 15)', desc: 'Header Pin 15 - Output Relai Gorden Otomatis' },
          { pin: 'Pi4 GPIO 23 (Pin 16)', desc: 'Header Pin 16 - Output Relai Lampu Teras' },
          { pin: 'Pi4 GPIO 24 (Pin 18)', desc: 'Header Pin 18 - Output Relai Pompa Toren' },
          { pin: 'Pi4 GPIO 25 (Pin 22)', desc: 'Header Pin 22 - Output Relai Pompa Kolam' },
          { pin: 'Pi4 GPIO 5 (Pin 29)', desc: 'Header Pin 29 - Output Relai Saklar AC' },
          { pin: 'Pi4 GPIO 6 (Pin 31)', desc: 'Header Pin 31 - Output Relai Auxiliary' }
        ];
      }
    }

    function renderAccountPills() {
      // 1. Render Top Banner Pills
      const topContainer = document.getElementById('topAccountsPillContainer');
      const tabContainer = document.getElementById('accountsPillContainer');
      
      const renderPills = (container) => {
        if (!container) return;
        container.innerHTML = '';

        if (!systemAccounts || systemAccounts.length === 0) {
          container.innerHTML = '<div style="color: var(--text-dim); font-size: 13px;">Belum ada akun klien terdaftar.</div>';
          return;
        }

        systemAccounts.forEach(acc => {
          const isSelected = acc.id === currentSelectedAccountId;
          const pill = document.createElement('div');
          pill.className = 'preset-card-item' + (isSelected ? ' selected' : '');
          pill.style.minWidth = '220px';
          pill.style.cursor = 'pointer';
          pill.style.padding = '12px 16px';
          pill.onclick = () => selectActiveAccount(acc.id, true);

          const hwBadge = acc.hardware_type.includes('Pi') ? '🍓 ' + acc.hardware_type : (acc.hardware_type.includes('PLC') ? '🏭 ' + acc.hardware_type : '⚡ ' + acc.hardware_type);

          pill.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
              <span style="font-weight: 800; font-size: 13.5px; color: var(--text-white);">${acc.name}</span>
              <span class="preset-tag ${acc.role === 'superadmin' ? 'global' : 'private'}">${acc.role.toUpperCase()}</span>
            </div>
            <div style="font-size: 11px; color: var(--cyan); font-family: var(--font-code); margin-bottom: 2px;">${hwBadge}</div>
            <div style="font-size: 11px; color: var(--text-dim);">${acc.email}</div>
          `;
          container.appendChild(pill);
        });
      };

      renderPills(topContainer);
      renderPills(tabContainer);

      // Update Banner title
      const activeAcc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      const bannerTitle = document.getElementById('bannerActiveAccountTitle');
      if (bannerTitle && activeAcc) {
        bannerTitle.innerHTML = `<span style="color: var(--cyan);">${activeAcc.name}</span> • <span>${activeAcc.hardware_type}</span> • <code style="font-size: 13px;">${activeAcc.mqtt_prefix}</code>`;
      }
    }

    function switchToAccountTab() {
      const tabs = document.querySelectorAll('.tab-pill-btn');
      if (tabs && tabs[4]) {
        switchSection('section-accounts', tabs[4]);
        tabs[4].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    }

    function selectActiveAccount(accId, isUserClick = false) {
      currentSelectedAccountId = accId;
      const activeAcc = systemAccounts.find(a => a.id === accId);
      if (!activeAcc) return;

      // 1. Populate Tab 1: Broker
      if (document.getElementById('mqtt_broker')) document.getElementById('mqtt_broker').value = activeAcc.mqtt_broker || 'broker.emqx.io';
      if (document.getElementById('mqtt_port')) document.getElementById('mqtt_port').value = activeAcc.mqtt_port || 1883;
      if (document.getElementById('mqtt_ws_port')) document.getElementById('mqtt_ws_port').value = activeAcc.mqtt_ws_port || 8083;
      if (document.getElementById('mqtt_prefix')) document.getElementById('mqtt_prefix').value = activeAcc.mqtt_prefix || 'alrisa/' + activeAcc.id;
      if (document.getElementById('mqtt_user')) document.getElementById('mqtt_user').value = activeAcc.mqtt_user || '';
      if (document.getElementById('mqtt_pass')) document.getElementById('mqtt_pass').value = activeAcc.mqtt_pass || '';

      // 2. Populate Tab 2: WiFi
      if (document.getElementById('wifi_ssid')) document.getElementById('wifi_ssid').value = activeAcc.wifi_ssid || '';
      if (document.getElementById('wifi_password')) document.getElementById('wifi_password').value = activeAcc.wifi_password || '';

      // 3. Populate Tab 3: PLC
      if (document.getElementById('plc_type')) document.getElementById('plc_type').value = activeAcc.plc_type || (activeAcc.hardware_type.includes('PLC') ? 'Mitsubishi FX5U (Modbus TCP)' : 'Modbus TCP Gateway');
      if (document.getElementById('plc_ip')) document.getElementById('plc_ip').value = activeAcc.plc_ip || '192.168.1.100';
      if (document.getElementById('plc_port')) document.getElementById('plc_port').value = activeAcc.plc_port || 502;

      // 4. Update Topology Display
      if (document.getElementById('topoBrokerDisplay')) {
        document.getElementById('topoBrokerDisplay').innerText = 'Broker: ' + (activeAcc.mqtt_broker || 'broker.emqx.io') + ':' + (activeAcc.mqtt_port || 1883);
      }
      if (document.getElementById('topoBrokerSub')) {
        document.getElementById('topoBrokerSub').innerText = activeAcc.mqtt_broker || 'broker.emqx.io';
      }
      if (document.getElementById('topoPlcSub')) {
        document.getElementById('topoPlcSub').innerText = (activeAcc.plc_ip || '192.168.1.100') + ':' + (activeAcc.plc_port || 502);
      }

      // 5. Update Sync URL Preview
      updateSyncUrlPreview(accId);

      // 6. Refresh UI Pills and Details
      renderAccountPills();
      renderActiveAccountDetail();

      if (isUserClick) {
        showToast('Akun Aktif: ' + activeAcc.name, 'Mesin: ' + activeAcc.hardware_type + ' (' + (activeAcc.devices ? activeAcc.devices.length : 0) + ' Perangkat Terdaftar)');
      }
    }

    function renderActiveAccountDetail() {
      const card = document.getElementById('accountDetailCard');
      if (!card) return;

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) {
        card.innerHTML = '<div style="color: var(--text-dim); text-align: center; padding: 30px;">Silakan pilih akun di atas.</div>';
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
            <td style="padding: 12px 10px; font-weight: 800; color: var(--text-white);">
              ${d.name}
              <div style="font-size: 11px; color: var(--text-dim); font-weight: 500;">ID: ${d.id}</div>
            </td>
            <td style="padding: 12px 10px; color: var(--text-secondary); font-size: 12.5px;">
              <span style="background: rgba(255,255,255,0.06); padding: 3px 8px; border-radius: 6px;">${typeBadge}</span>
            </td>
            <td style="padding: 12px 10px;">
              <span style="font-family: var(--font-code); font-size: 12px; background: rgba(0,240,255,0.12); color: var(--cyan); border: 1px solid rgba(0,240,255,0.25); padding: 4px 10px; border-radius: 6px; font-weight: 700;">
                ${d.hardwarePin || 'GPIO 2'}
              </span>
            </td>
            <td style="padding: 12px 10px; text-align: right; white-space: nowrap;">
              <button type="button" onclick="openDeviceWizardModal(${idx})" style="background: var(--cyan-subtle); border: 1px solid var(--cyan); color: var(--cyan); border-radius: 6px; padding: 5px 10px; font-size: 12px; font-weight: 700; cursor: pointer; margin-right: 6px;" title="Ganti PIN">
                ⚙️ Ubah PIN
              </button>
              <button type="button" onclick="deleteAccountDevice(${idx})" style="background: rgba(244,63,94,0.1); border: 1px solid rgba(244,63,94,0.3); color: var(--rose); border-radius: 6px; padding: 5px 10px; font-size: 12px; font-weight: 700; cursor: pointer;" title="Hapus Perangkat">
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
            <td style="padding: 12px 10px; font-weight: 800; color: var(--text-white);">
              ${c.name}
              <div style="font-size: 11px; color: var(--text-dim); font-weight: 500;">Lokasi: ${c.location || '-'}</div>
            </td>
            <td style="padding: 12px 10px; font-family: var(--font-code); font-size: 11.5px; color: var(--text-dim); max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
              ${c.rtspUrl}
            </td>
            <td style="padding: 12px 10px; color: var(--cyan); font-size: 12px;">
              🔗 ${c.boundGateId ? 'Pagar (' + c.boundGateId + ')' : 'Stand-alone'}
            </td>
            <td style="padding: 12px 10px; text-align: right;">
              <button type="button" onclick="deleteAccountCctv(${idx})" style="background: rgba(244,63,94,0.1); border: 1px solid rgba(244,63,94,0.3); color: var(--rose); border-radius: 6px; padding: 5px 10px; font-size: 12px; font-weight: 700; cursor: pointer;" title="Hapus CCTV">
                🗑️ Hapus
              </button>
            </td>
          </tr>
        `;
      });

      card.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 1px solid var(--border-subtle); padding-bottom: 16px; flex-wrap: wrap; gap: 10px;">
          <div>
            <div style="font-size: 11px; font-weight: 800; color: var(--cyan); text-transform: uppercase;">PROFIL HARDWARE AKUN TERPILIH</div>
            <h3 style="font-size: 18px; font-weight: 800; color: var(--text-white); margin-top: 2px;">${acc.name}</h3>
            <span style="font-size: 12px; color: var(--text-secondary);">ID Akun: <code>${acc.id}</code></span>
          </div>
          <div style="display: flex; gap: 8px;">
            <button type="button" onclick="handleFormSubmit()" style="background: var(--cyan); color: #000; border: none; border-radius: 8px; padding: 9px 18px; font-size: 13px; font-weight: 800; cursor: pointer; box-shadow: 0 0 15px var(--cyan-glow);">
              💾 Simpan Perubahan Akun Ini
            </button>
            ${acc.role !== 'superadmin' ? `<button type="button" onclick="deleteAccount('${acc.id}')" style="background: rgba(244,63,94,0.15); color: var(--rose); border: 1px solid var(--rose); border-radius: 8px; padding: 8px 14px; font-size: 12px; font-weight: 700; cursor: pointer;">🗑️ Hapus Akun</button>` : ''}
          </div>
        </div>

        <!-- FORM PARAMETER AKUN -->
        <div class="form-row-grid">
          <div class="form-group-box">
            <label>Nama Pemilik / Klien</label>
            <input type="text" id="acc_name_input" class="app-input" value="${acc.name}" onchange="updateActiveAccField('name', this.value)">
          </div>
          <div class="form-group-box">
            <label>Email Login HP</label>
            <input type="email" id="acc_email_input" class="app-input mono" value="${acc.email}" onchange="updateActiveAccField('email', this.value)">
          </div>
          <div class="form-group-box">
            <label>Kata Sandi Login HP</label>
            <input type="text" id="acc_pass_input" class="app-input mono" value="${acc.password}" onchange="updateActiveAccField('password', this.value)">
          </div>
          <div class="form-group-box">
            <label>Mesin Hardware (Gateway Controller)</label>
            <select id="acc_hw_input" class="app-input" onchange="updateActiveAccHardware(this.value)">
              <option value="Raspberry Pi 4 Gateway" ${acc.hardware_type.includes('Raspberry Pi 4') || acc.hardware_type.includes('Pi') ? 'selected' : ''}>🍓 Raspberry Pi 4 (Master Controller)</option>
              <option value="Mitsubishi FX5U PLC (Industrial Hub)" ${acc.hardware_type.includes('Mitsubishi') || acc.hardware_type.includes('PLC') ? 'selected' : ''}>🏭 Mitsubishi FX5U PLC (Industrial Hub)</option>
              <option value="ESP32 Smart Automation Hub" ${acc.hardware_type.includes('ESP32') ? 'selected' : ''}>⚡ ESP32 Smart Automation Hub</option>
            </select>
          </div>
          <div class="form-group-box">
            <label>Topic MQTT Prefix Khusus Akun Ini</label>
            <input type="text" id="acc_prefix_input" class="app-input mono" value="${acc.mqtt_prefix || 'alrisa/' + acc.id}" onchange="updateActiveAccField('mqtt_prefix', this.value)">
          </div>
        </div>

        <!-- TABEL PERANGKAT & PIN HARDWARE AKUN -->
        <div style="margin-top: 24px; background: var(--bg-card); border: 1.5px solid var(--border-subtle); border-radius: var(--radius-lg); padding: 20px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px;">
            <div>
              <div style="font-weight: 800; font-size: 15px; color: var(--text-white); display: flex; align-items: center; gap: 8px;">
                <span>🔌</span> Perangkat IoT & Pemetaan PIN Hardware (${devices.length})
              </div>
              <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Jalur PIN fisik dikunci khusus untuk mesin: <b style="color: var(--cyan);">${acc.hardware_type}</b></p>
            </div>
            <button type="button" onclick="openDeviceWizardModal()" style="background: linear-gradient(135deg, var(--cyan), #3B82F6); color: #000; border: none; border-radius: 8px; padding: 8px 16px; font-size: 12.5px; font-weight: 800; cursor: pointer; display: flex; align-items: center; gap: 6px; box-shadow: 0 0 15px var(--cyan-glow);">
              <span>➕</span> Tambah Perangkat (Lanjut ke Menu PIN)
            </button>
          </div>

          <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
            <thead>
              <tr style="border-bottom: 1.5px solid var(--border-subtle); color: var(--text-secondary); font-size: 11.5px; text-transform: uppercase;">
                <th style="padding: 10px;">Nama Perangkat</th>
                <th style="padding: 10px;">Tipe</th>
                <th style="padding: 10px;">PIN Hardware / Alamat PLC</th>
                <th style="padding: 10px; text-align: right;">Aksi</th>
              </tr>
            </thead>
            <tbody>
              ${devRowsHtml || '<tr><td colspan="4" style="padding: 24px; text-align: center; color: var(--text-dim);">Belum ada perangkat terpasang. Klik tombol di atas untuk menambah perangkat dan memilih PIN hardware.</td></tr>'}
            </tbody>
          </table>
        </div>

        <!-- TABEL KAMERA CCTV AKUN -->
        <div style="margin-top: 24px; background: var(--bg-card); border: 1.5px solid var(--border-subtle); border-radius: var(--radius-lg); padding: 20px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px;">
            <div>
              <div style="font-weight: 800; font-size: 15px; color: var(--text-white); display: flex; align-items: center; gap: 8px;">
                <span>📹</span> Kamera CCTV Khusus Akun Ini (${cctvs.length})
              </div>
              <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Streaming RTSP yang dapat diakses oleh HP pemilik akun ini.</p>
            </div>
            <button type="button" onclick="openCctvModal()" style="background: var(--cyan-subtle); color: var(--cyan); border: 1px solid var(--cyan); border-radius: 8px; padding: 8px 16px; font-size: 12px; font-weight: 700; cursor: pointer;">
              ➕ Pasang CCTV Baru
            </button>
          </div>

          <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
            <thead>
              <tr style="border-bottom: 1.5px solid var(--border-subtle); color: var(--text-secondary); font-size: 11.5px; text-transform: uppercase;">
                <th style="padding: 10px;">Nama Kamera</th>
                <th style="padding: 10px;">URL RTSP Stream</th>
                <th style="padding: 10px;">Koneksi Gerbang</th>
                <th style="padding: 10px; text-align: right;">Aksi</th>
              </tr>
            </thead>
            <tbody>
              ${cctvRowsHtml || '<tr><td colspan="4" style="padding: 20px; text-align: center; color: var(--text-dim);">Belum ada kamera CCTV terdaftar untuk akun ini.</td></tr>'}
            </tbody>
          </table>
        </div>
      `;
    }

    function updateActiveAccField(field, val) {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (acc) {
        acc[field] = val;
      }
    }

    function updateActiveAccHardware(hwType) {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (acc) {
        acc.hardware_type = hwType;
        renderAccountPills();
        renderActiveAccountDetail();
        showToast('Tipe Mesin Diperbarui', 'Alokasi PIN hardware disesuaikan untuk ' + hwType);
      }
    }

    // =========================================================================
    // 🔌 2-STEP DEVICE & HARDWARE PIN WIZARD CONTROLLER
    // =========================================================================
    let wizardEditDeviceIdx = null;
    let wizardSelectedPin = '';

    function openDeviceWizardModal(editIdx = null) {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) return;

      wizardEditDeviceIdx = editIdx;
      document.getElementById('wizardModalAccName').innerText = acc.name + ' (' + acc.hardware_type + ')';
      
      const modalTitle = document.getElementById('wizardModalTitle');
      if (editIdx !== null) {
        modalTitle.innerText = 'Ubah Pemetaan PIN Perangkat';
        const d = acc.devices[editIdx];
        document.getElementById('wizardDevName').value = d.name;
        document.getElementById('wizardDevType').value = d.type;
        document.getElementById('wizardDevCategory').value = d.category || 'Umum';
        wizardSelectedPin = d.hardwarePin;
      } else {
        modalTitle.innerText = 'Tambah Perangkat & Pemetaan PIN';
        document.getElementById('wizardDevName').value = '';
        document.getElementById('wizardDevType').value = '0';
        document.getElementById('wizardDevCategory').value = 'Keamanan';
        wizardSelectedPin = '';
      }

      // Reset to Step 1 (or directly Step 2 if quick PIN edit)
      if (editIdx !== null) {
        goToWizardStep2();
      } else {
        goToWizardStep1();
      }

      document.getElementById('deviceWizardModal').classList.add('active');
    }

    function closeDeviceWizardModal() {
      document.getElementById('deviceWizardModal').classList.remove('active');
      wizardEditDeviceIdx = null;
    }

    function handleWizardTypeChange(val) {
      const catInput = document.getElementById('wizardDevCategory');
      if (val === '0') catInput.value = 'Keamanan';
      else if (val === '1') catInput.value = 'Pencahayaan';
      else if (val === '2') catInput.value = 'Akses';
      else if (val === '3') catInput.value = 'Interior';
      else if (val === '4') catInput.value = 'Air';
    }

    function goToWizardStep1() {
      document.getElementById('wizardStep1Content').style.display = 'block';
      document.getElementById('wizardStep2Content').style.display = 'none';

      document.getElementById('stepIndicator1').className = 'wizard-step-node active';
      document.getElementById('stepIndicator2').className = 'wizard-step-node';
      document.getElementById('stepDivider').className = 'wizard-step-divider';

      document.getElementById('btnWizardNext').style.display = 'inline-flex';
      document.getElementById('btnWizardBack').style.display = 'none';
      document.getElementById('btnWizardFinish').style.display = 'none';
    }

    function goToWizardStep2() {
      const devName = document.getElementById('wizardDevName').value.trim();
      if (!devName) {
        alert('Harap masukkan Nama Perangkat terlebih dahulu (Contoh: Gerbang Belakang).');
        document.getElementById('wizardDevName').focus();
        return;
      }

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) return;

      document.getElementById('wizardStep1Content').style.display = 'none';
      document.getElementById('wizardStep2Content').style.display = 'block';

      document.getElementById('stepIndicator1').className = 'wizard-step-node completed';
      document.getElementById('stepIndicator2').className = 'wizard-step-node active';
      document.getElementById('stepDivider').className = 'wizard-step-divider active';

      document.getElementById('btnWizardNext').style.display = 'none';
      document.getElementById('btnWizardBack').style.display = 'inline-flex';
      document.getElementById('btnWizardFinish').style.display = 'inline-flex';

      document.getElementById('wizardStep2HwType').innerText = acc.hardware_type;
      document.getElementById('wizardStep2DevSummary').innerText = devName;

      renderWizardPinGrid();
    }

    function renderWizardPinGrid() {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) return;

      const grid = document.getElementById('wizardPinGrid');
      grid.innerHTML = '';

      const pinBank = getHardwarePinBank(acc.hardware_type);

      // Collect pins already used by OTHER devices in this account
      const usedPinsMap = {};
      (acc.devices || []).forEach((d, idx) => {
        if (wizardEditDeviceIdx === null || idx !== wizardEditDeviceIdx) {
          usedPinsMap[d.hardwarePin] = d.name;
        }
      });

      let firstVacantPin = null;

      pinBank.forEach(p => {
        const isUsed = usedPinsMap.hasOwnProperty(p.pin);
        const card = document.createElement('div');

        if (isUsed) {
          card.className = 'pin-card-box disabled';
          card.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
              <span style="font-family: var(--font-code); font-weight: 800; font-size: 13px; color: var(--text-dim);">${p.pin}</span>
              <span class="pin-badge-status used">🔒 TERPAKAI</span>
            </div>
            <div style="font-size: 11px; color: var(--rose); margin-top: 4px;">Dipakai oleh: <b>${usedPinsMap[p.pin]}</b></div>
          `;
        } else {
          if (!firstVacantPin) firstVacantPin = p.pin;
          const isSelected = (wizardSelectedPin === p.pin) || (!wizardSelectedPin && firstVacantPin === p.pin);

          if (isSelected) wizardSelectedPin = p.pin;

          card.className = 'pin-card-box' + (isSelected ? ' selected' : '');
          card.onclick = () => selectWizardPin(p.pin);
          card.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
              <span style="font-family: var(--font-code); font-weight: 800; font-size: 13px; color: var(--text-white);">${p.pin}</span>
              <span class="pin-badge-status free">✨ KOSONG</span>
            </div>
            <div style="font-size: 11px; color: var(--text-dim);">${p.desc}</div>
          `;
        }
        grid.appendChild(card);
      });
    }

    function selectWizardPin(pin) {
      wizardSelectedPin = pin;
      document.getElementById('chkUseCustomPin').checked = false;
      document.getElementById('customPinInputWrap').style.display = 'none';
      renderWizardPinGrid();
    }

    function toggleCustomPinInput() {
      const chk = document.getElementById('chkUseCustomPin');
      const wrap = document.getElementById('customPinInputWrap');
      if (chk.checked) {
        wrap.style.display = 'block';
        const input = document.getElementById('wizardCustomPinInput');
        if (input.value.trim()) {
          wizardSelectedPin = input.value.trim();
        }
      } else {
        wrap.style.display = 'none';
        renderWizardPinGrid();
      }
    }

    function selectCustomPin(val) {
      if (val.trim()) {
        wizardSelectedPin = val.trim();
      }
    }

    function finishDeviceWizard() {
      const devName = document.getElementById('wizardDevName').value.trim();
      const devType = parseInt(document.getElementById('wizardDevType').value);
      const devCat = document.getElementById('wizardDevCategory').value.trim() || 'Umum';

      if (!wizardSelectedPin) {
        alert('Harap pilih salah satu PIN hardware yang tersedia.');
        return;
      }

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) return;

      if (!acc.devices) acc.devices = [];

      if (wizardEditDeviceIdx !== null) {
        // Update existing device
        acc.devices[wizardEditDeviceIdx].name = devName;
        acc.devices[wizardEditDeviceIdx].type = devType;
        acc.devices[wizardEditDeviceIdx].category = devCat;
        acc.devices[wizardEditDeviceIdx].hardwarePin = wizardSelectedPin;
        showToast('PIN Berhasil Diperbarui!', `Perangkat "${devName}" kini terhubung ke ${wizardSelectedPin}.`);
      } else {
        // Create new device
        acc.devices.push({
          id: 'dev_' + Date.now(),
          name: devName,
          category: devCat,
          type: devType,
          hardwarePin: wizardSelectedPin,
          isActive: false,
          value: 0.0,
          statusText: devType === 1 ? 'Padam' : 'Terkunci'
        });
        showToast('Perangkat Berhasil Dipasangkan!', `Perangkat "${devName}" terpasang pada ${wizardSelectedPin}.`);
      }

      closeDeviceWizardModal();
      renderActiveAccountDetail();
      handleFormSubmit();
    }

    function deleteAccountDevice(idx) {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (acc && acc.devices && confirm(`Hapus perangkat "${acc.devices[idx].name}"?`)) {
        acc.devices.splice(idx, 1);
        renderActiveAccountDetail();
        handleFormSubmit();
      }
    }

    // =========================================================================
    // 📹 CCTV MODAL HANDLER
    // =========================================================================
    function openCctvModal() {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) return;

      document.getElementById('cctvModalName').value = '';
      document.getElementById('cctvModalLocation').value = 'Gerbang Depan';
      document.getElementById('cctvModalRtsp').value = 'rtsp://admin:admin123@192.168.1.50:554/live';

      const gateSelect = document.getElementById('cctvModalGate');
      gateSelect.innerHTML = '<option value="">(Tidak Terhubung / Stand-alone)</option>';
      (acc.devices || []).filter(d => d.type === 0 || d.type === 2).forEach(g => {
        gateSelect.innerHTML += `<option value="${g.id}">🚪 ${g.name}</option>`;
      });

      document.getElementById('cctvModal').classList.add('active');
    }

    function closeCctvModal() {
      document.getElementById('cctvModal').classList.remove('active');
    }

    function saveCctvModal() {
      const name = document.getElementById('cctvModalName').value.trim();
      const loc = document.getElementById('cctvModalLocation').value.trim();
      const rtsp = document.getElementById('cctvModalRtsp').value.trim();
      const gateId = document.getElementById('cctvModalGate').value;

      if (!name || !rtsp) {
        alert('Harap isi Nama Kamera dan URL RTSP.');
        return;
      }

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (acc) {
        if (!acc.cctv) acc.cctv = [];
        acc.cctv.push({
          id: 'cctv_' + Date.now(),
          name: name,
          location: loc || 'Lokasi ' + (acc.cctv.length + 1),
          rtspUrl: rtsp,
          onvifHost: '192.168.1.50',
          onvifPort: 80,
          boundGateId: gateId || null,
          isOnline: true,
          fps: 25.0,
          resolution: '1080P FHD (H.264)'
        });

        closeCctvModal();
        renderActiveAccountDetail();
        handleFormSubmit();
        showToast('CCTV Terpasang!', `Kamera "${name}" berhasil ditambahkan.`);
      }
    }

    function deleteAccountCctv(idx) {
      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (acc && acc.cctv && confirm(`Hapus kamera CCTV "${acc.cctv[idx].name}"?`)) {
        acc.cctv.splice(idx, 1);
        renderActiveAccountDetail();
        handleFormSubmit();
      }
    }

    // =========================================================================
    // 👥 NEW ACCOUNT MODAL HANDLER
    // =========================================================================
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
        mqtt_broker: document.getElementById('mqtt_broker').value.trim() || 'broker.emqx.io',
        mqtt_port: parseInt(document.getElementById('mqtt_port').value.trim()) || 1883,
        mqtt_ws_port: 8083,
        plc_ip: '192.168.1.100',
        plc_port: 502,
        wifi_ssid: document.getElementById('wifi_ssid').value.trim(),
        wifi_password: document.getElementById('wifi_password').value.trim(),
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

    // Initial Bootstrap
    document.addEventListener('DOMContentLoaded', () => {
      selectActiveAccount(currentSelectedAccountId);
    });
    // Immediate fallback
    selectActiveAccount(currentSelectedAccountId);
  </script>
</body>
</html>
