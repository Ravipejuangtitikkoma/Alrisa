# 🚀 PANDUAN CEPAT UPLOAD BACKEND NEXORA KE CPANEL ALFA

Halo! Karena Anda mengerjakan sistem ini sendirian, panduan ini dibuat **sangat ringkas dan mudah diikuti (hanya butuh waktu ±5-10 menit)** tanpa perlu mengetik perintah server Linux yang rumit.

---

## 📁 Struktur File yang Sudah Siap Upload
Semua file yang ada di folder `f:\Aplikasi Nexora\backend_cpanel\`:
```text
backend_cpanel/
├── api/
│   ├── control.php     <- Menerima perintah ON/OFF/Slider dari HP & Web
│   ├── devices.php     <- Menyediakan status terbaru perangkat
│   └── plc_sync.php    <- Menjembatani perintah ke PLC
├── config.php          <- Pengaturan Database & Kunci Keamanan API
├── database.sql        <- Database MySQL otomatis (6 perangkat + logs)
└── index.php           <- Web Dashboard Modern Alfa untuk laptop bos/klien
```

---

## 🛠️ Langkah 1: Buat Database di cPanel
1. Login ke **cPanel Alfa** (biasanya `https://domainalfa.com:2083`).
2. Cari dan klik menu **"MySQL® Database Wizard"** (atau **MySQL Databases**).
3. **Step 1**: Masukkan nama database, contoh: `nexora` (hasilnya nanti misal `alfa_nexora`). Klik *Next Step*.
4. **Step 2**: Buat User baru (contoh: `nexora_user`) dan Password (buat yang kuat, misal `AlfaNexora2026!`). Klik *Create User*.
5. **Step 3**: Centang **"ALL PRIVILEGES"** (semua hak akses), lalu klik *Make Changes*.
6. ⚠️ **Catat 3 data ini**:
   - Nama Database: `alfa_nexora`
   - Username: `alfa_nexora_user`
   - Password: `AlfaNexora2026!`

---

## 🗄️ Langkah 2: Import Tabel Database (2 Klik)
1. Di cPanel, cari dan klik menu **"phpMyAdmin"**.
2. Di sebelah kiri, klik nama database Anda (`alfa_nexora`).
3. Klik tab **"Import"** di bagian atas menu.
4. Klik tombol **"Choose File" / "Browse"**, lalu pilih file:
   `f:\Aplikasi Nexora\backend_cpanel\database.sql`
5. Gulir ke paling bawah dan klik tombol **"Import" / "Go"**.
6. ✅ Selesai! Tabel `nexora_devices` dan `nexora_logs` langsung terbuat otomatis beserta isinya.

---

## 📤 Langkah 3: Upload File ke cPanel
1. Di cPanel, klik menu **"File Manager"**.
2. Masuk ke folder **`public_html`**.
3. Klik tombol **"+ Folder"** di pojok kiri atas, buat folder baru bernama:
   `nexora`
4. Masuk ke dalam folder `nexora` tersebut (`public_html/nexora/`).
5. Upload semua file & subfolder yang ada di `backend_cpanel/`:
   - Folder `api/` (berisi `control.php`, `devices.php`, `plc_sync.php`)
   - `config.php`
   - `index.php`
   *(Tips: Anda bisa compress folder `backend_cpanel` jadi `.zip`, upload ke cPanel, lalu klik kanan -> **Extract**)*.

---

## ⚙️ Langkah 4: Sesuaikan `config.php`
1. Di File Manager cPanel, klik kanan file **`config.php`** -> pilih **"Edit"**.
2. Ubah bagian ini sesuai catatan Anda di Langkah 1:
   ```php
   define('DB_HOST', 'localhost');
   define('DB_USER', 'alfa_nexora_user');    // Username DB Anda
   define('DB_PASS', 'AlfaNexora2026!');     // Password DB Anda
   define('DB_NAME', 'alfa_nexora');         // Nama DB Anda
   
   // Kunci Keamanan API (Bisa Anda biarkan atau ganti)
   define('NEXORA_API_KEY', 'nexora_secret_token_2026');
   ```
3. Klik **Save Changes** di pojok kanan atas.

---

## 🎉 Langkah 5: Buka di Browser (Tes Berhasil!)
Sekarang buka browser di HP atau Laptop Anda:
👉 `https://domainalfa.com/nexora/`

Tampilan **NEXORA Cloud Central Dashboard** langsung muncul dengan 6 kartu perangkat siap kontrol dan tabel riwayat aktivitas real-time! Siapa pun di tim Alfa bisa melihatnya langsung.

---

## 🔗 Menghubungkan ke Gateway Python & PLC
Jika website sudah live di cPanel, di laptop Anda jalankan:
1. Buka file `f:\Aplikasi Nexora\gateway\cloud_sync_cpanel.py`.
2. Ubah `CLOUD_URL` menjadi URL website cPanel Anda:
   ```python
   CLOUD_URL = "https://domainalfa.com/nexora"
   ```
3. Jalankan:
   ```bash
   python cloud_sync_cpanel.py
   ```
Semua perintah dari Web & HP akan langsung dieksekusi oleh PLC secara otomatis!
