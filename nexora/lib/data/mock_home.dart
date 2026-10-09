import 'package:flutter/material.dart';

/// Model Perangkat Pintar
class DeviceModel {
  final String id;
  final String name;
  final String room;
  final IconData icon;
  bool isActive;
  String statusText;
  double? value; // misal brightness (0.0 - 1.0) atau water level (0.0 - 1.0)

  DeviceModel({
    required this.id,
    required this.name,
    required this.room,
    required this.icon,
    required this.isActive,
    required this.statusText,
    this.value,
  });
}

/// Model Skenario (Scene)
class SceneModel {
  final String id;
  final String title;
  final IconData icon;
  bool isSelected;

  SceneModel({
    required this.id,
    required this.title,
    required this.icon,
    this.isSelected = false,
  });
}

/// Model Titik Data Konsumsi Energi
class EnergyPoint {
  final String timeLabel;
  final double watt;

  EnergyPoint({required this.timeLabel, required this.watt});
}

/// Mock Data Ekosistem NEXORA
class MockHomeData {
  static List<SceneModel> getScenes() => [
    SceneModel(id: 'morning', title: 'Pagi Cerah', icon: Icons.wb_sunny_outlined, isSelected: true),
    SceneModel(id: 'away', title: 'Keluar Rumah', icon: Icons.directions_walk_outlined),
    SceneModel(id: 'sleep', title: 'Mode Tidur', icon: Icons.bedtime_outlined),
    SceneModel(id: 'eco', title: 'Hemat Energi', icon: Icons.eco_outlined),
  ];

  static List<EnergyPoint> getEnergyPoints() => [
    EnergyPoint(timeLabel: '06.00', watt: 180),
    EnergyPoint(timeLabel: '09.00', watt: 320),
    EnergyPoint(timeLabel: '12.00', watt: 490),
    EnergyPoint(timeLabel: '15.00', watt: 410),
    EnergyPoint(timeLabel: '18.00', watt: 680),
    EnergyPoint(timeLabel: '21.00', watt: 540),
    EnergyPoint(timeLabel: '23.00', watt: 260),
  ];
}
