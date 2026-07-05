import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';

/// Empty state dengan Lottie illustration + judul + subtitle.
///
/// Replace ikon static dengan animasi yang playful tapi tidak distraksi.
/// Asset Lottie JSON disimpan di `assets/lottie/`.
///
/// Usage:
/// ```dart
/// LottieEmptyState(
///   assetPath: 'assets/lottie/empty_library.json',
///   title: 'Pustaka kosong',
///   subtitle: 'Tap heart di Detail anime untuk mulai',
///   actionLabel: 'Jelajah',
///   onAction: () => context.go(AppRoutes.home),
/// )
/// ```
///
/// **Fallback**: kalau Lottie file tidak ditemukan / corrupt, widget
/// gracefully fallback ke icon (passed via [fallbackIcon]) supaya UI
/// tidak crash saat development sebelum asset ready.
class LottieEmptyState extends StatelessWidget {
  const LottieEmptyState({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitle,
    this.fallbackIcon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.size = 180,
  });

  final String assetPath;
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Lottie.asset(
                assetPath,
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, _) {
                  // Fallback kalau asset belum ada — tetap kasih visual
                  return Icon(
                    fallbackIcon,
                    size: size * 0.4,
                    color: AppColors.textMuted(context),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.explore_outlined, size: 16),
                label: Text(actionLabel!),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAdaptive(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
