import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/preset_manager_service.dart';
import 'package:nexora/services/device_manager_service.dart';

class PresetsView extends StatefulWidget {
  const PresetsView({Key? key}) : super(key: key);

  @override
  State<PresetsView> createState() => _PresetsViewState();
}

class _PresetsViewState extends State<PresetsView> {
  // Dialog Edit Preset yang sudah ada
  void _showEditPresetSheet(PresetSceneItem preset) {
    final nameCtrl = TextEditingController(text: preset.name);
    final descCtrl = TextEditingController(text: preset.description);
    Color selectedColor = preset.accentColor;

    // Ambil daftar perangkat yang tersedia di rumah
    final devices = DeviceManagerService().allDevices;

    // Map status target: deviceId -> bool (true = ON, false = OFF)
    final Map<String, bool> selectedStates = {};
    for (var d in devices) {
      // Cek apakah perangkat ini sudah ada targetnya di preset
      final existingAction = preset.actions.firstWhere(
        (a) => a.deviceId == d.id,
        orElse: () => PresetDeviceAction(deviceId: d.id, deviceName: d.name, targetState: false),
      );
      selectedStates[d.id] = existingAction.targetState;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, color: selectedColor, size: 24),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Edit Skenario Preset',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: NexoraTokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  Text(
                    'Ubah konfigurasi perangkat untuk skenario "${preset.name}".',
                    style: const TextStyle(fontSize: 12.5, color: NexoraTokens.inkSecondary),
                  ),

                  const SizedBox(height: 18),

