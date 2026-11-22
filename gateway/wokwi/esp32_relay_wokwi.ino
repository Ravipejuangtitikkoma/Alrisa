/*
  =============================================================================
  ALRISA SMART HOME & IOT HUB — ESP32 RELAY & ACTUATOR FIRMWARE (WOKWI EDITION)
  Simulasi Virtual Kontrol Relay (Pagar, Gorden, Lampu) via Wokwi & MQTT Cloud
  Pengembang: Alfatech Solutions IDN.
  =============================================================================

  FITUR SISTEM:
  1. Koneksi Otomatis ke WiFi (Wokwi-GUEST untuk simulator / WiFi Rumah untuk alat fisik).
  2. Terhubung ke Cloud MQTT Broker (broker.emqx.io:1883) dengan Client ID unik acak.
  3. Mengendalikan Relay Beban pada GPIO 2 (dan LED Internal ESP32):
     - ON / BUKA  : Relay Kontak ON (COM-NO menyambung) -> Lampu Beban / Motor MENYALA.
     - OFF / TUTUP: Relay Kontak OFF (COM-NO terputus)  -> Lampu Beban / Motor PADAM.
  4. Mendukung multi-device (Pagar, Gorden, Lampu) dan format perintah:
     - Teks: "OPEN", "CLOSE", "ON", "OFF", "BUKA", "TUTUP", "1", "0"
     - JSON: {"state": true}, {"state": false}
  5. Feedback dua arah: Mengirim status balik ke Web Dashboard & Aplikasi HP secara real-time.
  6. Pengujian interaktif lewat Serial Monitor (bisa diketik langsung: OPEN / CLOSE).
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// -----------------------------------------------------------------------------
// 1. KONFIGURASI WIFI & MQTT BROKER
// -----------------------------------------------------------------------------
// Catatan: Di Wokwi simulator gunakan "Wokwi-GUEST" (tanpa password)
// Untuk alat fisik di rumah, ganti dengan nama WiFi & Password rumah Anda
const char* WIFI_SSID     = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

// Cloud MQTT Broker EMQX (Gratis & Publik)
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;

// Client ID dibuat dinamis di setup() agar tidak bentrok dengan pengguna lain di EMQX
char mqttClientId[40];

// -----------------------------------------------------------------------------
// 2. PIN HARDWARE ESP32
// -----------------------------------------------------------------------------
// Di Wokwi & modul ESP32 standar, GPIO 2 terhubung ke Relay Input & LED Biru Onboard
#define RELAY_PIN         2
#define LED_ONBOARD_PIN   2

// Konfigurasi tipe modul relay:
// - Wokwi Relay Module = Active-HIGH (true saat sinyal HIGH) -> RELAY_ACTIVE_LOW = false
// - Modul Relay Fisik di pasaran biasanya Active-LOW       -> ubah jadi true jika pakai alat fisik
const bool RELAY_ACTIVE_LOW = false;

// -----------------------------------------------------------------------------
// 3. VARIABEL STATE SISTEM
// -----------------------------------------------------------------------------
bool isRelayActive = false;
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// -----------------------------------------------------------------------------
// 4. FUNGSI PENGGERAK RELAY & PENGIRIMAN FEEDBACK
// -----------------------------------------------------------------------------
void setRelay(bool turnOn, const char* targetDevice = "pagar") {
  isRelayActive = turnOn;

  // Aktifkan atau nonaktifkan pin GPIO sesuai tipe logika relay
  if (RELAY_ACTIVE_LOW) {
    digitalWrite(RELAY_PIN, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(RELAY_PIN, turnOn ? HIGH : LOW);
  }
  digitalWrite(LED_ONBOARD_PIN, turnOn ? HIGH : LOW);

  // Tampilkan visual log di Serial Monitor
  Serial.println("\n========================================================");
  if (turnOn) {
    Serial.print("⚡ [RELAY ON / MENYAMBUNG] Target: ");
    Serial.println(targetDevice);
    Serial.println("🟢 Kontak COM-NO Menyambung -> Lampu Beban / Motor MENYALA!");
  } else {
    Serial.print("🛑 [RELAY OFF / TERPUTUS] Target: ");
    Serial.println(targetDevice);
    Serial.println("⚫ Kontak COM-NO Terputus   -> Lampu Beban / Motor PADAM!");
  }
  Serial.println("========================================================");

  // Kirim feedback status balik ke broker MQTT agar HP dan Web seketika terupdate!
  if (mqttClient.connected()) {
    const char* strState = turnOn ? "OPEN" : "LOCKED";
    const char* strOnOff = turnOn ? "ON" : "OFF";
    char jsonFeedback[80];
    snprintf(jsonFeedback, sizeof(jsonFeedback), "{\"state\":%s,\"value\":%d,\"statusText\":\"%s\"}",
             turnOn ? "true" : "false", turnOn ? 100 : 0, turnOn ? "Menyala" : "Terkunci");

    // Publikasikan ke topik ALRISA
    char stateTopic[64];
    snprintf(stateTopic, sizeof(stateTopic), "alrisa/%s/state", targetDevice);
    mqttClient.publish(stateTopic, strState);
    mqttClient.publish(stateTopic, jsonFeedback);

    // Publikasikan juga ke fallback topik nexora
    char nexoraStateTopic[64];
    snprintf(nexoraStateTopic, sizeof(nexoraStateTopic), "nexora/%s/state", targetDevice);
    mqttClient.publish(nexoraStateTopic, strState);
    mqttClient.publish(nexoraStateTopic, jsonFeedback);

    // Feedback cadangan untuk lampu & gorden jika dipanggil
    if (strcmp(targetDevice, "lampu_teras") == 0 || strcmp(targetDevice, "lampu") == 0) {
      mqttClient.publish("alrisa/lampu_teras/state", strOnOff);
    } else if (strcmp(targetDevice, "gorden") == 0) {
      mqttClient.publish("alrisa/gorden/state", turnOn ? "OPEN" : "CLOSED");
    }

    Serial.print("📡 [STATUS BALIK KE CLOUD] Topik: ");
    Serial.print(stateTopic);
    Serial.print(" | Nilai: ");
    Serial.println(strState);
  }
}

// -----------------------------------------------------------------------------
// 5. PARSER PESAN MASUK DARI MQTT (HP & WEB DASHBOARD)
// -----------------------------------------------------------------------------
void onMqttMessageReceived(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();

  Serial.println("--------------------------------------------------------");
  Serial.print("📩 [PERINTAH MASUK DARI CLOUD / HP]\n📍 Topik : ");
  Serial.println(topic);
  Serial.print("📦 Isi   : ");
  Serial.println(message);

  // Deteksi nama device dari topik (misal: "alrisa/pagar/set" -> device "pagar")
  String strTopic = String(topic);
  String targetDev = "pagar";
  if (strTopic.indexOf("/gorden/") >= 0) {
    targetDev = "gorden";
  } else if (strTopic.indexOf("/lampu_teras/") >= 0 || strTopic.indexOf("/lampu/") >= 0) {
    targetDev = "lampu_teras";
  } else if (strTopic.indexOf("/pintu/") >= 0) {
    targetDev = "pintu";
  }

  // Evaluasi perintah Buka/Nyalakan
  bool turnOn = (message.indexOf("OPEN") >= 0 ||
                 message.indexOf("open") >= 0 ||
                 message.indexOf("BUKA") >= 0 ||
                 message.indexOf("buka") >= 0 ||
                 message.indexOf("ON") >= 0 ||
                 message.indexOf("on") >= 0 ||
                 message.indexOf("true") >= 0 ||
                 message == "1");

  // Evaluasi perintah Tutup/Matikan
  bool turnOff = (message.indexOf("CLOSE") >= 0 ||
                  message.indexOf("close") >= 0 ||
                  message.indexOf("TUTUP") >= 0 ||
                  message.indexOf("tutup") >= 0 ||
                  message.indexOf("LOCKED") >= 0 ||
                  message.indexOf("locked") >= 0 ||
                  message.indexOf("OFF") >= 0 ||
                  message.indexOf("off") >= 0 ||
                  message.indexOf("false") >= 0 ||
                  message == "0");

  if (turnOn) {
    setRelay(true, targetDev.c_str());
  } else if (turnOff) {
    setRelay(false, targetDev.c_str());
  } else {
    Serial.println("ℹ️ Format perintah tidak dikenali atau berupa pesan status.");
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

      // Berlangganan topik kendali ALRISA & Nexora
      mqttClient.subscribe("alrisa/+/set");
      mqttClient.subscribe("alrisa/+/+/set");
      mqttClient.subscribe("alrisa/pagar/set");
      mqttClient.subscribe("alrisa/gorden/set");
      mqttClient.subscribe("alrisa/lampu_teras/set");
      mqttClient.subscribe("nexora/+/set");
      mqttClient.subscribe("nexora/pagar/set");

      Serial.println("📡 Sukses subscribe topik: alrisa/+/set & nexora/+/set");

      // Publikasikan status awal ke broker
      setRelay(isRelayActive, "pagar");

      Serial.println("✅ ESP32 Siap menerima kendali dari Web Dashboard & HP Anda!\n");
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
      setRelay(true, "pagar");
    } else if (input.equalsIgnoreCase("CLOSE") || input.equalsIgnoreCase("OFF") || input.equalsIgnoreCase("0") || input.equalsIgnoreCase("TUTUP")) {
      setRelay(false, "pagar");
    } else {
      Serial.println("❓ Ketik 'OPEN' atau 'CLOSE' untuk menguji relay manual.");
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
  snprintf(mqttClientId, sizeof(mqttClientId), "ALRISA_ESP32_%04X", (unsigned int)random(0xFFFF));

  Serial.println("\n========================================================");
  Serial.println("🚀 ALRISA SMART HOME & IOT HUB — ESP32 RELAY SIMULATOR");
  Serial.println("🏢 Alfatech Solutions IDN. — Wokwi & Cloud Ready");
  Serial.print("🆔 Client ID: ");
  Serial.println(mqttClientId);
  Serial.println("========================================================");

  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_ONBOARD_PIN, OUTPUT);
  setRelay(false, "pagar"); // Posisi awal: Relay Terputus (OFF)

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
  mqttClient.setBufferSize(512); // Peningkatan buffer untuk JSON payload

  Serial.println("\n💡 TIPS PENGUJIAN:");
  Serial.println("1. Klik tombol di Website ALRISA (https://alrisa.vercel.app)");
  Serial.println("2. Atau tekan tombol Buka/Kunci di Aplikasi HP");
  Serial.println("3. Atau ketik 'OPEN' / 'CLOSE' di Serial Monitor di bawah ini!");
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
