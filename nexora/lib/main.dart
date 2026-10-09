import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'services/mqtt_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi status bar & navigasi untuk tema Clean White
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Ikon hitam/gelap di status bar
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inisialisasi MQTT Service sejak aplikasi dibuka
  MqttService();

  runApp(const NexoraApp());
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