                  // Input Nama Preset
                  const Text('Nama Skenario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Input Deskripsi
                  const Text('Keterangan Singkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Status Perangkat Menggunakan TOGGLE BUTTON (Switch Modern)
                  const Text(
                    'Atur Status Perangkat Saat Preset Aktif:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final dev = devices[idx];
                        final targetOn = selectedStates[dev.id] ?? false;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dev.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      targetOn ? 'Otomatis: MENYALA / BUKA' : 'Otomatis: MATI / KUNCI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: targetOn ? NexoraTokens.statusGreen : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle Button Switch
                              Switch.adaptive(
                                value: targetOn,
                                activeColor: selectedColor,
                                onChanged: (val) {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => selectedStates[dev.id] = val);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol Simpan Perubahan
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;

                        // Susun daftar aksi yang diupdate
                        final actions = <PresetDeviceAction>[];
                        for (var dev in devices) {
                          actions.add(
                            PresetDeviceAction(
                              deviceId: dev.id,
                              deviceName: dev.name,
                              targetState: selectedStates[dev.id] ?? false,
                            ),
                          );
                        }

                        preset.name = nameCtrl.text.trim();
                        preset.description = descCtrl.text.trim();
                        preset.actions = actions;

                        PresetManagerService().updatePreset(preset);

                        Navigator.pop(sheetContext);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: selectedColor,
                            content: Text('✅ Skenario "${preset.name}" berhasil diperbarui!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        primary: selectedColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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

  // Dialog Tambah Preset Baru
  void _showAddPresetSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Color selectedColor = const Color(0xFF0284C7);

    final devices = DeviceManagerService().allDevices;
    final Map<String, bool> selectedStates = {};
    for (var d in devices) {
      selectedStates[d.id] = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.add_task_rounded, color: NexoraTokens.brandCyan, size: 24),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Buat Preset Baru',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NexoraTokens.fontFamilySans,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: NexoraTokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const Text(
                    'Atur gabungan aksi saklar & gerbang dalam satu sentuhan.',
                    style: TextStyle(fontSize: 12.5, color: NexoraTokens.inkSecondary),
                  ),

                  const SizedBox(height: 18),

                  // Input Nama Preset
                  const Text('Nama Skenario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'misal: Mode Santai Sore, Mode Party',
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Input Deskripsi
                  const Text('Keterangan Singkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      hintText: 'misal: Matikan lampu teras, kunci pagar',
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Pilihan Warna Aksen
                  const Text('Pilih Tema Warna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildColorChoice(const Color(0xFF8B5CF6), selectedColor, () => setSheetState(() => selectedColor = const Color(0xFF8B5CF6))),
                      _buildColorChoice(const Color(0xFF0284C7), selectedColor, () => setSheetState(() => selectedColor = const Color(0xFF0284C7))),
                      _buildColorChoice(const Color(0xFF10B981), selectedColor, () => setSheetState(() => selectedColor = const Color(0xFF10B981))),
                      _buildColorChoice(const Color(0xFFF59E0B), selectedColor, () => setSheetState(() => selectedColor = const Color(0xFFF59E0B))),
                      _buildColorChoice(const Color(0xFFEC4899), selectedColor, () => setSheetState(() => selectedColor = const Color(0xFFEC4899))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Status Perangkat Menggunakan TOGGLE BUTTON (Switch Modern)
                  const Text(
                    'Atur Status Perangkat Saat Preset Aktif:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final dev = devices[idx];
                        final targetOn = selectedStates[dev.id] ?? false;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dev.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      targetOn ? 'Otomatis: MENYALA / BUKA' : 'Otomatis: MATI / KUNCI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: targetOn ? NexoraTokens.statusGreen : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle Button Switch
                              Switch.adaptive(
                                value: targetOn,
                                activeColor: selectedColor,
                                onChanged: (val) {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => selectedStates[dev.id] = val);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;

                        final actions = <PresetDeviceAction>[];
                        for (var dev in devices) {
                          actions.add(
                            PresetDeviceAction(
                              deviceId: dev.id,
                              deviceName: dev.name,
                              targetState: selectedStates[dev.id] ?? false,
                            ),
                          );
                        }

                        PresetManagerService().addCustomPreset(
                          name: nameCtrl.text,
                          description: descCtrl.text.isEmpty ? 'Skenario kustom rumah' : descCtrl.text,
                          icon: Icons.auto_awesome_rounded,
                          color: selectedColor,
                          actions: actions,
                        );

                        Navigator.pop(sheetContext);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: NexoraTokens.statusGreen,
                            content: Text('✅ Preset baru berhasil disimpan!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Simpan Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        primary: selectedColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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

  Widget _buildColorChoice(Color color, Color selected, VoidCallback onTap) {
    final isSelected = color.value == selected.value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.white,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresetSceneItem>>(
      stream: PresetManagerService().presetsStream,
      initialData: PresetManagerService().allPresets,
      builder: (context, snapshot) {
        final presets = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Skenario & Preset',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: NexoraTokens.ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Aktifkan skenario rumah dalam satu sentuhan saklar.',
                        style: TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 12.5,
                          color: NexoraTokens.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showAddPresetSheet,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Tambah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    primary: NexoraTokens.brandCyan,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // List Preset Cards - Desain Bersih & Elegan (List perangkat dihilangkan, diganti Switch Toggle)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final preset = presets[index];

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: preset.isActive ? preset.accentColor : NexoraTokens.cardBorder,
                      width: preset.isActive ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: preset.accentColor.withOpacity(preset.isActive ? 0.12 : 0.04),
                        blurRadius: preset.isActive ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Ikon Skenario
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: preset.accentColor.withOpacity(preset.isActive ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          preset.icon,
                          color: preset.accentColor,
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Nama, Deskripsi, dan Jumlah Perangkat
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    preset.name,
                                    style: const TextStyle(
                                      fontFamily: NexoraTokens.fontFamilySans,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: NexoraTokens.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (preset.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: preset.accentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'AKTIF',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: preset.accentColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.description,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: NexoraTokens.inkSecondary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${preset.actions.length} perangkat dikontrol',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: preset.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Tombol Edit
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Edit Skenario',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showEditPresetSheet(preset);
                        },
                      ),

                      // TOGGLE BUTTON (Switch Interaktif)
                      Switch.adaptive(
                        value: preset.isActive,
                        activeColor: preset.accentColor,
                        onChanged: (turnOn) async {
                          HapticFeedback.mediumImpact();
                          await PresetManagerService().togglePreset(preset.id, turnOn);
                          if (turnOn) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: preset.accentColor,
                                content: Text('✨ "${preset.name}" aktif!'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
