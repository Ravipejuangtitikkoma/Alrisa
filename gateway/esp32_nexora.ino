/*
  =============================================================================
  NEXORA SMART HOME - ESP32 FIRMWARE CONTROLLER
  Prototyping & Testing Gateway (Kompatibel Penuh dengan PLC Mitsubishi FX5U)
  =============================================================================
  Fitur:
  - Koneksi WiFi + MQTT (broker.emqx.io:1883)
  - Mengontrol Multi-Gerbang (Pagar Utama, Pagar Belakang, dll.)
  - Mengontrol Lampu, Pintu Geser, Gorden, Pompa Air
  - Menggunakan format MQTT topic yang SAMA PERSIS dengan PLC FX5U:
      Subscribes:  nexora/+/set
      Publishes:   nexora/<device_id>/state
  - Ketika PLC Mitsubishi FX5U tiba, Anda tidak perlu mengubah aplikasi Flutter!
    Hanya ganti gateway/hardware, ID perangkat & cara kerja tetap sama.
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// 1. KONFIGURASI WIFI & MQTT BROKER
const char* ssid = "NAMA_WIFI_ANDA";           // Ganti dengan nama WiFi Anda
const char* password = "PASSWORD_WIFI_ANDA";   // Ganti dengan password WiFi Anda

const char* mqtt_server = "broker.emqx.io";
const int   mqtt_port   = 1883;
const char* client_id   = "ESP32_Nexora_Client";

// 2. PEMETAAN PIN GPIO ESP32 (Sesuai dengan alamat PLC %QX)
// Pin ESP32 -> Setara Alamat PLC Mitsubishi FX5U
#define PIN_PAGAR_UTAMA    2   // GPIO 2  -> Setara PLC %QX0.0 (Onboard LED ESP32)
#define PIN_PAGAR_BELAKANG 4   // GPIO 4  -> Setara PLC %QX0.1 (Gerbang Tambahan)
#define PIN_PINTU_GESER    5   // GPIO 5  -> Setara PLC %QX0.2
#define PIN_LAMPU_TERAS    18  // GPIO 18 -> Setara PLC %QX0.3
#define PIN_POMPA_TOREN    19  // GPIO 19 -> Setara PLC %QX0.4

WiFiClient espClient;
PubSubClient client(espClient);

// Callback jika ada perintah masuk dari aplikasi Flutter (nexora/<device>/set)
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("📡 [PESAN DITERIMA] Topic: ");
  Serial.print(topic);
  Serial.print(" | Payload: ");
  Serial.println(message);

  String topicStr = String(topic);

  // Parsing ID perangkat dari topic: nexora/<device_id>/set
  // Contoh: "nexora/pagar/set" -> deviceId: "pagar"
  int firstSlash = topicStr.indexOf('/');
  int secondSlash = topicStr.lastIndexOf('/');
  if (firstSlash == -1 || secondSlash == -1 || firstSlash == secondSlash) return;

  String deviceId = topicStr.substring(firstSlash + 1, secondSlash);

  // Status ON/OPEN vs OFF/CLOSE
  bool turnOn = (message.indexOf("ON") >= 0 || message.indexOf("OPEN") >= 0 || 
                 message.indexOf("BUKA") >= 0 || message.indexOf("1") >= 0 || 
                 message.indexOf("true") >= 0);

  // 1. Ekstrak nomor PIN dinamis dari payload JSON jika ada (contoh: "pin": 23 atau "pin": 4)
  int dynamicPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx == -1) pinIdx = message.indexOf("\"pin\" :");
  if (pinIdx >= 0) {
    int startIdx = message.indexOf(':', pinIdx) + 1;
    while (startIdx < (int)message.length() && (message[startIdx] == ' ' || message[startIdx] == '\"')) startIdx++;
    int endIdx = startIdx;
    while (endIdx < (int)message.length() && isDigit(message[endIdx])) endIdx++;
    if (endIdx > startIdx) {
      dynamicPin = message.substring(startIdx, endIdx).toInt();
    }
  }

  // Jika payload membawa nomor PIN spesifik (diset di Website / HP)
  if (dynamicPin >= 0) {
    pinMode(dynamicPin, OUTPUT);
    digitalWrite(dynamicPin, turnOn ? HIGH : LOW);
    Serial.print("⚡ [PIN DINAMIS DARI WEB/HP] Berhasil aktifkan GPIO ");
    Serial.print(dynamicPin);
    Serial.println(turnOn ? " -> HIGH (AKTIF / TERBUKA)" : " -> LOW (MATI / TERKUNCI)");
  }

  // 2. Pemetaan Default jika PIN tidak disertakan / kontrol raw
  if (deviceId == "pagar") {
    if (dynamicPin == -1) digitalWrite(PIN_PAGAR_UTAMA, turnOn ? HIGH : LOW);
    Serial.println(turnOn ? "🚪 Gerbang Utama: MEMBUKA" : "🔒 Gerbang Utama: MENGUNCI");
    client.publish("nexora/pagar/state", turnOn ? "OPEN" : "LOCKED");
    client.publish("alrisa/pagar/state", turnOn ? "OPEN" : "LOCKED");
  }
  // 2. Pagar Belakang (Gerbang Tambahan Dinamis) -> Pin GPIO 4
  else if (deviceId == "pagar_belakang" || deviceId == "pagar_2") {
    if (dynamicPin == -1) digitalWrite(PIN_PAGAR_BELAKANG, turnOn ? HIGH : LOW);
    Serial.println(turnOn ? "🚪 Gerbang Belakang: MEMBUKA" : "🔒 Gerbang Belakang: MENGUNCI");
    String stateTopic1 = "nexora/" + deviceId + "/state";
    String stateTopic2 = "alrisa/" + deviceId + "/state";
    client.publish(stateTopic1.c_str(), turnOn ? "OPEN" : "LOCKED");
    client.publish(stateTopic2.c_str(), turnOn ? "OPEN" : "LOCKED");
  }
  // 3. Pintu Geser -> Pin GPIO 5
  else if (deviceId == "pintu_geser") {
    if (dynamicPin == -1) digitalWrite(PIN_PINTU_GESER, turnOn ? HIGH : LOW);
    client.publish("nexora/pintu_geser/state", turnOn ? "OPEN" : "LOCKED");
    client.publish("alrisa/pintu_geser/state", turnOn ? "OPEN" : "LOCKED");
  }
  // 4. Lampu Teras -> Pin GPIO 18
  else if (deviceId == "lampu_teras") {
    if (dynamicPin == -1) digitalWrite(PIN_LAMPU_TERAS, turnOn ? HIGH : LOW);
    client.publish("nexora/lampu_teras/state", turnOn ? "ON" : "OFF");
    client.publish("alrisa/lampu_teras/state", turnOn ? "ON" : "OFF");
  }
  // 5. Pompa Toren -> Pin GPIO 19
  else if (deviceId == "pompa_toren") {
    if (dynamicPin == -1) digitalWrite(PIN_POMPA_TOREN, turnOn ? HIGH : LOW);
    client.publish("nexora/pompa_toren/state", turnOn ? "ON" : "OFF");
    client.publish("alrisa/pompa_toren/state", turnOn ? "ON" : "OFF");
  }
  else {
    // Perangkat dinamis lainnya: kirim echo state balik
    Serial.print("ℹ️ Perangkat kustom: ");
    Serial.println(deviceId);
    String stateTopic1 = "nexora/" + deviceId + "/state";
    String stateTopic2 = "alrisa/" + deviceId + "/state";
    client.publish(stateTopic1.c_str(), turnOn ? "OPEN" : "LOCKED");
    client.publish(stateTopic2.c_str(), turnOn ? "OPEN" : "LOCKED");
  }
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Menghubungkan ke Broker MQTT...");
    if (client.connect(client_id)) {
      Serial.println(" TERHUBUNG!");
      // Subscribe ke SEMUA perintah perangkat secara otomatis (wildcard +)
      client.subscribe("nexora/+/set");
      client.subscribe("alrisa/+/set");
      Serial.println("Berhasil Subscribe ke: nexora/+/set & alrisa/+/set");
      
      // Kirim status awal ke aplikasi Flutter
      client.publish("nexora/pagar/state", "LOCKED");
      client.publish("alrisa/pagar/state", "LOCKED");
    } else {
      Serial.print("Gagal, rc=");
      Serial.print(client.state());
      Serial.println(" Coba lagi dalam 5 detik...");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  
  // Setup Pin GPIO sebagai OUTPUT
  pinMode(PIN_PAGAR_UTAMA, OUTPUT);
  pinMode(PIN_PAGAR_BELAKANG, OUTPUT);
  pinMode(PIN_PINTU_GESER, OUTPUT);
  pinMode(PIN_LAMPU_TERAS, OUTPUT);
  pinMode(PIN_POMPA_TOREN, OUTPUT);

  // Status awal LOW (Mati / Terkunci)
  digitalWrite(PIN_PAGAR_UTAMA, LOW);
  digitalWrite(PIN_PAGAR_BELAKANG, LOW);
  digitalWrite(PIN_PINTU_GESER, LOW);
  digitalWrite(PIN_LAMPU_TERAS, LOW);
  digitalWrite(PIN_POMPA_TOREN, LOW);

  // Hubungkan ke WiFi
  Serial.println();
  Serial.print("Menghubungkan ke WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi Terhubung!");
  Serial.print("IP ESP32: ");
  Serial.println(WiFi.localIP());

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
}
