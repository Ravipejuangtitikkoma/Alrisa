"""
=============================================================================
NEXORA IOT GATEWAY FOR MINI PC / INDUSTRIAL PC
Mitsubishi FX5U PLC <---> MQTT Cloud Bridge
=============================================================================
Fungsi Gateway ini:
1. Dijalankan di Mini PC (Windows / Linux Ubuntu / Raspberry Pi).
2. Terhubung ke Cloud MQTT (broker.emqx.io) via Internet / WiFi.
3. Terhubung ke PLC Mitsubishi FX5U via Kabel LAN (Modbus TCP Port 502 / MC Protocol).
4. Ketika ada perintah dari Aplikasi HP (misal: "nexora/pagar/set" -> OPEN):
   - Gateway langsung mengirim pulsa Modbus ke PLC (%QX0.0 / Terminal Y0).
5. Ketika limit switch gerbang / sensor PLC mendeteksi gerbang terbuka:
   - Gateway otomatis kirim balik status ke HP ("nexora/pagar/state" -> OPEN).
=============================================================================
"""

import json
import time
import threading
import sys

try:
    import paho.mqtt.client as mqtt
    from pymodbus.client import ModbusTcpClient
except ImportError:
    print("⚠️ Library belum lengkap. Silakan jalankan: pip install paho-mqtt pymodbus")
    sys.exit(1)

# 1. KONFIGURASI PLC MITSUBISHI FX5U (Kabel LAN RJ45)
# Ganti dengan IP PLC Anda (Default pabrik FX5U biasanya 192.168.3.250)
PLC_IP = "192.168.3.250"
PLC_PORT = 502

# 2. KONFIGURASI MQTT CLOUD (Sama dengan Aplikasi HP Nexora)
MQTT_BROKER = "broker.emqx.io"
MQTT_PORT = 1883
CLIENT_ID = "Nexora_MiniPC_Industrial_Gateway"

# 3. PEMETAAN COIL / REGISTER MODBUS KE PERANGKAT
# Menghubungkan ID di Aplikasi HP dengan Alamat Coil PLC (%QX0.x / Y0, Y1, dst.)
DEVICE_MAP = {
    # ID Perangkat di HP : Coil Modbus PLC (%QX)
    "pagar":           {"coil_open": 0, "coil_close": 1, "status_coil": 0},  # %QX0.0 & %QX0.1
    "pagar_belakang":  {"coil_open": 2, "coil_close": 3, "status_coil": 2},  # %QX0.2 & %QX0.3
    "pintu_geser":     {"coil_open": 4, "coil_close": 5, "status_coil": 4},  # %QX0.4 & %QX0.5
    "lampu_teras":     {"coil_open": 6, "coil_close": 7, "status_coil": 6},  # %QX0.6 & %QX0.7
    "pompa_toren":     {"coil_open": 8, "coil_close": 9, "status_coil": 8},  # %QX1.0 & %QX1.1
}

# Inisialisasi Koneksi PLC
print("=============================================================")
print("🚀 MEMULAI NEXORA INDUSTRIAL PLC GATEWAY")
print("=============================================================")
print(f"🔌 Menghubungkan ke PLC Mitsubishi FX5U di IP: {PLC_IP}:{PLC_PORT}...")
plc = ModbusTcpClient(PLC_IP, port=PLC_PORT, timeout=3)

# Kirim pulsa sesaat (0.5 detik) ke PLC (Simulasi Push Button Start/Stop)
def send_plc_pulse(coil_number):
    try:
        plc.write_coil(coil_number, True)
        time.sleep(0.4)
        plc.write_coil(coil_number, False)
        print(f"⚡ [PLC Sinyal] Pulsa sukses dikirim ke Coil %QX0.{coil_number}")
    except Exception as e:
        print(f"❌ Gagal mengirim sinyal ke PLC: {e}")

# Callback MQTT saat menerima perintah dari Aplikasi HP
def on_mqtt_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        print(f"📡 [HP -> GATEWAY] Topic: {topic} | Pesan: {payload}")

        # Topic format: nexora/<device_id>/set
        parts = topic.split('/')
        if len(parts) < 3: return
        device_id = parts[1]

        if device_id in DEVICE_MAP:
            config = DEVICE_MAP[device_id]
            is_open = ("OPEN" in payload.upper() or "true" in payload.lower() or 
                       "1" in payload or "ON" in payload.upper())

            target_coil = config["coil_open"] if is_open else config["coil_close"]
            print(f"⚙️ Meneruskan ke PLC: {device_id} -> {'BUKA (Y0)' if is_open else 'KUNCI (Y1)'}")
            send_plc_pulse(target_coil)

            # Kirim balik konfirmasi status ke HP
            state_topic = f"nexora/{device_id}/state"
            client.publish(state_topic, "OPEN" if is_open else "LOCKED")
    except Exception as err:
        print(f"⚠️ Error parsing perintah MQTT: {err}")

# Thread Pemantau Status PLC secara Realtime (Feedback PLC -> HP)
def monitor_plc_feedback(client):
    last_states = {}
    while True:
        try:
            if plc.is_socket_open():
                for dev_id, conf in DEVICE_MAP.items():
                    coil_idx = conf["status_coil"]
                    res = plc.read_coils(coil_idx, 1)
                    if not res.isError():
                        current_st = bool(res.bits[0])
                        if last_states.get(dev_id) != current_st:
                            last_states[dev_id] = current_st
                            state_str = "OPEN" if current_st else "LOCKED"
                            client.publish(f"nexora/{dev_id}/state", state_str)
                            print(f"🔄 [PLC -> HP Status] {dev_id} status berubah menjadi: {state_str}")
        except Exception:
            pass
        time.sleep(0.5)

# Setup MQTT Client
mqtt_client = mqtt.Client(client_id=CLIENT_ID)
mqtt_client.on_message = on_mqtt_message

def main():
    if plc.connect():
        print("✅ Berhasil terhubung ke PLC Mitsubishi FX5U!")
    else:
        print("⚠️ Catatan: PLC fisik belum tercolok (Gateway akan otomatis reconnect).")

    print(f"🌐 Menghubungkan ke Broker MQTT: {MQTT_BROKER}...")
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        # Berlangganan ke semua perintah kontrol: nexora/+/set
        mqtt_client.subscribe("nexora/+/set")
        print("✅ Terhubung ke Cloud! Siap menerima perintah dari Aplikasi HP.")
        
        # Jalankan background thread untuk monitor feedback PLC
        threading.Thread(target=monitor_plc_feedback, args=(mqtt_client,), daemon=True).start()
        
        # Loop utama berjalan tanpa henti di Mini PC
        mqtt_client.loop_forever()
    except KeyboardInterrupt:
        print("\nGateway dimatikan.")
        plc.close()

if __name__ == "__main__":
    main()
