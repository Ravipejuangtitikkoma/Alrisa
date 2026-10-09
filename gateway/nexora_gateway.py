# pip install paho-mqtt==1.6.1 pymodbus
import json, time, threading
import paho.mqtt.client as mqtt
from pymodbus.client import ModbusTcpClient

BROKER, PORT_MQTT = "broker.emqx.io", 1883
DEVICE = "lampu_teras"
COIL_LAMPU, COIL_ON, COIL_OFF = 0, 1, 2   # %QX0.0, %QX0.1, %QX0.2

plc = ModbusTcpClient("127.0.0.1", port=502); plc.connect()

def pulsa(coil):                          # perintah sesaat 0.5 detik
    plc.write_coil(coil, True); time.sleep(0.5); plc.write_coil(coil, False)

def on_message(c, u, msg):                # APP -> PLC
    if msg.topic == f"nexora/{DEVICE}/set":
        try: data = json.loads(msg.payload.decode())
        except Exception: return
        pulsa(COIL_ON if data.get("state") else COIL_OFF)

client = mqtt.Client(client_id="nexora-gateway-fi")
client.on_message = on_message
client.connect(BROKER, PORT_MQTT)
client.subscribe(f"nexora/{DEVICE}/set")

def feedback():                           # PLC -> APP (status real-time)
    last = None
    while True:
        try:
            st = bool(plc.read_coils(COIL_LAMPU, 1).bits[0])
            if st != last:
                client.publish(f"nexora/{DEVICE}/state",
                               json.dumps({"state": st, "value": 80 if st else 0}))
                last = st
        except Exception: pass
        time.sleep(0.5)

threading.Thread(target=feedback, daemon=True).start()
print("Gateway NEXORA hidup... menunggu perintah.")
client.loop_forever()