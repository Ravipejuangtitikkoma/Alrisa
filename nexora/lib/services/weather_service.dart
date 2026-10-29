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

/// WeatherService Singleton: Terintegrasi dengan Global Real-Time Weather API (Setara Google Weather / ECMWF & NOAA)
/// Dilengkapi Auto-Detect Lokasi & Koordinat Presisi Pengguna secara Real-Time (IP/Geolocation)
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal() {
    _setDefaultTimeCondition();
    initLocationAndWeather();
  }

  final _controller = StreamController<WeatherCondition>.broadcast();
  WeatherCondition _currentCondition = WeatherCondition.berawan;

  double _temperature = 27.0;
  int _humidity = 78;
  double _latitude = -1.6101;
  double _longitude = 103.6131;
  String _locationName = 'Mendeteksi Lokasi...';
  String _bmkgWeatherDesc = 'Cerah Berawan';
  bool _isLoading = false;
  String _currentCityKey = 'auto';

  WeatherCondition get currentCondition => _currentCondition;
  Stream<WeatherCondition> get weatherStream => _controller.stream;

  double get temperature => _temperature;
  int get humidity => _humidity;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get locationName => _locationName;
  String get bmkgWeatherDesc => _bmkgWeatherDesc;
  bool get isLoading => _isLoading;
  String get currentCityKey => _currentCityKey;

  void _setDefaultTimeCondition() {
    final hour = DateTime.now().hour;
    final isNight = hour >= 18 || hour < 6;
    _currentCondition = isNight ? WeatherCondition.malam : WeatherCondition.cerah;
    _bmkgWeatherDesc = isNight ? 'Malam Cerah' : 'Cerah Berawan';
  }

  /// Daftar Kota & Koordinat Presisi di Indonesia (beserta opsi Auto-Detect Lokasi Saat Ini)
  static const Map<String, Map<String, String>> supportedCities = {
    'auto': {
      'name': '📍 Lokasi Saya Saat Ini (Otomatis)',
      'lat': 'auto',
      'lon': 'auto',
    },
    'jambi': {
      'name': 'Kota Jambi, Jambi',
      'lat': '-1.6101',
      'lon': '103.6131',
    },
    'palembang': {
      'name': 'Kota Palembang, Sumsel',
      'lat': '-2.9761',
      'lon': '104.7754',
    },
    'jakarta': {
      'name': 'DKI Jakarta',
      'lat': '-6.2088',
      'lon': '106.8456',
    },
    'bandung': {
      'name': 'Kota Bandung, Jawa Barat',
      'lat': '-6.9175',
      'lon': '107.6191',
    },
    'surabaya': {
      'name': 'Kota Surabaya, Jawa Timur',
      'lat': '-7.2575',
      'lon': '112.7521',
    },
    'medan': {
      'name': 'Kota Medan, Sumatera Utara',
      'lat': '3.5952',
      'lon': '98.6722',
    },
    'semarang': {
      'name': 'Kota Semarang, Jawa Tengah',
      'lat': '-6.9667',
      'lon': '110.4167',
    },
    'makassar': {
      'name': 'Kota Makassar, Sulawesi Selatan',
      'lat': '-5.1477',
      'lon': '119.4327',
    },
    'denpasar': {
      'name': 'Kota Denpasar, Bali',
      'lat': '-8.6705',
      'lon': '115.2126',
    },
    'padang': {
      'name': 'Kota Padang, Sumatera Barat',
      'lat': '-0.9471',
      'lon': '100.4172',
    },
    'pekanbaru': {
      'name': 'Kota Pekanbaru, Riau',
      'lat': '0.5071',
      'lon': '101.4478',
    },
    'lampung': {
      'name': 'Bandar Lampung, Lampung',
      'lat': '-5.3971',
      'lon': '105.2668',
    },
    'yogyakarta': {
      'name': 'Yogyakarta, D.I. Yogyakarta',
      'lat': '-7.7956',
      'lon': '110.3695',
    },
  };

  /// Deteksi otomatis lokasi koordinat pengguna dari jaringan / IP secara real-time
  Future<void> initLocationAndWeather() async {
    _isLoading = true;
    bool locationDetected = false;

    // 1. Coba Geolocation Presisi via ipwho.is
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('https://ipwho.is/'));
      final res = await req.close();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble();
          final city = (data['city'] as String? ?? '').trim();
          final region = (data['region'] as String? ?? '').trim();

          if (lat != null && lon != null) {
            _latitude = lat;
            _longitude = lon;
            if (city.isNotEmpty && region.isNotEmpty && city != region) {
              _locationName = '$city, $region';
            } else if (city.isNotEmpty) {
              _locationName = city;
            }
            locationDetected = true;
          }
        }
      }
      client.close();
    } catch (_) {}

    // 2. Fallback Geolocation kedua via freeipapi.com jika ipwho.is gagal
    if (!locationDetected) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final req = await client.getUrl(Uri.parse('https://freeipapi.com/api/json'));
        final res = await req.close();

        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final lat = (data['latitude'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble();
          final city = (data['cityName'] as String? ?? '').trim();
          final region = (data['regionName'] as String? ?? '').trim();

          if (lat != null && lon != null) {
            _latitude = lat;
            _longitude = lon;
            if (city.isNotEmpty && region.isNotEmpty && city != region) {
              _locationName = '$city, $region';
            } else if (city.isNotEmpty) {
              _locationName = city;
            }
            locationDetected = true;
          }
        }
        client.close();
      } catch (_) {}
    }

    // 3. Fallback Geolocation ketiga via ip-api.com
    if (!locationDetected) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final req = await client.getUrl(
          Uri.parse('http://ip-api.com/json/?fields=status,regionName,city,lat,lon'),
        );
        final res = await req.close();

        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          if (data['status'] == 'success') {
            final lat = (data['lat'] as num?)?.toDouble();
            final lon = (data['lon'] as num?)?.toDouble();
            final city = (data['city'] as String? ?? '').trim();
            final region = (data['regionName'] as String? ?? '').trim();

            if (lat != null && lon != null) {
              _latitude = lat;
              _longitude = lon;
              if (city.isNotEmpty && region.isNotEmpty && city != region) {
                _locationName = '$city, $region';
              } else if (city.isNotEmpty) {
                _locationName = city;
              }
              locationDetected = true;
            }
          }
        }
        client.close();
      } catch (_) {}
    }

    if (!locationDetected && _locationName == 'Mendeteksi Lokasi...') {
      _locationName = 'Kota Jambi, Jambi';
    }

    _currentCityKey = 'auto';
    await fetchBMKGWeather();
  }

  /// Ganti Lokasi Kota secara manual atau kembalikan ke Auto-Detect Lokasi
  Future<void> setLocationCity(String cityKey) async {
    if (cityKey == 'auto') {
      _currentCityKey = 'auto';
      await initLocationAndWeather();
      return;
    }
    if (supportedCities.containsKey(cityKey)) {
      _currentCityKey = cityKey;
      final cityInfo = supportedCities[cityKey]!;
      _locationName = cityInfo['name']!;
      _latitude = double.tryParse(cityInfo['lat'] ?? '') ?? _latitude;
      _longitude = double.tryParse(cityInfo['lon'] ?? '') ?? _longitude;
      await fetchBMKGWeather();
    }
  }

  /// Fetch Cuaca Real-Time Presisi Tinggi berdasarkan Koordinat Lokasi Saat Ini
  /// Menggunakan Global Weather API (Open-Meteo Current Observation + wttr.in fallback)
  Future<void> fetchBMKGWeather({String? adm4}) async {
    _isLoading = true;
    bool fetched = false;

    // 1. Fetch dari Open-Meteo Global Real-Time Weather API (Model Satelit & Stasiun Cuaca Terdekat)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_latitude&longitude=$_longitude'
        '&current=temperature_2m,relative_humidity_2m,is_day,precipitation,rain,showers,weather_code,wind_speed_10m'
        '&timezone=auto',
      );
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        if (json.containsKey('current')) {
          _parseGlobalWeatherJson(json['current'] as Map<String, dynamic>);
          fetched = true;
        }
      }
      client.close();
    } catch (_) {}

    // 2. Fallback ke wttr.in Global Weather Observation jika Open-Meteo gagal
    if (!fetched) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 6);
        final url = Uri.parse('https://wttr.in/$_latitude,$_longitude?format=j1');
        final request = await client.getUrl(url);
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final currentList = json['current_condition'] as List?;
          if (currentList != null && currentList.isNotEmpty) {
            final cur = currentList.first as Map<String, dynamic>;
            _temperature = double.tryParse(cur['temp_C']?.toString() ?? '') ?? _temperature;
            _humidity = int.tryParse(cur['humidity']?.toString() ?? '') ?? _humidity;
            final precipMm = double.tryParse(cur['precipMM']?.toString() ?? '0') ?? 0.0;
            final hour = DateTime.now().hour;
            final isNight = hour >= 18 || hour < 6;

            if (precipMm >= 0.4) {
              _currentCondition = WeatherCondition.hujan;
              _bmkgWeatherDesc = precipMm > 2.5 ? 'Hujan Sedang' : 'Hujan Ringan';
            } else if (isNight) {
              _currentCondition = WeatherCondition.malam;
              _bmkgWeatherDesc = 'Malam Cerah Berawan';
            } else {
              _currentCondition = WeatherCondition.cerah;
              _bmkgWeatherDesc = 'Cerah Berawan';
            }
          }
        }
        client.close();
      } catch (_) {}
    }

    _isLoading = false;
    _controller.add(_currentCondition);
  }

  void _parseGlobalWeatherJson(Map<String, dynamic> current) {
    try {
      _temperature = (current['temperature_2m'] as num?)?.toDouble() ?? _temperature;
      _humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? _humidity;

      final int weatherCode = (current['weather_code'] as num?)?.toInt() ?? 1;
      final int isDayInt = (current['is_day'] as num?)?.toInt() ??
          ((DateTime.now().hour >= 6 && DateTime.now().hour < 18) ? 1 : 0);
      final bool isNight = isDayInt == 0;

      // Cek curah hujan aktual detik ini (mm) agar tidak salah menampilkan hujan jika tidak sedang hujan
      final double precipitation = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final double rain = (current['rain'] as num?)?.toDouble() ?? 0.0;
      final double showers = (current['showers'] as num?)?.toDouble() ?? 0.0;
      final double windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final double totalPrecip = precipitation > (rain + showers) ? precipitation : (rain + showers);

      // Hanya anggap hujan jika benar-benar ada presipitasi aktif (>= 0.25 mm) atau badai/hujan deras
      final bool isActuallyRaining = totalPrecip >= 0.25 ||
          weatherCode == 63 ||
          weatherCode == 65 ||
          weatherCode == 81 ||
          weatherCode == 82 ||
          weatherCode >= 95;

      if (isActuallyRaining) {
        _currentCondition = WeatherCondition.hujan;
        if (weatherCode >= 95) {
          _bmkgWeatherDesc = 'Hujan Petir';
        } else if (weatherCode == 65 || weatherCode == 82 || totalPrecip >= 3.0) {
          _bmkgWeatherDesc = 'Hujan Deras';
        } else {
          _bmkgWeatherDesc = 'Hujan Ringan';
        }
      } else if (windSpeed >= 28.0) {
        _currentCondition = WeatherCondition.angin;
        _bmkgWeatherDesc = 'Berangin';
      } else if (isNight) {
        // Saat malam dan tidak hujan, tampilkan suasana Malam yang akurat
        _currentCondition = WeatherCondition.malam;
        if (weatherCode == 0) {
          _bmkgWeatherDesc = 'Malam Cerah';
        } else if (weatherCode <= 2) {
          _bmkgWeatherDesc = 'Cerah Berawan';
        } else {
          _bmkgWeatherDesc = 'Malam Berawan';
        }
      } else {
        // Siang / Pagi / Sore hari dan tidak hujan
        if (weatherCode == 0) {
          _currentCondition = WeatherCondition.cerah;
          _bmkgWeatherDesc = 'Cerah';
        } else if (weatherCode == 1 || weatherCode == 2) {
          _currentCondition = WeatherCondition.cerah;
          _bmkgWeatherDesc = 'Cerah Berawan';
        } else {
          _currentCondition = WeatherCondition.berawan;
          _bmkgWeatherDesc = 'Berawan';
        }
      }
    } catch (_) {}
  }

  /// Override manual untuk keperluan pengujian / simulasi
  void setCondition(WeatherCondition condition) {
    _currentCondition = condition;
    _bmkgWeatherDesc = getConditionLabel(condition);
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
        return 'Malam Cerah';
    }
  }

  void dispose() {
    _controller.close();
  }
}
