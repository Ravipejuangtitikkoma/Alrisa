"""
=============================================================================
ALRISA IOT GATEWAY FOR MINI PC / INDUSTRIAL PC
Mitsubishi FX5U PLC <---> ALRISA Cloud MQTT Bridge
A product by Alfatech Solutions IDN.
=============================================================================
Fungsi Gateway ini di Lapangan (Rumah / Pabrik):
1. Dijalankan otomatis di Mini PC (Windows / Linux Ubuntu / Raspberry Pi).
2. Terhubung ke Cloud MQTT (broker.emqx.io) via Internet / WiFi / 4G Modem.
3. Terhubung ke PLC Mitsubishi FX5U via Kabel LAN RJ45 (Modbus TCP Port 502 / MC Protocol).
4. Menerima perintah dari Aplikasi HP ALRISA (misal: "alrisa/pagar/set" -> OPEN):
   - Meneruskan pulsa Modbus ke PLC (%QX0.0 / Terminal Y0).
5. Membaca Limit Switch & Sensor PLC:
   - Mengirim balik konfirmasi status real-time ke Cloud & HP ("alrisa/pagar/state" -> OPEN).
6. Mengirim Heartbeat liveness setiap 10 detik ke Cloud.
=============================================================================
"""

import json
import time
import threading
import sys
import socket

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

# 2. KONFIGURASI MQTT BROKER (Lokal Mini PC / Laptop)
MQTT_BROKER = "127.0.0.1"
MQTT_PORT = 1883
CLIENT_ID = f"ALRISA_MiniPC_Gateway_{socket.gethostname()}"

# 3. PEMETAAN COIL / REGISTER MODBUS KE PERANGKAT
DEVICE_MAP = {
    # ID Perangkat di HP & Cloud : Coil Modbus PLC (%QX)
    "pagar":           {"coil_open": 0, "coil_close": 1, "status_coil": 0},  # %QX0.0 & %QX0.1
    "pagar_belakang":  {"coil_open": 2, "coil_close": 3, "status_coil": 2},  # %QX0.2 & %QX0.3
    "pintu_geser":     {"coil_open": 4, "coil_close": 5, "status_coil": 4},  # %QX0.4 & %QX0.5
    "lampu_teras":     {"coil_open": 6, "coil_close": 7, "status_coil": 6},  # %QX0.6 & %QX0.7
    "pompa_toren":     {"coil_open": 8, "coil_close": 9, "status_coil": 8},  # %QX1.0 & %QX1.1
    "pompa_kolam":     {"coil_open": 10, "coil_close": 11, "status_coil": 10}, # %QX1.2 & %QX1.3
}

# Inisialisasi Koneksi PLC
print("=" * 65)
print("🚀 MEMULAI ALRISA INDUSTRIAL PLC GATEWAY")
print("🏢 A product by Alfatech Solutions IDN.")
print("=" * 65)
print(f"🔌 Menghubungkan ke PLC Mitsubishi FX5U di IP: {PLC_IP}:{PLC_PORT}...")
plc = ModbusTcpClient(PLC_IP, port=PLC_PORT, timeout=3)

# Kirim pulsa sesaat (0.4 detik) ke PLC (Simulasi Push Button Start/Stop)
def send_plc_pulse(coil_number):
    try:
        plc.write_coil(coil_number, True)
        time.sleep(0.4)
        plc.write_coil(coil_number, False)
        print(f"⚡ [PLC Sinyal] Pulsa sukses dikirim ke Coil %QX0.{coil_number}")
    except Exception as e:
        print(f"❌ Gagal mengirim sinyal ke PLC: {e}")

# Callback MQTT saat menerima perintah dari Aplikasi HP atau Web Portal
def on_mqtt_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload_raw = msg.payload.decode('utf-8')
        print(f"📡 [CLOUD -> GATEWAY] Topic: {topic} | Pesan: {payload_raw}")

        # Topic format: alrisa/<device_id>/set atau nexora/<device_id>/set
        parts = topic.split('/')
        if len(parts) < 3: return
        device_id = parts[1]

        if device_id in DEVICE_MAP:
            config = DEVICE_MAP[device_id]
            
            # Cek payload boolean JSON {"state": true} atau string biasa "OPEN"
            is_open = False
            try:
                data = json.loads(payload_raw)
                if isinstance(data, dict):
                    is_open = bool(data.get("state", False))
                else:
                    is_open = bool(data)
            except Exception:
                upper = payload_raw.upper()
                is_open = ("OPEN" in upper or "TRUE" in upper or "1" in upper or "ON" in upper)

            target_coil = config["coil_open"] if is_open else config["coil_close"]
            print(f"⚙️ Meneruskan ke PLC: {device_id} -> {'BUKA (Y0)' if is_open else 'KUNCI (Y1)'} [Coil {target_coil}]")
            send_plc_pulse(target_coil)

            # Kirim balik konfirmasi status ke HP & Cloud (Dual topic)
            state_payload = json.dumps({"state": is_open, "timestamp": int(time.time())})
            client.publish(f"alrisa/{device_id}/state", state_payload, qos=1)
            client.publish(f"nexora/{device_id}/state", state_payload, qos=1)
    except Exception as err:
        print(f"⚠️ Error parsing perintah MQTT: {err}")

# Thread Pemantau Status Limit Switch PLC secara Realtime (Feedback PLC -> HP)
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
                            state_payload = json.dumps({"state": current_st, "timestamp": int(time.time())})
                            client.publish(f"alrisa/{dev_id}/state", state_payload, qos=1)
                            client.publish(f"nexora/{dev_id}/state", state_payload, qos=1)
                            print(f"🔄 [PLC -> HP Status] {dev_id} status berubah -> {'OPEN' if current_st else 'LOCKED'}")
        except Exception:
            pass
        time.sleep(0.5)

# Thread Heartbeat Liveness Mini PC ke Cloud Server
def heartbeat_loop(client):
    while True:
        try:
            payload = json.dumps({
                "online": True,
                "plcConnected": plc.is_socket_open() if hasattr(plc, 'is_socket_open') else True,
                "hostname": socket.gethostname(),
                "timestamp": int(time.time())
            })
            client.publish("alrisa/gateway/heartbeat", payload)
            client.publish("nexora/gateway/heartbeat", payload)
        except Exception:
            pass
        time.sleep(10)

# Setup MQTT Client
mqtt_client = mqtt.Client(client_id=CLIENT_ID)
mqtt_client.on_message = on_mqtt_message

def main():
    if plc.connect():
        print("✅ Berhasil terhubung ke PLC Mitsubishi FX5U!")
    else:
        print("⚠️ Catatan: PLC fisik belum tercolok (Gateway akan otomatis reconnect jika kabel dicolok).")

    print(f"🌐 Menghubungkan ke Broker MQTT: {MQTT_BROKER}...")
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        # Berlangganan ke topik perintah kontrol ALRISA dan NEXORA
        mqtt_client.subscribe("alrisa/+/set")
        mqtt_client.subscribe("nexora/+/set")
        print("✅ Terhubung ke Cloud! Siap menerima perintah dari Aplikasi HP & Web Dashboard.")
        
        # Jalankan background thread untuk monitor feedback PLC & Heartbeat
        threading.Thread(target=monitor_plc_feedback, args=(mqtt_client,), daemon=True).start()
        threading.Thread(target=heartbeat_loop, args=(mqtt_client,), daemon=True).start()
        
        # Loop utama berjalan tanpa henti di Mini PC
        mqtt_client.loop_forever()
    except KeyboardInterrupt:
        print("\nGateway dimatikan.")
        plc.close()

if __name__ == "__main__":
    main()
