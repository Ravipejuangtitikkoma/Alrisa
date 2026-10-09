import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';

/// Data Model Ruangan
class RoomCategory {
  final String id;
  final String title;
  final IconData icon;
  final int deviceCount;

  const RoomCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.deviceCount,
  });
}

/// Data Model Item Perangkat di Ruangan
class RoomDeviceItem {
  final String id;
  final String name;
  final String roomName;
  final String roomId;
  final IconData icon;
  bool state;
  double? value; // e.g. 0-100%
  final String type; // 'toggle', 'dimmer', 'door', 'curtain'

  RoomDeviceItem({
    required this.id,
    required this.name,
    required this.roomName,
    required this.roomId,
    required this.icon,
    required this.state,
    this.value,
    required this.type,
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

  final List<RoomCategory> _categories = const [
    RoomCategory(id: 'all', title: 'Semua Ruangan', icon: Icons.grid_view, deviceCount: 7),
    RoomCategory(id: 'teras', title: 'Halaman & Teras', icon: Icons.home_work_outlined, deviceCount: 2),
    RoomCategory(id: 'living', title: 'Ruang Tamu', icon: Icons.weekend_outlined, deviceCount: 2),
    RoomCategory(id: 'utility', title: 'Utilitas Air', icon: Icons.opacity, deviceCount: 2),
    RoomCategory(id: 'bed', title: 'Kamar Utama', icon: Icons.hotel_outlined, deviceCount: 1),
  ];

  late List<RoomDeviceItem> _devices;

  @override
  void initState() {
    super.initState();
    _initDeviceList();

    // Sync dengan status MQTT live
    _mqttSub = MqttService().stateStream.listen((event) {
      if (!mounted) return;
      setState(() {
        for (var d in _devices) {
          if (d.id == event.deviceId) {
            d.state = event.payload.state;
            if (event.payload.value != null) {
              d.value = event.payload.value!.toDouble();
            }
          }
        }
      });
    });
  }

  void _initDeviceList() {
    final pagarState = MqttService().getDeviceState('pagar')?.state ?? false;
    final pintuState = MqttService().getDeviceState('pintu_geser')?.state ?? false;
    final gordenState = MqttService().getDeviceState('gorden')?.state ?? false;
    final lampuState = MqttService().getDeviceState('lampu_teras');
    final pompaState = MqttService().getDeviceState('pompa_toren')?.state ?? false;

    _devices = [
      RoomDeviceItem(
        id: 'pagar',
        name: 'Pagar Gerbang Utama',
        roomName: 'Halaman & Teras',
        roomId: 'teras',
        icon: Icons.security,
        state: pagarState,
        type: 'door',
      ),
      RoomDeviceItem(
        id: 'lampu_teras',
        name: 'Lampu Teras Depan',
        roomName: 'Halaman & Teras',
        roomId: 'teras',
        icon: Icons.lightbulb_outline,
        state: lampuState?.state ?? true,
        value: (lampuState?.value ?? 80).toDouble(),
        type: 'dimmer',
      ),
      RoomDeviceItem(
        id: 'pintu_geser',
        name: 'Pintu Geser Utama',
        roomName: 'Ruang Tamu',
        roomId: 'living',
        icon: Icons.meeting_room_outlined,
        state: pintuState,
        type: 'door',
      ),
      RoomDeviceItem(
        id: 'gorden',
        name: 'Gorden Otomatis',
        roomName: 'Ruang Tamu',
        roomId: 'living',
        icon: Icons.view_column_outlined,
        state: gordenState,
        type: 'curtain',
      ),
      RoomDeviceItem(
        id: 'pompa_toren',
        name: 'Pompa Toren Air',
        roomName: 'Utilitas Air',
        roomId: 'utility',
        icon: Icons.opacity,
        state: pompaState,
        value: 82,
        type: 'toggle',
      ),
      RoomDeviceItem(
        id: 'pompa_kolam',
        name: 'Pompa Sirkulasi Kolam',
        roomName: 'Utilitas Air',
        roomId: 'utility',
        icon: Icons.waves,
        state: false,
        type: 'toggle',
      ),
      RoomDeviceItem(
        id: 'ac_kamar',
        name: 'AC Inverter DualCool',
        roomName: 'Kamar Utama',
        roomId: 'bed',
        icon: Icons.ac_unit,
        state: true,
        value: 23, // 23 derajat Celcius
        type: 'ac',
      ),
    ];
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  void _handleDeviceToggle(RoomDeviceItem device) {
    HapticFeedback.lightImpact();
    final nextState = !device.state;

    setState(() {
      device.state = nextState;
    });

    if (MqttService().isConnected) {
      MqttService().publishSet(
        device.id,
        state: nextState,
        value: device.value?.round(),
      );
    } else {
      showOfflineWarning(context, device.name.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = _selectedRoomId == 'all'
        ? _devices
        : _devices.where((d) => d.roomId == _selectedRoomId).toList();

    final activeCount = _devices.where((d) => d.state).length;

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
                setState(() {
                  for (var d in filteredDevices) {
                    d.state = false;
                  }
                });
                if (MqttService().isConnected) {
                  for (var d in filteredDevices) {
                    MqttService().publishSet(d.id, state: false);
                  }
                } else {
                  showOfflineWarning(context, 'semua perangkat');
                }
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
                  children: const [
                    Icon(Icons.power_settings_new_rounded, size: 14, color: NexoraTokens.statusGray),
                    SizedBox(width: 6),
                    Text(
                      'Semua Mati',
                      style: TextStyle(
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
                        cat.title,
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

  Widget _buildDeviceCard(RoomDeviceItem dev) {
    final bool isOn = dev.state;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOn ? NexoraTokens.brandCyanSubtle : Colors.white,
        borderRadius: NexoraTokens.borderRadiusCard,
        border: Border.all(
          color: isOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
        ),
        boxShadow: NexoraTokens.cardShadow,
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
                  dev.icon,
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
                      '${dev.roomName} • ${_getStatusLabel(dev)}',
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
                value: dev.state,
                activeColor: NexoraTokens.brandCyan,
                onChanged: (_) => _handleDeviceToggle(dev),
              ),
            ],
          ),

          // Jika Lampu Dimmer -> Berikan slider intensitas
          if (dev.type == 'dimmer' && dev.state) ...[
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
                      value: (dev.value ?? 80).clamp(10, 100),
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
                  '${(dev.value ?? 80).round()}%',
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
        ],
      ),
    );
  }

  String _getStatusLabel(RoomDeviceItem dev) {
    if (dev.type == 'door') {
      return dev.state ? 'Terbuka' : 'Terkunci';
    } else if (dev.type == 'curtain') {
      return dev.state ? 'Terbuka' : 'Tertutup';
    } else if (dev.type == 'dimmer') {
      return dev.state ? 'Menyala ${(dev.value ?? 80).round()}%' : 'Mati';
    } else if (dev.type == 'ac') {
      return dev.state ? 'Suhu ${dev.value?.round() ?? 23}°C' : 'Standby';
    }
    return dev.state ? 'Aktif' : 'Mati';
  }
}
