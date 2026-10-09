"""
=============================================================================
NEXORA CLOUD BRIDGE (cPanel Web Hosting <-> PLC Simulator / Mitsubishi)
=============================================================================
Menjembatani website hosting cPanel Alfa dengan simulator PLC / PLC fisik.
- Mengambil antrean perintah dari HP / Website di cPanel
- Meneruskannya ke Visual PLC / MQTT
- Melaporkan status sensor PLC balik ke Website cPanel
=============================================================================
"""

import time
import requests
import json
import paho.mqtt.client as mqtt

# -------------------------------------------------------------
# KONFIGURASI CPANEL WEBSITE ALFA
# Ganti CLOUD_URL dengan alamat website Anda setelah di-upload
# Contoh: "https://iot.alfaperusahaan.com/nexora" atau "https://domainanda.com/api"
# -------------------------------------------------------------
# Jika sedang ditest lokal di PC Anda:
CLOUD_URL = "http://localhost/backend_cpanel"  # Ganti dengan URL cPanel Anda nanti!
API_KEY = "nexora_secret_token_2026"

# Konfigurasi MQTT lokal / simulator
MQTT_BROKER = "broker.emqx.io"
MQTT_PORT = 1883

print("=" * 65)
print("🌐 NEXORA CLOUD SYNC GATEWAY (cPanel <-> PLC)")
print(f"🔗 Target Cloud Website : {CLOUD_URL}")
print(f"📡 MQTT Gateway         : {MQTT_BROKER}:{MQTT_PORT}")
print("=" * 65)

# Status lokal perangkat
device_states = {
    "pagar": "TERTUTUP",
    "pintu_geser": "TERTUTUP",
    "gorden": "TERTUTUP",
    "lampu_teras": "OFF",
    "pompa_toren": "OFF",
    "pompa_kolam": "OFF"
}

device_values = {
    "lampu_teras": 0
}

# MQTT Callback
def on_mqtt_connect(client, userdata, flags, rc):
    print("✅ Gateway terhubung ke broker MQTT!")
    # Subscribe ke semua update status dari simulator PLC
    client.subscribe("nexora/+/state")

def on_mqtt_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        parts = topic.split('/')
        if len(parts) >= 3:
            dev_id = parts[1]
            if dev_id in device_states:
                device_states[dev_id] = payload
                # Cek jika berupa angka (brightness)
                if payload.isdigit():
                    device_values[dev_id] = int(payload)
                print(f"📥 [PLC/Sim Update] {dev_id.upper()} -> {payload}")
    except Exception as e:
        print(f"❌ Error parse MQTT message: {e}")

# Inisialisasi MQTT
client = mqtt.Client(client_id="NexoraCloudBridge")
client.on_connect = on_mqtt_connect
client.on_message = on_mqtt_message

try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_start()
except Exception as e:
    print(f"⚠️ Gagal koneksi MQTT: {e}")

# Loop Sinkronisasi ke cPanel Cloud
def sync_with_cloud():
    headers = {
        "Content-Type": "application/json",
        "X-API-KEY": API_KEY
    }

    payload = {
        "current_states": device_states,
        "values": device_values
    }

    try:
        url = f"{CLOUD_URL}/api/plc_sync.php"
        resp = requests.post(url, json=payload, headers=headers, timeout=5)
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get("has_commands", False):
                commands = data.get("commands", [])
                for cmd in commands:
                    dev_id = cmd.get("id")
                    action = cmd.get("pending_command")
                    val = cmd.get("pending_value")
                    
                    print(f"⚡ [DITERIMA DARI CLOUD] {dev_id.upper()} -> Perintah: {action}")
                    
                    # Teruskan ke MQTT / PLC
                    set_topic = f"nexora/{dev_id}/set"
                    if action == "SET_BRIGHTNESS" and val is not None:
                        client.publish(set_topic, str(val))
                    else:
                        client.publish(set_topic, action)
        else:
            print(f"⚠️ Respon Cloud bukan 200: {resp.status_code}")
    except requests.exceptions.ConnectionError:
        # Menunggu website cPanel diupload/aktif
        pass
    except Exception as e:
        print(f"❌ Sync Error: {e}")

def main():
    print("\n🚀 Gateway Cloud Sync aktif. Melakukan sinkronisasi setiap 1 detik...")
    print("Tekan Ctrl+C untuk berhenti.\n")
    while True:
        sync_with_cloud()
        time.sleep(1.0)

if __name__ == "__main__":
    main()
