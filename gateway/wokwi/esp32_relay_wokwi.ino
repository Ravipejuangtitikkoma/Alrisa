/*
  =============================================================================
  NEXORA / ALRISA SMART HOME - ESP32 GATE & RELAY SIMULATOR (WOKWI EDITION)
  Simulasi Virtual Kontrol Pagar Otomatis via Wokwi & MQTT Cloud
  A product by Alfatech Solutions IDN.
  =============================================================================
  
  FITUR DI WOKWI:
  1. Terhubung otomatis ke WiFi Virtual ("Wokwi-GUEST")
  2. Terhubung ke Cloud MQTT Broker ("broker.emqx.io:1883")
  3. Mengendalikan Modul Relay virtual pada GPIO 23:
     - Buka Pagar: Kontak Relay Menyambung -> Lampu LED Hijau "MOTOR PAGAR" MENYALA.
     - Tutup Pagar: Kontak Relay Terputus -> Lampu LED Hijau "MOTOR PAGAR" PADAM.
  4. Bisa dites langsung lewat:
     - Aplikasi HP Nexora (Tekan tombol Buka/Kunci Pagar)
     - Serial Monitor Wokwi (Ketik 'OPEN' atau 'CLOSE')
  =============================================================================
*/

#include <WiFi.h>
#include <PubSubClient.h>

// 1. KONEKSI WIFI VIRTUAL WOKWI
const char* WIFI_SSID     = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

// 2. CLOUD MQTT BROKER
const char* MQTT_SERVER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;
const char* MQTT_CLIENT_ID = "Wokwi_ESP32_Nexora_Gate_Sim";

// Topik Kontrol
const char* TOPIC_SET_ALRISA   = "alrisa/pagar/set";
const char* TOPIC_STATE_ALRISA = "alrisa/pagar/state";
const char* TOPIC_SET_NEXORA   = "nexora/pagar/set";
const char* TOPIC_STATE_NEXORA = "nexora/pagar/state";

/// 3. PIN HARDWARE RELAY DI WOKWI
// Disetel ke GPIO 2 sesuai skenario pengujian gerbang
#define WOKWI_RELAY_PIN   2   // Pin IN Modul Relay di Wokwi (GPIO 2)
#define PIN_LED_ONBOARD   2   // LED Onboard ESP32

// Modul Relay di Wokwi aktif dengan sinyal HIGH (Active-HIGH)
const bool RELAY_ACTIVE_LOW = false; 

bool isGateOpen = false;

WiFiClient espClient;
PubSubClient client(espClient);

void setRelayState(bool turnOn) {
  isGateOpen = turnOn;

  if (RELAY_ACTIVE_LOW) {
    digitalWrite(WOKWI_RELAY_PIN, turnOn ? LOW : HIGH);
  } else {
    digitalWrite(WOKWI_RELAY_PIN, turnOn ? HIGH : LOW);
  }
  digitalWrite(PIN_LED_ONBOARD, turnOn ? HIGH : LOW);

  if (turnOn) {
    Serial.println("\n==========================================");
    Serial.println("💡/🚪 [RELAY MENYAMBUNG] -> KONTAK ON! ⚡");
    Serial.println("🟢 LAMPU / MOTOR BEBAN MENYALA (LED HIJAU AKTIF)!");
    Serial.println("==========================================");
  } else {
    Serial.println("\n==========================================");
    Serial.println("🌑/🔒 [RELAY TERPUTUS] -> KONTAK OFF! 🛑");
    Serial.println("⚫ LAMPU / MOTOR BEBAN PADAM (LED HIJAU MATI)!");
    Serial.println("==========================================");
  }

  if (client.connected()) {
    const char* gatePayload = turnOn ? "OPEN" : "LOCKED";
    const char* lampPayload = turnOn ? "ON" : "OFF";
    
    // Kirim status balik ke topik pagar dan lampu
    client.publish(TOPIC_STATE_ALRISA, gatePayload);
    client.publish(TOPIC_STATE_NEXORA, gatePayload);
    client.publish("alrisa/lampu_teras/state", lampPayload);
    client.publish("alrisa/lampu/state", lampPayload);

    Serial.print("📡 [STATUS BALIK KE HP] Pagar: ");
    Serial.print(gatePayload);
    Serial.print(" | Lampu: ");
    Serial.println(lampPayload);
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();

  Serial.println("----------------------------------------------");
  Serial.print("📩 [PERINTAH MASUK DARI HP] Topik: ");
  Serial.println(topic);
  Serial.print("📦 Isi: ");
  Serial.println(message);

  // 1. Ekstrak Target Pin GPIO dari Payload JSON (jika ada "pin": <angka>)
  int targetPin = -1;
  int pinIdx = message.indexOf("\"pin\":");
  if (pinIdx >= 0) {
    int start = pinIdx + 6;
    while (start < message.length() && (message[start] == ' ' || message[start] == ':')) start++;
    int end = start;
    while (end < message.length() && isDigit(message[end])) end++;
    if (end > start) {
      targetPin = message.substring(start, end).toInt();
    }
  }

  // 2. Evaluasi Kesesuaian Pin GPIO
  if (targetPin != -1) {
    if (targetPin != WOKWI_RELAY_PIN) {
      Serial.println("\n⛔ [PIN TIDAK COCOK / PERINTAH DIABAIKAN]:");
      Serial.print("   ❌ Gerbang di HP diarahkan ke  : GPIO ");
      Serial.println(targetPin);
      Serial.print("   ⚠️ Sedangkan Relay Wokwi ada di : GPIO ");
      Serial.println(WOKWI_RELAY_PIN);
      Serial.println("   -> HASIL: Relay DIAM (TIDAK ADA PENGARUH), lampu tetap MATI!");
      Serial.print("   💡 TIPS: Buka menu edit gerbang di HP, ubah pin menjadi 'GPIO ");
      Serial.print(WOKWI_RELAY_PIN);
      Serial.println("' agar lampu menyala!");
      Serial.println("----------------------------------------------\n");
      return; // Berhenti di sini! Relay tidak bergerak sama sekali!
    } else {
      Serial.println("\n🎯 [PIN COCOK DENGAN WOKWI!]:");
      Serial.print("   ✅ HP GPIO ");
      Serial.print(targetPin);
      Serial.print(" == Wokwi Relay GPIO ");
      Serial.println(WOKWI_RELAY_PIN);
    }
  }

  // 3. Jika Pin Cocok atau Tidak Ditentukan, Eksekusi Relay
  bool willOpen = (message.indexOf("OPEN") >= 0 || 
                   message.indexOf("open") >= 0 || 
                   message.indexOf("true") >= 0 || 
                   message.indexOf("ON") >= 0 ||
                   message.indexOf("on") >= 0 || 
                   message == "1");

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
  }
  Serial.println("----------------------------------------------");
}

