import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/language_service.dart';

enum QuickAddCategory {
  light,
  gate,
  cctv,
  waterPump,
  curtain,
  slidingDoor,
}

/// Sheet Cepat Tambah Perangkat Pintar (Lampu, Gerbang, CCTV, Pompa, Gorden, Pintu Geser)
class QuickAddDeviceSheet extends StatefulWidget {
  const QuickAddDeviceSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QuickAddDeviceSheet(),
    );
  }

  @override
  State<QuickAddDeviceSheet> createState() => _QuickAddDeviceSheetState();
}

class _QuickAddDeviceSheetState extends State<QuickAddDeviceSheet> {
  QuickAddCategory _selectedCategory = QuickAddCategory.light;

  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late TextEditingController _cctvUrlController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _pinController = TextEditingController();
    _cctvUrlController = TextEditingController();
    _locationController = TextEditingController();
    _applyDefaultsForCategory(_selectedCategory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _cctvUrlController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applyDefaultsForCategory(QuickAddCategory category) {
    final devMgr = DeviceManagerService();
    final cctvMgr = CctvManagerService();
    final lang = LanguageService();

    switch (category) {
      case QuickAddCategory.light:
        final count = devMgr.lights.length + 1;
        _nameController.text = lang.isEnglish ? 'Smart Light $count' : 'Lampu Ruang $count';
        _pinController.text = 'GPIO ${12 + count} (%QX0.${2 + count})';
        break;
      case QuickAddCategory.gate:
        final count = devMgr.gates.length + 1;
        _nameController.text = lang.isEnglish ? 'Smart Gate $count' : 'Pagar Samping $count';
        _pinController.text = 'GPIO ${14 + count} (%QX0.$count)';
        break;
      case QuickAddCategory.cctv:
        final count = cctvMgr.allCameras.length + 1;
        _nameController.text = lang.isEnglish ? 'CCTV Camera $count' : 'CCTV Garasi $count';
        _locationController.text = lang.isEnglish ? 'Area $count' : 'Area Belakang $count';
        _cctvUrlController.text = 'rtsp://rtsp.rtsplink.com/live/traffic?token=999dde9e10cf680f477d8f9e3b36d2d8cd0579c270c67699fbec44bf03d52ace';
        break;
      case QuickAddCategory.waterPump:
        final count = devMgr.waterPumps.length + 1;
        _nameController.text = lang.isEnglish ? 'Water Pump $count' : 'Pompa Air $count';
        _pinController.text = 'GPIO ${19 + count} (%QX0.4)';
        break;
      case QuickAddCategory.curtain:
        final count = devMgr.curtains.length + 1;
        _nameController.text = lang.isEnglish ? 'Smart Curtain $count' : 'Gorden Kamar $count';
        _pinController.text = 'GPIO ${18 + count} (%QX0.2)';
        break;
      case QuickAddCategory.slidingDoor:
        final count = devMgr.slidingDoors.length + 1;
        _nameController.text = lang.isEnglish ? 'Sliding Door $count' : 'Pintu Geser $count';
        _pinController.text = 'GPIO ${5 + count} (%QX0.1)';
        break;
    }
  }

  void _onCategorySelected(QuickAddCategory category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      _applyDefaultsForCategory(category);
    });
  }

  void _saveDevice() {
    HapticFeedback.mediumImpact();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Nama perangkat tidak boleh kosong'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategory == QuickAddCategory.cctv) {
      final loc = _locationController.text.trim();
      CctvManagerService().addCamera(
        name: name,
        location: loc.isNotEmpty ? loc : 'Area Rumah',
        rtspUrl: '',
      );
    } else {
      DeviceType devType;
      switch (_selectedCategory) {
        case QuickAddCategory.light:
          devType = DeviceType.light;
          break;
        case QuickAddCategory.gate:
          devType = DeviceType.gate;
          break;
        case QuickAddCategory.waterPump:
          devType = DeviceType.waterPump;
          break;
        case QuickAddCategory.curtain:
          devType = DeviceType.curtain;
          break;
        case QuickAddCategory.slidingDoor:
          devType = DeviceType.slidingDoor;
          break;
        case QuickAddCategory.cctv:
          devType = DeviceType.light;
          break;
      }

      final autoPin = DeviceManagerService().getNextAvailablePin(devType);

      DeviceManagerService().addDevice(
        name: name,
        type: devType,
        hardwarePin: autoPin,
      );
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: NexoraTokens.brandCyan, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✅ Perangkat "$name" berhasil ditambahkan ke Beranda!',
                style: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NexoraTokens.brandCyanSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded, color: NexoraTokens.brandCyan, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isEnglish ? 'Quick Add Device' : 'Tambah Perangkat Cepat',
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: NexoraTokens.ink,
                        ),
                      ),
                      Text(
                        lang.isEnglish ? 'Directly connects to Dashboard & ESP32/PLC' : 'Langsung aktif di Beranda & dapat dites via IoT',
                        style: const TextStyle(fontSize: 12, color: NexoraTokens.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Category Chips Selector
            Text(
              lang.isEnglish ? 'DEVICE TYPE' : 'TIPE PERANGKAT',
              style: NexoraTokens.sectionLabel.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCategoryChip(
                    category: QuickAddCategory.light,
                    label: lang.isEnglish ? 'Light' : 'Lampu Pintar',
                    icon: Icons.lightbulb_outline_rounded,
                    color: const Color(0xFFEAB308),
                  ),
                  _buildCategoryChip(
                    category: QuickAddCategory.gate,
                    label: lang.isEnglish ? 'Gate' : 'Gerbang / Pagar',
                    icon: Icons.sensor_door_outlined,
                    color: NexoraTokens.brandCyan,
                  ),
                  _buildCategoryChip(
                    category: QuickAddCategory.cctv,
                    label: 'CCTV Live',
                    icon: Icons.videocam_outlined,
                    color: const Color(0xFF6366F1),
                  ),
                  _buildCategoryChip(
                    category: QuickAddCategory.waterPump,
                    label: lang.isEnglish ? 'Water Pump' : 'Pompa Air',
                    icon: Icons.opacity_outlined,
                    color: const Color(0xFF0EA5E9),
                  ),
                  _buildCategoryChip(
                    category: QuickAddCategory.curtain,
                    label: lang.isEnglish ? 'Curtain' : 'Gorden',
                    icon: Icons.view_sidebar_outlined,
                    color: const Color(0xFFEC4899),
                  ),
                  _buildCategoryChip(
                    category: QuickAddCategory.slidingDoor,
                    label: lang.isEnglish ? 'Sliding Door' : 'Pintu Geser',
                    icon: Icons.meeting_room_outlined,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Form Fields
            Text(
              lang.isEnglish ? 'Device Name' : 'Nama Perangkat',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.ink),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: lang.isEnglish ? 'e.g. Living Room Light' : 'misal: Lampu Ruang Tamu',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NexoraTokens.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NexoraTokens.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NexoraTokens.brandCyan, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_selectedCategory == QuickAddCategory.cctv) ...[
              Text(
                lang.isEnglish ? 'Camera Location' : 'Lokasi / Area Kamera',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.ink),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'misal: Area Parkir / Garasi Belakang',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NexoraTokens.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NexoraTokens.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NexoraTokens.brandCyan, width: 1.5),
                  ),
                ),
              ),
            ],

            // Info Card: PIN & IP Hardware diatur oleh Super Admin via Web
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 18, color: NexoraTokens.brandCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.isEnglish
                          ? 'Hardware PINs & Network streams are centrally managed by Cloud Super Admin.'
                          : 'PIN Hardware & Alamat IP dikontrol terpusat oleh Super Admin melalui Website.',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveDevice,
                style: ElevatedButton.styleFrom(
                  primary: NexoraTokens.brandCyan,
                  onPrimary: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      lang.isEnglish ? 'Add to Dashboard' : 'Simpan & Tampilkan di Beranda',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required QuickAddCategory category,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onCategorySelected(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : NexoraTokens.cardBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : NexoraTokens.inkSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : NexoraTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
