import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/cctv_manager_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'package:nexora/services/language_service.dart';
import 'package:nexora/features/home/widgets/cctv_stream_sheet.dart';

class CctvManagementScreen extends StatefulWidget {
  const CctvManagementScreen({Key? key}) : super(key: key);

  @override
  State<CctvManagementScreen> createState() => _CctvManagementScreenState();
}

class _CctvManagementScreenState extends State<CctvManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
          lang.isIndonesian ? 'Kamera Pengawas (CCTV)' : 'Surveillance Cameras (CCTV)',
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
              onPressed: () => _showAddCctvSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(lang.isIndonesian ? 'Tambah' : 'Add'),
              style: ElevatedButton.styleFrom(
                primary: NexoraTokens.brandCyan,
                onPrimary: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: NexoraTokens.fontFamilySans,
                  fontSize: 12.5,
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
            // BILAH PENCARIAN & INFO COUNTER
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
                            ? 'Cari nama kamera, lokasi, atau IP...'
                            : 'Search camera name, location, or IP...',
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
                  const SizedBox(height: 8),
                  StreamBuilder<List<CctvCameraItem>>(
                    stream: CctvManagerService().camerasStream,
                    initialData: CctvManagerService().allCameras,
                    builder: (context, snapshot) {
                      final allCams = CctvManagerService().allCameras;
                      final filtered = _getFilteredCameras(allCams);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? (lang.isIndonesian
                                      ? 'Total: ${allCams.length} Kamera Terdaftar'
                                      : 'Total: ${allCams.length} Registered Cameras')
                                  : (lang.isIndonesian
                                      ? 'Ditemukan: ${filtered.length} dari ${allCams.length} kamera'
                                      : 'Found: ${filtered.length} of ${allCams.length} cameras'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: NexoraTokens.inkSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'RTSP / ONVIF',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ==========================================
            // DAFTAR KAMERA CCTV (HASIL PENCARIAN)
            // ==========================================
            Expanded(
              child: StreamBuilder<List<CctvCameraItem>>(
                stream: CctvManagerService().camerasStream,
                initialData: CctvManagerService().allCameras,
                builder: (context, snapshot) {
                  final allCams = CctvManagerService().allCameras;
                  final filtered = _getFilteredCameras(allCams);

                  if (allCams.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.videocam_off_rounded,
                      title: lang.isIndonesian ? 'Belum Ada Kamera' : 'No Cameras Yet',
                      subtitle: lang.isIndonesian
                          ? 'Tambahkan kamera pengawas pertama Anda untuk memantau gerbang atau ruangan secara langsung.'
                          : 'Add your first surveillance camera to monitor gates or rooms live.',
                      actionLabel: lang.isIndonesian ? '+ Tambah Kamera CCTV' : '+ Add CCTV Camera',
                      onAction: () => _showAddCctvSheet(context),
                    );
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: lang.isIndonesian ? 'Kamera Tidak Ditemukan' : 'No Cameras Found',
                      subtitle: lang.isIndonesian
                          ? 'Tidak ada kamera yang cocok dengan kata kunci "$_searchQuery".'
                          : 'No cameras match the query "$_searchQuery".',
                      actionLabel: lang.isIndonesian ? 'Reset Pencarian' : 'Reset Search',
                      onAction: () => _searchCtrl.clear(),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cam = filtered[index];
                      return _buildCctvCard(context, cam, lang);
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

  List<CctvCameraItem> _getFilteredCameras(List<CctvCameraItem> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((cam) {
      final nameMatches = cam.name.toLowerCase().contains(_searchQuery);
      final locationMatches = cam.location.toLowerCase().contains(_searchQuery);
      final rtspMatches = cam.rtspUrl.toLowerCase().contains(_searchQuery);
      final hostMatches = cam.onvifHost.toLowerCase().contains(_searchQuery);
      final gateMatches = (cam.boundGateId ?? '').toLowerCase().contains(_searchQuery);
      return nameMatches || locationMatches || rtspMatches || hostMatches || gateMatches;
    }).toList();
  }

  Widget _buildCctvCard(BuildContext context, CctvCameraItem cam, LanguageService lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexoraTokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  size: 22,
                  color: NexoraTokens.brandCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cam.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: NexoraTokens.fontFamilySans,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: NexoraTokens.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NexoraTokens.statusGreenSubtle,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: NexoraTokens.statusGreen.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: NexoraTokens.statusGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${cam.location} • ${cam.resolution}',
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 11.5,
                        color: NexoraTokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Tombol Pantau Stream
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  CctvStreamSheet.show(
                    context,
                    camera: cam,
                    gateId: cam.boundGateId,
                    gateName: cam.name,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: NexoraTokens.brandCyan,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: NexoraTokens.brandCyan.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        lang.isIndonesian ? 'Pantau' : 'View',
                        style: const TextStyle(
                          fontFamily: NexoraTokens.fontFamilySans,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Tombol Edit
              InkWell(
                onTap: () => _showEditCctvSheet(context, cam),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined, size: 18, color: NexoraTokens.inkSecondary),
                ),
              ),
              // Tombol Hapus
              InkWell(
                onTap: () => _confirmDeleteCctv(context, cam),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 14, color: NexoraTokens.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cam.rtspUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                if (cam.boundGateId != null && cam.boundGateId!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pagar: ${cam.boundGateId}',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.ink,
                      ),
                    ),
                  ),
                ],
              ],
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

  // ==========================================
  // MODAL TAMBAH CCTV
  // ==========================================
  void _showAddCctvSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Pagar Depan');
    final rtspCtrl = TextEditingController(text: 'rtsp://admin:123456@192.168.1.105:554/live/ch0');
    final onvifHostCtrl = TextEditingController(text: '192.168.1.105');
    final onvifPortCtrl = TextEditingController(text: '80');
    String? selectedGateId = 'pagar';

    final gateDevices = DeviceManagerService().allDevices.where((d) => d.type == DeviceType.gate).toList();

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
                    'Tambah Kamera CCTV (RTSP / ONVIF)',
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hubungkan feed kamera pengawas IP Cam ke sistem Nexora.',
                    style: TextStyle(fontSize: 12, color: NexoraTokens.inkSecondary),
                  ),
                  const SizedBox(height: 18),

                  const Text('Nama Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: CCTV Gerbang Utama',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Lokasi / Area Pemasangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Misal: Gerbang Depan / Halaman Samping',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Tautkan ke Gerbang (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: gateDevices.any((d) => d.id == selectedGateId) ? selectedGateId : (gateDevices.isNotEmpty ? gateDevices.first.id : null),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Tidak ditautkan', overflow: TextOverflow.ellipsis)),
                      ...gateDevices.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text('${d.name} (${d.id})', overflow: TextOverflow.ellipsis))).toList(),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedGateId = val;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NexoraTokens.cardBorder),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 18, color: NexoraTokens.brandCyan),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alamat IP CCTV & RTSP Stream dikonfigurasi terpusat oleh Super Admin via Website.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: NexoraTokens.inkSecondary,
                            ),
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
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama kamera wajib diisi!')),
                          );
                          return;
                        }
                        CctvManagerService().addCamera(
                          name: nameCtrl.text.trim(),
                          location: locationCtrl.text.trim(),
                          rtspUrl: rtspCtrl.text.trim(),
                          onvifHost: onvifHostCtrl.text.trim(),
                          onvifPort: int.tryParse(onvifPortCtrl.text.trim()) ?? 80,
                          boundGateId: selectedGateId,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Kamera "${nameCtrl.text.trim()}" berhasil ditambahkan!'),
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
                      child: const Text('Simpan Kamera CCTV', style: TextStyle(fontWeight: FontWeight.w700)),
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
  // MODAL EDIT CCTV
  // ==========================================
  void _showEditCctvSheet(BuildContext context, CctvCameraItem cam) {
    final nameCtrl = TextEditingController(text: cam.name);
    final locationCtrl = TextEditingController(text: cam.location);
    final rtspCtrl = TextEditingController(text: cam.rtspUrl);
    final onvifHostCtrl = TextEditingController(text: cam.onvifHost);
    final onvifPortCtrl = TextEditingController(text: cam.onvifPort.toString());
    String? selectedGateId = cam.boundGateId;

    final gateDevices = DeviceManagerService().allDevices.where((d) => d.type == DeviceType.gate).toList();

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
                  Text(
                    'Edit Kamera: ${cam.name}',
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text('Nama Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
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

                  const Text('Lokasi / Area Pemasangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NexoraTokens.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NexoraTokens.cardBorder),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 18, color: NexoraTokens.brandCyan),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alamat IP CCTV & RTSP Stream dikonfigurasi terpusat oleh Super Admin via Website.',
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

                  const Text('Tautkan ke Gerbang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NexoraTokens.inkSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: gateDevices.any((d) => d.id == selectedGateId) ? selectedGateId : null,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Tidak ditautkan', overflow: TextOverflow.ellipsis)),
                      ...gateDevices.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text('${d.name} (${d.id})', overflow: TextOverflow.ellipsis))).toList(),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedGateId = val;
                      });
                    },
                    decoration: InputDecoration(
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
                        CctvManagerService().updateCamera(
                          cam.id,
                          name: nameCtrl.text.trim(),
                          location: locationCtrl.text.trim(),
                          rtspUrl: rtspCtrl.text.trim(),
                          onvifHost: onvifHostCtrl.text.trim(),
                          onvifPort: int.tryParse(onvifPortCtrl.text.trim()) ?? 80,
                          boundGateId: selectedGateId,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Perubahan kamera berhasil disimpan!'),
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
          );
        },
      ),
    );
  }

  // ==========================================
  // KONFIRMASI HAPUS CCTV
  // ==========================================
  void _confirmDeleteCctv(BuildContext context, CctvCameraItem cam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Hapus Kamera "${cam.name}"?'),
        content: const Text(
          'Kamera ini akan dihapus dari daftar pemantauan gerbang & halaman.',
          style: TextStyle(fontSize: 13, color: NexoraTokens.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              CctvManagerService().removeCamera(cam.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kamera "${cam.name}" telah dihapus.'),
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
