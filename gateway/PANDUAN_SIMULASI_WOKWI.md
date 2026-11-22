# Panduan Lengkap Simulasi Online ESP32 & Relay di Wokwi
**ALRISA Smart Home & Industrial IoT System**

Bila komponen fisik (ESP32 dan Relay) belum dipasang, Anda dapat menguji seluruh sistem secara **100% online, visual, dan interaktif** menggunakan **Wokwi Simulator (https://wokwi.com)**.

Simulasi di Wokwi ini bersifat **LIVE**: ESP32 virtual di browser Anda terhubung ke internet nyata via MQTT `broker.emqx.io`. Ketika Anda menekan tombol di Web Dashboard ALRISA atau di HP, saklar relay di browser Anda akan berbunyi klik (*ON*) dan lampu indikator beban menyala secara real-time!

---

## Langkah Menjalankan Simulasi di Wokwi (Hanya 2 Menit)

### 1. Buka Wokwi Simulator
Buka browser Anda dan kunjungi:
👉 **https://wokwi.com/projects/new/esp32**

### 2. Masukkan Kode Firmware (`sketch.ino`)
1. Di tab **`sketch.ino`** bawaan Wokwi, hapus semua kode di dalamnya.
2. Buka file: [gateway/wokwi/esp32_relay_wokwi.ino](file:///run/media/ravi-armanza/New%20Volume/Aplikasi%20Nexora/gateway/wokwi/esp32_relay_wokwi.ino)
3. Salin (*copy*) seluruh isinya, lalu tempel (*paste*) ke tab `sketch.ino` di Wokwi.

### 3. Masukkan Rangkaian Otomatis (`diagram.json`)
Agar Anda tidak perlu repot menarik kabel satu per satu di layar Wokwi:
1. Di Wokwi, klik tab **`diagram.json`**.
2. Hapus isinya, lalu buka file: [gateway/wokwi/diagram.json](file:///run/media/ravi-armanza/New%20Volume/Aplikasi%20Nexora/gateway/wokwi/diagram.json)
3. Salin seluruh teksnya dan tempel ke tab `diagram.json`.
4. Anda akan langsung melihat rangkaian instan:
   - 1x Board **ESP32 DevKit v4**
   - 1x Modul **Relay** terhubung ke pin GPIO 2, 5V, dan GND
   - 1x Lampu LED Hijau **"MOTOR PAGAR / BEBAN RELAY"** terhubung ke terminal NO (Normally Open)

### 4. Tambahkan Library `PubSubClient`
1. Di panel kiri Wokwi, klik tab **Library Manager** (ikon buku atau tab bertuliskan *Libraries* / `libraries.txt`).
2. Ketik / pastikan tertulis:
   ```text
   PubSubClient
   ```

### 5. Jalankan Simulasi!
1. Klik tombol **Play (ikon segitiga hijau)** di pojok atas Wokwi.
2. Di panel **Serial Monitor** di bagian bawah, Anda akan melihat log proses:
   - Terhubung ke WiFi virtual (`Wokwi-GUEST`)
   - Terhubung ke Cloud MQTT (`broker.emqx.io:1883`)
   - Muncul pesan: `✅ ESP32 Siap menerima kendali dari Web Dashboard & HP Anda!`

---

## 3 Cara Menguji Kendali Relay

### Cara 1: Dari Web Dashboard ALRISA
1. Buka **https://alrisa.vercel.app** (atau `http://localhost:3001`).
2. Login dengan akun: `raviarmanza149@gmail.com` / `ravi18`.
3. Pada kartu **Gerbang Utama Depan** (ID: `pagar`), klik tombol saklar:
   - Saklar relay di Wokwi langsung menyambung (*ON*).
   - Lampu LED hijau di layar Wokwi menyala terang!
   - Serial Monitor Wokwi menampilkan log: `⚡ [RELAY ON / MENYAMBUNG]`.

### Cara 2: Dari Aplikasi HP (Flutter)
1. Buka aplikasi ALRISA di HP Anda.
2. Tekan tombol **Buka Pagar**:
   - HP mem-publish perintah ke topik `alrisa/pagar/set`.
   - Relay virtual di Wokwi seketika merespons dan lampu menyala!

### Cara 3: Lewat Serial Monitor Wokwi (Manual)
1. Pada kotak input Serial Monitor di bawah simulasi Wokwi:
   - Ketik `OPEN` lalu Enter $\rightarrow$ Relay aktif, lampu menyala.
   - Ketik `CLOSE` lalu Enter $\rightarrow$ Relay mati, lampu padam.
