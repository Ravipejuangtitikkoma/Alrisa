/*
  =============================================================================
  ALRISA SMART HOME & IOT HUB — ESP32 RELAY & ACTUATOR FIRMWARE (WOKWI EDITION)
  Sistem Kontrol Gerbang Multi-User & Multi-Device dengan Filter PIN GPIO & ID
  Pengembang: Alfatech Solutions IDN.
  =============================================================================

  FITUR SISTEM MULTI-GERBANG:
  1. Identitas Khusus Perangkat (Target Account, Target Device ID, & Target GPIO Pin).
  2. Filter Ketat (Strict Matching):
     - Hanya merespon jika perintah ditujukan khusus untuk Device ID atau Pin GPIO milik ESP32 ini.
     - Perintah untuk gerbang lain otomatis DIABAIKAN (Relay tidak akan bergerak salah sasaran).
  3. Mendukung multi-user & multi-gerbang (Gerbang Utama, Gerbang Kedua, Gorden, Lampu).
  4. Kompatibel 100% dengan Web Dashboard (https://alrisa.vercel.app) & Aplikasi HP Flutter.
  5. Feedback status balik dua arah secara real-time ke Cloud MQTT Broker.
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// -----------------------------------------------------------------------------
// ⚙️ 1. PENGATURAN IDENTITAS ESP32 INI (SESUAIKAN DENGAN WEBSITE)
// -----------------------------------------------------------------------------
// A. Akun Pemilik (Topik Prefix MQTT dari Akun Anda di Website):
//    - Default Super Admin : "alrisa"
//    - Admin Cabang/Ilham : "alrisa/admin_ilham"
const char* TARGET_ACCOUNT_PREFIX = "alrisa";

// B. ID Perangkat yang Dikontrol oleh ESP32 ini:
//    - Untuk Gerbang Utama : "pagar" (atau "gerbang_utama")
//    - Untuk Gerbang Kedua : "gerbang_kedua" (atau "pagar_belakang")
//    - Untuk Lampu         : "lampu_teras"
const char* TARGET_DEVICE_ID      = "pagar";

// C. Pin Hardware GPIO Relay (Samakan persis dengan yang diatur di Website):
//    - Gerbang Utama : 2 (GPIO 2)
//    - Gerbang Kedua : 4 (GPIO 4)
const int   TARGET_GPIO_PIN       = 2;

// D. Mode Filter Ketat (Strict Matching):
//    - true  = HANYA merespon jika perintah untuk TARGET_DEVICE_ID atau TARGET_GPIO_PIN ini.
//    - false = Respon semua (mode umum)
const bool  STRICT_MATCHING       = true;

// -----------------------------------------------------------------------------
// 2. KONFIGURASI WIFI & MQTT BROKER
// -----------------------------------------------------------------------------
// Catatan: Di Wokwi gunakan "Wokwi-GUEST". Untuk alat fisik gunakan WiFi rumah Anda.
const char* WIFI_SSID     = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

// Cloud MQTT Broker EMQX (Publik & Gratis)
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;

// Client ID dinamis agar tidak bentrok
char mqttClientId[40];

// Konfigurasi tipe relay:
// - Wokwi Relay Module = Active-HIGH (true saat sinyal HIGH) -> RELAY_ACTIVE_LOW = false
// - Modul Relay Fisik di pasaran biasanya Active-LOW       -> ubah jadi true jika pakai modul fisik
const bool RELAY_ACTIVE_LOW = false;

// -----------------------------------------------------------------------------
// 3. VARIABEL STATE SISTEM
// -----------------------------------------------------------------------------
bool isRelayActive = false;
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// -----------------------------------------------------------------------------
// 4. FUNGSI PENGGERAK RELAY & PENGIRIMAN FEEDBACK STATUS KE CLOUD
// -----------------------------------------------------------------------------
void setRelay(bool turnOn, const char* targetDevice, int targetPin) {
  isRelayActive = turnOn;

  // Aktifkan atau matikan pin GPIO Relay
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(targetPin, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(targetPin, turnOn ? HIGH : LOW);
  }

  // Tampilkan visual log di Serial Monitor
  Serial.println("\n========================================================");
  if (turnOn) {
    Serial.print("⚡ [RELAY ON / MENYAMBUNG] Perangkat: ");
    Serial.print(targetDevice);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("🟢 Kontak COM-NO Menyambung -> Motor Gerbang / Lampu BEBAN MENYALA!");
  } else {
    Serial.print("🛑 [RELAY OFF / TERPUTUS] Perangkat: ");
    Serial.print(targetDevice);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("⚫ Kontak COM-NO Terputus   -> Motor Gerbang / Lampu BEBAN PADAM!");
  }
  Serial.println("========================================================");

  // Kirim feedback status balik ke broker MQTT agar HP dan Web seketika terupdate!
  if (mqttClient.connected()) {
    const char* strState = turnOn ? "OPEN" : "LOCKED";
    char jsonFeedback[128];
    snprintf(jsonFeedback, sizeof(jsonFeedback),
             "{\"state\":%s,\"action\":\"%s\",\"value\":%d,\"pin\":%d,\"deviceId\":\"%s\",\"statusText\":\"%s\"}",
             turnOn ? "true" : "false", turnOn ? "OPEN" : "CLOSE", turnOn ? 100 : 0, targetPin, targetDevice, turnOn ? "Terbuka" : "Terkunci");

    // Publikasikan ke topik status perangkat
    char stateTopic[80];
    snprintf(stateTopic, sizeof(stateTopic), "%s/%s/state", TARGET_ACCOUNT_PREFIX, targetDevice);
    mqttClient.publish(stateTopic, strState);
    mqttClient.publish(stateTopic, jsonFeedback);

    // Fallback jika device adalah pagar utama
    if (strcmp(targetDevice, "pagar") == 0) {
      mqttClient.publish("alrisa/pagar/state", strState);
      mqttClient.publish("alrisa/pagar/state", jsonFeedback);
    }

    Serial.print("📡 [STATUS BALIK KE CLOUD] Topik: ");
    Serial.print(stateTopic);
    Serial.print(" | Status: ");
    Serial.println(strState);
  }
}

// -----------------------------------------------------------------------------
// 5. PARSER PESAN MASUK DARI MQTT DENGAN FILTERING IDENTITAS GERBANG
// -----------------------------------------------------------------------------
void onMqttMessageReceived(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();

  String strTopic = String(topic);

  // 1. Abaikan jika topik berupa feedback status (/state)
  if (strTopic.endsWith("/state")) {
    return;
  }

  // 2. Ekstrak nama Device ID dari topik (misal: "alrisa/gerbang_kedua/set" -> "gerbang_kedua")
  String topicDevId = "";
  int lastSlash = strTopic.lastIndexOf('/');
  if (lastSlash > 0) {
    int prevSlash = strTopic.lastIndexOf('/', lastSlash - 1);
    if (prevSlash >= 0) {
      topicDevId = strTopic.substring(prevSlash + 1, lastSlash);
    } else {
      topicDevId = strTopic.substring(0, lastSlash);
    }
  }

  // 3. Ekstrak Pin GPIO dari Payload JSON (misal: "pin": 4)
  int payloadPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx >= 0) {
    String sub = message.substring(pinIdx + 6);
    sub.trim();
    payloadPin = sub.toInt();
  }

  // 4. LOGIKA FILTERING (PENYARINGAN KETAT UNTUK MULTI-GERBANG & MULTI-USER):
  if (STRICT_MATCHING) {
    bool isMatchById  = (topicDevId.equalsIgnoreCase(TARGET_DEVICE_ID));
    bool isMatchByPin = (payloadPin > 0 && payloadPin == TARGET_GPIO_PIN);

    // Jika perintah BUKAN untuk Device ID ini dan BUKAN untuk PIN GPIO ini -> ABAIKAN!
    if (!isMatchById && !isMatchByPin) {
      Serial.println("--------------------------------------------------------");
      Serial.print("⏩ [DIABAIKAN] Perintah ditujukan untuk gerbang lain: \"");
      Serial.print(topicDevId);
      if (payloadPin > 0) {
        Serial.print("\" (GPIO ");
        Serial.print(payloadPin);
        Serial.print(")");
      } else {
        Serial.print("\"");
      }
      Serial.print("\nℹ️  ESP32 ini khusus mengontrol: \"");
      Serial.print(TARGET_DEVICE_ID);
      Serial.print("\" pada PIN GPIO ");
      Serial.println(TARGET_GPIO_PIN);
      Serial.println("--------------------------------------------------------");
      return;
    }
  }

  Serial.println("--------------------------------------------------------");
  Serial.print("🎯 [PERINTAH DITERIMA — SESUAI TARGET!]\n📍 Topik : ");
  Serial.println(topic);
  Serial.print("📦 Isi   : ");
  Serial.println(message);

  bool turnOn = false;
  bool turnOff = false;

  // Evaluasi jika format JSON
  if (message.startsWith("{")) {
    if (message.indexOf("\"state\":true") >= 0 ||
        message.indexOf("\"state\": true") >= 0 ||
        message.indexOf("\"action\":\"OPEN\"") >= 0 ||
        message.indexOf("\"action\":\"ON\"") >= 0 ||
        message.indexOf("\"action\":\"BUKA\"") >= 0) {
      turnOn = true;
    } else if (message.indexOf("\"state\":false") >= 0 ||
               message.indexOf("\"state\": false") >= 0 ||
               message.indexOf("\"action\":\"CLOSE\"") >= 0 ||
               message.indexOf("\"action\":\"OFF\"") >= 0 ||
               message.indexOf("\"action\":\"TUTUP\"") >= 0 ||
               message.indexOf("\"action\":\"LOCKED\"") >= 0) {
      turnOff = true;
    }
  } 
  // Evaluasi jika format teks singkat (OPEN, CLOSE, BUKA, TUTUP)
  else {
    String upper = message;
    upper.toUpperCase();
    if (upper == "OPEN" || upper == "ON" || upper == "1" || upper == "BUKA" || upper == "TRUE") {
      turnOn = true;
    } else if (upper == "CLOSE" || upper == "OFF" || upper == "0" || upper == "TUTUP" || upper == "FALSE" || upper == "LOCKED") {
      turnOff = true;
    }
  }

  if (turnOn) {
    setRelay(true, TARGET_DEVICE_ID, TARGET_GPIO_PIN);
  } else if (turnOff) {
    setRelay(false, TARGET_DEVICE_ID, TARGET_GPIO_PIN);
  } else {
    Serial.println("ℹ️ Format perintah bukan instruksi BUKA/TUTUP yang valid.");
  }
  Serial.println("--------------------------------------------------------");
}

// -----------------------------------------------------------------------------
// 6. KONEKSI & REKONEKSI MQTT CLOUD
// -----------------------------------------------------------------------------
void checkMqttConnection() {
  static unsigned long lastConnectAttempt = 0;
  unsigned long now = millis();

  if (!mqttClient.connected() && (now - lastConnectAttempt > 4000)) {
    lastConnectAttempt = now;
    Serial.print("🌐 Menghubungkan ke EMQX Broker (");
    Serial.print(MQTT_SERVER);
    Serial.print(")... ");

    if (mqttClient.connect(mqttClientId)) {
      Serial.println("TERHUBUNG! ✅");

      // Berlangganan topik kendali akun ini dan fallback nexora
      char topicSub[64];
      snprintf(topicSub, sizeof(topicSub), "%s/#", TARGET_ACCOUNT_PREFIX);
      mqttClient.subscribe(topicSub);
      mqttClient.subscribe("nexora/#");

      Serial.print("📡 Berhasil subscribe: ");
      Serial.println(topicSub);

      // Publikasikan status awal ke broker
      setRelay(isRelayActive, TARGET_DEVICE_ID, TARGET_GPIO_PIN);

      Serial.println("✅ ESP32 Siap menerima kendali!\n");
    } else {
      Serial.print("Gagal (state=");
      Serial.print(mqttClient.state());
      Serial.println("), akan coba lagi...");
    }
  }
}

// -----------------------------------------------------------------------------
// 7. INPUT MANUAL DARI SERIAL MONITOR (TESTING CEPAT DI WOKWI)
// -----------------------------------------------------------------------------
void handleSerialMonitor() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() == 0) return;

    Serial.print("\n⌨️ [SERIAL MONITOR TEST]: ");
    Serial.println(input);

    if (input.equalsIgnoreCase("OPEN") || input.equalsIgnoreCase("ON") || input.equalsIgnoreCase("1") || input.equalsIgnoreCase("BUKA")) {
      setRelay(true, TARGET_DEVICE_ID, TARGET_GPIO_PIN);
    } else if (input.equalsIgnoreCase("CLOSE") || input.equalsIgnoreCase("OFF") || input.equalsIgnoreCase("0") || input.equalsIgnoreCase("TUTUP")) {
      setRelay(false, TARGET_DEVICE_ID, TARGET_GPIO_PIN);
    } else {
      Serial.println("❓ Ketik 'OPEN' atau 'CLOSE' untuk menguji relay secara manual.");
    }
  }
}

// -----------------------------------------------------------------------------
// 8. SETUP & LOOP UTAMA
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(300);

  // Buat Client ID acak unik
  randomSeed(micros());
  snprintf(mqttClientId, sizeof(mqttClientId), "ALRISA_%s_%04X", TARGET_DEVICE_ID, (unsigned int)random(0xFFFF));

  Serial.println("\n========================================================");
  Serial.println("🚀 ALRISA SMART HOME & IOT HUB — ESP32 CONTROLLER");
  Serial.print("🏢 Akun Target   : "); Serial.println(TARGET_ACCOUNT_PREFIX);
  Serial.print("🚪 Target Gerbang : "); Serial.println(TARGET_DEVICE_ID);
  Serial.print("📌 Pin GPIO Relay : GPIO "); Serial.println(TARGET_GPIO_PIN);
  Serial.print("🔒 Strict Filter  : "); Serial.println(STRICT_MATCHING ? "AKTIF (Menolak Perangkat Lain)" : "NONAKTIF");
  Serial.print("🆔 Client ID      : "); Serial.println(mqttClientId);
  Serial.println("========================================================");

  pinMode(TARGET_GPIO_PIN, OUTPUT);
  setRelay(false, TARGET_DEVICE_ID, TARGET_GPIO_PIN); // Posisi awal: Relay Terputus (OFF)

  // Hubungkan ke WiFi
  Serial.print("📶 Menghubungkan ke WiFi (");
  Serial.print(WIFI_SSID);
  Serial.print(")...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }

  Serial.println("\n🎉 WiFi Terhubung!");
  Serial.print("📍 IP Address: ");
  Serial.println(WiFi.localIP());

  // Setup MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(onMqttMessageReceived);
  mqttClient.setBufferSize(512);

  Serial.println("\n💡 TIPS MULTI-GERBANG:");
  Serial.println("Jika perintah dari Web/HP untuk Gerbang atau Pin lain, ESP32 ini akan mengabaikannya secara otomatis!");
  Serial.println("========================================================\n");
}

void loop() {
  handleSerialMonitor();

  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      checkMqttConnection();
    } else {
      mqttClient.loop();
    }
  }
}
