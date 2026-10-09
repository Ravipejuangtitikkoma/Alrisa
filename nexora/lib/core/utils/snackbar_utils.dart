import 'package:flutter/material.dart';
import 'package:nexora/core/design_tokens.dart';

/// Menampilkan notifikasi peringatan saat pengguna mengontrol perangkat ketika offline.
/// Sesuai permintaan: animasi tetap berjalan di layar (demo interaktif),
/// tetapi memberikan notifikasi bahwa koneksi ke server bermasalah dan sistem fisik tidak berjalan.
void showOfflineWarning(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: const Color(0xFF1E232A),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF5A524), width: 1.2),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A524).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFF5A524),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koneksi ke Server Bermasalah',
                  style: TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Silakan periksa jaringan Anda. Sistem $featureName ini tidak akan berjalan di perangkat fisik.',
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFBAC2DE),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}
