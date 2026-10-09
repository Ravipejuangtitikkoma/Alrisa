/// Konfigurasi Broker & Topik MQTT NEXORA
/// Alamat broker disimpan di sini agar mudah diganti jika nanti beralih ke Cloud milik Alfa
class MqttConfig {
  static String broker = 'broker.emqx.io';
  static int port = 1883;
  static const String topicPrefix = 'nexora';

  // Daftar Device ID resmi sesuai API Contract tim
  static const List<String> devices = [
    'pagar',
    'pintu_geser',
    'gorden',
    'lampu_teras',
    'pompa_toren',
    'pompa_kolam',
  ];

  static String setTopic(String deviceId) => '$topicPrefix/$deviceId/set';
  static String stateTopic(String deviceId) => '$topicPrefix/$deviceId/state';
  static String allStateTopics() => '$topicPrefix/+/state';
}
