<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NEXORA Home OS — Smart Home & Visual PLC Studio</title>
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
      --card-glass: rgba(255, 255, 255, 0.82);
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
      
      --radius-bento: 26px;
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
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 16px;
      padding-bottom: 20px;
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

    .lang-toggle-btn .flag {
      font-size: 18px;
    }

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

    /* HERO BENTO SUMMARY & STATUS (Apple Home Style) */
    .hero-summary-grid {
      display: grid;
      grid-template-columns: repeat(12, 1fr);
      gap: 18px;
      margin-bottom: 26px;
    }

    .summary-card {
      background: var(--card-white);
      border-radius: var(--radius-bento);
      padding: 20px 24px;
      border: 1px solid var(--border-subtle);
      box-shadow: var(--shadow-ambient);
      display: flex;
      align-items: center;
      gap: 18px;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
      overflow: hidden;
    }

    .summary-card:hover {
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    .summary-card.col-4 { grid-column: span 4; }
    .summary-card.col-8 { grid-column: span 8; }

    @media (max-width: 900px) {
      .summary-card.col-4, .summary-card.col-8 { grid-column: span 12; }
    }

    .summary-icon-wrapper {
      width: 52px;
      height: 52px;
      border-radius: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
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
      font-size: 24px;
      font-weight: 800;
      color: var(--ink);
      line-height: 1.1;
      letter-spacing: -0.5px;
    }

    .summary-data .lbl {
      font-size: 13px;
      color: var(--ink-secondary);
      margin-top: 4px;
      font-weight: 600;
    }

    /* QUICK SCENES BAR (Apple Home Shortcuts) */
    .scenes-wrapper {
      margin-bottom: 26px;
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
      gap: 12px;
      overflow-x: auto;
      padding-bottom: 6px;
      scrollbar-width: none;
    }

    .scenes-scroll::-webkit-scrollbar { display: none; }

    .scene-pill {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 10px 20px;
      border-radius: 999px;
      background: var(--card-white);
      border: 1px solid var(--border-subtle);
      color: var(--ink);
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      white-space: nowrap;
      box-shadow: var(--shadow-ambient);
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      user-select: none;
      font-family: inherit;
    }

    .scene-pill:hover {
      background: #FFFFFF;
      border-color: var(--cyan-primary);
      color: var(--cyan-primary);
      transform: translateY(-2px);
      box-shadow: var(--shadow-hover);
    }

    .scene-pill:active {
      transform: scale(0.96);
    }

    .scene-pill .icon {
      font-size: 16px;
    }

    /* NAVIGATION TABS (Bento Switcher) */
    .tab-bar {
      display: flex;
      gap: 8px;
      margin-bottom: 26px;
      background: #E5E9EC;
      padding: 6px;
      border-radius: 18px;
      width: fit-content;
    }

    .tab-btn {
      padding: 10px 24px;
      border-radius: 13px;
      border: none;
      font-family: inherit;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      background: transparent;
      color: var(--ink-secondary);
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      display: flex;
      align-items: center;
      gap: 8px;
      user-select: none;
    }

    .tab-btn.active {
      background: var(--card-white);
      color: var(--ink);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06);
    }

    .tab-content {
      display: none;
    }

    .tab-content.active {
      display: block;
      animation: tabFadeIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }

    @keyframes tabFadeIn {
      from { opacity: 0; transform: translateY(6px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* ========================================================= */
    /* BENTO DEVICE CARDS (APPLE HOME 2026 INSPIRATION)          */
    /* ========================================================= */
    .bento-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
      gap: 22px;
      margin-bottom: 40px;
    }

    .bento-card {
      background: var(--card-white);
      border-radius: var(--radius-bento);
      padding: 24px;
      border: 1px solid var(--border-subtle);
      box-shadow: var(--shadow-ambient);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
      overflow: hidden;
    }

    .bento-card:hover {
      transform: translateY(-4px);
      box-shadow: var(--shadow-hover);
    }

    .bento-card.is-active {
      border-color: var(--border-active);
      box-shadow: var(--shadow-active);
      background: linear-gradient(180deg, #FFFFFF 0%, #F8FBFE 100%);
    }

    /* Ambient Glow on Card Activation */
    .bento-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: transparent;
      transition: background 0.3s ease;
    }

    .bento-card.is-active::before {
      background: linear-gradient(90deg, var(--cyan-primary), var(--green-active));
    }

    /* Device Card Top Header */
    .bento-card-top {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 20px;
    }

    .device-info-header {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .device-avatar {
      width: 52px;
      height: 52px;
      border-radius: 18px;
      background: #F1F5F9;
      color: var(--ink-secondary);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      flex-shrink: 0;
      border: 1px solid rgba(0, 0, 0, 0.03);
    }

    .bento-card.is-active .device-avatar {
      background: linear-gradient(135deg, var(--cyan-soft), #BAE6FD);
      color: #0284C7;
      transform: scale(1.05);
      box-shadow: 0 6px 18px var(--cyan-glow);
    }

    .device-title {
      font-family: 'Outfit', sans-serif;
      font-size: 18px;
      font-weight: 700;
      color: var(--ink);
      letter-spacing: -0.3px;
      line-height: 1.2;
    }

    .device-category {
      font-size: 11px;
      color: var(--ink-dim);
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-top: 2px;
    }

    .device-plc-pill {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: 10px;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 700;
      background: #F1F5F9;
      color: var(--ink-secondary);
      padding: 3px 8px;
      border-radius: 6px;
      margin-top: 4px;
    }

    /* Status Badge */
    .status-badge {
      font-size: 11px;
      font-weight: 800;
      padding: 6px 14px;
      border-radius: 999px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      transition: all 0.25s ease;
      white-space: nowrap;
    }

    .status-badge.on {
      background: var(--green-soft);
      color: #047857;
      border: 1px solid rgba(16, 185, 129, 0.3);
      box-shadow: 0 2px 10px var(--green-glow);
    }

    .status-badge.off {
      background: #F1F5F9;
      color: var(--ink-secondary);
      border: 1px solid transparent;
    }

    /* SMOOTH TACTILE TOGGLE SWITCH (Zero-Delay) */
    .tactile-switch-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 16px;
      background: #F8FAFC;
      border-radius: 16px;
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
      width: 52px;
      height: 30px;
      cursor: pointer;
    }

    .ios-switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }

    .ios-slider {
      position: absolute;
      cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #CBD5E1;
      transition: 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      border-radius: 34px;
    }

    .ios-slider:before {
      position: absolute;
      content: "";
      height: 24px;
      width: 24px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      transition: 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      border-radius: 50%;
      box-shadow: 0 2px 6px rgba(0,0,0,0.18);
    }

    input:checked + .ios-slider {
      background-color: var(--cyan-primary);
      box-shadow: 0 0 14px var(--cyan-glow);
    }

    input:checked + .ios-slider:before {
      transform: translateX(22px);
    }

    /* DIMMER / SLIDER SECTION */
    .dimmer-card {
      background: #F8FAFC;
      padding: 14px 16px;
      border-radius: 16px;
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
      margin-bottom: 12px;
    }

    .dimmer-value {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      font-weight: 800;
      color: var(--cyan-primary);
      background: var(--card-white);
      padding: 2px 8px;
      border-radius: 6px;
      border: 1px solid var(--border-subtle);
    }

    .modern-slider {
      width: 100%;
      height: 8px;
      -webkit-appearance: none;
      background: #E2E8F0;
      border-radius: 6px;
      outline: none;
    }

    .modern-slider::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 22px;
      height: 22px;
      border-radius: 50%;
      background: var(--cyan-primary);
      cursor: pointer;
      box-shadow: 0 2px 10px var(--cyan-glow);
      transition: transform 0.15s ease;
    }

    .modern-slider::-webkit-slider-thumb:hover {
      transform: scale(1.15);
    }

    /* CARD ACTION BUTTONS */
    .card-actions-row {
      display: flex;
      gap: 10px;
      margin-top: 6px;
    }

    .btn-action {
      flex: 1;
      padding: 12px 16px;
      border-radius: var(--radius-btn);
      border: none;
      font-weight: 700;
      font-size: 13px;
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
      font-family: inherit;
      user-select: none;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
    }

    .btn-action:active {
      transform: scale(0.97);
    }

    .btn-action.primary {
      background: var(--ink);
      color: #FFF;
      box-shadow: 0 4px 14px rgba(11, 17, 22, 0.15);
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
      border-color: #CBD5E1;
    }

    /* ========================================================= */
    /* VISUAL PLC LADDER LOGIC STUDIO                            */
    /* ========================================================= */
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

    .rung-row:hover {
      border-color: #475569;
    }

    .rung-num {
      width: 50px;
      font-size: 12px;
      color: #94A3B8;
      font-weight: 700;
    }

    .ladder-circuit {
      display: flex;
      align-items: center;
      flex: 1;
      overflow-x: auto;
    }

    .power-rail-left {
      width: 4px;
      height: 52px;
      background: #F43F5E;
      border-radius: 2px;
      margin-right: 12px;
    }

    .power-rail-right {
      width: 4px;
      height: 52px;
      background: #3B82F6;
      border-radius: 2px;
      margin-left: 12px;
    }

    .wire {
      height: 4px;
      width: 36px;
      background: var(--plc-wire);
      transition: background 0.2s ease, box-shadow 0.2s ease;
    }

    .wire.active {
      background: var(--plc-wire-active);
      box-shadow: 0 0 10px rgba(52, 211, 153, 0.85);
    }

    .ladder-element {
      display: flex;
      flex-direction: column;
      align-items: center;
      cursor: pointer;
      user-select: none;
      padding: 6px 12px;
      border-radius: 8px;
      border: 1px dashed rgba(255,255,255,0.15);
      transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .ladder-element:hover {
      background: rgba(52, 211, 153, 0.15);
      border-color: var(--plc-wire-active);
      transform: translateY(-2px);
    }

    .ladder-element:active {
      transform: scale(0.96);
    }

    .elem-symbol {
      font-size: 17px;
      font-weight: 800;
      color: var(--plc-text-dim);
      padding: 4px 6px;
      letter-spacing: -1px;
      transition: all 0.2s ease;
    }

    .elem-symbol.active {
      color: var(--plc-wire-active);
      text-shadow: 0 0 14px rgba(52, 211, 153, 0.9);
      transform: scale(1.08);
    }

    .elem-label {
      font-size: 10px;
      color: #E2E8F0;
      margin-top: 4px;
      text-align: center;
      font-weight: 600;
    }

    .elem-addr {
      font-size: 9px;
      color: #FCD34D;
      margin-top: 2px;
    }

    .rung-desc {
      margin-left: auto;
      font-size: 11px;
      color: #94A3B8;
      text-align: right;
      padding-left: 16px;
      min-width: 150px;
    }

    /* RECENT ACTIVITY LOGS TABLE */
    .section-title {
      font-family: 'Outfit', sans-serif;
      font-size: 18px;
      font-weight: 800;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      letter-spacing: -0.3px;
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
      letter-spacing: 0.5px;
    }

    .logs-table td {
      padding: 14px 20px;
      border-bottom: 1px solid var(--border-subtle);
    }

    .logs-table tr:last-child td {
      border-bottom: none;
    }

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
      <!-- Language Switcher Button -->
      <button class="lang-toggle-btn" id="langToggleBtn" onclick="toggleLanguage()" title="Klik untuk berganti bahasa / Click to switch language">
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

  <!-- BENTO SUMMARY METRICS -->
  <div class="hero-summary-grid">
    <div class="summary-card col-4">
      <div class="summary-icon-wrapper cyan">⚡</div>
      <div class="summary-data">
        <div class="val" id="statActiveDevices">0 / 6</div>
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
        <div class="val">FX5U / OpenPLC</div>
        <div class="lbl" id="lblStatPlcStatus">Engine Otomasi</div>
      </div>
    </div>
  </div>

  <!-- QUICK SCENES BAR (Apple Home Shortcuts) -->
  <div class="scenes-wrapper">
    <div class="scenes-header">
      <span>✨</span> <span id="lblScenesTag">Skenario Otomatis Cepat:</span>
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
        Memuat status perangkat dari server...
      </div>
    </div>
  </div>

  <!-- TAB 2: VISUAL PLC LADDER STUDIO -->
  <div id="plcStudioTab" class="tab-content">
    <div class="plc-studio-card">
      <div class="plc-header">
        <div class="plc-title">
          <span>⚡</span> <span id="plcTitleText">OpenPLC / Mitsubishi FX5U Ladder Engine</span>
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
    <span>📜</span> <span id="logsTitleText">Riwayat Perintah & Aktivitas PLC Terakhir</span>
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
  let currentDevices = {};
  let currentLang = localStorage.getItem('nexora_lang') || 'id'; // 'id' atau 'en'

  // KAMUS BAHASA (DICTIONARY I18N)
  const i18n = {
    id: {
      flag: '🇮🇩',
      code: 'ID',
      next: '→ EN',
      brandSub: 'Platform Web IoT & Visual PLC Studio Alfa',
      tabSmartHome: 'Smart Home Cards',
      tabPlcStudio: 'Visual PLC Studio (Ladder View)',
      plcTitle: 'OpenPLC / Mitsubishi FX5U Ladder Engine',
      plcBadge: 'CYCLE TIME: 50ms • REAL-TIME SOLVER',
      logsTitle: 'Riwayat Perintah & Aktivitas PLC Terakhir',
      thTime: 'Waktu',
      thDevice: 'Perangkat',
      thAction: 'Aksi / Nilai',
      thSource: 'Sumber',
      syncLive: 'SINKRON LIVE',
      syncOffline: 'TERPUTUS (OFFLINE)',
      loadingDevices: 'Memuat status perangkat dari server...',
      loadingLogs: 'Memuat riwayat aktivitas...',
      noLogs: 'Belum ada riwayat aktivitas.',
      lblStatActive: 'Perangkat Menyala',
      lblStatLatency: 'Latensi Optimistik',
      lblStatPlcStatus: 'Engine Otomasi',
      lblScenesTag: 'Skenario Otomatis Cepat:',
      btnSceneAllOn: 'Nyalakan Semua',
      btnSceneAllOff: 'Matikan Semua',
      btnSceneLeaving: 'Keluar Rumah (Kunci & Matikan)',
      btnSceneArriving: 'Pulang ke Rumah (Buka & Nyalakan)',
      btnOpen: 'Buka',
      btnClose: 'Tutup',
      btnTurnOn: 'Nyalakan',
      btnTurnOff: 'Matikan',
      btnTurnOnPump: 'Nyalakan Pompa',
      btnTurnOffPump: 'Matikan Pompa',
      brightness: 'Tingkat Kecerahan',
      energized: '● ENERGIZED',
      deEnergized: '○ DE-ENERGIZED',
      clickToToggle: 'Klik untuk mengaktifkan / mematikan kontak',
      coilOutput: 'Koil Beban Output',
      devices: {
        pagar: { name: 'Pagar Utama Rumah', category: 'Akses Gerbang', desc: 'Kontrol Pagar Gerbang Utama', icon: '🚧' },
        pintu_geser: { name: 'Pintu Geser Ruang Tamu', category: 'Akses Ruangan', desc: 'Solenoid Pintu Geser Tamu', icon: '🚪' },
        gorden: { name: 'Gorden Otomatis', category: 'Interior Cerdas', desc: 'Motor Penggerak Gorden', icon: '🪟' },
        lampu_teras: { name: 'Lampu Teras Depan', category: 'Pencahayaan', desc: 'Relay Dimmer Lampu Depan', icon: '💡' },
        pompa_toren: { name: 'Pompa Pengisi Toren Air', category: 'Sanitasi & Air', desc: 'Pengisi Toren Air Otomatis', icon: '💧' },
        pompa_kolam: { name: 'Pompa Sirkulasi Kolam', category: 'Eksterior & Filter', desc: 'Sirkulasi & Filter Kolam', icon: '🏊' }
      },
      states: {
        'TERBUKA': 'TERBUKA',
        'TERTUTUP': 'TERTUTUP',
        'BUKA': 'BUKA',
        'TUTUP': 'TUTUP',
        'ON': 'ON',
        'OFF': 'OFF'
      }
    },
    en: {
      flag: '🇬🇧',
      code: 'EN',
      next: '→ ID',
      brandSub: 'Alfa IoT Cloud Platform & Visual PLC Studio',
      tabSmartHome: 'Smart Home Cards',
      tabPlcStudio: 'Visual PLC Studio (Ladder Logic)',
      plcTitle: 'OpenPLC / Mitsubishi FX5U Ladder Engine',
      plcBadge: 'CYCLE TIME: 50ms • REAL-TIME SOLVER',
      logsTitle: 'Recent PLC Commands & Activity History',
      thTime: 'Timestamp',
      thDevice: 'Device',
      thAction: 'Action / Value',
      thSource: 'Source',
      syncLive: 'LIVE SYNC',
      syncOffline: 'DISCONNECTED (OFFLINE)',
      loadingDevices: 'Loading devices from cloud server...',
      loadingLogs: 'Loading activity history...',
      noLogs: 'No activity history recorded yet.',
      lblStatActive: 'Active Devices',
      lblStatLatency: 'Optimistic Latency',
      lblStatPlcStatus: 'Automation Engine',
      lblScenesTag: 'Quick Automation Scenes:',
      btnSceneAllOn: 'Turn All On',
      btnSceneAllOff: 'Turn All Off',
      btnSceneLeaving: 'Leaving Home (Lock & Off)',
      btnSceneArriving: 'Arriving Home (Open & On)',
      btnOpen: 'Open',
      btnClose: 'Close',
      btnTurnOn: 'Turn On',
      btnTurnOff: 'Turn Off',
      btnTurnOnPump: 'Start Pump',
      btnTurnOffPump: 'Stop Pump',
      brightness: 'Brightness Level',
      energized: '● ENERGIZED',
      deEnergized: '○ DE-ENERGIZED',
      clickToToggle: 'Click to toggle contact ON/OFF',
      coilOutput: 'Output Coil Load',
      devices: {
        pagar: { name: 'Main Gate Access', category: 'Perimeter Access', desc: 'Main Gate Motor Drive Control', icon: '🚧' },
        pintu_geser: { name: 'Living Room Sliding Door', category: 'Room Entry', desc: 'Guest Sliding Door Solenoid', icon: '🚪' },
        gorden: { name: 'Motorized Smart Curtains', category: 'Smart Interior', desc: 'Automatic Curtain Motor Drive', icon: '🪟' },
        lampu_teras: { name: 'Front Porch Lighting', category: 'Lighting & Ambience', desc: 'Front Porch Dimmer Relay', icon: '💡' },
        pompa_toren: { name: 'Water Tank Pump', category: 'Plumbing & Storage', desc: 'Automatic Overhead Tank Filler', icon: '💧' },
        pompa_kolam: { name: 'Pool Circulation Pump', category: 'Exterior & Filtration', desc: 'Pool Filtration & Circulation', icon: '🏊' }
      },
      states: {
        'TERBUKA': 'OPEN',
        'TERTUTUP': 'CLOSED',
        'BUKA': 'OPEN',
        'TUTUP': 'CLOSED',
        'ON': 'ON',
        'OFF': 'OFF'
      }
    }
  };

  // FUNGSI GANTI BAHASA
  function toggleLanguage() {
    currentLang = currentLang === 'id' ? 'en' : 'id';
    localStorage.setItem('nexora_lang', currentLang);
    applyLanguage();
  }

  function applyLanguage() {
    const t = i18n[currentLang];
    
    // Header & Button Flag
    document.getElementById('langFlag').innerText = t.flag;
    document.getElementById('langLabel').innerText = t.code;
    document.getElementById('langNext').innerText = t.next;
    document.getElementById('txtBrandSub').innerText = t.brandSub;

    // Stats Bar
    document.getElementById('lblStatActive').innerText = t.lblStatActive;
    document.getElementById('lblStatLatency').innerText = t.lblStatLatency;
    document.getElementById('lblStatPlcStatus').innerText = t.lblStatPlcStatus;

    // Scenes
    document.getElementById('lblScenesTag').innerText = t.lblScenesTag;
    document.getElementById('btnSceneAllOn').innerText = t.btnSceneAllOn;
    document.getElementById('btnSceneAllOff').innerText = t.btnSceneAllOff;
    document.getElementById('btnSceneLeaving').innerText = t.btnSceneLeaving;
    document.getElementById('btnSceneArriving').innerText = t.btnSceneArriving;

    // Tabs
    document.getElementById('tabSmartHomeText').innerText = t.tabSmartHome;
    document.getElementById('tabPlcStudioText').innerText = t.tabPlcStudio;

    // PLC Card Header
    document.getElementById('plcTitleText').innerText = t.plcTitle;
    document.getElementById('plcBadgeText').innerText = t.plcBadge;

    // Table Headers & Section
    document.getElementById('logsTitleText').innerText = t.logsTitle;
    document.getElementById('thTime').innerText = t.thTime;
    document.getElementById('thDevice').innerText = t.thDevice;
    document.getElementById('thAction').innerText = t.thAction;
    document.getElementById('thSource').innerText = t.thSource;

    // Re-render konten jika devices sudah dimuat
    if (Object.keys(currentDevices).length > 0) {
      renderDevices(currentDevices);
      renderVisualLadder(currentDevices);
      updateSummaryStats(currentDevices);
    }
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
    const total = Object.keys(devices).length || 6;
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

  // Fetch status dari Backend
  async function fetchDevices() {
    const t = i18n[currentLang];
    try {
      const res = await fetch('api/devices.php');
      const data = await res.json();
      if (data.success) {
        currentDevices = data.devices;
        renderDevices(data.devices);
        renderVisualLadder(data.devices);
        renderLogs(data.recent_logs);
        updateSummaryStats(data.devices);
        document.getElementById('connStatus').innerText = t.syncLive;
      }
    } catch (e) {
      document.getElementById('connStatus').innerText = t.syncOffline;
    }
  }

  // Render Bento Smart Home Cards (Modern Apple Home Layout)
  function renderDevices(devices) {
    const t = i18n[currentLang];
    const container = document.getElementById('devicesContainer');
    let html = '';

    for (const key in devices) {
      const d = devices[key];
      const isAktif = d.state === 'ON' || d.state === 'BUKA' || d.state === 'TERBUKA' || (d.value && d.value > 0);
      const stateBadgeClass = isAktif ? 'on' : 'off';
      const devMeta = (t.devices && t.devices[d.id]) ? t.devices[d.id] : { name: d.name, category: 'Smart Device', icon: '⚡' };
      const devName = devMeta.name || d.name;
      const devCategory = devMeta.category || 'Smart Device';
      const devIcon = devMeta.icon || '⚡';
      
      const stateKey = (d.state || '').toUpperCase();
      const displayState = t.states[stateKey] || d.state;

      let actionButtons = '';
      if (d.id === 'pagar' || d.id === 'pintu_geser' || d.id === 'gorden') {
        actionButtons = `
          <button class="btn-action primary" onclick="sendCommand('${d.id}', 'BUKA')">${t.btnOpen}</button>
          <button class="btn-action outline" onclick="sendCommand('${d.id}', 'TUTUP')">${t.btnClose}</button>
        `;
      } else if (d.id === 'lampu_teras') {
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
      if (d.id === 'lampu_teras') {
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

      // Smooth switch toggle
      const switchChecked = isAktif ? 'checked' : '';
      const toggleTargetAction = (d.id === 'pagar' || d.id === 'pintu_geser' || d.id === 'gorden') 
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
                  <div class="device-plc-pill">PLC: ${d.plc_address || 'Virtual'}</div>
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

  // Render Visual Ladder Diagram (OpenPLC / Mitsubishi FX5U Engine)
  function renderVisualLadder(devices) {
    const t = i18n[currentLang];
    const container = document.getElementById('rungsContainer');
    
    const ladderDefs = [
      { rung: 0, devId: 'pagar', inAddr: '%IX0.0', outAddr: '%QX0.0', inName: 'CMD_PAGAR', outName: 'PAGAR_OUT' },
      { rung: 1, devId: 'pintu_geser', inAddr: '%IX0.1', outAddr: '%QX0.1', inName: 'CMD_PINTU', outName: 'PINTU_GESER' },
      { rung: 2, devId: 'gorden', inAddr: '%IX0.2', outAddr: '%QX0.2', inName: 'CMD_GORDEN', outName: 'MOTOR_GORDEN' },
      { rung: 3, devId: 'lampu_teras', inAddr: '%IX0.3', outAddr: '%QX0.3', inName: 'CMD_LAMPU', outName: 'LAMPU_TERAS' },
      { rung: 4, devId: 'pompa_toren', inAddr: '%IX0.4', outAddr: '%QX0.4', inName: 'FLOAT_LOW', outName: 'POMPA_TOREN' },
      { rung: 5, devId: 'pompa_kolam', inAddr: '%IX0.5', outAddr: '%QX0.5', inName: 'CMD_KOLAM', outName: 'POMPA_KOLAM' }
    ];

    let html = '';

    ladderDefs.forEach(l => {
      const dev = devices[l.devId] || {};
      const isAktif = dev.state === 'ON' || dev.state === 'BUKA' || dev.state === 'TERBUKA' || (dev.value && dev.value > 0) || dev.pending_command === 'ON' || dev.pending_command === 'BUKA';
      const wireClass = isAktif ? 'active' : '';
      const symClass = isAktif ? 'active' : '';
      const devMeta = (t.devices && t.devices[l.devId]) ? t.devices[l.devId] : {};
      const rungDesc = devMeta.desc || '';

      html += `
        <div class="rung-row">
          <div class="rung-num">RUNG ${l.rung}</div>
          
          <div class="ladder-circuit">
            <div class="power-rail-left"></div>
            <div class="wire ${wireClass}"></div>
            
            <!-- Kontak NO Input -->
            <div class="ladder-element" onclick="toggleLadderContact('${l.devId}', ${isAktif})" title="${t.clickToToggle}">
              <div class="elem-symbol ${symClass}">${isAktif ? '—[ ● ]—' : '—[   ]—'}</div>
              <div class="elem-label">${l.inName}</div>
              <div class="elem-addr">${l.inAddr}</div>
            </div>

            <div class="wire ${wireClass}" style="flex: 1;"></div>

            <!-- Koil Output -->
            <div class="ladder-element" onclick="toggleLadderContact('${l.devId}', ${isAktif})" title="${t.coilOutput}">
              <div class="elem-symbol ${symClass}">${isAktif ? '—( ● )—' : '—(   )—'}</div>
              <div class="elem-label">${l.outName}</div>
              <div class="elem-addr">${l.outAddr}</div>
            </div>

            <div class="wire ${wireClass}"></div>
            <div class="power-rail-right"></div>
          </div>

          <div class="rung-desc">
            <div style="font-weight: 700; color: ${isAktif ? '#34D399' : '#94A3B8'}; font-size: 13px;">${isAktif ? t.energized : t.deEnergized}</div>
            <div style="font-size: 11px; margin-top: 2px;">${rungDesc}</div>
          </div>
        </div>
      `;
    });

    container.innerHTML = html;
  }

  function toggleLadderContact(devId, currentlyActive) {
    let action = '';
    if (devId === 'pagar' || devId === 'pintu_geser' || devId === 'gorden') {
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
        <td><strong>${l.device_id.toUpperCase()}</strong></td>
        <td>${l.action}</td>
        <td><span class="badge-source">${l.source}</span></td>
      </tr>
    `).join('');
  }

  // KIRIM PERINTAH DENGAN 0-DELAY OPTIMISTIC UI
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

    // 2. DISPATCH ASYNC HTTP
    try {
      const payload = {
        device_id: deviceId,
        action: action,
        value: value !== null ? parseInt(value) : null,
        source: 'Web Portal & Ladder'
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

  // PRESET SCENES
  function applyScene(sceneName) {
    if (sceneName === 'ALL_ON') {
      ['pagar', 'pintu_geser', 'gorden'].forEach(id => sendCommand(id, 'BUKA'));
      ['lampu_teras', 'pompa_toren', 'pompa_kolam'].forEach(id => sendCommand(id, 'ON'));
    } else if (sceneName === 'ALL_OFF') {
      ['pagar', 'pintu_geser', 'gorden'].forEach(id => sendCommand(id, 'TUTUP'));
      ['lampu_teras', 'pompa_toren', 'pompa_kolam'].forEach(id => sendCommand(id, 'OFF'));
    } else if (sceneName === 'LEAVING_HOME') {
      ['pagar', 'pintu_geser', 'gorden'].forEach(id => sendCommand(id, 'TUTUP'));
      sendCommand('lampu_teras', 'OFF');
      sendCommand('pompa_kolam', 'OFF');
    } else if (sceneName === 'ARRIVING_HOME') {
      sendCommand('pagar', 'BUKA');
      sendCommand('pintu_geser', 'BUKA');
      sendCommand('lampu_teras', 'ON');
      sendCommand('lampu_teras', 'SET_BRIGHTNESS', 100);
    }
  }

  // Terapkan bahasa saat pertama kali dibuka
  applyLanguage();
  setInterval(fetchDevices, 1500);
  fetchDevices();
</script>

</body>
</html>
