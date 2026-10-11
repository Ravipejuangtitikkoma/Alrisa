/// Konfigurasi Broker & Topik MQTT NEXORA
/// Alamat broker disimpan di sini dan dapat diubah secara dinamis lewat HP oleh Super Admin
class MqttConfig {
  static String broker = 'broker.emqx.io';
  static int port = 1883;
  static String topicPrefix = 'nexora';
  static String? username;
  static String? password;

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

  /// Update konfigurasi broker secara dinamis dari menu Super Admin
  static void updateConfig({
    required String newBroker,
    required int newPort,
    String? newPrefix,
    String? newUsername,
    String? newPassword,
  }) {
    broker = newBroker.trim();
    port = newPort;
    if (newPrefix != null && newPrefix.trim().isNotEmpty) {
      topicPrefix = newPrefix.trim();
    }
    username = (newUsername != null && newUsername.trim().isNotEmpty) ? newUsername.trim() : null;
    password = (newPassword != null && newPassword.trim().isNotEmpty) ? newPassword.trim() : null;
  }
}

