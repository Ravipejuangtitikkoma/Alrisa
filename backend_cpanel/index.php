<?php
/**
 * ============================================================================
 * NEXORA IOT — PORTAL MANAJEMEN AKUN & KLIEN (HALAMAN UTAMA)
 * ============================================================================
 * Halaman Utama Web Portal:
 * - Menampilkan Tabel Akun Klien (Nama Pemilik, Username, Password, Hardware)
 * - Fitur Intip Password (👁️), Edit Akun, Hapus Akun, Tambah Akun Baru
 * - Akses Langsung ke Web Dashboard Nexora Home OS tiap akun (dashboard.php?account_id=...)
 * ============================================================================
 */

$settingsFile = __DIR__ . '/settings.json';

$defaultSettings = [
    'mqtt_broker'      => 'broker.emqx.io',
    'mqtt_port'        => 1883,
    'mqtt_ws_port'     => 8083,
    'mqtt_prefix'      => 'alrisa',
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

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $raw = file_get_contents('php://input');
        $input = json_decode($raw, true) ?: $_POST;

        if (isset($input['accounts']) && is_array($input['accounts'])) {
            $current['accounts'] = $input['accounts'];
        }
        if (isset($input['active_account_id'])) {
            $current['active_account_id'] = trim($input['active_account_id']);
        }

        saveSettings($settingsFile, $current);
        echo json_encode(['success' => true, 'message' => 'Data akun berhasil diperbarui!', 'data' => $current]);
        exit();
    }

    echo json_encode(['success' => true, 'data' => $current]);
    exit();
}
?>
<!DOCTYPE html>
<html lang="id" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NEXORA — Portal Manajemen Akun & Klien</title>
  
  <!-- Modern Google Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@400;500;600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    :root, [data-theme="dark"] {
      --bg-base: #07090E;
      --bg-surface: #0E131F;
      --bg-card: rgba(16, 22, 36, 0.78);
      --bg-card-hover: rgba(22, 30, 50, 0.92);
      --bg-input: #090D15;
      --bg-node: #0B0F1A;
      --bg-dock: rgba(14, 20, 32, 0.94);
      
      --cyan: #00F0FF;
      --cyan-glow: rgba(0, 240, 255, 0.35);
      --cyan-subtle: rgba(0, 240, 255, 0.08);
      
      --emerald: #10B981;
      --emerald-glow: rgba(16, 185, 129, 0.35);
      --emerald-subtle: rgba(16, 185, 129, 0.1);
      
      --amber: #F59E0B;
      --rose: #F43F5E;
      --purple: #8B5CF6;
      --indigo: #6366F1;
      
      --border-subtle: rgba(255, 255, 255, 0.09);
      --border-active: rgba(0, 240, 255, 0.4);
      
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
      --bg-card: rgba(255, 255, 255, 0.92);
      --bg-card-hover: #FFFFFF;
      --bg-input: #F8FAFC;
      --bg-node: #F8FAFC;
      --bg-dock: rgba(255, 255, 255, 0.96);
      
      --cyan: #0284C7;
      --cyan-glow: rgba(2, 132, 199, 0.25);
      --cyan-subtle: rgba(2, 132, 199, 0.1);
      
      --emerald: #059669;
      --emerald-glow: rgba(5, 150, 105, 0.25);
      --emerald-subtle: rgba(5, 150, 105, 0.12);
      
      --amber: #D97706;
      --rose: #E11D48;
      --purple: #7C3AED;
      --indigo: #4F46E5;
      
      --border-subtle: rgba(203, 213, 225, 0.85);
      --border-active: rgba(2, 132, 199, 0.45);
      
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
      padding: 24px 20px 80px;
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
      width: 48px;
      height: 48px;
      border-radius: 14px;
      background: linear-gradient(135deg, var(--cyan), #3B82F6);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
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

    .cyan-text { color: var(--cyan); }

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
      padding: 10px 18px;
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

    .btn-top.primary {
      background: linear-gradient(135deg, var(--cyan), #0284C7);
      color: #000;
      border: none;
      box-shadow: 0 0 20px var(--cyan-glow);
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

    /* SUMMARY STATS BAR */
    .summary-stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 18px;
      margin-bottom: 24px;
    }

    .stat-card {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 20px;
      padding: 20px 24px;
      display: flex;
      align-items: center;
      gap: 16px;
      box-shadow: var(--shadow-card);
      transition: all 0.25s;
    }
    .stat-card:hover {
      transform: translateY(-2px);
      border-color: var(--cyan);
    }

    .stat-icon {
      width: 48px;
      height: 48px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      flex-shrink: 0;
    }

    .stat-val {
      font-family: 'Outfit', sans-serif;
      font-size: 24px;
      font-weight: 800;
      color: var(--text-white);
      line-height: 1.1;
    }
    .stat-lbl {
      font-size: 12.5px;
      color: var(--text-secondary);
      margin-top: 3px;
      font-weight: 600;
    }

    /* BENTO CARD */
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
      font-size: 20px;
      font-weight: 800;
      color: var(--text-white);
    }
    .card-title-left p {
      font-size: 13px;
      color: var(--text-secondary);
      margin-top: 3px;
    }

    /* ULTRA-PREMIUM ACCOUNTS TABLE */
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
    .accounts-table tr:last-child td { border-bottom: none; }
    .accounts-table tr:hover { background: rgba(255, 255, 255, 0.02); }
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
      width: 42px;
      height: 42px;
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
      font-size: 10px;
      font-weight: 800;
      padding: 2px 7px;
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
    .credential-btn:hover { color: var(--cyan); }

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

    /* MODAL */
    .modal-backdrop-custom {
      position: fixed;
      top: 0; left: 0;
      width: 100vw; height: 100vh;
      background: rgba(4, 7, 13, 0.82);
      backdrop-filter: blur(10px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      padding: 16px;
    }
    .modal-backdrop-custom.active { display: flex !important; }

    .modal-box-custom {
      background: var(--bg-surface);
      border: 1.5px solid var(--border-subtle);
      border-radius: 22px;
      width: 100%;
      max-width: 600px;
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

    /* TOAST */
    .toast-popup {
      position: fixed;
      top: 24px; right: 24px;
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

    <!-- 1. TOP HEADER -->
    <header class="top-header">
      <div class="brand-group">
        <div class="brand-logo-badge">⚡</div>
        <div class="brand-title-wrap">
          <h1>
            <span class="gradient-text">NEXORA</span>
            <span class="cyan-text">Portal Studio</span>
            <span style="font-size: 11px; background: var(--cyan-subtle); color: var(--cyan); border: 1px solid var(--border-active); padding: 2px 8px; border-radius: 6px; font-family: 'JetBrains Mono', monospace; font-weight: 700;">v3.0</span>
          </h1>
          <p>Portal Manajemen Akun Pengguna, Kredensial Login & Gateway Multi-Tenant</p>
        </div>
      </div>

      <div class="header-actions">
        <button type="button" class="btn-top" onclick="toggleTheme()" id="themeToggleBtn" title="Ganti Mode Gelap / Terang">
          <span id="themeIcon">☀️</span> <span id="themeText">Mode Terang</span>
        </button>

        <div class="live-telemetry-pill">
          <div class="pulse-dot"></div>
          <span style="color: var(--emerald); font-weight: 800;">BROKER ONLINE</span>
          <span style="color: var(--text-dim);">•</span>
          <span style="color: var(--cyan);" id="headerPingText">LATENSI: 18ms</span>
        </div>

        <a href="settings.php" class="btn-top" title="Buka Halaman Pengaturan Broker MQTT & Jaringan Hardware">
          <span>⚙️</span> Pengaturan Broker
        </a>
      </div>
    </header>

    <!-- 2. SUMMARY COUNTERS -->
    <section class="summary-stats-grid">
      <div class="stat-card">
        <div class="stat-icon" style="background: rgba(0, 240, 255, 0.12); color: var(--cyan);">👥</div>
        <div>
          <div class="stat-val" id="statTotalAccounts">0</div>
          <div class="stat-lbl">Akun Pemilik Terdaftar</div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon" style="background: rgba(16, 185, 129, 0.12); color: var(--emerald);">⚡</div>
        <div>
          <div class="stat-val" id="statTotalDevices">0</div>
          <div class="stat-lbl">Total Perangkat IoT Terpasang</div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon" style="background: rgba(139, 92, 246, 0.12); color: var(--purple);">📹</div>
        <div>
          <div class="stat-val" id="statTotalCctv">0</div>
          <div class="stat-lbl">Kamera CCTV RTSP Aktif</div>
        </div>
      </div>
    </section>

    <!-- 3. TABEL UTAMA MANAJEMEN AKUN (YANG DIINGINKAN USER) -->
    <div class="bento-card">
      <div class="card-title-group">
        <div class="card-title-left">
          <div class="card-icon-badge">👥</div>
          <div>
            <h2>Tabel Manajemen Akun & Kredensial Pengguna</h2>
            <p>Pilih akun pemilik untuk menuju ke Web Dashboard profil Nexora Home OS masing-masing, atau kelola kredensial login aplikasi HP.</p>
          </div>
        </div>
        <button type="button" class="btn-top primary" onclick="showAddNewAccountModal()">
          <span>➕</span> Tambah Akun Klien Baru
        </button>
      </div>

      <!-- TABEL DATA AKUN -->
      <div class="accounts-table-wrapper">
        <table class="accounts-table">
          <thead>
            <tr>
              <th style="width: 260px;">Nama Pemilik / Klien</th>
              <th style="width: 230px;">Username / Email Login</th>
              <th style="width: 200px;">Kata Sandi (Password)</th>
              <th style="width: 220px;">Mesin Hardware Gateway</th>
              <th style="width: 140px;">Perangkat Terpasang</th>
              <th style="text-align: right; width: 230px;">Aksi Cepat</th>
            </tr>
          </thead>
          <tbody id="accountsTableBody">
            <!-- Dirender secara dinamis oleh JavaScript -->
          </tbody>
        </table>
      </div>

      <!-- PANEL RINCIAN PERANGKAT AKUN TERPILIH -->
      <div id="accountDetailCard">
        <!-- Dirender secara dinamis oleh JavaScript -->
      </div>
    </div>

  </div>

  <!-- ========================================================================= -->
  <!-- ✏️ MODAL: EDIT AKUN KLIEN                                                -->
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
        <button type="button" class="btn-top primary" onclick="saveEditAccountModal()" style="padding: 10px 22px; font-size: 13px;">
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
        <button type="button" class="btn-top primary" onclick="saveNewAccountModal()" style="padding: 10px 22px; font-size: 13px;">
          <span>✅ Daftarkan Akun Klien</span>
        </button>
      </div>
    </div>
  </div>

  <!-- JAVASCRIPT CONTROLLER -->
  <script>
    // Theme
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
      if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
      return name.substring(0, 2).toUpperCase();
    }

    function updateSummaryMetrics() {
      document.getElementById('statTotalAccounts').innerText = systemAccounts.length;
      let totalDevs = 0;
      let totalCctvs = 0;
      systemAccounts.forEach(a => {
        totalDevs += (a.devices || []).length;
        totalCctvs += (a.cctv || []).length;
      });
      document.getElementById('statTotalDevices').innerText = totalDevs;
      document.getElementById('statTotalCctv').innerText = totalCctvs;
    }

    // RENDER TABEL AKUN MASTER
    function renderAccountsTable() {
      const tbody = document.getElementById('accountsTableBody');
      if (!tbody) return;
      tbody.innerHTML = '';

      updateSummaryMetrics();

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
              Prefix: ${acc.mqtt_prefix || 'alrisa/' + acc.id}
            </div>
          </td>
          <td>
            <div style="font-weight: 700; font-size: 13px; color: var(--text-white);">${devCount} Saklar</div>
            <div style="font-size: 11px; color: var(--text-secondary);">${cctvCount} Kamera CCTV</div>
          </td>
          <td>
            <div class="action-btn-group">
              <a href="dashboard.php?account_id=${acc.id}" class="btn-act-dashboard" title="Menuju ke Halaman Web Dashboard Profil Nexora Home OS untuk Akun Ini">
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

    function selectActiveAccount(accId, isUserClick = false) {
      currentSelectedAccountId = accId;
      renderAccountsTable();
      renderActiveAccountDetail();
      if (isUserClick) {
        const acc = systemAccounts.find(a => a.id === accId);
        if (acc) showToast('Akun Dipilih: ' + acc.name, 'Klik "Buka Dashboard" untuk melihat kontrol perangkat.');
      }
    }

    function renderActiveAccountDetail() {
      const card = document.getElementById('accountDetailCard');
      if (!card) return;

      const acc = systemAccounts.find(a => a.id === currentSelectedAccountId);
      if (!acc) {
        card.innerHTML = '';
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
            <td style="padding: 12px 14px; text-align: right; color: var(--text-dim); font-size: 12px;">
              ${d.isActive ? '<span style="color: var(--emerald); font-weight: 700;">● AKTIF</span>' : '● OFF'}
            </td>
          </tr>
        `;
      });

      card.innerHTML = `
        <div style="background: var(--bg-surface); border: 1.5px solid var(--border-subtle); border-radius: 20px; padding: 22px; margin-top: 10px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; border-bottom: 1px solid var(--border-subtle); padding-bottom: 16px; flex-wrap: wrap; gap: 12px;">
            <div>
              <div style="font-size: 11px; font-weight: 800; color: var(--cyan); text-transform: uppercase; letter-spacing: 0.8px;">RINCIAN PERANGKAT AKUN TERPILIH</div>
              <h3 style="font-size: 18px; font-weight: 800; color: var(--text-white); margin-top: 2px;">${acc.name}</h3>
              <span style="font-size: 12px; color: var(--text-secondary);">Mesin: <b style="color: var(--cyan);">${acc.hardware_type}</b> • Prefix: <code>${acc.mqtt_prefix || 'alrisa/' + acc.id}</code></span>
            </div>
            <div style="display: flex; gap: 10px;">
              <a href="dashboard.php?account_id=${acc.id}" class="btn-act-dashboard" style="padding: 10px 20px; font-size: 13px;">
                <span>🌐</span> Masuk ke Halaman Dashboard Profil Ini ➔
              </a>
            </div>
          </div>

          <div style="background: var(--bg-node); border: 1px solid var(--border-subtle); border-radius: 16px; padding: 18px;">
            <div style="font-weight: 800; font-size: 14.5px; color: var(--text-white); margin-bottom: 12px;">
              Daftar Perangkat IoT Terpasang (${devices.length})
            </div>
            <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
              <thead>
                <tr style="border-bottom: 1.5px solid var(--border-subtle); color: var(--text-secondary); font-size: 11.5px; text-transform: uppercase;">
                  <th style="padding: 10px 14px;">Nama Perangkat</th>
                  <th style="padding: 10px 14px;">Tipe</th>
                  <th style="padding: 10px 14px;">PIN Hardware</th>
                  <th style="padding: 10px 14px; text-align: right;">Status</th>
                </tr>
              </thead>
              <tbody>
                ${devRowsHtml || '<tr><td colspan="4" style="padding: 20px; text-align: center; color: var(--text-dim);">Belum ada perangkat terpasang pada akun ini.</td></tr>'}
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
        alert('Nama dan Email wajib diisi.');
        return;
      }

      acc.name = name;
      acc.email = email;
      acc.password = pass;
      acc.hardware_type = hw;
      acc.mqtt_prefix = prefix;

      closeEditAccountModal();
      saveAccountsToServer();
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
      saveAccountsToServer();
      showToast('Akun Klien Dibuat!', `Akun ${name} siap digunakan.`);
    }

    function deleteAccount(accId) {
      if (confirm('Yakin ingin menghapus akun klien ini secara permanen?')) {
        systemAccounts = systemAccounts.filter(a => a.id !== accId);
        currentSelectedAccountId = systemAccounts.length > 0 ? systemAccounts[0].id : '';
        saveAccountsToServer();
        showToast('Akun Dihapus', 'Akun telah dihapus dari sistem.');
      }
    }

    function saveAccountsToServer() {
      renderAccountsTable();
      renderActiveAccountDetail();

      fetch('index.php?api=1', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          accounts: systemAccounts,
          active_account_id: currentSelectedAccountId
        })
      }).catch(e => console.error(e));
    }

    function showToast(title, message) {
      const toast = document.getElementById('toastAlert');
      document.getElementById('toastTitle').innerText = title;
      document.getElementById('toastMessage').innerText = message;
      toast.classList.add('show');
      setTimeout(() => { toast.classList.remove('show'); }, 3500);
    }

    // Bootstrap
    renderAccountsTable();
    renderActiveAccountDetail();
  </script>
</body>
</html>
