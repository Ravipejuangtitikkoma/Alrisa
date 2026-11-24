/*
  =============================================================================
  ALRISA & NEXORA SMART HOME — ESP32 DUAL LED / LAMPU TESTER
  1 Unit ESP32 Mengontrol 2 Lampu LED Fisik (Sebagai Pengganti Relay / Simulator)
  Pengembang: Alfatech Solutions IDN
  =============================================================================

  SKENARIO TESTING LAMPU LED (PENGGANTI DUA RELAY):
  - Lampu 1 (Simulasi Gerbang Utama / Pagar) : Device ID = "pagar", Pin = GPIO 2
    👉 Keren: GPIO 2 otomatis menyalakan LED BIRU ONBOARD yang ada di badan ESP32!
  - Lampu 2 (Simulasi Gerbang Kedua / Lampu 2) : Device ID = "gerbang_kedua", Pin = GPIO 4

  SKEMA WIRING KABEL LAMPU LED FISIK KE ESP32:
  -------------------------------------------------------------
  1. LAMPU 1 (LED External opsional / LED Onboard):
     - Kaki Panjang (Anoda +)   -> Pin GPIO 2 (disertai resistor 220Ω-330Ω jika ada)
     - Kaki Pendek (Katoda -)  -> Pin GND
     *(Catatan: Tanpa pasang LED eksternal pun, LED Biru di papan ESP32 akan menyala!)*

  2. LAMPU 2 (LED External):
     - Kaki Panjang (Anoda +)   -> Pin GPIO 4 (disertai resistor 220Ω-330Ω jika ada)
     - Kaki Pendek (Katoda -)  -> Pin GND
  -------------------------------------------------------------

  LOGIKA LAMPU LED:
  - HIGH (3.3V) -> Lampu LED MENYALA (Simulasi Relay Buka Gerbang / ON)
  - LOW  (0V)   -> Lampu LED PADAM   (Simulasi Relay Kunci Gerbang / OFF)
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// -----------------------------------------------------------------------------
// ⚙️ 1. PENGATURAN IDENTITAS PERANGKAT (GERBANG / LAMPU)
// -----------------------------------------------------------------------------
// A. Akun Pemilik (Prefix Topik MQTT):
const char* TARGET_ACCOUNT_PREFIX = "alrisa";

// B. Lampu 1 (Sebagai Pengganti Relay Gerbang Utama):
const char* GATE1_DEVICE_ID = "Gerbang_Utama";
const int   LED1_GPIO_PIN   = 14;  // LED Biru Onboard ESP32 + Pin D2
bool        led1State       = false;

// C. Lampu 2 (Sebagai Pengganti Relay Gerbang Kedua):
const char* GATE2_DEVICE_ID = "gerbang_kedua";
const int   LED2_GPIO_PIN   = 13;  // Pin D4
bool        led2State       = false;

// -----------------------------------------------------------------------------
// ⚙️ 2. KONFIGURASI WIFI & MQTT BROKER
// -----------------------------------------------------------------------------
// Ganti dengan nama WiFi / Hotspot Anda (Wajib frekuensi 2.4 GHz):
const char* WIFI_SSID     = "Gatau ini apa";
const char* WIFI_PASSWORD = "Almar1812";

// Broker MQTT:
// 1. Cloud Publik: "broker.emqx.io"
// 2. Private Broker: Ganti dengan IP laptop/Mini PC Anda (contoh: "192.168.1.15")
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;

char mqttClientId[40];

WiFiClient espClient;
PubSubClient mqttClient(espClient);

// -----------------------------------------------------------------------------
// 3. FUNGSI MENGONTROL LAMPU LED (SIMULASI RELAY)
// -----------------------------------------------------------------------------
void setLightState(int lightNumber, bool turnOn) {
  int targetPin = (lightNumber == 1) ? LED1_GPIO_PIN : LED2_GPIO_PIN;
  const char* targetName = (lightNumber == 1) ? GATE1_DEVICE_ID : GATE2_DEVICE_ID;

  if (lightNumber == 1) led1State = turnOn;
  else led2State = turnOn;

  // Lampu LED: HIGH = MENYALA, LOW = PADAM
  digitalWrite(targetPin, turnOn ? HIGH : LOW);

  // Tampilkan di Serial Monitor
  Serial.println("\n========================================================");
  if (turnOn) {
    Serial.print("💡 [LAMPU MENYALA / RELAY ON] Target: ");
    Serial.print(targetName);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("🟢 Lampu LED MENYALA -> Sinyal Buka Gerbang / Beban AKTIF!");
  } else {
    Serial.print("⚫ [LAMPU PADAM / RELAY OFF] Target: ");
    Serial.print(targetName);
    Serial.print(" | PIN: GPIO ");
    Serial.println(targetPin);
    Serial.println("🔴 Lampu LED PADAM   -> Sinyal Kunci Gerbang / Beban MATI!");
  }
  Serial.println("========================================================");

  // Kirim feedback status ke MQTT Web & Aplikasi HP
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

    // Kompatibilitas topik pagar & lampu
    if (strcmp(targetName, "pagar") == 0) {
      mqttClient.publish("alrisa/pagar/state", strState);
      mqttClient.publish("alrisa/pagar/state", jsonFeedback);
      mqttClient.publish("nexora/pagar/state", strState);
      mqttClient.publish("nexora/pagar/state", jsonFeedback);
    }

    Serial.print("📡 [FEEDBACK TERKIRIM] ");
    Serial.print(stateTopic);
    Serial.print(" -> ");
    Serial.println(strState);
  }
}

// -----------------------------------------------------------------------------
// 4. PARSER PESAN MASUK (MENERIMA PERINTAH WEB / APP / SERIAL)
// -----------------------------------------------------------------------------
void onMqttMessageReceived(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();
  String strTopic = String(topic);

  // Abaikan pesan state agar tidak looping
  if (strTopic.endsWith("/state")) return;

  // Ekstrak device ID dari topik
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

  // Ekstrak pin jika dalam format JSON
  int payloadPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx >= 0) {
    String sub = message.substring(pinIdx + 6);
    sub.trim();
    payloadPin = sub.toInt();
  }

  // Tentukan apakah ditujukan untuk Lampu 1 atau Lampu 2
  int targetLight = 0;

  // Mendukung nama: pagar, lampu, lampu1, atau pin 2
  if (topicDevId.equalsIgnoreCase(GATE1_DEVICE_ID) ||
      topicDevId.equalsIgnoreCase("lampu") ||
      topicDevId.equalsIgnoreCase("lampu1") ||
      payloadPin == LED1_GPIO_PIN) {
    targetLight = 1;
  }
  // Mendukung nama: gerbang_kedua, lampu2, atau pin 4
  else if (topicDevId.equalsIgnoreCase(GATE2_DEVICE_ID) ||
           topicDevId.equalsIgnoreCase("lampu2") ||
           payloadPin == LED2_GPIO_PIN) {
    targetLight = 2;
  }

  if (targetLight == 0) {
    Serial.println("--------------------------------------------------------");
    Serial.print("⏩ [DIABAIKAN] Perintah untuk device lain: \"");
    Serial.print(topicDevId);
    Serial.println("\"");
    Serial.print("ℹ️  ESP32 ini hanya mengontrol Lampu 1 (GPIO ");
    Serial.print(LED1_GPIO_PIN);
    Serial.print(") & Lampu 2 (GPIO ");
    Serial.print(LED2_GPIO_PIN);
    Serial.println(").");
    Serial.println("--------------------------------------------------------");
    return;
  }

  Serial.println("--------------------------------------------------------");
  Serial.print("🎯 [PERINTAH DITERIMA] -> Ditujukan ke LAMPU ");
  Serial.println(targetLight);
  Serial.print("📍 Topik: "); Serial.println(topic);
  Serial.print("📦 Isi  : "); Serial.println(message);

  bool turnOn = false;
  bool turnOff = false;

  // Mendukung format JSON maupun text biasa (OPEN, ON, 1, CLOSE, OFF, 0)
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
    setLightState(targetLight, true);
  } else if (turnOff) {
    setLightState(targetLight, false);
  }
  Serial.println("--------------------------------------------------------");
}

// -----------------------------------------------------------------------------
// 5. KONEKSI & REKONEKSI MQTT
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

      char subTopic[64];
      snprintf(subTopic, sizeof(subTopic), "%s/#", TARGET_ACCOUNT_PREFIX);
      mqttClient.subscribe(subTopic);
      mqttClient.subscribe("nexora/#");

      Serial.print("📡 Berhasil subscribe: ");
      Serial.println(subTopic);

      // Sinkronisasi status awal
      setLightState(1, led1State);
      setLightState(2, led2State);

      Serial.println("✅ ESP32 Siap Menerima Kendali Lampu LED!\n");
    } else {
      Serial.print("Gagal (state=");
      Serial.print(mqttClient.state());
      Serial.println("), akan coba lagi...");
    }
  }
}

// -----------------------------------------------------------------------------
// 6. SETUP & LOOP
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(300);

  randomSeed(micros());
  snprintf(mqttClientId, sizeof(mqttClientId), "ALRISA_LED_%04X", (unsigned int)random(0xFFFF));

  Serial.println("\n========================================================");
  Serial.println("🚀 ALRISA & NEXORA — ESP32 DUAL LED / LAMPU TESTER");
  Serial.print("🏢 Akun Target   : "); Serial.println(TARGET_ACCOUNT_PREFIX);
  Serial.print("💡 Lampu 1 (Pagar) : GPIO "); Serial.print(LED1_GPIO_PIN); Serial.println(" (LED Onboard Biru + D2)");
  Serial.print("💡 Lampu 2 (Kedua) : GPIO "); Serial.print(LED2_GPIO_PIN); Serial.println(" (Pin D4)");
  Serial.println("========================================================");

  // Inisialisasi kedua Pin LED (Kondisi Awal PADAM)
  pinMode(LED1_GPIO_PIN, OUTPUT);
  pinMode(LED2_GPIO_PIN, OUTPUT);
  digitalWrite(LED1_GPIO_PIN, LOW);
  digitalWrite(LED2_GPIO_PIN, LOW);

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

  Serial.println("\n🎉 WiFi Terhubung! IP ESP32: ");
  Serial.println(WiFi.localIP());

  // Inisialisasi MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(onMqttMessageReceived);
  mqttClient.setBufferSize(512);
}

void loop() {
  // Pengujian Manual langsung lewat Serial Monitor Arduino IDE:
  // Ketik '1 ON'  -> Menyalakan Lampu 1 (LED Onboard Biru menyala)
  // Ketik '1 OFF' -> Mematikan Lampu 1 (LED Onboard Biru padam)
  // Ketik '2 ON'  -> Menyalakan Lampu 2 (Pin D4)
  // Ketik '2 OFF' -> Mematikan Lampu 2 (Pin D4)
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.equalsIgnoreCase("1 ON") || input.equalsIgnoreCase("1 OPEN")) setLightState(1, true);
    else if (input.equalsIgnoreCase("1 OFF") || input.equalsIgnoreCase("1 CLOSE")) setLightState(1, false);
    else if (input.equalsIgnoreCase("2 ON") || input.equalsIgnoreCase("2 OPEN")) setLightState(2, true);
    else if (input.equalsIgnoreCase("2 OFF") || input.equalsIgnoreCase("2 CLOSE")) setLightState(2, false);
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      checkMqttConnection();
    } else {
      mqttClient.loop();
    }
  }
}
