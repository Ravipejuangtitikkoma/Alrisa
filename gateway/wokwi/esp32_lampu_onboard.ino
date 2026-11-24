/*
  =============================================================================
  ALRISA & NEXORA SMART HOME — ESP32 ONBOARD LED TESTER (AKUN USUP)
  Khusus Akun "usup" (email: usup@gmail.com) di Website Dashboard
  Pengembang: Alfatech Solutions IDN.
  =============================================================================

  PENYEBAB LAMPU SEBELUMNYA TIDAK BERUBAH:
  1. Prefix Topik di Website untuk Akun Usup adalah "alrisa/usup" (BUKAN "usup").
     - Website mem-publish ke topik: "alrisa/usup/usup_pagar/set"
     - Jika Anda hanya subscribe ke "usup/#", ESP32 TIDAK AKAN PERNAH menerima sinyalnya!
  2. ID Perangkat Gerbang Utama milik Usup di Website adalah "usup_pagar" (BUKAN "pagar").
  3. Pin Hardware: GPIO 2 (Lampu LED Biru Onboard ESP32).

  DENGAN KODINGAN INI:
  - Sudah otomatis subscribe ke "alrisa/usup/#", "alrisa/#", dan "nexora/#".
  - Sudah mengenali baik ID "usup_pagar" maupun "pagar" (Pin GPIO 2).
  - Ketika tombol Gerbang Utama diklik di Web -> LED BIRU ESP32 LANGSUNG MERESPON!
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// -----------------------------------------------------------------------------
// ⚙️ 1. PENGATURAN IDENTITAS AKUN USUP (SESUAI DATABASE WEBSITE)
// -----------------------------------------------------------------------------
// A. Prefix Topik Akun Usup di Website:
const char* TARGET_ACCOUNT_PREFIX = "alrisa/usup";

// B. ID Perangkat Gerbang Utama milik Akun Usup:
const char* TARGET_DEVICE_ID      = "usup_pagar";

// C. Pin Hardware GPIO (LED Biru Onboard ESP32):
const int   TARGET_GPIO_PIN       = 2;

// D. Filter Ketat:
const bool  STRICT_MATCHING       = true;

// -----------------------------------------------------------------------------
// 2. KONFIGURASI WIFI & MQTT BROKER
// -----------------------------------------------------------------------------
const char* WIFI_SSID     = "Gatau ini apa";
const char* WIFI_PASSWORD = "Almar1812";

// Cloud MQTT Broker EMQX (Publik & Gratis)
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;

char mqttClientId[40];

// Logika LED Onboard ESP32: HIGH = Menyala, LOW = Padam
const bool RELAY_ACTIVE_LOW = false;

// -----------------------------------------------------------------------------
// 3. VARIABEL STATE SISTEM
// -----------------------------------------------------------------------------
bool isRelayActive = false;
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// -----------------------------------------------------------------------------
// 4. FUNGSI PENGGERAK LAMPU & PENGIRIMAN FEEDBACK KE CLOUD
// -----------------------------------------------------------------------------
void setRelay(bool turnOn, const char* targetDevice, int targetPin) {
  isRelayActive = turnOn;

  // Aktifkan atau matikan LED Biru Onboard ESP32
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(targetPin, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(targetPin, turnOn ? HIGH : LOW);
  }

  // Tampilkan visual log di Serial Monitor
  Serial.println("\n========================================================");
  if (turnOn) {
    Serial.print("⚡ [ON / MENYAMBUNG] Perangkat: ");
    Serial.print(targetDevice);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("🟢 Lampu LED Onboard MENYALA -> Gerbang Utama BEBAN AKTIF!");
  } else {
    Serial.print("🛑 [OFF / TERPUTUS] Perangkat: ");
    Serial.print(targetDevice);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("⚫ Lampu LED Onboard PADAM   -> Gerbang Utama BEBAN PADAM!");
  }
  Serial.println("========================================================");

  // Kirim feedback status balik ke broker MQTT agar Web seketika terupdate!
  if (mqttClient.connected()) {
    const char* strState = turnOn ? "OPEN" : "LOCKED";
    char jsonFeedback[150];
    snprintf(jsonFeedback, sizeof(jsonFeedback),
             "{\"state\":%s,\"action\":\"%s\",\"value\":%d,\"pin\":%d,\"deviceId\":\"%s\",\"statusText\":\"%s\"}",
             turnOn ? "true" : "false", turnOn ? "OPEN" : "CLOSE", turnOn ? 100 : 0, targetPin, targetDevice, turnOn ? "Terbuka" : "Terkunci");

    // Publikasikan ke topik usup
    char stateTopic[90];
    snprintf(stateTopic, sizeof(stateTopic), "%s/%s/state", TARGET_ACCOUNT_PREFIX, targetDevice);
    mqttClient.publish(stateTopic, strState);
    mqttClient.publish(stateTopic, jsonFeedback);

    // Fallback publish ke berbagai variasi topik agar web 100% mendeteksi
    mqttClient.publish("alrisa/usup/usup_pagar/state", strState);
    mqttClient.publish("alrisa/usup/usup_pagar/state", jsonFeedback);
    mqttClient.publish("alrisa/usup/pagar/state", strState);
    mqttClient.publish("alrisa/usup/pagar/state", jsonFeedback);
    mqttClient.publish("alrisa/pagar/state", strState);
    mqttClient.publish("alrisa/pagar/state", jsonFeedback);
    mqttClient.publish("nexora/pagar/state", strState);
    mqttClient.publish("nexora/pagar/state", jsonFeedback);

    Serial.print("📡 [STATUS BALIK KE WEB] Topik: ");
    Serial.print(stateTopic);
    Serial.print(" | Status: ");
    Serial.println(strState);
  }
}

// -----------------------------------------------------------------------------
// 5. PARSER PESAN MASUK DARI MQTT DENGAN FILTERING FLEKSIBEL
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

  // 2. Ekstrak nama Device ID dari topik
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

  // 3. Ekstrak Pin GPIO dari Payload JSON (misal: "pin": 2)
  int payloadPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx >= 0) {
    String sub = message.substring(pinIdx + 6);
    sub.trim();
    payloadPin = sub.toInt();
  }

  // 4. LOGIKA FILTERING KETAT (STRICT PIN & ID MATCHING):
  // A. VALIDASI PIN: Jika website mengirim nomor Pin spesifik, WAJIB COCOK dengan Pin ESP32 (GPIO 2)!
  //    Jika di website diatur GPIO 15 sedangkan ESP32 ini pin 2, maka perintah DITOLAK!
  if (payloadPin > 0 && payloadPin != TARGET_GPIO_PIN) {
    Serial.println("--------------------------------------------------------");
    Serial.println("❌ [DITOLAK — PIN HARDWARE TIDAK COCOK!]");
    Serial.print("📍 Topik   : "); Serial.println(topic);
    Serial.print("🌐 Pin Web : GPIO "); Serial.print(payloadPin);
    Serial.print(" | 📟 Pin ESP32 : GPIO "); Serial.println(TARGET_GPIO_PIN);
    Serial.println("⚠️  Lampu LED Onboard TIDAK MENYALA karena pin di website berbeda!");
    Serial.println("👉 Solusi: Di pop-up website, klik tombol 'GPIO 2 (%QX0.0)' lalu Simpan.");
    Serial.println("--------------------------------------------------------");
    return;
  }

  // B. VALIDASI DEVICE ID: Hanya merespon jika perintah untuk usup_pagar / pagar
  bool isMatchById = (topicDevId.equalsIgnoreCase(TARGET_DEVICE_ID) ||
                      topicDevId.equalsIgnoreCase("usup_pagar") ||
                      topicDevId.equalsIgnoreCase("pagar"));

  if (STRICT_MATCHING && !isMatchById) {
    Serial.println("--------------------------------------------------------");
    Serial.print("⏩ [DIABAIKAN] Perintah ditujukan untuk perangkat lain: \"");
    Serial.print(topicDevId);
    Serial.println("\"");
    Serial.print("ℹ️  ESP32 ini khusus untuk Usup: \"");
    Serial.print(TARGET_DEVICE_ID);
    Serial.print("\" pada PIN GPIO ");
    Serial.println(TARGET_GPIO_PIN);
    Serial.println("--------------------------------------------------------");
    return;
  }

  Serial.println("--------------------------------------------------------");
  Serial.print("🎯 [PERINTAH DITERIMA UNTUK USUP!]\n📍 Topik : ");
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
  // Evaluasi jika format teks biasa (OPEN, CLOSE, BUKA, TUTUP, 1, 0)
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

      // Berlangganan topik Akun Usup & Global
      mqttClient.subscribe("alrisa/usup/#");
      mqttClient.subscribe("alrisa/#");
      mqttClient.subscribe("usup/#");
      mqttClient.subscribe("nexora/#");

      Serial.println("📡 Berhasil subscribe topik:");
      Serial.println("   - alrisa/usup/# (Topik Akun Usup)");
      Serial.println("   - alrisa/# (Topik Global)");
      Serial.println("   - nexora/#");

      // Publikasikan status awal ke broker
      setRelay(isRelayActive, TARGET_DEVICE_ID, TARGET_GPIO_PIN);

      Serial.println("✅ ESP32 Usup Siap menerima kendali!\n");
    } else {
      Serial.print("Gagal (state=");
      Serial.print(mqttClient.state());
      Serial.println("), akan coba lagi...");
    }
  }
}

// -----------------------------------------------------------------------------
// 7. INPUT MANUAL DARI SERIAL MONITOR (TESTING CEPAT)
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
      Serial.println("❓ Ketik 'OPEN' atau 'CLOSE' untuk menguji lampu secara manual.");
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
  snprintf(mqttClientId, sizeof(mqttClientId), "ALRISA_USUP_%04X", (unsigned int)random(0xFFFF));

  // Inisialisasi Pin GPIO 2 (Lampu LED Onboard)
  pinMode(TARGET_GPIO_PIN, OUTPUT);

  // Kedip tes 3x saat awal nyala (menandakan alat siap)
  for (int i = 0; i < 3; i++) {
    digitalWrite(TARGET_GPIO_PIN, HIGH);
    delay(100);
    digitalWrite(TARGET_GPIO_PIN, LOW);
    delay(100);
  }

  Serial.println("\n========================================================");
  Serial.println("🚀 ALRISA & NEXORA — ESP32 ONBOARD LED (AKUN USUP)");
  Serial.print("🏢 Akun Target   : "); Serial.println(TARGET_ACCOUNT_PREFIX);
  Serial.print("🚪 Target Gerbang : "); Serial.println(TARGET_DEVICE_ID);
  Serial.print("📌 Pin GPIO LED   : GPIO "); Serial.println(TARGET_GPIO_PIN);
  Serial.print("🆔 Client ID      : "); Serial.println(mqttClientId);
  Serial.println("========================================================");

  setRelay(false, TARGET_DEVICE_ID, TARGET_GPIO_PIN); // Posisi awal: Padam (OFF)

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
