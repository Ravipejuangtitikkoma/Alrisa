import paho.mqtt.client as mqtt
import json
import time

BROKER = "broker.emqx.io"
PORT = 1883

print("="*50)
print("🏭 OPENPLC SIMULATOR (PLC PALSU) SEDANG HIDUP...")
print("Menunggu perintah dari Aplikasi NEXORA...")
print("="*50)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Terhubung ke Broker MQTT!")
        client.subscribe("nexora/+/set") # Dengarkan semua perintah 'set'
    else:
        print(f"❌ Gagal connect, kode: {rc}")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        device = msg.topic.split('/')[1] # ambil nama device (misal: lampu_teras)
        
        print(f"\n🚨 PERINTAH DITERIMA DARI APLIKASI NEXORA! 🚨")
        print(f"   Perangkat : {device.upper()}")
        print(f"   Perintah  : {payload}")
        
        # Logika PLC Palsu
        if payload.get("state") == True:
            print(f"   ⚡ AKSI PLC: Menyalakan {device}...")
            # Kirim balik status ke aplikasi (ini yang bikin toggle di HP tetap ON)
            client.publish(f"nexora/{device}/state", json.dumps({"state": True, "value": 80}))
        else:
            print(f"   🛑 AKSI PLC: Mematikan {device}...")
            client.publish(f"nexora/{device}/state", json.dumps({"state": False, "value": 0}))
            
    except Exception as e:
        print(f"Error memproses pesan: {e}")

client = mqtt.Client(client_id="plc-simulator-fi")
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.loop_forever()