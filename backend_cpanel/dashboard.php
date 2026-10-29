<?php
/**
 * ============================================================================
 * NEXORA HOME OS — SMART SYSTEMS, MULTI-ACCOUNT & VISUAL PLC STUDIO
 * ============================================================================
 * Halaman Dashboard Utama Interaktif:
 * - Dukungan Multi-Akun (1 Akun = 1 HP / Lokasi Klien / Controller Terpisah)
 * - Tampilan Dinamis Berdasarkan Akun yang Dipilih (?account_id=...)
 * - Zero-Latency Optimistic UI & Visual PLC Ladder Simulator
 * ============================================================================
 */

$settingsFile = __DIR__ . '/settings.json';
$settingsData = file_exists($settingsFile) ? json_decode(file_get_contents($settingsFile), true) : [];
$allAccounts = $settingsData['accounts'] ?? [];
$activeAccountId = $_GET['account_id'] ?? $settingsData['active_account_id'] ?? 'acc_superadmin';

// Cari akun aktif
$activeAccount = null;
foreach ($allAccounts as $acc) {
    if ($acc['id'] === $activeAccountId) {
        $activeAccount = $acc;
        break;
    }
}
if (!$activeAccount && !empty($allAccounts)) {
    $activeAccount = $allAccounts[0];
    $activeAccountId = $activeAccount['id'];
}
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NEXORA Home OS — Smart Systems & Multi-Account Studio</title>
  <!-- Google Fonts: Plus Jakarta Sans, Outfit & JetBrains Mono -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;700&family=Outfit:wght@400;500;600;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <style>
    :root {
      /* Apple Home / Smart Life 2026 Color Palette */
      --bg-ambient: #F3F5F7;
      --bg-mesh: radial-gradient(at 0% 0%, rgba(0, 163, 224, 0.08) 0px, transparent 50%),
                 radial-gradient(at 100% 0%, rgba(16, 185, 129, 0.06) 0px, transparent 50%),
                 radial-gradient(at 50% 100%, rgba(99, 102, 241, 0.04) 0px, transparent 50%);
      --card-white: #FFFFFF;
      --card-glass: rgba(255, 255, 255, 0.85);
      --ink: #0B1116;
      --ink-secondary: #4A5568;
      --ink-dim: #94A3B8;
      
      --cyan-primary: #00A3E0;
      --cyan-soft: #E0F4FB;
      --cyan-glow: rgba(0, 163, 224, 0.28);
      
      --green-active: #10B981;
      --green-soft: #D1FAE5;
      --green-glow: rgba(16, 185, 129, 0.25);
      
      --amber-accent: #F59E0B;
      --amber-soft: #FEF3C7;
      
      --border-subtle: rgba(226, 232, 240, 0.85);
      --border-active: rgba(0, 163, 224, 0.35);
      
      --radius-bento: 24px;
      --radius-sm: 14px;
      --radius-btn: 12px;
      
      --shadow-ambient: 0 4px 20px -2px rgba(15, 23, 42, 0.04), 0 10px 30px -4px rgba(15, 23, 42, 0.03);
      --shadow-hover: 0 16px 40px -4px rgba(15, 23, 42, 0.08), 0 4px 16px -2px rgba(0, 163, 224, 0.06);
      --shadow-active: 0 18px 45px -4px rgba(0, 163, 224, 0.12), 0 6px 20px -2px rgba(0, 163, 224, 0.08);

      /* Visual PLC Studio Dark Theme */
      --plc-bg: #11131B;
      --plc-card: #181C28;
      --plc-wire: #475569;
      --plc-wire-active: #34D399;
      --plc-text: #E2E8F0;
      --plc-text-dim: #94A3B8;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      background-color: var(--bg-ambient);
      background-image: var(--bg-mesh);
      background-attachment: fixed;
      color: var(--ink);
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      min-height: 100vh;
      padding: 24px 20px;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }

    .container {
      max-width: 1260px;
      margin: 0 auto;
    }

    /* TOP STATUS BAR & HEADER */
    .app-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
      flex-wrap: wrap;
      gap: 16px;
      padding-bottom: 18px;
      border-bottom: 1px solid var(--border-subtle);
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .lang-toggle-btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 16px;
      border-radius: var(--radius-sm);
      border: 1px solid var(--border-subtle);
      background: var(--card-white);
      color: var(--ink);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      box-shadow: var(--shadow-ambient);
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      font-family: inherit;
      user-select: none;
    }

    .lang-toggle-btn:hover {
      border-color: var(--cyan-primary);
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    .lang-toggle-btn .flag { font-size: 18px; }
    .lang-toggle-btn .lang-badge {
      font-size: 11px;
      background: var(--cyan-soft);
      color: #0284C7;
      padding: 2px 7px;
      border-radius: 6px;
      font-weight: 800;
      letter-spacing: 0.5px;
    }

    .brand-title {
      font-family: 'Outfit', sans-serif;
      font-size: 28px;
      font-weight: 800;
      letter-spacing: -0.8px;
      line-height: 1.1;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .brand-title .logo-badge {
      width: 32px;
      height: 32px;
      background: linear-gradient(135deg, var(--cyan-primary), #0284C7);
      border-radius: 9px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 17px;
      box-shadow: 0 4px 12px var(--cyan-glow);
    }

    .brand-title span.accent {
      font-weight: 400;
      color: var(--cyan-primary);
    }

    .brand-sub {
      font-size: 13px;
      color: var(--ink-secondary);
      margin-top: 4px;
      font-weight: 500;
    }

    .header-right {
      display: flex;
      align-items: center;
      gap: 14px;
      flex-wrap: wrap;
    }

    .status-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--green-soft);
      color: #065F46;
      padding: 8px 16px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.3px;
      border: 1px solid rgba(16, 185, 129, 0.2);
    }

    .pulse-dot {
      width: 8px;
      height: 8px;
      background-color: var(--green-active);
      border-radius: 50%;
      animation: pulseGlow 1.8s infinite;
    }

    @keyframes pulseGlow {
      0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
      70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
      100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }

    .clock-display {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      font-weight: 700;
      color: var(--ink-secondary);
      background: var(--card-white);
      padding: 8px 14px;
      border-radius: 999px;
      border: 1px solid var(--border-subtle);
    }

    /* ========================================================= */
    /* 👤 ACCOUNT PROFILE BANNER & QUICK SWITCHER                */
    /* ========================================================= */
    .account-profile-bar {
      background: var(--card-white);
      border: 1.5px solid var(--border-subtle);
      border-radius: 20px;
      padding: 16px 22px;
      margin-bottom: 24px;
      box-shadow: var(--shadow-ambient);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      position: relative;
      overflow: hidden;
    }

    .account-profile-bar::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      width: 5px;
      height: 100%;
      background: linear-gradient(180deg, var(--cyan-primary), #3B82F6);
    }

    .account-profile-left {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .account-avatar {
      width: 44px;
      height: 44px;
      border-radius: 13px;
      background: linear-gradient(135deg, var(--cyan-primary), #0284C7);
      color: #FFFFFF;
      font-weight: 800;
      font-size: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px var(--cyan-glow);
      flex-shrink: 0;
    }

    .account-profile-title {
      font-family: 'Outfit', sans-serif;
      font-size: 18px;
      font-weight: 800;
      color: var(--ink);
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .account-pill-role {
      font-size: 10.5px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 6px;
      background: var(--cyan-soft);
      color: #0284C7;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .account-profile-sub {
      font-size: 12.5px;
      color: var(--ink-secondary);
      margin-top: 3px;
    }

    .account-profile-right {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .account-switcher-wrap {
      display: flex;
      align-items: center;
      gap: 8px;
      background: #F8FAFC;
      border: 1px solid var(--border-subtle);
      padding: 6px 12px;
      border-radius: 12px;
    }

    .account-select-dropdown {
      background: transparent;
      border: none;
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-size: 13px;
      font-weight: 700;
      color: var(--ink);
      outline: none;
      cursor: pointer;
    }

    .btn-manage-accounts {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--card-white);
      border: 1.5px solid var(--border-subtle);
      color: var(--ink);
      font-size: 13px;
      font-weight: 700;
      padding: 10px 16px;
      border-radius: 12px;
      text-decoration: none;
      transition: all 0.2s ease;
      box-shadow: var(--shadow-ambient);
    }
    .btn-manage-accounts:hover {
      border-color: var(--cyan-primary);
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    /* HERO BENTO SUMMARY */
    .hero-summary-grid {
      display: grid;
      grid-template-columns: repeat(12, 1fr);
      gap: 18px;
      margin-bottom: 24px;
    }

    .summary-card {
      background: var(--card-white);
      border-radius: var(--radius-bento);
      padding: 18px 22px;
      border: 1px solid var(--border-subtle);
      box-shadow: var(--shadow-ambient);
      display: flex;
      align-items: center;
      gap: 16px;
      transition: all 0.25s;
    }

    .summary-card:hover {
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    .summary-card.col-4 { grid-column: span 4; }

    @media (max-width: 900px) {
      .summary-card.col-4 { grid-column: span 12; }
      .account-profile-bar { flex-direction: column; align-items: flex-start; }
      .account-profile-right { width: 100%; justify-content: space-between; }
    }

    .summary-icon-wrapper {
      width: 48px;
      height: 48px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      flex-shrink: 0;
    }

    .summary-icon-wrapper.cyan {
      background: linear-gradient(135deg, var(--cyan-soft), #BAE6FD);
      color: #0284C7;
    }

    .summary-icon-wrapper.green {
      background: linear-gradient(135deg, var(--green-soft), #A7F3D0);
      color: #047857;
    }

    .summary-data .val {
      font-family: 'Outfit', sans-serif;
      font-size: 22px;
      font-weight: 800;
      color: var(--ink);
      line-height: 1.1;
    }

    .summary-data .lbl {
      font-size: 12.5px;
      color: var(--ink-secondary);
      margin-top: 3px;
      font-weight: 600;
    }

    /* QUICK SCENES BAR */
    .scenes-wrapper {
      margin-bottom: 24px;
    }

    .scenes-header {
      font-size: 13px;
      font-weight: 700;
      color: var(--ink-secondary);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .scenes-scroll {
      display: flex;
      align-items: center;
      gap: 10px;
      overflow-x: auto;
      padding-bottom: 6px;
    }

    .scene-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 18px;
      border-radius: 999px;
      background: var(--card-white);
      border: 1px solid var(--border-subtle);
      color: var(--ink);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      white-space: nowrap;
      box-shadow: var(--shadow-ambient);
      transition: all 0.25s;
      font-family: inherit;
    }

    .scene-pill:hover {
      border-color: var(--cyan-primary);
      color: var(--cyan-primary);
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    /* NAVIGATION TABS */
    .tab-bar {
      display: flex;
      gap: 8px;
      margin-bottom: 24px;
      background: #E5E9EC;
      padding: 6px;
      border-radius: 16px;
      width: fit-content;
    }

    .tab-btn {
      padding: 10px 22px;
      border-radius: 12px;
      border: none;
      font-family: inherit;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      background: transparent;
      color: var(--ink-secondary);
      transition: all 0.25s;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .tab-btn.active {
      background: var(--card-white);
      color: var(--ink);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06);
    }

    .tab-content { display: none; }
    .tab-content.active {
      display: block;
      animation: tabFadeIn 0.25s ease;
    }
    @keyframes tabFadeIn {
      from { opacity: 0; transform: translateY(6px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* BENTO DEVICE CARDS */
    .bento-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .bento-card {
      background: var(--card-white);
      border-radius: var(--radius-bento);
      padding: 22px;
      border: 1.5px solid var(--border-subtle);
      box-shadow: var(--shadow-ambient);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: all 0.25s ease;
      position: relative;
      overflow: hidden;
    }

    .bento-card:hover {
      transform: translateY(-3px);
      box-shadow: var(--shadow-hover);
      border-color: #CBD5E1;
    }

    .bento-card.is-active {
      border-color: var(--border-active);
      box-shadow: var(--shadow-active);
    }

    .bento-card-top {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 18px;
    }

    .device-info-header {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .device-avatar {
      width: 48px;
      height: 48px;
      border-radius: 15px;
      background: #F1F5F9;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      transition: all 0.25s;
    }

    .is-active .device-avatar {
      background: linear-gradient(135deg, var(--cyan-soft), #BAE6FD);
      color: var(--cyan-primary);
      box-shadow: 0 4px 12px var(--cyan-glow);
    }

    .device-title {
      font-size: 16px;
      font-weight: 800;
      color: var(--ink);
    }

    .device-category {
      font-size: 12px;
      color: var(--ink-secondary);
      margin-top: 2px;
    }

    .device-plc-pill {
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      color: #0284C7;
      background: var(--cyan-soft);
      padding: 2px 7px;
      border-radius: 6px;
      display: inline-block;
      margin-top: 4px;
      font-weight: 700;
    }

    .status-badge {
      font-size: 11.5px;
      font-weight: 800;
      padding: 5px 12px;
      border-radius: 999px;
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }

    .status-badge.on {
      background: var(--green-soft);
      color: #047857;
      border: 1px solid rgba(16, 185, 129, 0.3);
    }

    .status-badge.off {
      background: #F1F5F9;
      color: var(--ink-dim);
      border: 1px solid var(--border-subtle);
    }

    .tactile-switch-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 14px;
      background: #F8FAFC;
      border-radius: 14px;
      border: 1px solid var(--border-subtle);
      margin-bottom: 16px;
    }

    .tactile-switch-label {
      font-size: 13px;
      font-weight: 700;
      color: var(--ink-secondary);
    }

    .ios-switch {
      position: relative;
      display: inline-block;
      width: 50px;
      height: 28px;
      cursor: pointer;
    }

    .ios-switch input { opacity: 0; width: 0; height: 0; }
    .ios-slider {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #CBD5E1;
      transition: 0.25s;
      border-radius: 34px;
    }
    .ios-slider:before {
      position: absolute;
      content: "";
      height: 22px;
      width: 22px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      transition: 0.25s;
      border-radius: 50%;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    }
    input:checked + .ios-slider {
      background-color: var(--cyan-primary);
      box-shadow: 0 0 12px var(--cyan-glow);
    }
    input:checked + .ios-slider:before {
      transform: translateX(22px);
    }

    /* DIMMER SLIDER */
    .dimmer-card {
      background: #F8FAFC;
      padding: 12px 14px;
      border-radius: 14px;
      border: 1px solid var(--border-subtle);
      margin-bottom: 16px;
    }
    .dimmer-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      color: var(--ink-secondary);
      font-weight: 700;
      margin-bottom: 10px;
    }
    .dimmer-value {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      font-weight: 800;
      color: var(--cyan-primary);
      background: var(--card-white);
      padding: 2px 7px;
      border-radius: 6px;
      border: 1px solid var(--border-subtle);
    }
    .modern-slider {
      width: 100%;
      height: 7px;
      -webkit-appearance: none;
      background: #E2E8F0;
      border-radius: 6px;
      outline: none;
    }
    .modern-slider::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: var(--cyan-primary);
      cursor: pointer;
      box-shadow: 0 2px 6px var(--cyan-glow);
    }

    .card-actions-row {
      display: flex;
      gap: 10px;
      margin-top: 10px;
    }

    .btn-action {
      flex: 1;
      padding: 10px 14px;
      border-radius: var(--radius-btn);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      transition: all 0.2s;
      font-family: inherit;
    }
    .btn-action.primary {
      background: var(--ink);
      color: white;
    }
    .btn-action.primary:hover {
      background: #1E293B;
      transform: translateY(-1px);
    }
    .btn-action.outline {
      background: transparent;
      border: 1px solid var(--border-subtle);
      color: var(--ink);
    }
    .btn-action.outline:hover {
      background: #F8FAFC;
    }

    /* VISUAL PLC STUDIO */
    .plc-studio-card {
      background: var(--plc-bg);
      color: var(--plc-text);
      border-radius: var(--radius-bento);
      padding: 24px;
      box-shadow: 0 16px 50px rgba(0,0,0,0.35);
      border: 1px solid #282E40;
      font-family: 'JetBrains Mono', monospace;
      margin-bottom: 30px;
    }

    .plc-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 16px;
      border-bottom: 1px solid #282E40;
      margin-bottom: 20px;
      flex-wrap: wrap;
      gap: 12px;
    }

    .plc-title {
      font-size: 18px;
      font-weight: 800;
      color: #F4B8E4;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .plc-badge {
      font-size: 11px;
      background: #202434;
      color: #93C5FD;
      padding: 6px 14px;
      border-radius: 8px;
      border: 1px solid rgba(147, 197, 253, 0.2);
    }

    .rungs-container {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .rung-row {
      background: var(--plc-card);
      border-radius: 16px;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      position: relative;
      border: 1px solid #2C3348;
      transition: all 0.2s ease;
    }

    .rung-num {
      width: 70px;
      font-size: 12px;
      color: #94A3B8;
      font-weight: 700;
    }

    .ladder-circuit {
      flex: 1;
      display: flex;
      align-items: center;
      padding: 0 14px;
    }

    .power-rail-left, .power-rail-right {
      width: 4px;
      height: 38px;
      background: #E2E8F0;
      border-radius: 2px;
    }

    .wire {
      height: 2px;
      background: var(--plc-wire);
      width: 24px;
    }
    .wire.active {
      background: var(--plc-wire-active);
      box-shadow: 0 0 8px rgba(52, 211, 153, 0.6);
    }

    .ladder-element {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 4px 10px;
      cursor: pointer;
      border-radius: 8px;
      transition: all 0.15s ease;
    }
    .ladder-element:hover {
      background: rgba(255, 255, 255, 0.05);
    }

    .elem-symbol {
      font-size: 15px;
      color: #64748B;
      font-weight: 700;
    }
    .elem-symbol.active {
      color: var(--plc-wire-active);
      text-shadow: 0 0 10px rgba(52, 211, 153, 0.8);
    }

    .elem-label {
      font-size: 11px;
      color: #CBD5E1;
      margin-top: 3px;
      font-weight: 700;
    }

    .elem-addr {
      font-size: 10px;
      color: #93C5FD;
      font-family: inherit;
    }

    .rung-desc {
      width: 170px;
      text-align: right;
      padding-left: 14px;
    }

    /* RECENT LOGS */
    .section-title {
      font-size: 16px;
      font-weight: 800;
      color: var(--ink);
      margin-bottom: 14px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .logs-card {
      background: var(--card-white);
      border-radius: var(--radius-bento);
      box-shadow: var(--shadow-ambient);
      border: 1px solid var(--border-subtle);
      overflow: hidden;
    }

    .logs-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }

    .logs-table th {
      background: #F8FAFC;
      padding: 14px 20px;
      text-align: left;
      font-weight: 700;
      color: var(--ink-secondary);
      border-bottom: 1px solid var(--border-subtle);
      font-size: 12px;
      text-transform: uppercase;
    }

    .logs-table td {
      padding: 14px 20px;
      border-bottom: 1px solid var(--border-subtle);
    }

    .logs-table tr:last-child td { border-bottom: none; }

    .badge-source {
      background: #F1F5F9;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      color: var(--ink-secondary);
    }
  </style>
</head>
<body>

<div class="container">
  <!-- TOP APP HEADER -->
  <header class="app-header">
    <div class="header-left">
      <button class="lang-toggle-btn" id="langToggleBtn" onclick="toggleLanguage()" title="Ganti bahasa">
        <span class="flag" id="langFlag">🇮🇩</span>
        <span id="langLabel">ID</span>
        <span class="lang-badge" id="langNext">→ EN</span>
      </button>

      <div>
        <h1 class="brand-title">
          <span class="logo-badge">⚡</span>
          NEXORA <span class="accent">Home OS</span>
        </h1>
        <p class="brand-sub" id="txtBrandSub">Platform Web IoT & Visual PLC Studio Alfa</p>
      </div>
    </div>

    <div class="header-right">
      <div class="status-pill">
        <div class="pulse-dot"></div>
        <span id="connStatus">SINKRON LIVE</span>
      </div>
      <div class="clock-display" id="liveClock"></div>
    </div>
  </header>

  <!-- ========================================================================= -->
  <!-- 👤 ACCOUNT PROFILE BAR (HEADER PROFIL AKUN DINAMIS & QUICK SWITCHER)      -->
  <!-- ========================================================================= -->
  <section class="account-profile-bar">
    <div class="account-profile-left">
      <div class="account-avatar" id="accAvatarBadge">RA</div>
      <div>
        <div class="account-profile-title">
          <span id="accOwnerName">Memuat profil akun...</span>
          <span class="account-pill-role" id="accRoleTag">AKUN</span>
        </div>
        <div class="account-profile-sub">
          Mesin: <b id="accHwTag" style="color: var(--cyan-primary);">-</b> • ID: <code id="accIdTag">-</code> • Topic Prefix: <code id="accPrefixTag">-</code>
        </div>
      </div>
    </div>

    <div class="account-profile-right">
      <div class="account-switcher-wrap">
        <span style="font-size: 11px; font-weight: 800; color: var(--ink-dim); text-transform: uppercase;">Ganti Profil:</span>
        <select id="accountDropdownSelect" class="account-select-dropdown" onchange="switchAccountProfile(this.value)">
          <!-- Populated by JavaScript -->
        </select>
      </div>
      <a href="index.php" class="btn-manage-accounts" style="background: var(--ink); color: #FFFFFF;" title="Kembali ke Halaman Utama Tabel Akun">
        <span>👥</span> Kembali ke Tabel Akun
      </a>
      <a href="settings.php" class="btn-manage-accounts" title="Buka Halaman Pengaturan Broker & Hardware">
        <span>⚙️</span> Pengaturan Broker
      </a>
    </div>
  </section>

  <!-- BENTO SUMMARY METRICS -->
  <div class="hero-summary-grid">
    <div class="summary-card col-4">
      <div class="summary-icon-wrapper cyan">⚡</div>
      <div class="summary-data">
        <div class="val" id="statActiveDevices">0 / 0</div>
        <div class="lbl" id="lblStatActive">Perangkat Menyala</div>
      </div>
    </div>

    <div class="summary-card col-4">
      <div class="summary-icon-wrapper green">🚀</div>
      <div class="summary-data">
        <div class="val">0 ms</div>
        <div class="lbl" id="lblStatLatency">Latensi Optimistik</div>
      </div>
    </div>

    <div class="summary-card col-4">
      <div class="summary-icon-wrapper cyan">🏭</div>
      <div class="summary-data">
        <div class="val" id="statEngineVal">Controller Hub</div>
        <div class="lbl" id="lblStatPlcStatus">Engine Otomasi</div>
      </div>
    </div>
  </div>

  <!-- QUICK SCENES BAR -->
  <div class="scenes-wrapper">
    <div class="scenes-header">
      <span>✨</span> <span id="lblScenesTag">Skenario Otomatis Cepat Akun Ini:</span>
    </div>
    <div class="scenes-scroll">
      <button class="scene-pill" onclick="applyScene('ALL_ON')">
        <span class="icon">💡</span> <span id="btnSceneAllOn">Nyalakan Semua</span>
      </button>
      <button class="scene-pill" onclick="applyScene('ALL_OFF')">
        <span class="icon">🌙</span> <span id="btnSceneAllOff">Matikan Semua</span>
      </button>
      <button class="scene-pill" onclick="applyScene('LEAVING_HOME')">
        <span class="icon">🚪</span> <span id="btnSceneLeaving">Keluar Rumah (Kunci & Matikan)</span>
      </button>
      <button class="scene-pill" onclick="applyScene('ARRIVING_HOME')">
        <span class="icon">🏡</span> <span id="btnSceneArriving">Pulang ke Rumah (Buka & Nyalakan)</span>
      </button>
    </div>
  </div>

  <!-- TAB SWITCHER -->
  <div class="tab-bar">
    <button class="tab-btn active" id="tabSmartHomeBtn" onclick="switchTab('smartHomeTab', this)">
      <span>🏡</span> <span id="tabSmartHomeText">Smart Home Cards</span>
    </button>
    <button class="tab-btn" id="tabPlcStudioBtn" onclick="switchTab('plcStudioTab', this)">
      <span>⚡</span> <span id="tabPlcStudioText">Visual PLC Studio (Ladder View)</span>
    </button>
  </div>

  <!-- TAB 1: BENTO SMART HOME CARDS -->
  <div id="smartHomeTab" class="tab-content active">
    <div class="bento-grid" id="devicesContainer">
      <div id="loadingDevicesTxt" style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--ink-dim);">
        Memuat status perangkat akun dari server...
      </div>
    </div>
  </div>

  <!-- TAB 2: VISUAL PLC LADDER STUDIO -->
  <div id="plcStudioTab" class="tab-content">
    <div class="plc-studio-card">
      <div class="plc-header">
        <div class="plc-title">
          <span>⚡</span> <span id="plcTitleText">Visual PLC Ladder Engine</span>
        </div>
        <div class="plc-badge" id="plcBadgeText">CYCLE TIME: 50ms • REAL-TIME SOLVER</div>
      </div>

      <div class="rungs-container" id="rungsContainer">
        <!-- Rendered dynamically by JS -->
      </div>
    </div>
  </div>

  <!-- RECENT ACTIVITY LOGS -->
  <div class="section-title">
    <span>📜</span> <span id="logsTitleText">Riwayat Perintah & Aktivitas Terakhir</span>
  </div>
  <div class="logs-card">
    <table class="logs-table">
      <thead>
        <tr>
          <th id="thTime">Waktu</th>
          <th id="thDevice">Perangkat</th>
          <th id="thAction">Aksi / Nilai</th>
          <th id="thSource">Sumber</th>
        </tr>
      </thead>
      <tbody id="logsContainer">
        <tr>
          <td colspan="4" id="loadingLogsTxt" style="text-align: center; color: var(--ink-dim); padding: 20px;">
            Memuat riwayat aktivitas...
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<script>
  const API_KEY = 'nexora_secret_token_2026';
  
  // Data Multi-Akun dari PHP / Fallback
  let SYSTEM_ACCOUNTS = <?php echo json_encode($allAccounts); ?> || [];
  let currentAccountId = <?php echo json_encode($activeAccountId); ?> || 'acc_superadmin';
  let activeAccount = null;

  // Baca URL query jika ada (?account_id=...)
  const urlParams = new URLSearchParams(window.location.search);
  const qAccId = urlParams.get('account_id');
  if (qAccId) {
    currentAccountId = qAccId;
  }

  let currentDevices = {};
  let currentLang = localStorage.getItem('nexora_lang') || 'id';

  // KAMUS BAHASA (I18N)
  const i18n = {
    id: {
      flag: '🇮🇩',
      code: 'ID',
      next: '→ EN',
      brandSub: 'Platform Web IoT & Visual PLC Studio Alfa',
      tabSmartHome: 'Smart Home Cards',
      tabPlcStudio: 'Visual PLC Studio (Ladder View)',
      plcTitle: 'Visual PLC Ladder Engine',
      plcBadge: 'CYCLE TIME: 50ms • REAL-TIME SOLVER',
      logsTitle: 'Riwayat Perintah & Aktivitas Terakhir',
      thTime: 'Waktu',
      thDevice: 'Perangkat',
      thAction: 'Aksi / Nilai',
      thSource: 'Sumber',
      syncLive: 'SINKRON LIVE',
      syncOffline: 'TERPUTUS (OFFLINE)',
      loadingDevices: 'Memuat status perangkat dari server...',
      loadingLogs: 'Memuat riwayat aktivitas...',
      noLogs: 'Belum ada riwayat aktivitas.',
      btnOpen: 'Buka',
      btnClose: 'Tutup',
      btnTurnOn: 'Nyalakan',
      btnTurnOff: 'Matikan',
      btnTurnOnPump: 'Hidupkan Pompa',
      btnTurnOffPump: 'Matikan Pompa',
      brightness: 'Tingkat Kecerahan',
      energized: 'ENERGIZED (AKTIF)',
      deEnergized: 'DE-ENERGIZED (OFF)',
      clickToToggle: 'Klik untuk ubah status kontak NO',
      coilOutput: 'Koil Output Fisik Terhubung',
      lblStatActive: 'Perangkat Menyala',
      lblStatLatency: 'Latensi Optimistik',
      lblStatPlcStatus: 'Engine Otomasi',
      lblScenesTag: 'Skenario Otomatis Cepat Akun Ini:',
      btnSceneAllOn: 'Nyalakan Semua',
      btnSceneAllOff: 'Matikan Semua',
      btnSceneLeaving: 'Keluar Rumah (Kunci & Matikan)',
      btnSceneArriving: 'Pulang ke Rumah (Buka & Nyalakan)',
      states: {
        'ON': 'MENYALA',
        'OFF': 'PADAM / MATI',
        'TERBUKA': 'TERBUKA',
        'TERTUTUP': 'TERTUTUP',
        'BUKA': 'TERBUKA',
        'TUTUP': 'TERTUTUP'
      }
    },
    en: {
      flag: '🇬🇧',
      code: 'EN',
      next: '→ ID',
      brandSub: 'IoT Web Platform & Visual PLC Studio Alfa',
      tabSmartHome: 'Smart Home Cards',
      tabPlcStudio: 'Visual PLC Studio (Ladder View)',
      plcTitle: 'Visual PLC Ladder Engine',
      plcBadge: 'CYCLE TIME: 50ms • REAL-TIME SOLVER',
      logsTitle: 'Recent Command & Activity Logs',
      thTime: 'Time',
      thDevice: 'Device',
      thAction: 'Action / Value',
      thSource: 'Source',
      syncLive: 'LIVE SYNC',
      syncOffline: 'OFFLINE',
      loadingDevices: 'Loading devices status from server...',
      loadingLogs: 'Loading activity logs...',
      noLogs: 'No activity logs found.',
      btnOpen: 'Open',
      btnClose: 'Close',
      btnTurnOn: 'Turn On',
      btnTurnOff: 'Turn Off',
      btnTurnOnPump: 'Start Pump',
      btnTurnOffPump: 'Stop Pump',
      brightness: 'Brightness Level',
      energized: 'ENERGIZED (ACTIVE)',
      deEnergized: 'DE-ENERGIZED (OFF)',
      clickToToggle: 'Click to toggle NO contact',
      coilOutput: 'Connected Hardware Coil Output',
      lblStatActive: 'Active Devices',
      lblStatLatency: 'Optimistic Latency',
      lblStatPlcStatus: 'Automation Engine',
      lblScenesTag: 'Quick Automatic Scenes for this Account:',
      btnSceneAllOn: 'Turn All On',
      btnSceneAllOff: 'Turn All Off',
      btnSceneLeaving: 'Leaving Home (Lock & Turn Off)',
      btnSceneArriving: 'Arriving Home (Open & Turn On)',
      states: {
        'ON': 'ON',
        'OFF': 'OFF',
        'TERBUKA': 'OPEN',
        'TERTUTUP': 'CLOSED',
        'BUKA': 'OPEN',
        'TUTUP': 'CLOSED'
      }
    }
  };

  function toggleLanguage() {
    currentLang = currentLang === 'id' ? 'en' : 'id';
    localStorage.setItem('nexora_lang', currentLang);
    applyLanguage();
  }

  function applyLanguage() {
    const t = i18n[currentLang];
    document.getElementById('langFlag').innerText = t.flag;
    document.getElementById('langLabel').innerText = t.code;
    document.getElementById('langNext').innerText = t.next;
    document.getElementById('txtBrandSub').innerText = t.brandSub;

    document.getElementById('lblStatActive').innerText = t.lblStatActive;
    document.getElementById('lblStatLatency').innerText = t.lblStatLatency;
    document.getElementById('lblStatPlcStatus').innerText = t.lblStatPlcStatus;

    document.getElementById('lblScenesTag').innerText = t.lblScenesTag;
    document.getElementById('btnSceneAllOn').innerText = t.btnSceneAllOn;
    document.getElementById('btnSceneAllOff').innerText = t.btnSceneAllOff;
    document.getElementById('btnSceneLeaving').innerText = t.btnSceneLeaving;
    document.getElementById('btnSceneArriving').innerText = t.btnSceneArriving;

    document.getElementById('tabSmartHomeText').innerText = t.tabSmartHome;
    document.getElementById('tabPlcStudioText').innerText = t.tabPlcStudio;
    document.getElementById('plcTitleText').innerText = t.plcTitle;
    document.getElementById('plcBadgeText').innerText = t.plcBadge;

    document.getElementById('logsTitleText').innerText = t.logsTitle;
    document.getElementById('thTime').innerText = t.thTime;
    document.getElementById('thDevice').innerText = t.thDevice;
    document.getElementById('thAction').innerText = t.thAction;
    document.getElementById('thSource').innerText = t.thSource;

    if (Object.keys(currentDevices).length > 0) {
      renderDevices(currentDevices);
      renderVisualLadder(currentDevices);
      updateSummaryStats(currentDevices);
    }
  }

  // =========================================================================
  // 👤 ACCOUNT PROFILE & SWITCHER CONTROLLER
  // =========================================================================
  function getInitials(name) {
    if (!name) return '??';
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  function setupAccountProfile() {
    // Cari data akun aktif
    activeAccount = SYSTEM_ACCOUNTS.find(a => a.id === currentAccountId);
    if (!activeAccount && SYSTEM_ACCOUNTS.length > 0) {
      activeAccount = SYSTEM_ACCOUNTS[0];
      currentAccountId = activeAccount.id;
    }

    if (activeAccount) {
      document.getElementById('accAvatarBadge').innerText = getInitials(activeAccount.name);
      document.getElementById('accOwnerName').innerText = activeAccount.name;
      document.getElementById('accRoleTag').innerText = (activeAccount.role || 'user').toUpperCase();
      document.getElementById('accHwTag').innerText = activeAccount.hardware_type || 'Raspberry Pi 4';
      document.getElementById('accIdTag').innerText = activeAccount.id;
      document.getElementById('accPrefixTag').innerText = activeAccount.mqtt_prefix || 'alrisa/' + activeAccount.id;
      document.getElementById('statEngineVal').innerText = activeAccount.hardware_type.includes('PLC') ? 'Mitsubishi FX5U' : 'Raspberry Pi 4';

      // Isi Dropdown Switcher
      const sel = document.getElementById('accountDropdownSelect');
      sel.innerHTML = '';
      SYSTEM_ACCOUNTS.forEach(acc => {
        const opt = document.createElement('option');
        opt.value = acc.id;
        opt.innerText = `${acc.name} (${acc.hardware_type})`;
        if (acc.id === currentAccountId) opt.selected = true;
        sel.appendChild(opt);
      });
    }
  }

  function switchAccountProfile(newAccId) {
    if (newAccId === currentAccountId) return;
    // Redirect ke URL dengan query param baru
    const url = new URL(window.location.href);
    url.searchParams.set('account_id', newAccId);
    window.location.href = url.toString();
  }

  // TAB SWITCHER
  function switchTab(tabId, btn) {
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
    document.getElementById(tabId).classList.add('active');
    btn.classList.add('active');
  }

  function updateClock() {
    const now = new Date();
    const localeStr = currentLang === 'id' ? 'id-ID' : 'en-US';
    const tzStr = currentLang === 'id' ? ' WIB' : ' (UTC+7)';
    document.getElementById('liveClock').innerText = now.toLocaleTimeString(localeStr, { hour: '2-digit', minute: '2-digit', second: '2-digit' }) + tzStr;
  }
  setInterval(updateClock, 1000);
  updateClock();

  function updateSummaryStats(devices) {
    let activeCount = 0;
    const total = Object.keys(devices).length || 0;
    for (const key in devices) {
      const d = devices[key];
      if (d.state === 'ON' || d.state === 'BUKA' || d.state === 'TERBUKA' || (d.value && d.value > 0)) {
        activeCount++;
      }
    }
    const statElem = document.getElementById('statActiveDevices');
    if (statElem) {
      statElem.innerText = `${activeCount} / ${total}`;
    }
  }

  // FETCH DEVICES STATUS DARI BACKEND
  async function fetchDevices() {
    const t = i18n[currentLang];
    
    // Inisialisasi daftar perangkat spesifik milik akun yang sedang dibuka
    const devMap = {};
    if (activeAccount && activeAccount.devices) {
      activeAccount.devices.forEach(d => {
        devMap[d.id] = {
          id: d.id,
          name: d.name,
          category: d.category || 'Umum',
          type: d.type,
          state: d.isActive ? 'ON' : 'OFF',
          value: d.value || 0,
          plc_address: d.hardwarePin || 'GPIO 2'
        };
      });
    }

    try {
      const res = await fetch(`api/devices.php?account_id=${currentAccountId}`);
      const data = await res.json();
      if (data.success && data.devices) {
        // Gabungkan status live dari server untuk perangkat akun ini
        for (const k in data.devices) {
          if (devMap[k]) {
            devMap[k].state = data.devices[k].state;
            devMap[k].value = data.devices[k].value;
            devMap[k].pending_command = data.devices[k].pending_command;
          } else if (Object.keys(devMap).length === 0) {
            devMap[k] = data.devices[k];
          }
        }
        if (data.recent_logs) renderLogs(data.recent_logs);
        document.getElementById('connStatus').innerText = t.syncLive;
      }
    } catch (e) {
      document.getElementById('connStatus').innerText = t.syncOffline;
    }

    currentDevices = devMap;
    renderDevices(devMap);
    renderVisualLadder(devMap);
    updateSummaryStats(devMap);
  }

  // RENDER BENTO SMART HOME CARDS (SESUAI PERANGKAT AKUN AKTIF)
  function renderDevices(devices) {
    const t = i18n[currentLang];
    const container = document.getElementById('devicesContainer');
    let html = '';

    const devKeys = Object.keys(devices);
    if (devKeys.length === 0) {
      container.innerHTML = `<div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--ink-dim);">Belum ada perangkat terdaftar pada akun ini. Buka <b>Tabel Akun & Pengaturan</b> untuk menambah perangkat.</div>`;
      return;
    }

    for (const key of devKeys) {
      const d = devices[key];
      const isAktif = d.state === 'ON' || d.state === 'BUKA' || d.state === 'TERBUKA' || (d.value && d.value > 0);
      const stateBadgeClass = isAktif ? 'on' : 'off';
      
      let devIcon = '⚡';
      if (d.type === 0 || d.id.includes('pagar') || d.id.includes('gerbang')) devIcon = '🚪';
      else if (d.type === 1 || d.id.includes('lampu')) devIcon = '💡';
      else if (d.type === 2 || d.id.includes('pintu')) devIcon = '🚪';
      else if (d.type === 3 || d.id.includes('gorden')) devIcon = '🪟';
      else if (d.type === 4 || d.id.includes('pompa')) devIcon = '💧';

      const devName = d.name;
      const devCategory = d.category || 'Smart Device';
      const stateKey = (d.state || '').toUpperCase();
      const displayState = t.states[stateKey] || d.state;

      let actionButtons = '';
      if (d.type === 0 || d.type === 2 || d.type === 3 || d.id.includes('pagar') || d.id.includes('pintu') || d.id.includes('gorden')) {
        actionButtons = `
          <button class="btn-action primary" onclick="sendCommand('${d.id}', 'BUKA')">${t.btnOpen}</button>
          <button class="btn-action outline" onclick="sendCommand('${d.id}', 'TUTUP')">${t.btnClose}</button>
        `;
      } else if (d.type === 1 || d.id.includes('lampu')) {
        actionButtons = `
          <button class="btn-action ${isAktif ? 'outline' : 'primary'}" onclick="sendCommand('${d.id}', '${isAktif ? 'OFF' : 'ON'}')">
            ${isAktif ? t.btnTurnOff : t.btnTurnOn}
          </button>
        `;
      } else {
        actionButtons = `
          <button class="btn-action ${isAktif ? 'outline' : 'primary'}" onclick="sendCommand('${d.id}', '${isAktif ? 'OFF' : 'ON'}')">
            ${isAktif ? t.btnTurnOffPump : t.btnTurnOnPump}
          </button>
        `;
      }

      let sliderHtml = '';
      if (d.type === 1 || d.id.includes('lampu')) {
        sliderHtml = `
          <div class="dimmer-card">
            <div class="dimmer-header">
              <span>${t.brightness}</span>
              <span class="dimmer-value" id="sliderVal_${d.id}">${d.value || 0}%</span>
            </div>
            <input type="range" class="modern-slider" min="0" max="100" value="${d.value || 0}" 
              oninput="document.getElementById('sliderVal_${d.id}').innerText = this.value + '%'"
              onchange="sendCommand('${d.id}', 'SET_BRIGHTNESS', this.value)">
          </div>
        `;
      }

      const switchChecked = isAktif ? 'checked' : '';
      const toggleTargetAction = (d.type === 0 || d.type === 2 || d.type === 3 || d.id.includes('pagar') || d.id.includes('pintu') || d.id.includes('gorden'))
        ? (isAktif ? 'TUTUP' : 'BUKA') 
        : (isAktif ? 'OFF' : 'ON');

      html += `
        <div class="bento-card ${isAktif ? 'is-active' : ''}">
          <div>
            <div class="bento-card-top">
              <div class="device-info-header">
                <div class="device-avatar">${devIcon}</div>
                <div>
                  <div class="device-title">${devName}</div>
                  <div class="device-category">${devCategory}</div>
                  <div class="device-plc-pill">PIN: ${d.plc_address || 'Virtual'}</div>
                </div>
              </div>
              <div class="status-badge ${stateBadgeClass}">
                ${d.pending_command ? '⏳ ' + d.pending_command : displayState}
              </div>
            </div>

            <!-- TACTILE TOGGLE SWITCH -->
            <div class="tactile-switch-row">
              <span class="tactile-switch-label">${displayState}</span>
              <label class="ios-switch">
                <input type="checkbox" ${switchChecked} onchange="sendCommand('${d.id}', '${toggleTargetAction}')">
                <span class="ios-slider"></span>
              </label>
            </div>

            ${sliderHtml}
          </div>

          <div class="card-actions-row">
            ${actionButtons}
          </div>
        </div>
      `;
    }

    container.innerHTML = html;
  }

  // RENDER VISUAL LADDER DIAGRAM (DINAMIS SESUAI REGISTER AKUN)
  function renderVisualLadder(devices) {
    const t = i18n[currentLang];
    const container = document.getElementById('rungsContainer');
    const devKeys = Object.keys(devices);

    if (devKeys.length === 0) {
      container.innerHTML = `<div style="text-align: center; color: var(--plc-text-dim); padding: 30px;">Tidak ada rung ladder untuk akun ini.</div>`;
      return;
    }

    let html = '';
    devKeys.forEach((devId, idx) => {
      const dev = devices[devId] || {};
      const isAktif = dev.state === 'ON' || dev.state === 'BUKA' || dev.state === 'TERBUKA' || (dev.value && dev.value > 0);
      const wireClass = isAktif ? 'active' : '';
      const symClass = isAktif ? 'active' : '';
      
      const inAddr = `%IX0.${idx}`;
      const outAddr = dev.plc_address || `%QX0.${idx}`;
      const inName = `CMD_${devId.toUpperCase()}`;
      const outName = `${devId.toUpperCase()}_OUT`;

      html += `
        <div class="rung-row">
          <div class="rung-num">RUNG ${idx}</div>
          
          <div class="ladder-circuit">
            <div class="power-rail-left"></div>
            <div class="wire ${wireClass}"></div>
            
            <!-- Kontak NO Input -->
            <div class="ladder-element" onclick="toggleLadderContact('${devId}', ${isAktif})" title="${t.clickToToggle}">
              <div class="elem-symbol ${symClass}">${isAktif ? '—[ ● ]—' : '—[   ]—'}</div>
              <div class="elem-label">${inName}</div>
              <div class="elem-addr">${inAddr}</div>
            </div>

            <div class="wire ${wireClass}" style="flex: 1;"></div>

            <!-- Koil Output -->
            <div class="ladder-element" onclick="toggleLadderContact('${devId}', ${isAktif})" title="${t.coilOutput}">
              <div class="elem-symbol ${symClass}">${isAktif ? '—( ● )—' : '—(   )—'}</div>
              <div class="elem-label">${outName}</div>
              <div class="elem-addr">${outAddr}</div>
            </div>

            <div class="wire ${wireClass}"></div>
            <div class="power-rail-right"></div>
          </div>

          <div class="rung-desc">
            <div style="font-weight: 700; color: ${isAktif ? '#34D399' : '#94A3B8'}; font-size: 13px;">${isAktif ? t.energized : t.deEnergized}</div>
            <div style="font-size: 11px; margin-top: 2px; color: #94A3B8;">${dev.name}</div>
          </div>
        </div>
      `;
    });

    container.innerHTML = html;
  }

  function toggleLadderContact(devId, currentlyActive) {
    const dev = currentDevices[devId];
    let action = '';
    if (dev && (dev.type === 0 || dev.type === 2 || dev.type === 3 || devId.includes('pagar') || devId.includes('pintu') || devId.includes('gorden'))) {
      action = currentlyActive ? 'TUTUP' : 'BUKA';
    } else {
      action = currentlyActive ? 'OFF' : 'ON';
    }
    sendCommand(devId, action);
  }

  function renderLogs(logs) {
    const t = i18n[currentLang];
    const container = document.getElementById('logsContainer');
    if (!logs || logs.length === 0) {
      container.innerHTML = `<tr><td colspan="4" style="text-align: center; color: var(--ink-dim); padding: 18px;">${t.noLogs}</td></tr>`;
      return;
    }

    container.innerHTML = logs.map(l => `
      <tr>
        <td style="color: var(--ink-secondary); font-family: 'JetBrains Mono', monospace; font-size: 12px;">${l.timestamp}</td>
        <td><strong>${(l.device_id || '').toUpperCase()}</strong></td>
        <td>${l.action}</td>
        <td><span class="badge-source">${l.source || 'Web'}</span></td>
      </tr>
    `).join('');
  }

  // KIRIM PERINTAH DENGAN 0-DELAY OPTIMISTIC UI & SINKRONISASI AKUN
  async function sendCommand(deviceId, action, value = null) {
    // 1. INSTANT ZERO-LATENCY UI UPDATE
    if (currentDevices[deviceId]) {
      if (action === 'BUKA' || action === 'ON') {
        currentDevices[deviceId].state = action === 'BUKA' ? 'TERBUKA' : 'ON';
      } else if (action === 'TUTUP' || action === 'OFF') {
        currentDevices[deviceId].state = action === 'TUTUP' ? 'TERTUTUP' : 'OFF';
      } else if (action === 'SET_BRIGHTNESS' && value !== null) {
        currentDevices[deviceId].value = parseInt(value);
        currentDevices[deviceId].state = parseInt(value) > 0 ? 'ON' : 'OFF';
      }
      renderVisualLadder(currentDevices);
      renderDevices(currentDevices);
      updateSummaryStats(currentDevices);
    }

    // 2. DISPATCH ASYNC HTTP KE BACKEND
    try {
      const payload = {
        device_id: deviceId,
        action: action,
        value: value !== null ? parseInt(value) : null,
        account_id: currentAccountId,
        source: `Web Dashboard (${activeAccount ? activeAccount.name : currentAccountId})`
      };

      fetch('api/control.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': API_KEY
        },
        body: JSON.stringify(payload)
      }).catch(err => console.error(err));
    } catch (e) {
      console.error("Gagal kirim kontrol:", e);
    }
  }

  // PRESET SCENES KHUSUS PERANGKAT AKUN AKTIF
  function applyScene(sceneName) {
    const devKeys = Object.keys(currentDevices);
    devKeys.forEach(id => {
      const d = currentDevices[id];
      const isGate = d.type === 0 || d.type === 2 || d.type === 3 || id.includes('pagar') || id.includes('pintu') || id.includes('gorden');
      
      if (sceneName === 'ALL_ON') {
        sendCommand(id, isGate ? 'BUKA' : 'ON');
      } else if (sceneName === 'ALL_OFF') {
        sendCommand(id, isGate ? 'TUTUP' : 'OFF');
      } else if (sceneName === 'LEAVING_HOME') {
        sendCommand(id, isGate ? 'TUTUP' : 'OFF');
      } else if (sceneName === 'ARRIVING_HOME') {
        if (isGate) sendCommand(id, 'BUKA');
        if (d.type === 1 || id.includes('lampu')) {
          sendCommand(id, 'ON');
          sendCommand(id, 'SET_BRIGHTNESS', 100);
        }
      }
    });
  }

  // Inisialisasi awal
  setupAccountProfile();
  applyLanguage();
  fetchDevices();
  setInterval(fetchDevices, 2000);
</script>

</body>
</html>
