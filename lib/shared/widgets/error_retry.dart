import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Widget error state yang ramah user — auto-detect tipe error + ilustrasi.
///
/// Variants berdasarkan keyword di [message]:
/// - Network / offline → icon WiFi off + pesan "Tidak ada koneksi"
/// - 429 / rate limit → icon timer + pesan "Terlalu banyak request"
/// - Other → icon error generic
///
/// **compact**: kalau true, ukuran lebih kecil — cocok di dalam section card.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    required this.message,
    required this.onRetry,
    this.compact = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  /// Determine icon + friendly title berdasarkan content message.
  _ErrorVariant get _variant {
    final lower = message.toLowerCase();
    if (lower.contains('koneksi') ||
        lower.contains('socket') ||
        lower.contains('host lookup') ||
        lower.contains('connection')) {
      return _ErrorVariant.offline;
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('429')) {
      return _ErrorVariant.rateLimit;
    }
    if (lower.contains('timeout')) {
      return _ErrorVariant.timeout;
    }
    return _ErrorVariant.generic;
  }

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
        : const EdgeInsets.all(32);
    final variant = _variant;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 88,
            height: compact ? 56 : 88,
            decoration: BoxDecoration(
              color: variant.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              variant.icon,
              size: compact ? 28 : 44,
              color: variant.color,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            variant.title,
            style: GoogleFonts.roboto(
              fontSize: compact ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            variant.message ?? message,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba lagi'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorVariant {
  const _ErrorVariant({
    required this.icon,
    required this.color,
    required this.title,
    this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? message;

  static const offline = _ErrorVariant(
    icon: Icons.wifi_off_rounded,
    color: AppColors.warning,
    title: 'Tidak ada koneksi',
    message: 'Cek WiFi atau data seluler, lalu coba lagi.',
  );

  static const rateLimit = _ErrorVariant(
    icon: Icons.timer_outlined,
    color: AppColors.warning,
    title: 'Terlalu banyak request',
    message: 'Tunggu sebentar lalu coba lagi. Biasanya 1 menit cukup.',
  );

  static const timeout = _ErrorVariant(
    icon: Icons.hourglass_disabled_rounded,
    color: AppColors.warning,
    title: 'Koneksi lambat',
    message: 'Server butuh waktu lama untuk respond. Coba lagi.',
  );

  static const generic = _ErrorVariant(
    icon: Icons.error_outline_rounded,
    color: AppColors.error,
    title: 'Terjadi kesalahan',
  );
}
