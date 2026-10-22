import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/services/mqtt_service.dart';

class IotDeviceManagementScreen extends StatefulWidget {
  const IotDeviceManagementScreen({Key? key}) : super(key: key);

  @override
  State<IotDeviceManagementScreen> createState() => _IotDeviceManagementScreenState();
}

class _IotDeviceManagementScreenState extends State<IotDeviceManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DeviceType? _selectedCategory; // null = Semua

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return Scaffold(
      backgroundColor: NexoraTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: NexoraTokens.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.isIndonesian ? 'Perangkat IoT (ESP32 / PLC)' : 'IoT Devices (ESP32 / PLC)',
          style: const TextStyle(
            fontFamily: NexoraTokens.fontFamilySans,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: NexoraTokens.ink,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddDeviceSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(lang.isIndonesian ? 'Tambah' : 'Add'),
              style: ElevatedButton.styleFrom(
                primary: NexoraTokens.brandCyan,
                onPrimary: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: NexoraTokens.cardBorder,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // BILAH PENCARIAN & FILTER KATEGORI
            // ==========================================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 13.5,
                        color: NexoraTokens.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: lang.isIndonesian
                            ? 'Cari nama perangkat, pin GPIO, atau ID...'
                            : 'Search device name, GPIO pin, or ID...',
                        hintStyle: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 13,
                          color: NexoraTokens.inkMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: NexoraTokens.brandCyan,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, size: 18, color: NexoraTokens.inkMuted),
                                onPressed: () {
                                  _searchCtrl.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter Chips Horisontal
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip(
                          label: lang.isIndonesian ? 'Semua' : 'All',
                          isSelected: _selectedCategory == null,
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryChip(
                          label: 'Gerbang',
                          icon: Icons.sensor_door_outlined,
                          isSelected: _selectedCategory == DeviceType.gate,
                          onTap: () {
                            setState(() {
                              _selectedCategory = DeviceType.gate;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryChip(
                          label: 'Lampu',
                          icon: Icons.lightbulb_outline,
                          isSelected: _selectedCategory == DeviceType.light,
                          onTap: () {
                            setState(() {
                              _selectedCategory = DeviceType.light;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryChip(
                          label: 'Pintu Geser',
                          icon: Icons.meeting_room_outlined,
                          isSelected: _selectedCategory == DeviceType.slidingDoor,
                          onTap: () {
                            setState(() {
                              _selectedCategory = DeviceType.slidingDoor;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryChip(
                          label: 'Gorden',
                          icon: Icons.view_sidebar_outlined,
                          isSelected: _selectedCategory == DeviceType.curtain,
                          onTap: () {
                            setState(() {
                              _selectedCategory = DeviceType.curtain;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryChip(
                          label: 'Pompa Air',
                          icon: Icons.opacity_outlined,
                          isSelected: _selectedCategory == DeviceType.waterPump,
                          onTap: () {
                            setState(() {
                              _selectedCategory = DeviceType.waterPump;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // DAFTAR PERANGKAT IOT (HASIL FILTER)
            // ==========================================
            Expanded(
              child: StreamBuilder<List<CustomDeviceItem>>(
                stream: DeviceManagerService().devicesStream,
                initialData: DeviceManagerService().allDevices,
                builder: (context, snapshot) {
                  final allDevices = DeviceManagerService().allDevices;
                  final filtered = _getFilteredDevices(allDevices);

                  if (allDevices.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.developer_board_off_rounded,
                      title: lang.isIndonesian ? 'Belum Ada Perangkat' : 'No Devices Yet',
                      subtitle: lang.isIndonesian
                          ? 'Daftarkan perangkat ESP32 atau PLC Mitsubishi Anda untuk memulai kendali cerdas.'
                          : 'Register your ESP32 or Mitsubishi PLC device to start smart control.',
                      actionLabel: lang.isIndonesian ? '+ Tambah Perangkat' : '+ Add Device',
                      onAction: () => _showAddDeviceSheet(context),
                    );
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: lang.isIndonesian ? 'Perangkat Tidak Ditemukan' : 'No Devices Found',
                      subtitle: lang.isIndonesian
                          ? 'Tidak ada perangkat yang cocok dengan kriteria filter Anda.'
                          : 'No devices match your filter criteria.',
                      actionLabel: lang.isIndonesian ? 'Reset Filter' : 'Reset Filter',
                      onAction: () {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedCategory = null;
                        });
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final dev = filtered[index];
                      return _buildDeviceCard(context, dev, lang);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CustomDeviceItem> _getFilteredDevices(List<CustomDeviceItem> list) {
    return list.where((dev) {
      if (_selectedCategory != null && dev.type != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final nameMatches = dev.name.toLowerCase().contains(_searchQuery);
        final idMatches = dev.id.toLowerCase().contains(_searchQuery);
        final pinMatches = dev.hardwarePin.toLowerCase().contains(_searchQuery);
        return nameMatches || idMatches || pinMatches;
      }
      return true;
    }).toList();
  }

  Widget _buildCategoryChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? NexoraTokens.brandCyan : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? NexoraTokens.brandCyan : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : NexoraTokens.inkSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : NexoraTokens.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, CustomDeviceItem dev, LanguageService lang) {
    final devColor = _getDeviceColor(dev.type);
    final devIcon = _getDeviceIcon(dev.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexoraTokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: devColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(devIcon, size: 22, color: devColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dev.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'nexora/${dev.id}/set',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        dev.hardwarePin,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: NexoraTokens.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Tombol Trigger / Switch Tes
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              final nextState = !dev.isActive;
              dev.isActive = nextState;
              dev.statusText = nextState ? 'Aktif' : 'Nonaktif';
              MqttService().publishSet(
                dev.id,
                state: nextState,
                hardwarePin: dev.hardwarePin,
              );
              setState(() {});
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dev.isActive ? NexoraTokens.statusGreenSubtle : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dev.isActive ? NexoraTokens.statusGreen.withOpacity(0.4) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                dev.isActive ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: dev.isActive ? NexoraTokens.statusGreen : NexoraTokens.inkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tombol Edit
          InkWell(
            onTap: () => _showEditDeviceSheet(context, dev),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_outlined, size: 18, color: NexoraTokens.inkSecondary),
            ),
          ),
          // Tombol Hapus
          InkWell(
            onTap: () => _confirmDeleteDevice(context, dev),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: NexoraTokens.inkSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: NexoraTokens.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12.5,
                color: NexoraTokens.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                primary: NexoraTokens.brandCyan,
                onPrimary: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.gate:
        return Icons.sensor_door_outlined;
      case DeviceType.light:
        return Icons.lightbulb_outline;
      case DeviceType.slidingDoor:
        return Icons.meeting_room_outlined;
      case DeviceType.curtain:
        return Icons.view_sidebar_outlined;
      case DeviceType.waterPump:
        return Icons.opacity_outlined;
    }
  }

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.gate:
        return NexoraTokens.brandCyan;
      case DeviceType.light:
        return const Color(0xFFEAB308);
      case DeviceType.slidingDoor:
        return const Color(0xFF6366F1);
      case DeviceType.curtain:
        return const Color(0xFFEC4899);
      case DeviceType.waterPump:
        return const Color(0xFF0EA5E9);
    }
  }

  // ==========================================
  // MODAL TAMBAH PERANGKAT
  // ==========================================
  void _showAddDeviceSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: 'GPIO 2 (%QX0.0)');
    final idCtrl = TextEditingController();
    DeviceType selectedType = DeviceType.gate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Perangkat Baru',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Perangkat langsung aktif di sistem Nexora & dapat dites via ESP32 / PLC.',
                    style: TextStyle(fontSize: 12, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 18),

                  const Text('Tipe Perangkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<DeviceType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: DeviceType.gate, child: Text('Gerbang / Pagar Otomatis')),
                      DropdownMenuItem(value: DeviceType.light, child: Text('Lampu / Penerangan')),
                      DropdownMenuItem(value: DeviceType.slidingDoor, child: Text('Pintu Geser')),
                      DropdownMenuItem(value: DeviceType.curtain, child: Text('Gorden Cerdas')),
                      DropdownMenuItem(value: DeviceType.waterPump, child: Text('Pompa Air / Irigasi')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('Nama Perangkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Lampu Teras Belakang',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NexoraTokens.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.developer_board_rounded, size: 18, color: NexoraTokens.brandCyan),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alamat PIN hardware (Relay / GPIO / PLC) dikonfigurasi terpusat via Website Portal cPanel.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: NexoraTokens.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Topic MQTT ID (Unik)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: idCtrl,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Misal: lampu_teras_belakang',
                      prefixText: 'nexora/',
                      suffixText: '/set',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama perangkat wajib diisi!')),
                          );
                          return;
                        }
                        final cleanId = idCtrl.text.trim().isNotEmpty
                            ? idCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')
                            : 'dev_${DateTime.now().millisecondsSinceEpoch}';

                        DeviceManagerService().addDevice(
                          customId: cleanId,
                          name: nameCtrl.text.trim(),
                          type: selectedType,
                          hardwarePin: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : 'GPIO 2',
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Perangkat "${nameCtrl.text.trim()}" berhasil ditambahkan!'),
                            backgroundColor: NexoraTokens.statusGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: NexoraTokens.brandCyan,
                        onPrimary: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Simpan Perangkat', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODAL EDIT PERANGKAT
  // ==========================================
  void _showEditDeviceSheet(BuildContext context, CustomDeviceItem dev) {
    final nameCtrl = TextEditingController(text: dev.name);
    final pinCtrl = TextEditingController(text: dev.hardwarePin);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit Perangkat: ${dev.name}',
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NexoraTokens.ink,
                ),
              ),
              const SizedBox(height: 18),

              const Text('Nama Perangkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Alamat PIN Hardware (Terkunci oleh Website)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NexoraTokens.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: NexoraTokens.inkMuted),
                    const SizedBox(width: 8),
                    Text(
                      dev.hardwarePin,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Terkunci Cloud',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    DeviceManagerService().updateDevice(
                      dev.id,
                      newName: nameCtrl.text.trim(),
                      newPin: pinCtrl.text.trim(),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Perubahan perangkat berhasil disimpan!'),
                        backgroundColor: NexoraTokens.statusGreen,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    primary: NexoraTokens.brandCyan,
                    onPrimary: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // KONFIRMASI HAPUS PERANGKAT
  // ==========================================
  void _confirmDeleteDevice(BuildContext context, CustomDeviceItem dev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Hapus "${dev.name}"?'),
        content: Text(
          'Perangkat ini akan dihapus dari sistem Nexora & MQTT topic nexora/${dev.id}.',
          style: const TextStyle(fontSize: 13, color: NexoraTokens.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              DeviceManagerService().removeDevice(dev.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Perangkat "${dev.name}" berhasil dihapus.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
