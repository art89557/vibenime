import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/i18n/l10n_extension.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/theme/app_colors.dart';

/// Banner tipis "tidak ada koneksi" — tampil otomatis saat offline,
/// menghilang saat online. Pasang di atas konten utama (mis. body
/// `MainScaffold`) supaya muncul di semua tab.
///
/// Pakai `SafeArea(bottom:false)` supaya tidak ketiban status bar saat
/// banner aktif; saat online return [SizedBox.shrink] (nol tinggi).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // loading/error → anggap online (jangan tampilkan banner palsu).
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();

    return Material(
      color: AppColors.warning,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 15,
                color: Colors.black87,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.errorNetwork,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
