/*
  =============================================================================
  NEXORA / ALRISA SMART HOME - ESP32 GATE CONTROLLER (RELAY TESTER)
  Kontrol Pagar Otomatis Menggunakan Modul Relay & ESP32 Extension Board
  A product by Alfatech Solutions IDN.
  =============================================================================

  CARA KERJA:
  1. PERINTAH BUKA PAGAR:
     - Diterima dari HP / Private Broker / Serial Monitor: "OPEN" / "1" / "true"
     - ESP32 mengaktifkan RELAY -> Relay "KLIK" dan MENYAMBUNG (JALAN).
     - LED indikator ON.
     - ESP32 membalas status: "OPEN".
  
  2. PERINTAH TUTUP / KUNCI PAGAR:
     - Diterima dari HP / Private Broker / Serial Monitor: "CLOSE" / "LOCKED" / "0" / "false"
     - ESP32 mematikan RELAY -> Relay "KLIK" dan TERPUTUS (MATI).
     - LED indikator OFF.
     - ESP32 membalas status: "LOCKED".

  KOMPATIBILITAS BROKER:
  - Mendukung Private MQTT Broker lokal ALRISA (node broker.js / Mini PC / Laptop).
  - Bisa juga diarahkan ke Cloud Public Broker (broker.emqx.io).
  - Berlangganan topik ganda: "alrisa/pagar/set" DAN "nexora/pagar/set".
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// =============================================================================
// 1. PENGATURAN WIFI (Ganti dengan Hotspot / WiFi Anda)
// =============================================================================
const char* WIFI_SSID     = "NAMA_WIFI_ANDA";     // Ganti nama WiFi / Hotspot
const char* WIFI_PASSWORD = "PASSWORD_WIFI_ANDA"; // Ganti password WiFi

// =============================================================================
// 2. PENGATURAN MQTT BROKER
// =============================================================================
// OPSI A: Gunakan Private Broker Laptop/Mini PC (Jalankan 'node broker.js' di backend_cloud_js)
//         Ganti dengan IP Laptop Anda pada jaringan WiFi yang sama (contoh: "192.168.1.10")
// OPSI B: Jika belum menyalakan broker laptop, bisa gunakan "broker.emqx.io"
const char* MQTT_SERVER   = "broker.emqx.io";    // Atau ganti IP Private Broker: misal "192.168.1.5"
const int   MQTT_PORT     = 1883;
const char* MQTT_CLIENT_ID = "ESP32_Pagar_Nexora_Client";

// Topik MQTT (Mendukung prefix 'alrisa' & 'nexora')
const char* TOPIC_SET_ALRISA   = "alrisa/pagar/set";
const char* TOPIC_STATE_ALRISA = "alrisa/pagar/state";
const char* TOPIC_SET_NEXORA   = "nexora/pagar/set";
const char* TOPIC_STATE_NEXORA = "nexora/pagar/state";

// =============================================================================
// 3. PEMETAAN PIN HARDWARE (ESP32 EXTENSION BOARD)
// =============================================================================
// Pin Sinyal IN Relay: Hubungkan pin IN modul relay ke GPIO 23 (atau pin lain di board extension)
#define PIN_RELAY_PAGAR   23  

// Pin LED Indikator Onboard ESP32 (GPIO 2 pada sebagian besar board ESP32 30/38 pin)
#define PIN_LED_ONBOARD   2   

// =============================================================================
// 4. KARAKTERISTIK MODUL RELAY
// =============================================================================
// CATATAN PENTING MODUL RELAY:
// Sebagian besar modul relay 5V di pasaran bertipe "Active-LOW" 
// (Artinya: Diberi sinyal LOW = Relay Menyala/Menyambung, sinyal HIGH = Relay Mati).
// Jika modul relay Anda tipe Active-HIGH, ubah nilai di bawah ini menjadi 'false'.
const bool RELAY_ACTIVE_LOW = true; 

// Variabel status gerbang saat ini
bool isGateOpen = false;

WiFiClient espClient;
PubSubClient client(espClient);

// =============================================================================
// FUNGSI KONTROL FISIK RELAY
// =============================================================================
void setRelayState(bool turnOn) {
  isGateOpen = turnOn;

  if (RELAY_ACTIVE_LOW) {
    // Active-LOW: LOW = Relay Aktif (JALAN), HIGH = Relay Non-aktif (MATI)
    digitalWrite(PIN_RELAY_PAGAR, turnOn ? LOW : HIGH);
  } else {
    // Active-HIGH: HIGH = Relay Aktif (JALAN), LOW = Relay Non-aktif (MATI)
    digitalWrite(PIN_RELAY_PAGAR, turnOn ? HIGH : LOW);
  }

  // Nyalakan LED Onboard sebagai indikator visual sejajar
  digitalWrite(PIN_LED_ONBOARD, turnOn ? HIGH : LOW);

  // Tampilkan di Serial Monitor
  if (turnOn) {
    Serial.println("\n==========================================");
    Serial.println("🚪 [PAGAR DIBUKA] -> RELAY AKTIF / JALAN! ⚡");
    Serial.println("💡 Kontak Relay (COM & NO) MENYAMBUNG.");
    Serial.println("==========================================");
  } else {
    Serial.println("\n==========================================");
    Serial.println("🔒 [PAGAR DITUTUP] -> RELAY MATI / TERPUTUS! 🛑");
    Serial.println("🌑 Kontak Relay (COM & NO) TERBUKA.");
    Serial.println("==========================================");
  }

  // Kirim status balik ke broker (HP & Dashboard langsung update)
  if (client.connected()) {
    const char* statePayload = turnOn ? "OPEN" : "LOCKED";
    client.publish(TOPIC_STATE_ALRISA, statePayload);
    client.publish(TOPIC_STATE_NEXORA, statePayload);
    Serial.print("📡 [STATUS TERKIRIM KE HP] -> ");
    Serial.println(statePayload);
  }
}

// =============================================================================
// CALLBACK: SAAT MENERIMA PESAN DARI BROKER MQTT (HP / DASHBOARD)
// =============================================================================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();

  Serial.println("----------------------------------------------");
  Serial.print("📩 [PERINTAH MASUK] Topik: ");
  Serial.println(topic);
  Serial.print("📦 Isi Perintah: ");
  Serial.println(message);

  // Periksa apakah perintahnya BUKA (OPEN / true / 1 / ON / json)
  bool willOpen = (message.indexOf("OPEN") >= 0 || 
                   message.indexOf("open") >= 0 || 
                   message.indexOf("true") >= 0 || 
                   message.indexOf("ON") >= 0 ||
                   message.indexOf("on") >= 0 ||
                   message == "1");

  // Periksa apakah perintahnya TUTUP (CLOSE / LOCKED / false / 0 / OFF / json)
  bool willClose = (message.indexOf("CLOSE") >= 0 || 
                    message.indexOf("close") >= 0 || 
                    message.indexOf("LOCKED") >= 0 || 
                    message.indexOf("locked") >= 0 || 
                    message.indexOf("false") >= 0 || 
                    message.indexOf("OFF") >= 0 || 
                    message.indexOf("off") >= 0 || 
                    message == "0");

  if (willOpen) {
    setRelayState(true);
  } else if (willClose) {
    setRelayState(false);
  } else {
    Serial.println("⚠️ Format perintah tidak dikenal. Gunakan: OPEN atau CLOSE.");
  }
  Serial.println("----------------------------------------------");
}

// =============================================================================
// REKONEKSI MQTT JIKA TERPUTUS
// =============================================================================
void reconnectMqtt() {
  static unsigned long lastReconnectAttempt = 0;
  unsigned long now = millis();

  if (!client.connected() && (now - lastReconnectAttempt > 5000)) {
    lastReconnectAttempt = now;
    Serial.print("🌐 Menghubungkan ke MQTT Broker (");
    Serial.print(MQTT_SERVER);
    Serial.print(")... ");

    if (client.connect(MQTT_CLIENT_ID)) {
      Serial.println("BERHASIL TERHUBUNG! ✅");

      // Berlangganan topik kontrol pagar
      client.subscribe(TOPIC_SET_ALRISA);
      client.subscribe(TOPIC_SET_NEXORA);
      client.subscribe("alrisa/+/set");
      client.subscribe("nexora/+/set");

      Serial.println("📡 Berlangganan topik: [alrisa/pagar/set] & [nexora/pagar/set]");

      // Kirim status awal gerbang: LOCKED (Terkunci)
      client.publish(TOPIC_STATE_ALRISA, isGateOpen ? "OPEN" : "LOCKED");
      client.publish(TOPIC_STATE_NEXORA, isGateOpen ? "OPEN" : "LOCKED");
      Serial.println("✅ Alat siap menerima perintah dari HP!");
    } else {
      Serial.print("Gagal (rc=");
      Serial.print(client.state());
      Serial.println("). Mengulang 5 detik lagi...");
    }
  }
}

// =============================================================================
// FITUR PENGUJIAN MANUAL VIA SERIAL MONITOR ARDUINO
// =============================================================================
void checkSerialInput() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() == 0) return;

    Serial.print("⌨️ [INPUT SERIAL DITERIMA]: ");
    Serial.println(input);

    if (input.equalsIgnoreCase("1") || input.equalsIgnoreCase("OPEN") || input.equalsIgnoreCase("ON")) {
      Serial.println("👉 Menjalankan perintah manual: BUKA PAGAR");
      setRelayState(true);
    } else if (input.equalsIgnoreCase("0") || input.equalsIgnoreCase("CLOSE") || input.equalsIgnoreCase("OFF")) {
      Serial.println("👉 Menjalankan perintah manual: TUTUP PAGAR");
      setRelayState(false);
    } else if (input.equalsIgnoreCase("HELP")) {
      Serial.println("\n--- BANTUAN PERINTAH SERIAL MONITOR ---");
      Serial.println(" Ketik '1' atau 'OPEN'  : Buka Pagar (Relay Jalan)");
      Serial.println(" Ketik '0' atau 'CLOSE' : Tutup Pagar (Relay Mati)");
      Serial.println(" Ketik 'STATUS'         : Cek status pagar saat ini");
      Serial.println("----------------------------------------\n");
    } else if (input.equalsIgnoreCase("STATUS")) {
      Serial.print("ℹ️ Status pagar saat ini: ");
      Serial.println(isGateOpen ? "TERBUKA (Relay ON)" : "TERKUNCI (Relay OFF)");
    } else {
      Serial.println("⚠️ Perintah tidak valid. Ketik 'HELP' untuk melihat daftar perintah.");
    }
  }
}

// =============================================================================
// SETUP: DIJALANKAN SEKALI SAAT ESP32 MENYALA
// =============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n========================================================");
  Serial.println("🚀 NEXORA / ALRISA SMART GATE - ESP32 RELAY CONTROLLER");
  Serial.println("🏢 Alfatech Solutions IDN.");
  Serial.println("========================================================");

  // 1. Inisialisasi Pin GPIO
  pinMode(PIN_RELAY_PAGAR, OUTPUT);
  pinMode(PIN_LED_ONBOARD, OUTPUT);

  // 2. Set kondisi awal: PAGAR TERKUNCI / RELAY MATI
  setRelayState(false);

  // 3. Menghubungkan ke Jaringan WiFi
  Serial.print("📶 Menghubungkan ke WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 30) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n🎉 WiFi Terhubung!");
    Serial.print("📍 IP ESP32 : ");
    Serial.println(WiFi.localIP());
    Serial.print("📶 Sinyal RSSI: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\n⚠️ WiFi belum terhubung. Anda tetap dapat menguji Relay lewat Serial Monitor!");
    Serial.println("👉 Buka Serial Monitor (baud 115200) lalu ketik 'OPEN' atau 'CLOSE'.");
  }

  // 4. Inisialisasi Konfigurasi MQTT
  client.setServer(MQTT_SERVER, MQTT_PORT);
  client.setCallback(mqttCallback);

  Serial.println("\n💡 TIPS PENGUJIAN CEPAT:");
  Serial.println("Ketik 'OPEN' atau '1' di Serial Monitor -> Relay JALAN (Aktif).");
  Serial.println("Ketik 'CLOSE' atau '0' di Serial Monitor -> Relay MATI.");
  Serial.println("========================================================\n");
}

// =============================================================================
// LOOP: DIJALANKAN TERUS MENERUS
// =============================================================================
void loop() {
  // Cek input keyboard dari Serial Monitor Arduino IDE
  checkSerialInput();

  // Kelola koneksi WiFi dan MQTT jika WiFi terhubung
  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      reconnectMqtt();
    } else {
      client.loop();
    }
  }
}
