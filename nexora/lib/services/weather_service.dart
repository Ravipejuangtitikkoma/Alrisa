import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum WeatherCondition {
  cerah,
  berawan,
  hujan,
  angin,
  malam,
}

/// WeatherService Singleton: Terintegrasi langsung dengan API Resmi BMKG Indonesia
/// Dilengkapi Auto-Detect Lokasi Pengguna (Jambi, Palembang, Jakarta, dll) & Pilihan Kota Dinamis
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal() {
    // Otomatis deteksi lokasi pengguna dan muat data BMKG yang sesuai
    initLocationAndWeather();
  }

  final _controller = StreamController<WeatherCondition>.broadcast();
  WeatherCondition _currentCondition = WeatherCondition.berawan;

  double _temperature = 27.0;
  int _humidity = 81;
  String _locationName = 'Kota Jambi';
  String _bmkgWeatherDesc = 'Berawan';
  bool _isLoading = false;
  String _currentCityKey = 'jambi';

  WeatherCondition get currentCondition => _currentCondition;
  Stream<WeatherCondition> get weatherStream => _controller.stream;

  double get temperature => _temperature;
  int get humidity => _humidity;
  String get locationName => _locationName;
  String get bmkgWeatherDesc => _bmkgWeatherDesc;
  bool get isLoading => _isLoading;
  String get currentCityKey => _currentCityKey;

  /// Daftar Kode Wilayah Resmi BMKG (adm4) untuk berbagai kota/provinsi di Indonesia
  static const Map<String, Map<String, String>> supportedCities = {
    'jambi': {
      'name': 'Kota Jambi, Jambi',
      'adm4': '15.71.01.1001',
    },
    'palembang': {
      'name': 'Kota Palembang, Sumsel',
      'adm4': '16.71.01.1001',
    },
    'jakarta': {
      'name': 'Jakarta Pusat, DKI Jakarta',
      'adm4': '31.71.03.1001',
    },
    'bandung': {
      'name': 'Kota Bandung, Jawa Barat',
      'adm4': '32.73.01.1001',
    },
    'surabaya': {
      'name': 'Kota Surabaya, Jawa Timur',
      'adm4': '35.78.01.1001',
    },
    'medan': {
      'name': 'Kota Medan, Sumatera Utara',
      'adm4': '12.71.01.1001',
    },
    'semarang': {
      'name': 'Kota Semarang, Jawa Tengah',
      'adm4': '33.74.01.1001',
    },
    'makassar': {
      'name': 'Kota Makassar, Sulawesi Selatan',
      'adm4': '73.71.01.1001',
    },
    'denpasar': {
      'name': 'Kota Denpasar, Bali',
      'adm4': '51.71.01.1001',
    },
    'padang': {
      'name': 'Kota Padang, Sumatera Barat',
      'adm4': '13.71.01.1001',
    },
    'pekanbaru': {
      'name': 'Kota Pekanbaru, Riau',
      'adm4': '14.71.01.1001',
    },
    'lampung': {
      'name': 'Bandar Lampung, Lampung',
      'adm4': '18.71.01.1001',
    },
    'yogyakarta': {
      'name': 'Yogyakarta, D.I. Yogyakarta',
      'adm4': '34.71.01.1001',
    },
  };

  /// Inisialisasi otomatis lokasi berdasarkan IP/jaringan perangkat
  Future<void> initLocationAndWeather() async {
    _isLoading = true;
    String detectedAdm4 = '15.71.01.1001'; // Default Kota Jambi
    String matchedCityKey = 'jambi';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('https://ipwho.is/'));
      final res = await req.close();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final city = (data['city'] as String? ?? '').toLowerCase();
          final region = (data['region'] as String? ?? '').toLowerCase();

          // Cocokkan kota pengguna
          for (final entry in supportedCities.entries) {
            final key = entry.key;
            final label = entry.value['name']!.toLowerCase();
            if (city.contains(key) || region.contains(key) || label.contains(city)) {
              matchedCityKey = key;
              detectedAdm4 = entry.value['adm4']!;
              break;
            }
          }
        }
      }
      client.close();
    } catch (_) {
      // Jika offline, gunakan default jambi
    }

    _currentCityKey = matchedCityKey;
    await fetchBMKGWeather(adm4: detectedAdm4);
  }

  /// Ganti Lokasi BMKG secara manual oleh pengguna (misal Jambi, Palembang, Jakarta)
  Future<void> setLocationCity(String cityKey) async {
    if (supportedCities.containsKey(cityKey)) {
      _currentCityKey = cityKey;
      final adm4 = supportedCities[cityKey]!['adm4']!;
      await fetchBMKGWeather(adm4: adm4);
    }
  }

  /// Fetch Cuaca Riil dari API Resmi BMKG Publik
  Future<void> fetchBMKGWeather({String? adm4}) async {
    _isLoading = true;
    final targetAdm4 = adm4 ?? supportedCities[_currentCityKey]?['adm4'] ?? '15.71.01.1001';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final url = Uri.parse('https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=$targetAdm4');
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        _parseBMKGJson(json);
      }
      client.close();
    } catch (e) {
      // Jika offline / timeout, pertahankan data sebelumnya dengan aman
    } finally {
      _isLoading = false;
      _controller.add(_currentCondition);
    }
  }

  void _parseBMKGJson(Map<String, dynamic> json) {
    try {
      // 1. Ambil Nama Lokasi
      if (json.containsKey('lokasi')) {
        final lokasi = json['lokasi'] as Map<String, dynamic>;
        final desa = lokasi['desa'] ?? '';
        final kotkab = lokasi['kotkab'] ?? '';
        if (desa.toString().isNotEmpty) {
          _locationName = '$desa, $kotkab';
        }
      }

      // 2. Ambil Prakiraan Cuaca Terkini dari BMKG (Pilih slot waktu terdekat dengan saat ini)
      if (json.containsKey('data') && (json['data'] as List).isNotEmpty) {
        final firstData = json['data'][0] as Map<String, dynamic>;
        if (firstData.containsKey('cuaca') && (firstData['cuaca'] as List).isNotEmpty) {
          final cuacaList = firstData['cuaca'] as List;

          Map<String, dynamic>? closestWeather;
          int minDiffSeconds = 99999999;
          final nowUtc = DateTime.now().toUtc();

          // Iterasi seluruh hari & slot waktu untuk mencari prakiraan paling presisi detik ini
          for (final dayGroup in cuacaList) {
            if (dayGroup is List) {
              for (final slot in dayGroup) {
                if (slot is Map<String, dynamic>) {
                  final dtStr = slot['datetime'] as String?;
                  if (dtStr != null) {
                    try {
                      final slotTime = DateTime.parse(dtStr);
                      final diff = (nowUtc.difference(slotTime).inSeconds).abs();
                      if (diff < minDiffSeconds) {
                        minDiffSeconds = diff;
                        closestWeather = slot;
                      }
                    } catch (_) {}
                  }
                }
              }
            }
          }

          final currentWeatherObj = closestWeather ?? (cuacaList[0] is List && (cuacaList[0] as List).isNotEmpty ? (cuacaList[0] as List)[0] as Map<String, dynamic> : null);

          if (currentWeatherObj != null) {
            // Suhu & Kelembaban Riil BMKG
            _temperature = (currentWeatherObj['t'] as num?)?.toDouble() ?? 27.0;
            _humidity = (currentWeatherObj['hu'] as num?)?.toInt() ?? 80;
            _bmkgWeatherDesc = currentWeatherObj['weather_desc'] as String? ?? 'Berawan';

            // Pemetaan deskripsi cuaca BMKG ke enum WeatherCondition NEXORA
            final descLower = _bmkgWeatherDesc.toLowerCase();
            final currentHour = DateTime.now().hour;
            final isNight = currentHour >= 18 || currentHour < 6;

            if (descLower.contains('hujan') || descLower.contains('petir') || descLower.contains('gerimis') || descLower.contains('badai')) {
              _currentCondition = WeatherCondition.hujan;
            } else if (descLower.contains('angin')) {
              _currentCondition = WeatherCondition.angin;
            } else if (descLower.contains('berawan') || descLower.contains('mendung') || descLower.contains('asap') || descLower.contains('kabut')) {
              _currentCondition = WeatherCondition.berawan;
            } else if (descLower.contains('cerah')) {
              _currentCondition = isNight ? WeatherCondition.malam : WeatherCondition.cerah;
            } else {
              _currentCondition = isNight ? WeatherCondition.malam : WeatherCondition.berawan;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Override manual untuk keperluan pengujian / simulasi
  void setCondition(WeatherCondition condition) {
    _currentCondition = condition;
    _controller.add(_currentCondition);
  }

  String getConditionLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.cerah:
        return 'Cerah';
      case WeatherCondition.berawan:
        return 'Berawan';
      case WeatherCondition.hujan:
        return 'Hujan';
      case WeatherCondition.angin:
        return 'Angin';
      case WeatherCondition.malam:
        return 'Malam';
    }
  }

  void dispose() {
    _controller.close();
  }
}
