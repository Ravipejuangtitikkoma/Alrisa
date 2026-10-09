import 'dart:async';

enum AppLanguage { id, en }

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  AppLanguage _currentLanguage = AppLanguage.id;
  AppLanguage get currentLanguage => _currentLanguage;
  bool get isEnglish => _currentLanguage == AppLanguage.en;
  bool get isIndonesian => _currentLanguage == AppLanguage.id;

  final StreamController<AppLanguage> _languageController =
      StreamController<AppLanguage>.broadcast();
  Stream<AppLanguage> get languageStream => _languageController.stream;

  void toggleLanguage() {
    _currentLanguage = (_currentLanguage == AppLanguage.id) ? AppLanguage.en : AppLanguage.id;
    _languageController.add(_currentLanguage);
  }

  void setLanguage(AppLanguage lang) {
    if (_currentLanguage != lang) {
      _currentLanguage = lang;
      _languageController.add(_currentLanguage);
    }
  }

  // Helper terjemahan kunci utama
  String tr(String key) {
    final Map<String, Map<AppLanguage, String>> translations = {
      // Navigasi
      'nav_home': {AppLanguage.id: 'Beranda', AppLanguage.en: 'Home'},
      'nav_rooms': {AppLanguage.id: 'Ruangan', AppLanguage.en: 'Rooms'},
      'nav_energy': {AppLanguage.id: 'Energi', AppLanguage.en: 'Energy'},
      'nav_settings': {AppLanguage.id: 'Pengaturan', AppLanguage.en: 'Settings'},

      // Sapaan
      'greeting_morning': {AppLanguage.id: 'Selamat pagi, ', AppLanguage.en: 'Good morning, '},
      'greeting_afternoon': {AppLanguage.id: 'Selamat siang, ', AppLanguage.en: 'Good afternoon, '},
      'greeting_evening': {AppLanguage.id: 'Selamat sore, ', AppLanguage.en: 'Good evening, '},
      'greeting_night': {AppLanguage.id: 'Selamat malam, ', AppLanguage.en: 'Good night, '},
      'status_sentence': {
        AppLanguage.id: 'Semua tenang. Rumah terkunci, sistem IoT aktif.',
        AppLanguage.en: 'All calm. House secured, IoT system active.',
      },

      // Section Labels
      'section_scenes': {AppLanguage.id: 'SKENARIO RUMAH', AppLanguage.en: 'HOME SCENES'},
      'section_gate': {AppLanguage.id: 'AKSES GERBANG', AppLanguage.en: 'GATE ACCESS'},
      'section_devices': {AppLanguage.id: 'PERANGKAT & UTILITAS', AppLanguage.en: 'DEVICES & UTILITIES'},

      // Gate Status
      'gate_open': {AppLanguage.id: 'TERBUKA', AppLanguage.en: 'OPEN'},
      'gate_locked': {AppLanguage.id: 'TERKUNCI', AppLanguage.en: 'LOCKED'},
      'gate_opening': {AppLanguage.id: 'MEMBUKA...', AppLanguage.en: 'OPENING...'},
      'gate_closing': {AppLanguage.id: 'MENUTUP...', AppLanguage.en: 'CLOSING...'},
      'btn_open_gate': {AppLanguage.id: 'Buka Pagar', AppLanguage.en: 'Open Gate'},
      'btn_lock_gate': {AppLanguage.id: 'Kunci Pagar', AppLanguage.en: 'Lock Gate'},

      // Settings
      'settings_title': {AppLanguage.id: 'Pengaturan', AppLanguage.en: 'Settings'},
      'settings_subtitle': {
        AppLanguage.id: 'Konfigurasi Sistem IoT, Broker & Ekosistem Rumah',
        AppLanguage.en: 'IoT System Configuration, Broker & Home Ecosystem',
      },
      'settings_iot_manage': {AppLanguage.id: 'Manajemen Perangkat IoT', AppLanguage.en: 'IoT Device Management'},
      'settings_add_btn': {AppLanguage.id: 'Tambah', AppLanguage.en: 'Add Device'},
      'settings_reconnect': {AppLanguage.id: 'Hubungkan Ulang Broker', AppLanguage.en: 'Reconnect Broker'},
      'settings_weather_sim': {AppLanguage.id: 'Simulasi Cuaca & Lingkungan', AppLanguage.en: 'Weather & Environment Simulation'},
      'settings_security': {AppLanguage.id: 'Otomasi & Keamanan', AppLanguage.en: 'Automation & Security'},
    };

    if (translations.containsKey(key)) {
      return translations[key]![_currentLanguage] ?? key;
    }
    return key;
  }
}
