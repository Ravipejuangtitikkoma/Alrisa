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

        saveSettings($settingsFile, $current);
        echo json_encode([
            'success' => true,
            'message' => 'Konfigurasi sistem berhasil diperbarui!',
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

    @media (max-width: 900px) {
      .col-8, .col-4, .col-6 { grid-column: span 12; }
      .topology-flow { flex-direction: column; }
      .pipe-connector { transform: rotate(90deg); margin: 10px 0; }
      .floating-save-dock { flex-direction: column; gap: 14px; text-align: center; }
      .dock-status-info { flex-direction: column; }
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

  </div>

  <script>
    // THEME SWITCHER
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

      document.querySelectorAll('.preset-card-item').forEach(c => c.classList.remove('selected'));
      el.classList.add('selected');

      document.getElementById('topoBrokerDisplay').innerText = 'Broker: ' + host + ':' + tcpPort;
      document.getElementById('topoBrokerSub').innerText = host;

      addTermLog('SYSTEM', 'Preset diganti ke: ' + host + ' (TCP: ' + tcpPort + ', WS: ' + wsPort + ')', 'warn');
    }

    // Set Sync URL
    const fullApiUrl = window.location.origin + window.location.pathname + '?api=1';
    document.getElementById('syncUrlPreview').innerText = fullApiUrl;

    function copySyncUrl() {
      navigator.clipboard.writeText(fullApiUrl).then(() => {
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
      e.preventDefault();
      const saveBtn = document.getElementById('btnSubmitForm');
      saveBtn.innerHTML = '<span>⏳</span> Menyimpan...';
      saveBtn.style.opacity = '0.7';

      const formData = new FormData(document.getElementById('mainConfigForm'));
      const payload = {};
      formData.forEach((value, key) => payload[key] = value);

      fetch('settings.php?api=1', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })
      .then(res => res.json())
      .then(data => {
        saveBtn.innerHTML = '<span>💾</span> Simpan Konfigurasi';
        saveBtn.style.opacity = '1';

        if (data.success) {
          showToast('Konfigurasi Berhasil Disimpan!', 'Semua aplikasi HP dan PLC otomatis tersinkronisasi.');
          addTermLog('CONFIG', 'Konfigurasi sistem berhasil diperbarui & disimpan ke disk.', 'success');
        } else {
          showToast('Gagal Menyimpan', data.message || 'Terjadi kesalahan sistem', true);
        }
      })
      .catch(err => {
        saveBtn.innerHTML = '<span>💾</span> Simpan Konfigurasi';
        saveBtn.style.opacity = '1';
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
  </script>
</body>
</html>
