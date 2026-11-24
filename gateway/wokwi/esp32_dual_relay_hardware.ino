/*
  =============================================================================
  ALRISA & NEXORA SMART HOME — ESP32 DUAL GATE CONTROLLER (HARDWARE EDITION)
  1 Unit ESP32 Mengontrol 2 Gerbang / 2 Relay Fisik Sekaligus (Multi-Pin GPIO)
  Pengembang: Alfatech Solutions IDN
  =============================================================================

  SKENARIO HARDWARE (1 ESP32 MENGONTROL 2 GERBANG FISIK):
  - Gerbang 1 (Utama) : Device ID = "pagar", Pin Relay IN1 = GPIO 23
  - Gerbang 2 (Kedua) : Device ID = "gerbang_kedua", Pin Relay IN2 = GPIO 22

  WIRING DARI ESP32 KE MODUL DUAL RELAY:
  - VCC / DC+  -> 5V / VIN (ESP32)
  - GND / DC-  -> GND (ESP32)
  - IN1        -> GPIO 23 (Relay Gerbang 1)
  - IN2        -> GPIO 22 (Relay Gerbang 2)

  CATATAN TERMINAL RELAY KE MOTOR GERBANG:
  - Gunakan terminal COM (Common) dan NO (Normally Open).
  - Ketika perintah Buka -> Kontak COM-NO Menyambung (Motor jalan / gerbang buka).
  - Ketika perintah Kunci -> Kontak COM-NO Terputus (Motor mati / gerbang aman).
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// -----------------------------------------------------------------------------
// ⚙️ 1. PENGATURAN IDENTITAS AKUN & 2 GERBANG (SESUAIKAN DENGAN WEBSITE/APP)
// -----------------------------------------------------------------------------
// A. Akun Pemilik (Prefix Topik MQTT):
const char* TARGET_ACCOUNT_PREFIX = "alrisa";

// B. Definisi Gerbang 1 (Gerbang Utama):
const char* GATE1_DEVICE_ID = "pagar";
const int   GATE1_GPIO_PIN  = 23; // Pin aman ESP32 (Hubungkan ke IN1 Relay)
bool        gate1State      = false;

// C. Definisi Gerbang 2 (Gerbang Kedua / Pagar Belakang):
const char* GATE2_DEVICE_ID = "gerbang_kedua";
const int   GATE2_GPIO_PIN  = 22; // Pin aman ESP32 (Hubungkan ke IN2 Relay)
bool        gate2State      = false;

// -----------------------------------------------------------------------------
// ⚙️ 2. KONFIGURASI WIFI & MQTT BROKER
// -----------------------------------------------------------------------------
// Ganti dengan nama WiFi / Hotspot Anda (Wajib frekuensi 2.4 GHz, bukan 5 GHz):
const char* WIFI_SSID     = "NAMA_WIFI_ANDA";
const char* WIFI_PASSWORD = "PASSWORD_WIFI_ANDA";

// Opsi Broker:
// 1. Cloud Publik: "broker.emqx.io"
// 2. Private Broker Laptop/Mini PC: Ganti dengan IP laptop Anda (misal "192.168.1.15")
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;

char mqttClientId[40];

// -----------------------------------------------------------------------------
// ⚙️ 3. KARAKTERISTIK MODUL RELAY FISIK (ACTIVE-LOW VS ACTIVE-HIGH)
// -----------------------------------------------------------------------------
// Sebagian besar modul relay 5V di pasaran bertipe Active-LOW:
// - Sinyal LOW (0V)   = Relay AKTIF / Menyambung (Klik ON)
// - Sinyal HIGH (3.3V) = Relay MATI / Terputus (Klik OFF)
// Jika modul relay Anda tipe Active-HIGH, ubah nilai di bawah menjadi 'false'.
const bool RELAY_ACTIVE_LOW = true;

WiFiClient espClient;
PubSubClient mqttClient(espClient);

// -----------------------------------------------------------------------------
// 4. FUNGSI AKTIVASI RELAY PER GERBANG
// -----------------------------------------------------------------------------
void setGateRelay(int gateNumber, bool turnOn) {
  int targetPin = (gateNumber == 1) ? GATE1_GPIO_PIN : GATE2_GPIO_PIN;
  const char* targetName = (gateNumber == 1) ? GATE1_DEVICE_ID : GATE2_DEVICE_ID;

  if (gateNumber == 1) gate1State = turnOn;
  else gate2State = turnOn;

  // Gerakkan pin fisik relay
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(targetPin, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(targetPin, turnOn ? HIGH : LOW);
  }

  // Tampilkan log di Serial Monitor
  Serial.println("\n========================================================");
  if (turnOn) {
    Serial.print("⚡ [RELAY ON / MENYAMBUNG] Gerbang: ");
    Serial.print(targetName);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("🟢 Kontak COM-NO Menyambung -> Motor Gerbang BEBAN MENYALA!");
  } else {
    Serial.print("🛑 [RELAY OFF / TERPUTUS] Gerbang: ");
    Serial.print(targetName);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("⚫ Kontak COM-NO Terputus   -> Motor Gerbang BEBAN PADAM!");
  }
  Serial.println("========================================================");

  // Kirim feedback status balik ke Web & HP
  if (mqttClient.connected()) {
    const char* strState = turnOn ? "OPEN" : "LOCKED";
    char jsonFeedback[140];
    snprintf(jsonFeedback, sizeof(jsonFeedback),
             "{\"state\":%s,\"action\":\"%s\",\"value\":%d,\"pin\":%d,\"deviceId\":\"%s\",\"statusText\":\"%s\"}",
             turnOn ? "true" : "false", turnOn ? "OPEN" : "CLOSE", turnOn ? 100 : 0, targetPin, targetName, turnOn ? "Terbuka" : "Terkunci");

    char stateTopic[80];
    snprintf(stateTopic, sizeof(stateTopic), "%s/%s/state", TARGET_ACCOUNT_PREFIX, targetName);
    mqttClient.publish(stateTopic, strState);
    mqttClient.publish(stateTopic, jsonFeedback);

    // Kompatibilitas ganda topik utama
    if (strcmp(targetName, "pagar") == 0) {
      mqttClient.publish("alrisa/pagar/state", strState);
      mqttClient.publish("alrisa/pagar/state", jsonFeedback);
      mqttClient.publish("nexora/pagar/state", strState);
      mqttClient.publish("nexora/pagar/state", jsonFeedback);
    }
    Serial.print("📡 [FEEDBACK STATUS TERKIRIM] ");
    Serial.print(stateTopic);
    Serial.print(" -> ");
    Serial.println(strState);
  }
}

// -----------------------------------------------------------------------------
// 5. PARSER PESAN MASUK (MENYARING GERBANG 1 VS GERBANG 2)
// -----------------------------------------------------------------------------
void onMqttMessageReceived(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();
  String strTopic = String(topic);

  // Abaikan feedback state agar tidak terjadi feedback loop
  if (strTopic.endsWith("/state")) return;

  // Ekstrak device ID dari topik (contoh: alrisa/pagar/set -> deviceId: "pagar")
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

  // Ekstrak nomor Pin GPIO jika format JSON menyertakan info pin
  int payloadPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx >= 0) {
    String sub = message.substring(pinIdx + 6);
    sub.trim();
    payloadPin = sub.toInt();
  }

  // Tentukan apakah pesan ditujukan untuk Gerbang 1 atau Gerbang 2
  int targetGate = 0; // 0 = abaikan, 1 = Gerbang 1, 2 = Gerbang 2

  if (topicDevId.equalsIgnoreCase(GATE1_DEVICE_ID) || payloadPin == GATE1_GPIO_PIN) {
    targetGate = 1;
  } else if (topicDevId.equalsIgnoreCase(GATE2_DEVICE_ID) || payloadPin == GATE2_GPIO_PIN) {
    targetGate = 2;
  }

  if (targetGate == 0) {
    Serial.println("--------------------------------------------------------");
    Serial.print("⏩ [DIABAIKAN] Perintah untuk perangkat lain: \"");
    Serial.print(topicDevId);
    if (payloadPin > 0) {
      Serial.print("\" (GPIO "); Serial.print(payloadPin); Serial.print(")");
    } else {
      Serial.print("\"");
    }
    Serial.print("\nℹ️  ESP32 ini hanya mengontrol Gerbang 1 (GPIO ");
    Serial.print(GATE1_GPIO_PIN);
    Serial.print(") & Gerbang 2 (GPIO ");
    Serial.print(GATE2_GPIO_PIN);
    Serial.println(").");
    Serial.println("--------------------------------------------------------");
    return;
  }

  Serial.println("--------------------------------------------------------");
  Serial.print("🎯 [PERINTAH DITERIMA] -> Ditujukan ke GERBANG ");
  Serial.println(targetGate);
  Serial.print("📍 Topik: "); Serial.println(topic);
  Serial.print("📦 Isi  : "); Serial.println(message);

  bool turnOn = false;
  bool turnOff = false;

  // Mendukung JSON format & String mentah (OPEN/CLOSE/1/0/BUKA/TUTUP)
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
  } else {
    String upper = message;
    upper.toUpperCase();
    if (upper == "OPEN" || upper == "ON" || upper == "1" || upper == "BUKA" || upper == "TRUE") {
      turnOn = true;
    } else if (upper == "CLOSE" || upper == "OFF" || upper == "0" || upper == "TUTUP" || upper == "FALSE" || upper == "LOCKED") {
      turnOff = true;
    }
  }

  if (turnOn) {
    setGateRelay(targetGate, true);
  } else if (turnOff) {
    setGateRelay(targetGate, false);
  }
  Serial.println("--------------------------------------------------------");
}

// -----------------------------------------------------------------------------
// 6. KONEKSI & REKONEKSI MQTT
// -----------------------------------------------------------------------------
void checkMqttConnection() {
  static unsigned long lastAttempt = 0;
  unsigned long now = millis();

  if (!mqttClient.connected() && (now - lastAttempt > 4000)) {
    lastAttempt = now;
    Serial.print("🌐 Menghubungkan ke MQTT Broker (");
    Serial.print(MQTT_SERVER);
    Serial.print(")... ");

    if (mqttClient.connect(mqttClientId)) {
      Serial.println("TERHUBUNG! ✅");

      // Subscribe topik akun dan topik nexora
      char subTopic[64];
      snprintf(subTopic, sizeof(subTopic), "%s/#", TARGET_ACCOUNT_PREFIX);
      mqttClient.subscribe(subTopic);
      mqttClient.subscribe("nexora/#");

      Serial.print("📡 Berhasil subscribe: ");
      Serial.println(subTopic);

      // Inisialisasi status awal ke broker
      setGateRelay(1, gate1State);
      setGateRelay(2, gate2State);

      Serial.println("✅ ESP32 Dual Gate Siap Menerima Kendali Fisik!\n");
    } else {
      Serial.print("Gagal (state=");
      Serial.print(mqttClient.state());
      Serial.println("), akan coba lagi...");
    }
  }
}

// -----------------------------------------------------------------------------
// 7. SETUP & LOOP
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(300);

  // Inisialisasi Client ID Unik
  randomSeed(micros());
  snprintf(mqttClientId, sizeof(mqttClientId), "ALRISA_DUAL_%04X", (unsigned int)random(0xFFFF));

  Serial.println("\n========================================================");
  Serial.println("🚀 ALRISA & NEXORA — ESP32 DUAL GATE (HARDWARE EDITION)");
  Serial.print("🏢 Akun Target   : "); Serial.println(TARGET_ACCOUNT_PREFIX);
  Serial.print("🚪 Gerbang 1     : "); Serial.print(GATE1_DEVICE_ID); Serial.print(" -> PIN GPIO "); Serial.println(GATE1_GPIO_PIN);
  Serial.print("🚪 Gerbang 2     : "); Serial.print(GATE2_DEVICE_ID); Serial.print(" -> PIN GPIO "); Serial.println(GATE2_GPIO_PIN);
  Serial.print("⚡ Mode Relay    : "); Serial.println(RELAY_ACTIVE_LOW ? "Active-LOW (Standar Modul 5V)" : "Active-HIGH");
  Serial.println("========================================================");

  // 1. Inisialisasi kedua Pin GPIO Relay dengan Status Awal MATI/TERKUNCI
  pinMode(GATE1_GPIO_PIN, OUTPUT);
  pinMode(GATE2_GPIO_PIN, OUTPUT);
  digitalWrite(GATE1_GPIO_PIN, RELAY_ACTIVE_LOW ? HIGH : LOW);
  digitalWrite(GATE2_GPIO_PIN, RELAY_ACTIVE_LOW ? HIGH : LOW);

  // 2. Hubungkan ke WiFi
  Serial.print("📶 Menghubungkan ke WiFi (");
  Serial.print(WIFI_SSID);
  Serial.print(")...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }

  Serial.println("\n🎉 WiFi Terhubung! IP ESP32: ");
  Serial.println(WiFi.localIP());

  // 3. Inisialisasi MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(onMqttMessageReceived);
  mqttClient.setBufferSize(512);
}

void loop() {
  // Fitur Uji Coba Manual via Serial Monitor Arduino IDE:
  // Ketik '1 ON'  -> Relay 1 (Gerbang Utama) menyala
  // Ketik '1 OFF' -> Relay 1 (Gerbang Utama) mati
  // Ketik '2 ON'  -> Relay 2 (Gerbang Kedua) menyala
  // Ketik '2 OFF' -> Relay 2 (Gerbang Kedua) mati
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.equalsIgnoreCase("1 ON") || input.equalsIgnoreCase("1 OPEN")) setGateRelay(1, true);
    else if (input.equalsIgnoreCase("1 OFF") || input.equalsIgnoreCase("1 CLOSE")) setGateRelay(1, false);
    else if (input.equalsIgnoreCase("2 ON") || input.equalsIgnoreCase("2 OPEN")) setGateRelay(2, true);
    else if (input.equalsIgnoreCase("2 OFF") || input.equalsIgnoreCase("2 CLOSE")) setGateRelay(2, false);
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      checkMqttConnection();
    } else {
      mqttClient.loop();
    }
  }
}