void reconnectMqtt() {
  static unsigned long lastReconnectAttempt = 0;
  unsigned long now = millis();

  if (!client.connected() && (now - lastReconnectAttempt > 5000)) {
    lastReconnectAttempt = now;
    Serial.print("🌐 Menghubungkan ke Broker (");
    Serial.print(MQTT_SERVER);
    Serial.print(")... ");

    if (client.connect(MQTT_CLIENT_ID)) {
      Serial.println("TERHUBUNG! ✅");

      client.subscribe(TOPIC_SET_ALRISA);
      client.subscribe(TOPIC_SET_NEXORA);
      client.subscribe("alrisa/+/set");
      client.subscribe("nexora/+/set");

      Serial.println("📡 Berlangganan topik kontrol pagar.");
      client.publish(TOPIC_STATE_ALRISA, isGateOpen ? "OPEN" : "LOCKED");
      client.publish(TOPIC_STATE_NEXORA, isGateOpen ? "OPEN" : "LOCKED");
      Serial.println("✅ ESP32 Siap menerima kendali dari HP Anda!");
    } else {
      Serial.print("Gagal (rc=");
      Serial.print(client.state());
      Serial.println("), mencoba lagi...");
    }
  }
}

void checkSerialInput() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() == 0) return;

    Serial.print("⌨️ [SERIAL INPUT]: ");
    Serial.println(input);

    if (input.equalsIgnoreCase("1") || input.equalsIgnoreCase("OPEN") || input.equalsIgnoreCase("ON")) {
      setRelayState(true);
    } else if (input.equalsIgnoreCase("0") || input.equalsIgnoreCase("CLOSE") || input.equalsIgnoreCase("OFF")) {
      setRelayState(false);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n========================================================");
  Serial.println("🚀 NEXORA / ALRISA - WOKWI ESP32 GATE RELAY SIMULATOR");
  Serial.println("========================================================");

  pinMode(WOKWI_RELAY_PIN, OUTPUT);
  pinMode(PIN_LED_ONBOARD, OUTPUT);

  setRelayState(false); // Awal: Terkunci / Relay Mati

  Serial.print("📶 Menghubungkan ke WiFi Wokwi-GUEST...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }

  Serial.println("\n🎉 WiFi Virtual Terhubung!");
  Serial.print("📍 IP Virtual: ");
  Serial.println(WiFi.localIP());

  client.setServer(MQTT_SERVER, MQTT_PORT);
  client.setCallback(mqttCallback);

  Serial.println("\n💡 TIPS PENGUJIAN:");
  Serial.println("• Tekan tombol di HP Nexora -> Perhatikan saklar Relay & Lampu Hijau!");
  Serial.println("• Atau ketik 'OPEN' / 'CLOSE' di Serial Monitor di bawah!");
  Serial.println("========================================================\n");
}

void loop() {
  checkSerialInput();

  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      reconnectMqtt();
    } else {
      client.loop();
    }
  }
}
