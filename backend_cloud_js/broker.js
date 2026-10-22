import { Aedes } from 'aedes';
import { createServer } from 'net';
import os from 'os';

// 1. Inisialisasi Aedes Broker & Aktifkan Engine
const aedes = new Aedes();
await aedes.listen(); // Wajib di Aedes v1.x agar engine siap kirim CONNACK

const server = createServer(aedes.handle);
const PORT = process.env.MQTT_PORT || 1883;

// Dapatkan daftar IP Laptop / Mesin
function getLocalIPs() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ name, ip: iface.address });
      }
    }
  }
  return addresses;
}

// -------------------------------------------------------------
// EVENT LISTENER BROKER (LOGGING AKTIVITAS LENGKAP)
// -------------------------------------------------------------

// 1. Saat ada klien baru terhubung
aedes.on('client', (client) => {
  console.log(`\n🟢 [KLIEN TERHUBUNG] Client ID: ${client.id}`);
});

// 2. Saat klien terputus
aedes.on('clientDisconnect', (client) => {
  console.log(`\n🔴 [KLIEN TERPUTUS] Client ID: ${client ? client.id : 'Unknown'}`);
});

// 3. Saat ada klien yang subscribe topik
aedes.on('subscribe', (subscriptions, client) => {
  const topics = subscriptions.map((s) => s.topic).join(', ');
  console.log(`📡 [SUBSCRIBE] Client '${client ? client.id : 'Unknown'}' -> Topik: [${topics}]`);
});

// 4. Saat ada pesan dipublikasikan
aedes.on('publish', (packet, client) => {
  // Abaikan paket internal aedes ($SYS)
  if (packet.topic.startsWith('$SYS')) return;

  const payload = packet.payload ? packet.payload.toString() : '';
  const sender = client ? client.id : 'SERVER_INTERNAL';

  console.log(`⚡ [PESAN MQTT] Topik: ${packet.topic}`);
  console.log(`   Dari   : ${sender}`);
  console.log(`   Pesan  : ${payload}`);
});

// -------------------------------------------------------------
// JALANKAN BROKER PADA PORT 1883
// -------------------------------------------------------------
server.listen(PORT, '0.0.0.0', () => {
  const ips = getLocalIPs();
  console.log('='.repeat(65));
  console.log('🚀 ALRISA PRIVATE MQTT BROKER (Edisi Mini PC & Laptop)');
  console.log('🏢 Alfatech Solutions IDN.');
  console.log('='.repeat(65));
  console.log(`✅ Broker AKTIF dan siap menerima koneksi pada Port: ${PORT}`);
  console.log('\n📍 Alamat IP untuk menghubungkan Klien:');
  console.log(`   • Dari Laptop Sendiri : localhost:${PORT} atau 127.0.0.1:${PORT}`);
  ips.forEach((item) => {
    console.log(`   • Dari HP / Mini PC (${item.name}) : ${item.ip}:${PORT}`);
  });
  console.log('='.repeat(65));
  console.log('Menunggu HP ALRISA, Web Dashboard, dan PLC terhubung...\n');
});

// Tangani error jika port 1883 sedang bentrok/dipakai aplikasi lain
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} sudah digunakan oleh aplikasi lain! Tutup aplikasi tersebut terlebih dahulu.`);
  } else {
    console.error('❌ Broker Error:', err.message);
  }
  process.exit(1);
});
