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
import sys

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

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
    # Subscribe ke semua pesan nexora/# dan alrisa/# (dari Flutter App, Web, ESP32, dan PLC)
    client.subscribe("nexora/#")
    client.subscribe("alrisa/#")

def update_device_internal(dev_id, payload, source="MQTT"):
    if dev_id not in devices:
        return

    clean_p = payload.strip()
    # Jika payload berupa JSON dari Flutter App: {"state": true, "value": 50}
    if clean_p.startswith('{') and clean_p.endswith('}'):
        try:
            pj = json.loads(clean_p)
            if 'value' in pj and pj['value'] is not None:
                devices[dev_id]["value"] = int(pj['value'])
            st = pj.get('state')
            if st is True:
                clean_p = "TERBUKA" if dev_id in ["pagar", "pintu_geser", "gorden"] else "ON"
            elif st is False:
                clean_p = "TERTUTUP" if dev_id in ["pagar", "pintu_geser", "gorden"] else "OFF"
        except Exception:
            pass

    clean_p = clean_p.upper()
    if clean_p in ["BUKA", "TERBUKA", "OPEN"]:
        devices[dev_id]["state"] = "TERBUKA"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["TUTUP", "TERTUTUP", "CLOSE", "LOCKED"]:
        devices[dev_id]["state"] = "TERTUTUP"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["ON", "HIDUP"]:
        devices[dev_id]["state"] = "ON"
        devices[dev_id]["pending_command"] = None
    elif clean_p in ["OFF", "MATI"]:
        devices[dev_id]["state"] = "OFF"
        devices[dev_id]["pending_command"] = None
    elif clean_p.isdigit():
        val = int(clean_p)
        devices[dev_id]["value"] = val
        devices[dev_id]["state"] = "ON" if val > 0 else "OFF"
        devices[dev_id]["pending_command"] = None
    else:
        devices[dev_id]["state"] = clean_p

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
            dev_id = parts[-2]
            channel = parts[-1] # 'set' atau 'state'

            if dev_id in devices:
                source_tag = "Flutter App (SET)" if channel == "set" else "Hardware/PLC (STATE)"
                print(f"📥 [{source_tag}] {topic} -> {payload}")

                update_device_internal(dev_id, payload, source_tag)

                # Jika menerima 'set' dari Flutter / Web, broadcast balik ke 'state' agar semua sinkron
                if channel == "set":
                    state_val = devices[dev_id]["state"]
                    is_active = state_val in ["ON", "TERBUKA", "BUKA"]
                    json_state = json.dumps({
                        "state": is_active,
                        "value": devices[dev_id]["value"],
                        "hardwarePin": devices[dev_id].get("plc_address")
                    })

                    # Broadcast ke topik nexora dan alrisa
                    client.publish(f"nexora/{dev_id}/state", state_val)
                    client.publish(f"nexora/{dev_id}/state", json_state)
                    client.publish(f"alrisa/{dev_id}/state", json_state)
                    client.publish(f"alrisa/admin/{dev_id}/state", json_state)
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
        # API Sync Endpoint (Multi-Account Profil, Perangkat & CCTV)
        if self.path.startswith('/api/sync.php'):
            import urllib.parse
            parsed_url = urllib.parse.urlparse(self.path)
            query_params = urllib.parse.parse_qs(parsed_url.query)
            acc_id = query_params.get('account_id', [None])[0]
            email = query_params.get('email', [None])[0]

            json_path = os.path.join(DIRECTORY, 'settings.json')
            target_acc = None
            if os.path.exists(json_path):
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    for a in data.get('accounts', []):
                        if (acc_id and a.get('id') == acc_id) or (email and a.get('email', '').lower() == email.lower()):
                            target_acc = a
                            break
                    if not target_acc and data.get('accounts'):
                        target_acc = data['accounts'][0]

            self.send_response(200 if target_acc else 404)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            if target_acc:
                acc_info = {
                    "id": target_acc.get("id"),
                    "name": target_acc.get("name"),
                    "email": target_acc.get("email"),
                    "role": target_acc.get("role", "user"),
                    "hardware_type": target_acc.get("hardware_type", "Raspberry Pi 4"),
                    "hardware_desc": target_acc.get("hardware_desc", ""),
                    "mqtt_prefix": target_acc.get("mqtt_prefix", "alrisa/client"),
                    "mqtt_broker": target_acc.get("mqtt_broker", "broker.emqx.io"),
                    "mqtt_port": target_acc.get("mqtt_port", 1883)
                }
                devs = target_acc.get("devices", [])
                cctvs = target_acc.get("cctv", [])
                resp = {
                    "success": True,
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "account": acc_info,
                    "total_devices": len(devs),
                    "devices": devs,
                    "total_cctv": len(cctvs),
                    "cctv": cctvs
                }
                self.wfile.write(json.dumps(resp, indent=2).encode('utf-8'))
            else:
                self.wfile.write(json.dumps({"success": False, "message": "Akun tidak ditemukan"}).encode('utf-8'))
            return

        # API Devices Endpoint
        if self.path.startswith('/api/devices.php'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()

            target_account_id = None
            if 'account_id=' in self.path:
                target_account_id = self.path.split('account_id=')[1].split('&')[0]

            account_devices = devices
            if target_account_id:
                json_path = os.path.join(DIRECTORY, 'settings.json')
                if os.path.exists(json_path):
                    try:
                        with open(json_path, 'r', encoding='utf-8') as f:
                            sdata = json.load(f)
                            for a in sdata.get('accounts', []):
                                if a.get('id') == target_account_id:
                                    dev_map = {}
                                    for d in a.get('devices', []):
                                        dev_map[d['id']] = {
                                            "id": d['id'],
                                            "name": d['name'],
                                            "category": d.get('category', 'Umum'),
                                            "type": d.get('type', 0),
                                            "state": "ON" if d.get('isActive') else "OFF",
                                            "value": int(d.get('value', 0)),
                                            "pending_command": None,
                                            "plc_address": d.get('hardwarePin', 'GPIO 2')
                                        }
                                    if dev_map:
                                        account_devices = dev_map
                                    break
                    except Exception:
                        pass

            resp = {
                "success": True,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "total_devices": len(account_devices),
                "devices": account_devices,
                "recent_logs": recent_logs[:10]
            }
            self.wfile.write(json.dumps(resp).encode('utf-8'))
            return

        # Serve settings.php
        if self.path.startswith('/settings.php') or self.path.startswith('/api/settings.php'):
            settings_path = os.path.join(DIRECTORY, 'settings.php')
            if 'api=1' in self.path or self.path.startswith('/api/settings.php'):
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                json_path = os.path.join(DIRECTORY, 'settings.json')
                data = {}
                if os.path.exists(json_path):
                    with open(json_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                else:
                    data = {
                        "mqtt_broker": "broker.emqx.io",
                        "mqtt_port": 1883,
                        "mqtt_ws_port": 8083,
                        "mqtt_prefix": "alrisa",
                        "wifi_ssid": "ALRISA_OFFICE_WIFI",
                        "plc_ip": "192.168.1.100",
                        "plc_port": 502,
                        "api_secret_key": "alrisa_secret_token_2026"
                    }
                self.wfile.write(json.dumps({"success": True, "data": data}).encode('utf-8'))
                return

            if os.path.exists(settings_path):
                # Eksekusi PHP CLI agar seluruh tag PHP dan JSON multi-akun ter-evaluasi sempurna
                try:
                    import subprocess
                    res = subprocess.run(['php', 'settings.php'], capture_output=True, cwd=DIRECTORY)
                    if res.returncode == 0 and res.stdout:
                        self.send_response(200)
                        self.send_header('Content-Type', 'text/html; charset=utf-8')
                        self.end_headers()
                        self.wfile.write(res.stdout)
                        return
                except Exception as e:
                    pass

                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.end_headers()
                with open(settings_path, 'rb') as f:
                    content = f.read()
                    if b'<!DOCTYPE html>' in content:
                        html_part = content[content.find(b'<!DOCTYPE html>'):]
                        self.wfile.write(html_part)
                    else:
                        self.wfile.write(content)
                return

        # Serve dashboard.php as HTML (Nexora Home OS Device Dashboard)
        if self.path.startswith('/dashboard.php'):
            dash_path = os.path.join(DIRECTORY, 'dashboard.php')
            if os.path.exists(dash_path):
                try:
                    import subprocess
                    env = os.environ.copy()
                    query = self.path.split('?')[1] if '?' in self.path else ''
                    env['QUERY_STRING'] = query
                    res = subprocess.run(['php', 'dashboard.php'], capture_output=True, cwd=DIRECTORY, env=env)
                    if res.returncode == 0 and res.stdout:
                        self.send_response(200)
                        self.send_header('Content-Type', 'text/html; charset=utf-8')
                        self.end_headers()
                        self.wfile.write(res.stdout)
                        return
                except Exception:
                    pass

                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.end_headers()
                with open(dash_path, 'rb') as f:
                    self.wfile.write(f.read())
                return

        # Serve index.php as HTML
        if self.path == '/' or self.path.startswith('/index.php') or self.path == '/index.html':
            index_path = os.path.join(DIRECTORY, 'index.php')
            if os.path.exists(index_path):
                try:
                    import subprocess
                    res = subprocess.run(['php', 'index.php'], capture_output=True, cwd=DIRECTORY)
                    if res.returncode == 0 and res.stdout:
                        self.send_response(200)
                        self.send_header('Content-Type', 'text/html; charset=utf-8')
                        self.end_headers()
                        self.wfile.write(res.stdout)
                        return
                except Exception:
                    pass

                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.end_headers()
                with open(index_path, 'rb') as f:
                    self.wfile.write(f.read())
                return

        super().do_GET()

    def do_POST(self):
        # API Auth Endpoint (Login Multi-Akun)
        if self.path.startswith('/api/auth.php'):
            content_length = int(self.headers.get('Content-Length', 0))
            post_body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = json.loads(post_body) if post_body.startswith('{') else {}
                if not data:
                    import urllib.parse
                    parsed = urllib.parse.parse_qs(post_body)
                    for k, v in parsed.items():
                        data[k] = v[0]

                email = data.get('email', '').strip().lower()
                password = data.get('password', '').strip()

                json_path = os.path.join(DIRECTORY, 'settings.json')
                matched_acc = None
                if os.path.exists(json_path):
                    with open(json_path, 'r', encoding='utf-8') as f:
                        settings_data = json.load(f)
                        for a in settings_data.get('accounts', []):
                            if a.get('email', '').lower() == email and a.get('password') == password:
                                matched_acc = {
                                    "id": a.get("id"),
                                    "name": a.get("name"),
                                    "email": a.get("email"),
                                    "role": a.get("role", "user"),
                                    "hardware_type": a.get("hardware_type", "Raspberry Pi 4"),
                                    "hardware_desc": a.get("hardware_desc", ""),
                                    "mqtt_prefix": a.get("mqtt_prefix", "alrisa/client"),
                                    "mqtt_broker": a.get("mqtt_broker", "broker.emqx.io"),
                                    "mqtt_port": a.get("mqtt_port", 1883)
                                }
                                break

                self.send_response(200 if matched_acc else 401)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                if matched_acc:
                    resp = {
                        "success": True,
                        "message": "Login berhasil!",
                        "token": "local_token_" + time.strftime("%Y%m%d%H%M%S"),
                        "account": matched_acc
                    }
                    self.wfile.write(json.dumps(resp).encode('utf-8'))
                else:
                    self.wfile.write(json.dumps({"success": False, "message": "Email atau password salah."}).encode('utf-8'))
                return
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "message": str(e)}).encode('utf-8'))
                return

        # API Settings Endpoint (Save Config)
        if self.path.startswith('/settings.php') or self.path.startswith('/api/settings.php'):
            content_length = int(self.headers.get('Content-Length', 0))
            post_body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = {}
                if post_body.startswith('{'):
                    data = json.loads(post_body)
                else:
                    import urllib.parse
                    parsed = urllib.parse.parse_qs(post_body)
                    for k, v in parsed.items():
                        data[k] = v[0]

                json_path = os.path.join(DIRECTORY, 'settings.json')
                existing = {}
                if os.path.exists(json_path):
                    with open(json_path, 'r', encoding='utf-8') as f:
                        existing = json.load(f)

                for k, v in data.items():
                    if k in ['mqtt_port', 'mqtt_ws_port', 'plc_port']:
                        try:
                            existing[k] = int(v)
                        except:
                            existing[k] = v
                    else:
                        existing[k] = v
                existing['updated_at'] = time.strftime("%Y-%m-%d %H:%M:%S")

                with open(json_path, 'w', encoding='utf-8') as f:
                    json.dump(existing, f, indent=4)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({"success": True, "message": "Pengaturan sistem berhasil disimpan!", "data": existing}).encode('utf-8'))
                print("💾 [CONFIG] Pengaturan baru berhasil disimpan ke settings.json!")
                return
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "message": str(e)}).encode('utf-8'))
                return

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

                    # Publish ke MQTT agar Flutter, ESP32, dan visual_plc langsung merespon!
                    is_active = devices[dev_id]["state"] in ["ON", "TERBUKA", "BUKA"]
                    json_state = json.dumps({
                        "state": is_active,
                        "value": devices[dev_id]["value"],
                        "hardwarePin": devices[dev_id].get("plc_address")
                    })

                    if action == "SET_BRIGHTNESS" and val is not None:
                        mqtt_client.publish(f"nexora/{dev_id}/set", str(val))
                        mqtt_client.publish(f"nexora/{dev_id}/state", str(val))
                    else:
                        mqtt_client.publish(f"nexora/{dev_id}/set", action)
                        mqtt_client.publish(f"nexora/{dev_id}/state", devices[dev_id]["state"])

                    # Broadcast ke Flutter
                    mqtt_client.publish(f"alrisa/{dev_id}/state", json_state)
                    mqtt_client.publish(f"alrisa/admin/{dev_id}/state", json_state)

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
        # POST Settings / Multi-Account Sync (from settings.php)
        if self.path.startswith('/settings.php') or self.path.startswith('/api/settings.php'):
            content_length = int(self.headers.get('Content-Length', 0))
            post_body = self.rfile.read(content_length).decode('utf-8', errors='replace')
            try:
                data = json.loads(post_body) if post_body.startswith('{') else {}
                json_path = os.path.join(DIRECTORY, 'settings.json')
                current = {}
                if os.path.exists(json_path):
                    with open(json_path, 'r', encoding='utf-8') as f:
                        current = json.load(f)

                # Update accounts and active_account_id
                if 'accounts' in data and isinstance(data['accounts'], list):
                    current['accounts'] = data['accounts']
                if 'active_account_id' in data:
                    current['active_account_id'] = str(data['active_account_id']).strip()

                for k, v in data.items():
                    if k not in ['accounts', 'active_account_id']:
                        current[k] = v

                current['updated_at'] = time.strftime("%Y-%m-%d %H:%M:%S")

                with open(json_path, 'w', encoding='utf-8') as f:
                    json.dump(current, f, indent=2, ensure_ascii=False)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "success": True,
                    "message": "Konfigurasi multi-akun berhasil disimpan ke server disk!",
                    "data": current
                }).encode('utf-8'))
                return
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
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
