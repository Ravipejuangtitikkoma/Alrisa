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

class _DeviceSectionGroup {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<CustomDeviceItem> devices;

  _DeviceSectionGroup({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.devices,
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
    if (dev.name.toLowerCase().contains('kamar') || dev.name.toLowerCase().contains('tidur')) {
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

    MqttService().publishSet(
      device.id,
      state: nextState,
      value: device.value.round(),
    );
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
        // 1. Header Ringkasan Ruangan & Aksi Cepat (Kontras Tinggi di Atas Ambient Sky)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.40),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.meeting_room_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ruangan Rumah',
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedRoomId == 'all'
                              ? '4 Zona • $activeCount Perangkat Aktif'
                              : '${filteredDevices.where((d) => d.isActive).length} dari ${filteredDevices.length} Aktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.92),
                            shadows: const [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Tombol Cepat Matikan/Nyalakan Semua di Zona Ini
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

                for (var d in filteredDevices) {
                  MqttService().publishSet(d.id, state: targetState, value: d.value.round());
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: filteredDevices.any((d) => d.isActive)
                      ? const Color(0xFFFFF1F2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: filteredDevices.any((d) => d.isActive)
                        ? const Color(0xFFFDA4AF)
                        : NexoraTokens.cardBorder,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                          ? const Color(0xFFE11D48)
                          : NexoraTokens.brandCyan,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      filteredDevices.any((d) => d.isActive) ? 'Matikan Semua' : 'Nyalakan Semua',
                      style: TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: filteredDevices.any((d) => d.isActive)
                            ? const Color(0xFFE11D48)
                            : NexoraTokens.ink,
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

        // 3. Grid Kartu Perangkat Berdasarkan Seksi Berurutan (Lampu, Gerbang, Pintu, Gorden, Pompa, AC)
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
          ..._buildGroupedSections(filteredDevices),
      ],
    );
  }

  List<Widget> _buildGroupedSections(List<CustomDeviceItem> filteredDevices) {
    final lights = filteredDevices.where((d) => d.type == DeviceType.light).toList();
    final gates = filteredDevices.where((d) => d.type == DeviceType.gate).toList();
    final slidingDoors = filteredDevices.where((d) => d.type == DeviceType.slidingDoor).toList();
    final curtains = filteredDevices.where((d) => d.type == DeviceType.curtain).toList();
    final waterPumps = filteredDevices.where((d) => d.type == DeviceType.waterPump).toList();

    final sections = [
      if (lights.isNotEmpty)
        _DeviceSectionGroup(
          title: 'Lampu Pintar',
          icon: Icons.lightbulb_outline_rounded,
          accentColor: const Color(0xFFEAB308),
          devices: lights,
        ),
      if (gates.isNotEmpty)
        _DeviceSectionGroup(
          title: 'Gerbang & Pagar Otomatis',
          icon: Icons.fence_rounded,
          accentColor: NexoraTokens.brandCyan,
          devices: gates,
        ),
      if (slidingDoors.isNotEmpty)
        _DeviceSectionGroup(
          title: 'Pintu Geser',
          icon: Icons.meeting_room_outlined,
          accentColor: const Color(0xFF8B5CF6),
          devices: slidingDoors,
        ),
      if (curtains.isNotEmpty)
        _DeviceSectionGroup(
          title: 'Gorden Otomatis',
          icon: Icons.view_column_outlined,
          accentColor: const Color(0xFFEC4899),
          devices: curtains,
        ),
      if (waterPumps.isNotEmpty)
        _DeviceSectionGroup(
          title: 'Pompa Air & Toren',
          icon: Icons.opacity_rounded,
          accentColor: const Color(0xFF0EA5E9),
          devices: waterPumps,
        ),
    ];

    return sections.map((sec) => _buildDeviceSection(sec)).toList();
  }

  Widget _buildDeviceSection(_DeviceSectionGroup section) {
    final activeCount = section.devices.where((d) => d.isActive).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Seksi Kategori
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: section.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        section.icon,
                        size: 15,
                        color: section.accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: NexoraTokens.inkSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeCount > 0
                        ? section.accentColor.withOpacity(0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount/${section.devices.length} Aktif',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activeCount > 0 ? section.accentColor : NexoraTokens.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Daftar Perangkat Dalam Seksi Ini
          ...section.devices.map((dev) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDeviceCard(dev),
              )),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(CustomDeviceItem dev) {
    final bool isOn = dev.isActive;
    final icon = _getIconForDevice(dev);
    final roomName = _getRoomNameForDevice(dev);
    final isLight = dev.type == DeviceType.light;
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

          // Jika Pagar / Gerbang -> Berikan Tombol Cepat Buka / Kunci
          if (isGate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = true);
                      MqttService().publishSet(dev.id, state: true);
                    },
                    icon: Icon(
                      Icons.lock_open_rounded,
                      size: 14,
                      color: dev.isActive ? Colors.white : NexoraTokens.inkSecondary,
                    ),
                    label: Text(
                      'Buka',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: dev.isActive ? Colors.white : NexoraTokens.ink,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: dev.isActive ? NexoraTokens.brandCyan : Colors.white,
                      elevation: dev.isActive ? 2 : 0,
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = false);
                      MqttService().publishSet(dev.id, state: false);
                    },
                    icon: Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: !dev.isActive ? Colors.white : NexoraTokens.inkSecondary,
                    ),
                    label: Text(
                      'Kunci',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !dev.isActive ? Colors.white : NexoraTokens.ink,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: !dev.isActive ? NexoraTokens.ink : Colors.white,
                      elevation: !dev.isActive ? 2 : 0,
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

          // Jika Gorden -> Berikan Tombol Cepat Buka / Tutup
          if (dev.type == DeviceType.curtain) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = true);
                      MqttService().publishSet(dev.id, state: true);
                    },
                    icon: Icon(
                      Icons.meeting_room_outlined,
                      size: 14,
                      color: dev.isActive ? Colors.white : NexoraTokens.inkSecondary,
                    ),
                    label: Text(
                      'Buka',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: dev.isActive ? Colors.white : NexoraTokens.ink,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: dev.isActive ? NexoraTokens.brandCyan : Colors.white,
                      elevation: dev.isActive ? 2 : 0,
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => dev.isActive = false);
                      MqttService().publishSet(dev.id, state: false);
                    },
                    icon: Icon(
                      Icons.door_sliding_outlined,
                      size: 14,
                      color: !dev.isActive ? Colors.white : NexoraTokens.inkSecondary,
                    ),
                    label: Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !dev.isActive ? Colors.white : NexoraTokens.ink,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: !dev.isActive ? NexoraTokens.ink : Colors.white,
                      elevation: !dev.isActive ? 2 : 0,
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

  String _getStatusLabel(CustomDeviceItem dev) {
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
