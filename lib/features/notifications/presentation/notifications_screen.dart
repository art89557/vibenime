import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../data/notification_prefs.dart';
import '../../../core/theme/app_radius.dart';

/// Layar pengaturan notifikasi — 5 toggle disimpan di Hive box `settings`.
///
/// FCM belum di-integrate (Phase D di plan production-readiness). Saat
/// FCM aktif, toggle ini akan otomatis trigger subscribe/unsubscribe
/// topic Firebase via NotificationPrefsNotifier listener.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Status header — total aktif
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${prefs.activeCount} aktif dari 5',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kontrol notifikasi yang kamu terima',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Toggle list
          _SectionLabel('KONTEN'),
          _SwitchTile(
            icon: Icons.movie_filter_outlined,
            title: 'Episode baru',
            subtitle: 'Notif saat anime favorit punya episode baru',
            value: prefs.newEpisode,
            onChanged: (v) {
              Haptic.selection();
              notifier.setNewEpisode(v);
            },
          ),

          const SizedBox(height: 20),
          _SectionLabel('SOSIAL'),
          _SwitchTile(
            icon: Icons.group_add_outlined,
            title: 'Undangan Watch Party',
            subtitle: 'Saat teman invite kamu ke party',
            value: prefs.watchPartyInvite,
            onChanged: (v) {
              Haptic.selection();
              notifier.setWatchPartyInvite(v);
            },
          ),
          _SwitchTile(
            icon: Icons.alternate_email_rounded,
            title: 'Mention di chat',
            subtitle: 'Saat seseorang mention kamu di party chat',
            value: prefs.chatMention,
            onChanged: (v) {
              Haptic.selection();
              notifier.setChatMention(v);
            },
          ),

          const SizedBox(height: 20),
          _SectionLabel('LAINNYA'),
          _SwitchTile(
            icon: Icons.email_outlined,
            title: 'Weekly digest (email)',
            subtitle: 'Recap mingguan aktivitas tontonmu',
            value: prefs.weeklyDigest,
            onChanged: (v) {
              Haptic.selection();
              notifier.setWeeklyDigest(v);
            },
          ),
          _SwitchTile(
            icon: Icons.system_update_outlined,
            title: 'Update aplikasi',
            subtitle: 'Notif saat versi baru tersedia',
            value: prefs.appUpdate,
            onChanged: (v) {
              Haptic.selection();
              notifier.setAppUpdate(v);
            },
          ),

          const SizedBox(height: 24),

          // FCM info footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Push notification (FCM) belum aktif. Toggle di sini '
                      'akan otomatis tersinkron saat fitur push diaktifkan.',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 20, 8),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}
