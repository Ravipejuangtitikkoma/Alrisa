/*
  =============================================================================
  NEXORA SMART HOME - ESP8266 (NodeMCU / Wemos D1 Mini) CONTROLLER
  Prototyping & Testing Pagar Otomatis menggunakan Lampu LED
  =============================================================================
  Cara Kerja:
  - Ketika tombol "Buka Pagar" ditekan di HP:
      Aplikasi kirim MQTT -> ESP8266 terima -> Lampu LED MENYALA (Gerbang Terbuka)
  - Ketika tombol "Kunci Pagar" ditekan di HP:
      Aplikasi kirim MQTT -> ESP8266 terima -> Lampu LED MATI (Gerbang Terkunci)
  
  Koneksi Pin ESP8266:
  - Menggunakan PIN D4 (GPIO 2) yang terhubung ke Lampu LED kecil bawaan NodeMCU.
    (Catatan ESP8266: LED bawaan bersifat Active-LOW, di kodingan ini sudah disesuaikan
     sehingga saat Buka Pagar -> LED Menyala, saat Kunci Pagar -> LED Mati).
  - Anda juga bisa pasang kaki (+) LED eksternal ke pin D1 (GPIO 5) dan (-) ke GND.
  =============================================================================
*/

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// 1. PENGATURAN WIFI (Ganti dengan nama WiFi & Password hotspot Anda)
const char* ssid     = "NAMA_WIFI_ANDA";       // Contoh: "Hotspot_HP"
const char* password = "PASSWORD_WIFI_ANDA";   // Contoh: "12345678"

// 2. BROKER MQTT CLOUD (Sama persis dengan yang dipakai di aplikasi Flutter Nexora)
const char* mqtt_server = "broker.emqx.io";
const int   mqtt_port   = 1883;
const char* client_id   = "ESP8266_Nexora_Gate_Tester";

// 3. PEMETAAN PIN LAMPU / RELAY PADA ESP8266
// Di NodeMCU / ESP8266:
// D4 = GPIO 2 (Lampu LED Biru bawaan di modul NodeMCU)
// D1 = GPIO 5 (Bisa dicolok lampu LED eksternal / Modul Relay)
#define PIN_LED_UTAMA    D4   // LED Onboard bawaan (D4 / GPIO 2)
#define PIN_LED_EXTERNAL D1   // Pin tambahan untuk LED luar (D1 / GPIO 5)

WiFiClient espClient;
PubSubClient client(espClient);

