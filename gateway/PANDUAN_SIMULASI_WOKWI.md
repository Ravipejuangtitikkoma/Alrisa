# Panduan Simulasi Online ESP32 & Relay Pagar di Wokwi
**Nexora / ALRISA Smart Home System**

Bila komponen fisik (ESP32 dan Relay) belum sampai, Anda **SANGAT BISA** mengujinya secara online dan visual 100% menggunakan **Wokwi Simulator (https://wokwi.com)**.

Simulasi di Wokwi ini bersifat **LIVE**: ESP32 virtual di browser akan terhubung ke internet nyata via MQTT `broker.emqx.io`. Ketika Anda menekan tombol "Buka Pagar" di HP, relay virtual di browser Anda akan langsung bergerak, saklar kontak berbunyi "klik", dan lampu indikator motor pagar menyala hijau!

---

## Opsi 1: Simulasi di Browser via Wokwi (Rekomendasi Utama)

### Langkah 1: Buka Wokwi
1. Buka browser dan kunjungi: **https://wokwi.com/projects/new/esp32**

### Langkah 2: Masukkan Kode Kodingan
1. Pada tab **`sketch.ino`** di Wokwi, hapus semua kode bawaan.
2. Salin seluruh isi file: [`gateway/wokwi/esp32_relay_wokwi.ino`](file:///f:/Aplikasi%20Nexora/gateway/wokwi/esp32_relay_wokwi.ino) lalu tempel (*paste*) ke Wokwi.

### Langkah 3: Tambahkan Library PubSubClient
1. Di bagian kiri panel kode Wokwi, klik tab **Library Manager** (ikon buku atau tab bertuliskan *Libraries*).
2. Klik tombol **+ Add a Library** atau ketik:
   ```text
   PubSubClient
   ```
3. Pilih library **PubSubClient by Nick O'Leary** (atau cukup tempel teks `PubSubClient` di tab `libraries.txt`).

### Langkah 4: Pasang Rangkaian Otomatis (Diagram)
Agar Anda tidak perlu repot menggambar dan menarik kabel relay satu per satu di Wokwi:
1. Di Wokwi, klik tab **`diagram.json`**.
2. Salin seluruh isi file: [`gateway/wokwi/diagram.json`](file:///f:/Aplikasi%20Nexora/gateway/wokwi/diagram.json) lalu tempel ke tab `diagram.json` tersebut.
3. Anda akan langsung melihat:
   - 1x Board **ESP32**
   - 1x Modul **Relay** lengkap dengan kabel warna-warni terpasang ke pin GPIO 23, VCC (5V), GND, dan COM
   - 1x Lampu LED Hijau bertuliskan **"MOTOR PAGAR"** yang tersambung ke terminal NO (Normally Open)

### Langkah 5: Jalankan Simulasi!
1. Klik tombol **Play (ikon segitiga hijau)** di pojok atas Wokwi.
2. Perhatikan panel **Serial Monitor** di bawah:
   - ESP32 akan menyambung ke `WiFi Wokwi-GUEST`
   - ESP32 akan terhubung ke `broker.emqx.io:1883`
   - Muncul status: `✅ ESP32 Siap menerima kendali dari HP Anda!`

### Langkah 6: Cara Menguji
- **Cara A (Langsung dari HP Nexora)**:
  - Buka aplikasi Nexora di HP.
  - Tekan tombol **Buka Pagar** $\rightarrow$ Di layar Wokwi, saklar relay akan bergerak menyambung dan lampu LED **"MOTOR PAGAR"** menyala terang!
  - Tekan tombol **Kunci Pagar** $\rightarrow$ Saklar relay terputus dan lampu motor pagar padam!
- **Cara B (Lewat Serial Monitor Wokwi)**:
  - Pada kotak input Serial Monitor di bawah simulasi, ketik `OPEN` lalu Enter $\rightarrow$ Relay aktif!
  - Ketik `CLOSE` lalu Enter $\rightarrow$ Relay mati!

---

## Opsi 2: Simulasi Offline di Laptop (Visual PLC Simulator)

Jika Anda ingin simulasi visual langsung di layar komputer tanpa membuka browser, Anda sudah memiliki aplikasi simulator bawaan di project ini:

1. Buka terminal PowerShell di folder project:
   ```powershell
   python "f:\Aplikasi Nexora\gateway\visual_plc.py"
   ```
2. Aplikasi desktop **ALRISA OpenPLC Visual Simulator** akan terbuka:
   - Menampilkan diagram kontak relay pagar (%QX0.1).
   - Kabel dan coil akan menyala hijau saat pagar dibuka dari HP.
