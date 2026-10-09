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

  // Periksa apakah perintah untuk pagar: nexora/pagar/set
  if (topicStr.indexOf("/pagar/set") >= 0 || topicStr.indexOf("/pagar") >= 0) {
    // Cek apakah perintahnya BUKA (OPEN / true / 1) atau KUNCI (CLOSE / LOCKED / false / 0)
    bool willOpen = (message.indexOf("OPEN") >= 0 || message.indexOf("true") >= 0 || 
                     message.indexOf("1") >= 0 || message.indexOf("ON") >= 0);

    if (willOpen) {
      Serial.println("🚪 GERBANG DIBUKA -> LAMPU LED MENYALA! 💡");
      
      // Nyalakan LED bawaan D4 (Active LOW: LOW = menyala)
      digitalWrite(PIN_LED_UTAMA, LOW);
      // Nyalakan LED eksternal D1 (Active HIGH: HIGH = menyala)
      digitalWrite(PIN_LED_EXTERNAL, HIGH);

      // Balas status ke Aplikasi HP agar tampilan gerbang di HP berubah jadi "TERBUKA"
      client.publish("nexora/pagar/state", "OPEN");
    } else {
      Serial.println("🔒 GERBANG DIKUNCI -> LAMPU LED PADAM! 🌑");
      
      // Matikan LED bawaan D4
      digitalWrite(PIN_LED_UTAMA, HIGH);
      // Matikan LED eksternal D1
      digitalWrite(PIN_LED_EXTERNAL, LOW);

      // Balas status ke Aplikasi HP agar tampilan gerbang di HP berubah jadi "TERKUNCI"
      client.publish("nexora/pagar/state", "LOCKED");
    }
  } 
  // Jika mengendalikan Gerbang Belakang (nexora/pagar_belakang/set)
  else if (topicStr.indexOf("/pagar_belakang/set") >= 0) {
    bool willOpen = (message.indexOf("OPEN") >= 0 || message.indexOf("true") >= 0);
    Serial.println(willOpen ? "🚪 Gerbang Belakang: BUKA" : "🔒 Gerbang Belakang: KUNCI");
    client.publish("nexora/pagar_belakang/state", willOpen ? "OPEN" : "LOCKED");
  }
  Serial.println("----------------------------------------------");
}

// Menghubungkan ulang ke MQTT jika koneksi internet terputus
void reconnect() {
  while (!client.connected()) {
    Serial.print("🌐 Menghubungkan ke Broker MQTT (broker.emqx.io)... ");
    if (client.connect(client_id)) {
      Serial.println("BERHASIL TERHUBUNG!");
      
      // Berlangganan (Subscribe) ke perintah semua perangkat rumah: nexora/+/set
      client.subscribe("nexora/+/set");
      Serial.println("✅ Siap menerima perintah dari Aplikasi HP Nexora!");
      
      // Kirim status awal gerbang ke HP saat pertama kali menyala: TERKUNCI
      client.publish("nexora/pagar/state", "LOCKED");
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
