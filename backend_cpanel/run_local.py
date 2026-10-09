"""
=============================================================================
NEXORA LOCAL SERVER & MQTT BRIDGE (Uji Coba Lokal Langsung)
=============================================================================
Menjalankan Web Portal & API cPanel secara lokal di PC Anda.
- Tanpa perlu install PHP atau XAMPP terlebih dahulu!
- Terhubung langsung ke MQTT broker.emqx.io
- Sinkron seketika dengan Aplikasi Flutter & Visual PLC Simulator!
=============================================================================
"""

import http.server
import socketserver
import json
import time
import os
import paho.mqtt.client as mqtt

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

# Data State Perangkat Lokal
devices = {
    "pagar": {
        "id": "pagar",
        "name": "Pagar Utama Rumah",
        "category": "Keamanan",
        "state": "TERTUTUP",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.0"
    },
    "pintu_geser": {
        "id": "pintu_geser",
        "name": "Pintu Geser Ruang Tamu",
        "category": "Akses",
        "state": "TERTUTUP",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.1"
    },
    "gorden": {
        "id": "gorden",
        "name": "Gorden Otomatis",
        "category": "Interior",
        "state": "TERTUTUP",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.2"
    },
    "lampu_teras": {
        "id": "lampu_teras",
        "name": "Lampu Teras Depan",
        "category": "Pencahayaan",
        "state": "OFF",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.3"
    },
    "pompa_toren": {
        "id": "pompa_toren",
        "name": "Pompa Pengisi Toren Air",
        "category": "Air",
        "state": "OFF",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.4"
    },
    "pompa_kolam": {
        "id": "pompa_kolam",
        "name": "Pompa Sirkulasi Kolam",
        "category": "Air",
        "state": "OFF",
        "value": 0,
        "pending_command": None,
        "plc_address": "%QX0.5"
    }
}

