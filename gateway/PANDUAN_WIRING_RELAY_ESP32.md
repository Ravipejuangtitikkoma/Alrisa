# Panduan Pengujian Modul Relay & ESP32 Board Extension
**Nexora / ALRISA Smart Home System**  
*Alfatech Solutions IDN.*

---

## 1. Skema Pengkabelan (Wiring Pinout)

Sambungkan kabel jumper dari **ESP32 Extension Board** ke **Modul Relay**:

| Pin Modul Relay | Pin ESP32 Extension Board | Keterangan |
| :--- | :--- | :--- |
| **VCC** / **DC+** | **5V** / **VIN** | Sumber daya coil relay (5 Volt dari extension shield) |
| **GND** / **DC-** | **GND** | Ground bersama |
| **IN** / **IN1** | **GPIO 23** | Pin sinyal pemicu relay dari ESP32 |

> [!TIP]
> **Mengenal Terminal Output Relay (Sisi Baut/Terminal Hijau/Biru):**
> - **COM (Common)**: Terminal sumber tegangan beban (misal motor pagar / adaptor).
> - **NO (Normally Open)**: Terminal yang **terhubung saat Relay JALAN (Buka Pagar)**. Pasang kabel motor pagar ke **COM** dan **NO**.
> - **NC (Normally Closed)**: Terminal yang terhubung saat Relay MATI. *(Biarkan kosong).*

---

## 2. Cara Menguji Alat Step-by-Step

### Tahap 1: Upload Firmware ke ESP32
1. Buka software **Arduino IDE**.
2. Buka file firmware: [`gateway/esp32_relay_pagar.ino`](file:///f:/Aplikasi%20Nexora/gateway/esp32_relay_pagar.ino).
3. Pastikan library **PubSubClient** sudah terpasang di Arduino IDE (`Sketch -> Include Library -> Manage Libraries -> Cari "PubSubClient"`).
4. Pilih board: **Tools -> Board -> ESP32 Arduino -> ESP32 Dev Module**.
5. Pilih Port USB yang terdeteksi: **Tools -> Port -> COMx**.
6. Klik tombol **Upload** (tanda panah ke kanan).

---

### Tahap 2: Uji Mandiri Lewat Serial Monitor (Tanpa Perlu HP)
1. Setelah upload selesai, buka **Tools -> Serial Monitor** di Arduino IDE.
2. Atur baudrate di pojok kanan bawah Serial Monitor ke **115200 baud**.
3. Ketik perintah di kolom input atas lalu tekan Enter:
   - Ketik `OPEN` atau `1`  
     👉 **Hasil:** Terdengar bunyi **"KLIK"** pada relay, lampu indikator relay menyala (Pagar Terbuka / Relay Jalan).
   - Ketik `CLOSE` atau `0`  
     👉 **Hasil:** Terdengar bunyi **"KLIK"**, lampu indikator relay padam (Pagar Terkunci / Relay Mati).

> [!NOTE]
> Jika kondisi relay terbalik (misal ketik `OPEN` malah mati, ketik `CLOSE` malah menyala), cukup ubah baris 53 di file `.ino`:
> ```cpp
> const bool RELAY_ACTIVE_LOW = false; // Ganti jadi false
> ```
> Lalu upload ulang.

---

### Tahap 3: Uji Coba Terhubung ke Broker & Aplikasi HP

#### A. Menggunakan Private Broker ALRISA (Laptop / Mini PC)
Anda sudah memiliki private broker lokal di project ini.
1. Buka terminal di folder `backend_cloud_js`:
   ```bash
   node broker.js
   ```
2. Terminal akan menampilkan IP laptop Anda (misal `192.168.1.15`).
3. Pada file `esp32_relay_pagar.ino`, ganti:
   ```cpp
   const char* MQTT_SERVER = "192.168.1.15"; // Isi dengan IP Laptop Anda
   ```
4. Masukkan nama WiFi & Password hotspot Anda pada `WIFI_SSID` dan `WIFI_PASSWORD`.
5. Upload kembali ke ESP32.
6. Buka aplikasi Nexora di HP (terhubung ke WiFi yang sama):
   - Tekan tombol **Buka Pagar** di HP -> Relay langsung **JALAN / AKTIF**!
   - Tekan tombol **Kunci Pagar** di HP -> Relay langsung **MATI**!

#### B. Menggunakan Cloud Broker Publik (broker.emqx.io)
Jika laptop tidak dinyalakan sebagai server, Anda cukup membiarkan `MQTT_SERVER = "broker.emqx.io"`, masukkan WiFi hotspot HP, dan ESP32 akan langsung terhubung ke cloud broker publik secara otomatis.
