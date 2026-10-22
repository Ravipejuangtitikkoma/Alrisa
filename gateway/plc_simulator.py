import paho.mqtt.client as mqtt
import json
import time
import threading

# Menggunakan Private Broker di Laptop / Mini PC sendiri
BROKER = "127.0.0.1"
PORT = 1883

print("=" * 60)
print("🏭 ALRISA PLC & MINI PC SIMULATOR SEDANG BERJALAN...")
print("🏢 A product by Alfatech Solutions IDN.")
print("Menunggu perintah dari Aplikasi HP ALRISA atau Web Dashboard...")
print("=" * 60)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Terhubung ke Broker MQTT (broker.emqx.io)!")
        # Dengarkan semua perintah 'set' pada prefix alrisa dan nexora
        client.subscribe("alrisa/+/set")
        client.subscribe("nexora/+/set")
        print("📡 Mendengarkan topik: alrisa/+/set & nexora/+/set")
    else:
        print(f"❌ Gagal koneksi MQTT, kode: {rc}")

def on_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload_str = msg.payload.decode('utf-8')
        parts = topic.split('/')
        if len(parts) < 3: return
        prefix = parts[0]
        device = parts[1]

        # Parse state
        is_active = False
        try:
            payload = json.loads(payload_str)
            if isinstance(payload, dict):
                is_active = bool(payload.get("state", False))
            else:
                is_active = bool(payload)
        except Exception:
            upper = payload_str.upper()
            is_active = ("OPEN" in upper or "TRUE" in upper or "1" in upper or "ON" in upper)

        print(f"\n🚨 [PERINTAH DITERIMA] -> Dari: {prefix.upper()}")
        print(f"   Perangkat : {device.upper()}")
        print(f"   Perintah  : {'BUKA / ON' if is_active else 'TUTUP / OFF'}")

        # Simulasi respons fisik relay PLC (0.3 detik)
        time.sleep(0.3)
        if is_active:
            print(f"   ⚡ [PLC AKSI] Mengaktifkan relay {device.upper()} (%QX0)...")
        else:
            print(f"   🛑 [PLC AKSI] Menonaktifkan relay {device.upper()}...")

        # Kirim balik konfirmasi status ke HP & Web Dashboard (kedua prefix)
        resp_payload = json.dumps({"state": is_active, "value": 85 if is_active else 0, "timestamp": int(time.time())})
        client.publish(f"alrisa/{device}/state", resp_payload, qos=1)
        client.publish(f"nexora/{device}/state", resp_payload, qos=1)
        print(f"   📡 [FEEDBACK DIKIRIM KE HP & CLOUD] Status -> {'ON' if is_active else 'OFF'}")

    except Exception as e:
        print(f"⚠️ Error memproses pesan: {e}")

def heartbeat_sender(client):
    while True:
        try:
            hb = json.dumps({"online": True, "plcConnected": True, "ip": "192.168.1.150", "timestamp": int(time.time())})
            client.publish("alrisa/gateway/heartbeat", hb)
            client.publish("nexora/gateway/heartbeat", hb)
        except Exception:
            pass
        time.sleep(10)

client = mqtt.Client(client_id="ALRISA_PLC_Simulator")
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)

# Jalankan heartbeat background
threading.Thread(target=heartbeat_sender, args=(client,), daemon=True).start()

client.loop_forever()