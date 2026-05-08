import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    required this.message,
    required this.onRetry,
    this.compact = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  /// Compact mode: dipakai di dalam section/baris (tidak full screen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
        : const EdgeInsets.all(32);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: compact ? 36 : 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Terjadi kesalahan',
            style: GoogleFonts.poppins(
              fontSize: compact ? 14 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