recent_logs = [
    {
        "id": 1,
        "device_id": "system",
        "action": "Server Lokal NEXORA aktif di http://localhost:8080",
        "source": "Local System",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
]

# Inisialisasi MQTT Client untuk komunikasi dengan Flutter & visual_plc
mqtt_client = mqtt.Client(client_id="NexoraLocalWebServer")

def on_mqtt_connect(client, userdata, flags, rc):
    print("✅ Web Server Lokal terhubung ke Broker MQTT (broker.emqx.io)!")
    # Subscribe ke semua pesan (set dari HP dan state dari PLC/sensor)
    client.subscribe("nexora/#")

def update_device_internal(dev_id, payload, source="MQTT"):
    if dev_id not in devices:
        return
    
    clean_p = payload.strip().upper()
    if clean_p in ["BUKA", "TERBUKA", "OPEN"]:
        devices[dev_id]["state"] = "TERBUKA"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["TUTUP", "TERTUTUP", "CLOSE"]:
        devices[dev_id]["state"] = "TERTUTUP"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["ON", "HIDUP"]:
        devices[dev_id]["state"] = "ON"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["OFF", "MATI"]:
        devices[dev_id]["state"] = "OFF"
        devices[dev_id]["pending_command"] = None
    elif payload.isdigit():
        val = int(payload)
        devices[dev_id]["value"] = val
        devices[dev_id]["state"] = "ON" if val > 0 else "OFF"
        devices[dev_id]["pending_command"] = None
    else:
        devices[dev_id]["state"] = payload

    recent_logs.insert(0, {
        "id": len(recent_logs) + 1,
        "device_id": dev_id,
        "action": f"Status: {devices[dev_id]['state']}" + (f" ({devices[dev_id]['value']}%)" if dev_id == 'lampu_teras' else ""),
        "source": source,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    })
    if len(recent_logs) > 30:
        recent_logs.pop()

def on_mqtt_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        parts = topic.split('/')
        if len(parts) >= 3:
            dev_id = parts[1]
            channel = parts[2] # 'set' atau 'state'
            
            # Abaikan jika ini echo dari Web Server sendiri
            source_tag = "Flutter App (SET)" if channel == "set" else "PLC (STATE)"
            print(f"📥 [{source_tag}] {dev_id.upper()} -> {payload}")
            
            update_device_internal(dev_id, payload, source_tag)
            
            # Jika menerima 'set' dari HP, broadcast balik ke 'state' agar semua sinkron
            if channel == "set":
                state_val = devices[dev_id]["state"]
                client.publish(f"nexora/{dev_id}/state", state_val)
    except Exception as e:
        print(f"❌ Error parse MQTT message: {e}")

mqtt_client.on_connect = on_mqtt_connect
mqtt_client.on_message = on_mqtt_message

try:
    mqtt_client.connect("broker.emqx.io", 1883, 60)
    mqtt_client.loop_start()
except Exception as e:
    print(f"⚠️ Peringatan: Tidak bisa konek MQTT: {e}")

class NexoraLocalHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-API-KEY')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        # API Devices Endpoint
        if self.path.startswith('/api/devices.php'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            resp = {
                "success": True,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "total_devices": len(devices),
                "devices": devices,
                "recent_logs": recent_logs[:10]
            }
            self.wfile.write(json.dumps(resp).encode('utf-8'))
            return

        # Serve index.php as HTML
        if self.path == '/' or self.path == '/index.php' or self.path == '/index.html':
            index_path = os.path.join(DIRECTORY, 'index.php')
            if os.path.exists(index_path):
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.end_headers()
                with open(index_path, 'rb') as f:
                    self.wfile.write(f.read())
                return

        super().do_GET()

    def do_POST(self):
        # API Control Endpoint
        if self.path.startswith('/api/control.php'):
            content_length = int(self.headers.get('Content-Length', 0))
            post_body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = json.loads(post_body)
                dev_id = data.get('device_id')
                action = data.get('action')
                val = data.get('value')
                source = data.get('source', 'Web Portal & Ladder')

                if dev_id in devices:
                    # Update status internal seketika
                    if action == "SET_BRIGHTNESS" and val is not None:
                        update_device_internal(dev_id, str(val), source)
                    else:
                        update_device_internal(dev_id, action, source)

                    # Publish ke MQTT agar Flutter dan visual_plc langsung merespon!
                    set_topic = f"nexora/{dev_id}/set"
                    state_topic = f"nexora/{dev_id}/state"
                    
                    if action == "SET_BRIGHTNESS" and val is not None:
                        mqtt_client.publish(set_topic, str(val))
                        mqtt_client.publish(state_topic, str(val))
                    else:
                        mqtt_client.publish(set_topic, action)
                        mqtt_client.publish(state_topic, devices[dev_id]["state"])

                    print(f"⚡ [WEB KONTROL] {dev_id.upper()} -> {action} ({devices[dev_id]['state']})")

                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json; charset=utf-8')
                    self.end_headers()
                    self.wfile.write(json.dumps({
                        "success": True,
                        "message": f"Perintah {action} berhasil diproses!",
                        "state": devices[dev_id]["state"]
                    }).encode('utf-8'))
                    return
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "message": str(e)}).encode('utf-8'))
                return

        super().do_POST()

def run_server():
    os.chdir(DIRECTORY)
    with socketserver.TCPServer(("", PORT), NexoraLocalHandler) as httpd:
        print("=" * 70)
        print("🌐 NEXORA LOCAL WEB SERVER & VISUAL PLC BERJALAN!")
        print(f"👉 Buka browser di laptop Anda: http://localhost:{PORT}")
        print("⚡ Terhubung langsung ke MQTT broker.emqx.io")
        print("📱 Coba kendalikan lewat HP atau Web, keduanya akan sinkron!")
        print("=" * 70)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Server lokal dihentikan.")
            mqtt_client.loop_stop()

if __name__ == "__main__":
    run_server()
