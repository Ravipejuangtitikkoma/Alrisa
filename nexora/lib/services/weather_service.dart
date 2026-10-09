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
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal() {
    // Otomatis fetch data cuaca riil BMKG saat service diinisialisasi
    fetchBMKGWeather();
  }

  final _controller = StreamController<WeatherCondition>.broadcast();
  WeatherCondition _currentCondition = WeatherCondition.berawan;

  double _temperature = 27.0;
  int _humidity = 81;
  String _locationName = 'Kemayoran, Jakarta Pusat';
  String _bmkgWeatherDesc = 'Berawan';
  bool _isLoading = false;

  WeatherCondition get currentCondition => _currentCondition;
  Stream<WeatherCondition> get weatherStream => _controller.stream;

  double get temperature => _temperature;
  int get humidity => _humidity;
  String get locationName => _locationName;
  String get bmkgWeatherDesc => _bmkgWeatherDesc;
  bool get isLoading => _isLoading;

  /// Fetch Cuaca Riil dari API Resmi BMKG Publik
  /// adm4 default: 31.71.03.1001 (Jakarta Pusat). Dapat diganti dengan kode desa/wilayah mana saja di Indonesia
  Future<void> fetchBMKGWeather({String adm4 = '31.71.03.1001'}) async {
    _isLoading = true;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final url = Uri.parse('https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=$adm4');
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
