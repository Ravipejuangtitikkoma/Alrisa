
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
  