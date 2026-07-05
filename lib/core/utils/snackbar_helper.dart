import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'haptic_helper.dart';
import '../../core/theme/app_radius.dart';

/// Helper untuk show consistent snackbar di seluruh app.
///
/// Style sesuai prinsip **Golden Rule 3 (Informative Feedback)**:
/// - Success: cyan background + check icon
/// - Error: red background + error icon
/// - Info dengan undo: cyan border + tombol "Urungkan"
///
/// Auto-trigger haptic feedback bersamaan dengan visual feedback.
///
/// ```dart
/// AppSnackbar.success(context, 'Tersimpan');
/// AppSnackbar.error(context, 'Gagal koneksi');
/// AppSnackbar.undoable(
///   context,
///   message: 'Dihapus',
///   onUndo: () => repo.restore(item),
/// );
/// ```
class AppSnackbar {
  AppSnackbar._();

  /// Show success snackbar — cyan background + check icon.
  /// Trigger haptic medium impact.
  static void success(BuildContext context, String message) {
    Haptic.medium();
    _show(
      context,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.white,
      backgroundColor: AppColors.primary.withValues(alpha: 0.95),
      textColor: AppColors.onAccent,
      message: message,
    );
  }

  /// Show error snackbar — red background + error icon.
  /// Trigger haptic heavy impact.
  static void error(BuildContext context, String message) {
    Haptic.heavy();
    _show(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: Colors.white,
      backgroundColor: AppColors.error.withValues(alpha: 0.95),
      textColor: Colors.white,
      message: message,
    );
  }

  /// Show informational snackbar — neutral surface.
  static void info(BuildContext context, String message) {
    Haptic.light();
    _show(
      context,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh(context),
      textColor: AppColors.textPrimary(context),
      message: message,
    );
  }

  /// Show undoable snackbar — info dengan tombol "Urungkan".
  ///
  /// Sesuai **Golden Rule 6 (Easy Reversal)** — user dapat membatalkan
  /// action destructive dalam window 5 detik tanpa harus re-create.
  ///
  /// ```dart
  /// AppSnackbar.undoable(
  ///   context,
  ///   message: 'Video dihapus',
  ///   onUndo: () => repo.insert(deletedSource),
  /// );
  /// ```
  static void undoable(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String undoLabel = 'Urungkan',
    Duration duration = const Duration(seconds: 5),
  }) {
    Haptic.light();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh(context),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: AppColors.borderColor(context)),
        ),
        content: Row(
          children: [
            const Icon(Icons.undo_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: undoLabel,
          textColor: AppColors.primary,
          onPressed: () {
            Haptic.medium();
            onUndo();
          },
        ),
      ),
    );
  }

  static void _show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color textColor,
    required String message,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
