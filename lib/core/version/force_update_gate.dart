import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'version_check_provider.dart';
import '../../core/theme/app_radius.dart';

/// Wrap halaman Home/Splash/dll dengan ini untuk auto-block kalau ada
/// force update atau maintenance mode.
///
/// Usage:
/// ```dart
/// ForceUpdateGate(child: HomeScreen())
/// ```
///
/// - [VersionStatus.forceUpdate] → full-screen blocking modal "Update Required"
/// - [VersionStatus.maintenance] → blocking "Server sedang maintenance"
/// - lainnya → tampilkan [child] apa adanya
class ForceUpdateGate extends ConsumerWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(versionCheckProvider);

    return versionAsync.when(
      // Saat cek, langsung show child (jangan blocking loading)
      loading: () => child,
      error: (_, _) => child,
      data: (result) {
        switch (result.status) {
          case VersionStatus.forceUpdate:
            return _BlockingScreen(
              icon: Icons.system_update_alt_rounded,
              title: 'Update Diperlukan',
              message:
                  'Versi aplikasi kamu (${result.currentVersion}) sudah '
                  'tidak didukung. Silakan update ke versi terbaru '
                  '(${result.latestVersion ?? result.minVersion}).',
              actionLabel: 'Update Sekarang',
              actionUrl: result.updateUrl,
            );
          case VersionStatus.maintenance:
            return _BlockingScreen(
              icon: Icons.build_circle_outlined,
              title: 'Sedang Maintenance',
              message:
                  'Server VibeNime sedang dalam pemeliharaan. '
                  'Mohon coba lagi dalam beberapa menit.',
              actionLabel: 'Coba Lagi',
              onAction: () => ref.invalidate(versionCheckProvider),
            );
          case VersionStatus.optionalUpdate:
          case VersionStatus.upToDate:
          case VersionStatus.unknown:
            return child;
        }
      },
    );
  }
}

class _BlockingScreen extends StatelessWidget {
  const _BlockingScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.actionUrl,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final String? actionUrl;
  final VoidCallback? onAction;

  Future<void> _onPressed() async {
    if (onAction != null) {
      onAction!();
      return;
    }
    if (actionUrl != null && actionUrl!.isNotEmpty) {
      final uri = Uri.tryParse(actionUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tidak ada AppBar / back button — user harus update / retry
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 52, color: AppColors.primary),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: AppColors.textMuted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
