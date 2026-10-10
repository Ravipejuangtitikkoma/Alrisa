import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';

/// Data Model Ruangan
class RoomCategory {
  final String id;
  final String title;
  final IconData icon;

  const RoomCategory({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class RoomsView extends StatefulWidget {
  const RoomsView({Key? key}) : super(key: key);

  @override
  State<RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<RoomsView> {
  String _selectedRoomId = 'all';
  StreamSubscription<DeviceStateEvent>? _mqttSub;
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  final List<RoomCategory> _categories = const [
    RoomCategory(id: 'all', title: 'Semua Ruangan', icon: Icons.grid_view_rounded),
    RoomCategory(id: 'teras', title: 'Halaman & Teras', icon: Icons.home_work_outlined),
    RoomCategory(id: 'living', title: 'Ruang Tamu', icon: Icons.weekend_outlined),
    RoomCategory(id: 'utility', title: 'Utilitas Air', icon: Icons.opacity_rounded),
    RoomCategory(id: 'bed', title: 'Kamar Utama', icon: Icons.hotel_outlined),
  ];

  List<CustomDeviceItem> _dynamicDevices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();

    // Dengarkan perubahan daftar perangkat dari DeviceManagerService
    _deviceSub = DeviceManagerService().devicesStream.listen((devs) {
      if (!mounted) return;
      setState(() {
        _dynamicDevices = List.from(devs);
        _syncWithMqtt();
      });
    });

    // Sync dengan status MQTT live
    _mqttSub = MqttService().stateStream.listen((event) {
      if (!mounted) return;
      setState(() {
        for (var d in _dynamicDevices) {
          if (d.id == event.deviceId) {
            d.isActive = event.payload.state;
            if (event.payload.value != null) {
              d.value = event.payload.value!.toDouble();
            }
          }
        }
      });
    });
  }

  void _loadDevices() {
    _dynamicDevices = List.from(DeviceManagerService().allDevices);
    
    // Pastikan perangkat default AC ada jika belum ada
    if (!_dynamicDevices.any((d) => d.id == 'ac_kamar')) {
      _dynamicDevices.add(
        CustomDeviceItem(
          id: 'ac_kamar',
          name: 'AC Inverter DualCool',
          type: DeviceType.light, // Disajikan sebagai kontrol temperatur khusus
          hardwarePin: 'IR Remote',
          isActive: true,
          value: 23.0,
          statusText: '23°C',
        ),
      );
    }
    _syncWithMqtt();
  }

  void _syncWithMqtt() {
    for (var d in _dynamicDevices) {
      final mqttState = MqttService().getDeviceState(d.id);
      if (mqttState != null) {
        d.isActive = mqttState.state;
        if (mqttState.value != null) {
          d.value = mqttState.value!.toDouble();
        }
      }
    }
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }

  String _getRoomIdForDevice(CustomDeviceItem dev) {
    if (dev.id == 'ac_kamar' || dev.name.toLowerCase().contains('kamar') || dev.name.toLowerCase().contains('tidur')) {
      return 'bed';
    }
    if (dev.type == DeviceType.gate || dev.name.toLowerCase().contains('pagar') || dev.name.toLowerCase().contains('teras') || dev.name.toLowerCase().contains('taman')) {
      return 'teras';
    }
    if (dev.type == DeviceType.waterPump || dev.name.toLowerCase().contains('pompa') || dev.name.toLowerCase().contains('toren') || dev.name.toLowerCase().contains('air') || dev.name.toLowerCase().contains('kolam')) {
      return 'utility';
    }
    if (dev.type == DeviceType.slidingDoor || dev.type == DeviceType.curtain || dev.name.toLowerCase().contains('tamu') || dev.name.toLowerCase().contains('keluarga')) {
      return 'living';
    }
    return 'teras';
  }

  String _getRoomNameForDevice(CustomDeviceItem dev) {
    final roomId = _getRoomIdForDevice(dev);
    switch (roomId) {
      case 'teras':
        return 'Halaman & Teras';
      case 'living':
        return 'Ruang Tamu';
      case 'utility':
        return 'Utilitas Air';
      case 'bed':
        return 'Kamar Utama';
      default:
        return 'Ruangan';
    }
  }

  IconData _getIconForDevice(CustomDeviceItem dev) {
    if (dev.id == 'ac_kamar') return Icons.ac_unit_rounded;
    switch (dev.type) {
      case DeviceType.gate:
        return Icons.fence_rounded;
      case DeviceType.light:
        return Icons.lightbulb_outline_rounded;
      case DeviceType.slidingDoor:
        return Icons.meeting_room_outlined;
      case DeviceType.curtain:
        return Icons.view_column_outlined;
      case DeviceType.waterPump:
        return Icons.opacity_rounded;
    }
  }

  void _handleDeviceToggle(CustomDeviceItem device) {
    HapticFeedback.lightImpact();
    final nextState = !device.isActive;

    setState(() {
      device.isActive = nextState;
    });

    if (MqttService().isConnected) {
      MqttService().publishSet(
        device.id,
        state: nextState,
        value: device.value.round(),
      );
    } else {
      showOfflineWarning(context, device.name.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = _selectedRoomId == 'all'
        ? _dynamicDevices
        : _dynamicDevices.where((d) => _getRoomIdForDevice(d) == _selectedRoomId).toList();

    final activeCount = _dynamicDevices.where((d) => d.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Ringkasan Ruangan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ruangan Rumah',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: NexoraTokens.ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '4 Zona • $activeCount Perangkat Sedang Aktif',
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
              ],
            ),
            // Tombol Cepat Matikan Semua di Ruangan
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                final anyActive = filteredDevices.any((d) => d.isActive);
                final targetState = !anyActive;

                setState(() {
                  for (var d in filteredDevices) {
                    d.isActive = targetState;
                  }
                });

                if (MqttService().isConnected) {
                  for (var d in filteredDevices) {
                    MqttService().publishSet(d.id, state: targetState, value: d.value.round());
                  }
                } else {
                  showOfflineWarning(context, 'perangkat');
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Text(
                      targetState
                          ? '⚡ Semua perangkat di zona ini dinyalakan'
                          : '🔌 Semua perangkat di zona ini dinonaktifkan',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NexoraTokens.cardBorder),
                  boxShadow: NexoraTokens.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filteredDevices.any((d) => d.isActive)
                          ? Icons.power_settings_new_rounded
                          : Icons.flash_on_rounded,
                      size: 14,
                      color: filteredDevices.any((d) => d.isActive)
                          ? NexoraTokens.statusGray
                          : NexoraTokens.brandCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filteredDevices.any((d) => d.isActive) ? 'Matikan Semua' : 'Nyalakan Semua',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. Filter Kategori Ruangan (Horizontal Chips)
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat.id == _selectedRoomId;
              final count = cat.id == 'all'
                  ? _dynamicDevices.length
                  : _dynamicDevices.where((d) => _getRoomIdForDevice(d) == cat.id).length;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedRoomId = cat.id;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? NexoraTokens.brandCyan : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.cardBorder,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: NexoraTokens.brandCyan.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : NexoraTokens.cardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected ? Colors.white : NexoraTokens.inkSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cat.title} ($count)',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : NexoraTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // 3. Grid Kartu Perangkat
        if (filteredDevices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: NexoraTokens.borderRadiusCard,
              border: Border.all(color: NexoraTokens.cardBorder),
            ),
            child: Column(
              children: const [
                Icon(Icons.devices_other_rounded, size: 40, color: NexoraTokens.statusGray),
                SizedBox(height: 12),
                Text(
                  'Belum ada perangkat di ruangan ini',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredDevices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dev = filteredDevices[index];
              return _buildDeviceCard(dev);
            },
          ),
      ],
    );
  }

  Widget _buildDeviceCard(CustomDeviceItem dev) {
    final bool isOn = dev.isActive;
    final icon = _getIconForDevice(dev);
    final roomName = _getRoomNameForDevice(dev);
    final isAc = dev.id == 'ac_kamar';
    final isLight = dev.type == DeviceType.light && !isAc;
    final isGate = dev.type == DeviceType.gate || dev.type == DeviceType.slidingDoor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOn ? NexoraTokens.brandCyanSubtle : Colors.white,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(
          color: isOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
          width: isOn ? 1.5 : 1.0,
        ),
        boxShadow: isOn
            ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
            : NexoraTokens.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Ikon Perangkat Bulat
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOn ? NexoraTokens.brandCyan : const Color(0xFFF1F4F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isOn ? Colors.white : NexoraTokens.inkSecondary,
                ),
              ),
              const SizedBox(width: 14),
              // Nama & Lokasi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.name,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$roomName • ${_getStatusLabel(dev)}',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOn ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                      ),
                    ),
                  ],
                ),
              ),
              // Switch Interaktif
              Switch.adaptive(
                value: dev.isActive,
                activeColor: NexoraTokens.brandCyan,
                onChanged: (_) => _handleDeviceToggle(dev),
              ),
            ],
          ),

          // Jika Lampu Dimmer -> Berikan slider intensitas
          if (isLight && dev.isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.brightness_medium_rounded, size: 16, color: NexoraTokens.brandCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: NexoraTokens.brandCyan,
                      inactiveTrackColor: NexoraTokens.brandCyanBorder,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: dev.value.clamp(10, 100),
                      min: 10,
                      max: 100,
                      onChanged: (val) {
                        setState(() {
                          dev.value = val;
                        });
                      },
                      onChangeEnd: (val) {
                        if (MqttService().isConnected) {
                          MqttService().publishSet(dev.id, state: true, value: val.round());
                        } else {
                          showOfflineWarning(context, dev.name.toLowerCase());
                        }
                      },
                    ),
                  ),
                ),
                Text(
                  '${dev.value.round()}%',
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.brandCyan,
                  ),
                ),
              ],
            ),
          ],

          // Jika AC -> Berikan Pengatur Suhu (+/-)
          if (isAc && dev.isActive) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Suhu Target Ruangan',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NexoraTokens.inkSecondary,
                  ),
                ),
                Row(
                  children: [
                    _buildTempButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (dev.value > 16) {
                          setState(() => dev.value -= 1);
                          if (MqttService().isConnected) {
                            MqttService().publishSet(dev.id, state: true, value: dev.value.round());
                          }
                        }
                      },
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NexoraTokens.brandCyanBorder),
                      ),
                      child: Text(
                        '${dev.value.round()}°C',
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: NexoraTokens.brandCyan,
                        ),
                      ),
                    ),
                    _buildTempButton(
                      icon: Icons.add,
                      onTap: () {
                        if (dev.value < 30) {
                          setState(() => dev.value += 1);
                          if (MqttService().isConnected) {
                            MqttService().publishSet(dev.id, state: true, value: dev.value.round());
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],

          // Jika Pagar / Gerbang -> Berikan Tombol Cepat Buka / Tutup
          if (isGate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = true);
                      if (MqttService().isConnected) {
                        MqttService().publishSet(dev.id, state: true);
                      } else {
                        showOfflineWarning(context, dev.name.toLowerCase());
                      }
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 14),
                    label: const Text('Buka', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      primary: dev.isActive ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                      side: BorderSide(
                        color: dev.isActive ? NexoraTokens.brandCyan : NexoraTokens.cardBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = false);
                      if (MqttService().isConnected) {
                        MqttService().publishSet(dev.id, state: false);
                      } else {
                        showOfflineWarning(context, dev.name.toLowerCase());
                      }
                    },
                    icon: const Icon(Icons.lock_rounded, size: 14),
                    label: const Text('Kunci', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      primary: !dev.isActive ? NexoraTokens.ink : NexoraTokens.inkSecondary,
                      side: BorderSide(
                        color: !dev.isActive ? NexoraTokens.ink : NexoraTokens.cardBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTempButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NexoraTokens.cardBorder),
        ),
        child: Icon(icon, size: 16, color: NexoraTokens.ink),
      ),
    );
  }

  String _getStatusLabel(CustomDeviceItem dev) {
    if (dev.id == 'ac_kamar') {
      return dev.isActive ? 'Suhu ${dev.value.round()}°C' : 'Standby';
    }
    if (dev.type == DeviceType.gate || dev.type == DeviceType.slidingDoor) {
      return dev.isActive ? 'Terbuka' : 'Terkunci';
    } else if (dev.type == DeviceType.curtain) {
      return dev.isActive ? 'Terbuka' : 'Tertutup';
    } else if (dev.type == DeviceType.light) {
      return dev.isActive ? 'Menyala ${dev.value.round()}%' : 'Mati';
    } else if (dev.type == DeviceType.waterPump) {
      return dev.isActive ? 'Mengalir' : 'Mati';
    }
    return dev.isActive ? 'Aktif' : 'Mati';
  }
}