// Fungsi penerima perintah dari Aplikasi HP
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.println("----------------------------------------------");
  Serial.print("📡 [PERINTAH DITERIMA DARI HP] Topic: ");
  Serial.println(topic);
  Serial.print("📩 Isi Perintah: ");
  Serial.println(message);

  String topicStr = String(topic);

  // Parsing deviceId
  int firstSlash = topicStr.indexOf('/');
  int secondSlash = topicStr.lastIndexOf('/');
  String deviceId = "pagar";
  if (firstSlash != -1 && secondSlash != -1 && firstSlash != secondSlash) {
    deviceId = topicStr.substring(firstSlash + 1, secondSlash);
  }

  // Cek apakah perintahnya BUKA / ON atau KUNCI / OFF
  bool willOpen = (message.indexOf("OPEN") >= 0 || message.indexOf("open") >= 0 ||
                   message.indexOf("BUKA") >= 0 || message.indexOf("buka") >= 0 ||
                   message.indexOf("true") >= 0 || message.indexOf("1") >= 0 || 
                   message.indexOf("ON") >= 0 || message.indexOf("on") >= 0);

  // Ekstrak nomor PIN dinamis jika dikirim dari Web / HP
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

  // Jika ada PIN dinamis (misal GPIO 2, GPIO 5, GPIO 4, dll.)
  if (dynamicPin >= 0) {
    pinMode(dynamicPin, OUTPUT);
    digitalWrite(dynamicPin, willOpen ? HIGH : LOW);
    Serial.print("⚡ [DYNAMIC PIN SET] Mengaktifkan GPIO ");
    Serial.print(dynamicPin);
    Serial.println(willOpen ? " -> HIGH (AKTIF)" : " -> LOW (MATI)");
  }

  // Kontrol Pagar Utama
  if (deviceId == "pagar" || topicStr.indexOf("/pagar") >= 0) {
    if (willOpen) {
      Serial.println("🚪 GERBANG DIBUKA -> LAMPU LED MENYALA! 💡");
      if (dynamicPin == -1) {
        digitalWrite(PIN_LED_UTAMA, LOW);   // Active-LOW (D4 menyala)
        digitalWrite(PIN_LED_EXTERNAL, HIGH); // Active-HIGH (D1 menyala)
      }
      client.publish("nexora/pagar/state", "OPEN");
      client.publish("alrisa/pagar/state", "OPEN");
    } else {
      Serial.println("🔒 GERBANG DIKUNCI -> LAMPU LED PADAM! 🌑");
      if (dynamicPin == -1) {
        digitalWrite(PIN_LED_UTAMA, HIGH);  // Active-LOW (D4 padam)
        digitalWrite(PIN_LED_EXTERNAL, LOW); // Active-HIGH (D1 padam)
      }
      client.publish("nexora/pagar/state", "LOCKED");
      client.publish("alrisa/pagar/state", "LOCKED");
    }
  } 
  // Jika mengendalikan Gerbang Belakang atau perangkat lainnya
  else {
    Serial.print(willOpen ? "🚪 Perangkat AKTIF: " : "🔒 Perangkat NONAKTIF: ");
    Serial.println(deviceId);
    String stateTopic1 = "nexora/" + deviceId + "/state";
    String stateTopic2 = "alrisa/" + deviceId + "/state";
    client.publish(stateTopic1.c_str(), willOpen ? "OPEN" : "LOCKED");
    client.publish(stateTopic2.c_str(), willOpen ? "OPEN" : "LOCKED");
  }
  Serial.println("----------------------------------------------");
}

// Menghubungkan ulang ke MQTT jika koneksi internet terputus
void reconnect() {
  while (!client.connected()) {
    Serial.print("🌐 Menghubungkan ke Broker MQTT (broker.emqx.io)... ");
    if (client.connect(client_id)) {
      Serial.println("BERHASIL TERHUBUNG!");
      
      // Berlangganan (Subscribe) ke perintah semua perangkat rumah
      client.subscribe("nexora/+/set");
      client.subscribe("alrisa/+/set");
      Serial.println("✅ Siap menerima perintah dari Aplikasi HP Nexora & Web Studio!");
      
      // Kirim status awal gerbang ke HP saat pertama kali menyala: TERKUNCI
      client.publish("nexora/pagar/state", "LOCKED");
      client.publish("alrisa/pagar/state", "LOCKED");
    } else {
      Serial.print("Gagal, status error=");
      Serial.print(client.state());
      Serial.println(" -> Mengulang dalam 5 detik...");
      delay(5000);
    }
  }
}

void setup() {
  // Inisialisasi Serial Monitor
  Serial.begin(115200);
  delay(200);
  Serial.println("\n\n==============================================");
  Serial.println("🚀 NEXORA HOME - ESP8266 GATE TESTER DIMULAI");
  Serial.println("==============================================");

  // Atur pin LED sebagai OUTPUT
  pinMode(PIN_LED_UTAMA, OUTPUT);
  pinMode(PIN_LED_EXTERNAL, OUTPUT);

  // Kondisi Awal: Lampu Mati (Pagar Terkunci)
  digitalWrite(PIN_LED_UTAMA, HIGH); // D4 mati (Active-LOW)
  digitalWrite(PIN_LED_EXTERNAL, LOW);

  // Hubungkan ESP8266 ke WiFi
  Serial.print("📶 Menghubungkan ke WiFi: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n🎉 WiFi Terhubung!");
  Serial.print("📍 Alamat IP ESP8266: ");
  Serial.println(WiFi.localIP());

  // Konfigurasi Server MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
}
