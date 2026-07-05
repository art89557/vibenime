import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/notifications/episode_notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/subtitle_language.dart';
import '../../../core/settings/subtitle_size.dart';
import '../../../core/settings/title_language.dart';
import '../../notifications/data/episode_airing_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../../downloads/data/download_repository.dart';
import '../../notifications/data/notification_prefs.dart';
import '../../../core/theme/app_radius.dart';

/// Format ringkasan storage untuk tile "Episode tersimpan" —
/// "5 file · 320 MB" atau "Kosong" kalau belum ada download.
String _formatStorageSummary(
  BuildContext context,
  AsyncValue<dynamic> asyncDownloads,
) {
  final list = asyncDownloads.valueOrNull;
  if (list == null || (list is List && list.isEmpty)) {
    return context.l10n.commonEmpty;
  }
  if (list is List) {
    final totalBytes = list.fold<int>(0, (sum, e) {
      final size = (e as dynamic).fileSizeBytes as int? ?? 0;
      return sum + size;
    });
    final sizeStr = totalBytes < 1024 * 1024
        ? '${(totalBytes / 1024).toStringAsFixed(0)} KB'
        : totalBytes < 1024 * 1024 * 1024
        ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(0)} MB'
        : '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    return '${list.length} file · $sizeStr';
  }
  return context.l10n.commonEmpty;
}

/// Pengaturan v2 — 4 sections (AKUN, PEMUTAR, SOSIAL, UNDUHAN).
/// Most settings UI only (toggle/value tidak tersimpan ke real backend).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _themeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.l10n.settingsThemeLight;
      case ThemeMode.system:
        return context.l10n.settingsFollowSystem;
      case ThemeMode.dark:
        return context.l10n.settingsThemeDark;
    }
  }

  String _localeLabel(BuildContext context, String code) {
    switch (code) {
      case 'id':
        return 'Indonesia';
      case 'en':
        return 'English';
      default:
        return context.l10n.settingsFollowSystem;
    }
  }

  Future<void> _showLocalePicker(BuildContext context, WidgetRef ref) async {
    Haptic.selection();
    final current = ref.read(localeProvider.notifier).currentCode;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.tiny),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in [
                ('id', 'Indonesia', Icons.translate_rounded),
                ('en', 'English', Icons.language_rounded),
                (
                  'system',
                  context.l10n.settingsFollowSystem,
                  Icons.settings_suggest_rounded,
                ),
              ])
                ListTile(
                  leading: Icon(entry.$3, size: 22),
                  title: Text(entry.$2),
                  trailing: current == entry.$1
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, entry.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(localeProvider.notifier).setLocale(picked);
  }

  Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
    Haptic.selection();
    final current = ref.read(appSettingsProvider).themeMode;
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _ThemePickerSheet(current: current),
    );
    if (picked == null || !mounted) return;
    await ref.read(appSettingsProvider.notifier).setThemeMode(picked);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.logoutTitle),
        content: Text(context.l10n.logoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonLogout),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await ref.read(appAuthControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appAuthControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              NavHelper.safePop(context, fallback: AppRoutes.profile),
        ),
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Text(
                context.l10n.settingsTitle,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),

            // AKUN
            _SectionLabel(context.l10n.settingsAccount.toUpperCase()),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsAccount,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: user != null
                            ? AppColors.success
                            : AppColors.textMuted(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user != null
                            ? context.l10n.settingsLoggedIn
                            : context.l10n.settingsNotLoggedIn,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: user != null
                              ? AppColors.success
                              : AppColors.textMuted(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  onTap: user == null
                      ? () => context.go(AppRoutes.login)
                      : _confirmLogout,
                ),
                _SettingTile(
                  title: context.l10n.settingsProfile,
                  trailingText: user != null ? '@${user.username}' : '@guest',
                  // `/profile` adalah shell route — pakai `go` (switch tab),
                  // bukan `push` (yang bikin duplikat instance + key collision).
                  onTap: () => context.go(AppRoutes.profile),
                ),
                _SettingTile(
                  title: context.l10n.settingsNotifications,
                  trailingText:
                      '${ref.watch(notificationPrefsProvider).activeCount} aktif',
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                _SettingTile(
                  title: context.l10n.settingsFriends,
                  trailingText: context.l10n.settingsManageSub,
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.friendsList),
                ),
                _SettingTile(
                  title: context.l10n.settingsMessages,
                  trailingText: 'Direct messages',
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.conversations),
                ),
                _SettingTile(
                  title: context.l10n.settingsActivityFeed,
                  trailingText: 'Feed',
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.activityFeed),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ADMIN (gated by user_metadata.role == 'admin')
            // User normal tidak melihat section ini sama sekali.
            if (ref.watch(appAuthControllerProvider).user?.isAdmin == true) ...[
              const _SectionLabel('ADMIN'),
              _SectionContainer(
                children: [
                  _SettingTile(
                    title: 'Dashboard',
                    trailingText: context.l10n.adminStatsGlobal,
                    trailingTextColor: AppColors.primary,
                    onTap: () => context.push(AppRoutes.adminDashboard),
                  ),
                  _SettingTile(
                    title: 'User Management',
                    trailingText: 'ban / promote',
                    trailingTextColor: AppColors.primary,
                    onTap: () => context.push(AppRoutes.adminUsers),
                  ),
                  _SettingTile(
                    title: context.l10n.adminMessageModeration,
                    trailingText: context.l10n.adminDeleteMessages,
                    trailingTextColor: AppColors.primary,
                    onTap: () => context.push(AppRoutes.adminModeration),
                  ),
                  _SettingTile(
                    title: 'Video Catalog',
                    trailingText: context.l10n.adminManageAnime,
                    trailingTextColor: AppColors.primary,
                    onTap: () => context.push(AppRoutes.adminPanel),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // TAMPILAN (theme picker persisted via Hive)
            _SectionLabel(context.l10n.settingsDisplay),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsTheme,
                  trailingText: _themeLabel(
                    context,
                    ref.watch(appSettingsProvider).themeMode,
                  ),
                  trailingTextColor: AppColors.primary,
                  onTap: () => _showThemePicker(context, ref),
                ),
                _SettingTile(
                  title: context.l10n.settingsLanguage,
                  trailingText: _localeLabel(
                    context,
                    ref.watch(localeProvider.notifier).currentCode,
                  ),
                  trailingTextColor: AppColors.primary,
                  onTap: () => _showLocalePicker(context, ref),
                ),
                _SettingTile(
                  title: context.l10n.settingsTitleLanguage,
                  trailingText:
                      ref.watch(appSettingsProvider).titleLanguage ==
                          TitleLanguage.english
                      ? 'English'
                      : 'Romaji',
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).titleLanguage;
                    final next = cur == TitleLanguage.romaji
                        ? TitleLanguage.english
                        : TitleLanguage.romaji;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setTitleLanguage(next);
                  },
                ),
                _SettingTile(
                  title: context.l10n.settingsSubtitleLanguage,
                  trailingText:
                      ref.watch(appSettingsProvider).subtitleLanguage ==
                          SubtitleLanguage.english
                      ? 'English'
                      : 'Indonesia',
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).subtitleLanguage;
                    final next = cur == SubtitleLanguage.indonesian
                        ? SubtitleLanguage.english
                        : SubtitleLanguage.indonesian;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setSubtitleLanguage(next);
                  },
                ),
                _SettingTile(
                  title: context.l10n.settingsSubtitleSize,
                  trailingText: switch (ref
                      .watch(appSettingsProvider)
                      .subtitleSize) {
                    SubtitleSize.small => 'Small',
                    SubtitleSize.medium => 'Medium',
                    SubtitleSize.large => 'Large',
                  },
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).subtitleSize;
                    final next = switch (cur) {
                      SubtitleSize.small => SubtitleSize.medium,
                      SubtitleSize.medium => SubtitleSize.large,
                      SubtitleSize.large => SubtitleSize.small,
                    };
                    ref
                        .read(appSettingsProvider.notifier)
                        .setSubtitleSize(next);
                  },
                ),
                _SettingTile(
                  title: context.l10n.settingsReduceMotion,
                  trailingText: ref.watch(appSettingsProvider).reduceAnimations
                      ? 'on'
                      : 'off',
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).reduceAnimations;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setReduceAnimations(!cur);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // PEMUTAR
            _SectionLabel(context.l10n.settingsPlayer.toUpperCase()),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsQuality,
                  trailingText: 'Auto',
                ),
                const _SettingTile(
                  title: 'Subtitle',
                  trailingText: 'Indonesia',
                ),
                _SettingTile(
                  title: context.l10n.settingsAutoNext,
                  trailingText: ref.watch(appSettingsProvider).autoNext
                      ? 'on'
                      : 'off',
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).autoNext;
                    ref.read(appSettingsProvider.notifier).setAutoNext(!cur);
                  },
                ),
                _SettingTile(
                  title: context.l10n.settingsAutoSkip,
                  trailingText: ref.watch(appSettingsProvider).autoSkip
                      ? 'on'
                      : 'off',
                  trailingTextColor: AppColors.primary,
                  onTap: () {
                    Haptic.selection();
                    final cur = ref.read(appSettingsProvider).autoSkip;
                    ref.read(appSettingsProvider.notifier).setAutoSkip(!cur);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SOSIAL
            _SectionLabel(context.l10n.settingsSocial.toUpperCase()),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsNotifEpisodes,
                  trailingText: ref.watch(appSettingsProvider).notifEpisodes
                      ? 'on'
                      : 'off',
                  trailingTextColor: AppColors.primary,
                  onTap: () async {
                    Haptic.selection();
                    final next = !ref.read(appSettingsProvider).notifEpisodes;
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setNotifEpisodes(next);
                    if (next) {
                      await EpisodeNotificationService.instance
                          .requestPermission();
                    }
                    await rescheduleEpisodeNotifications(ref);
                  },
                ),
                // Toggle Watch Party / Aktivitas / Live Reactions DIHAPUS —
                // sebelumnya UI-only (tidak tersimpan & tidak berefek).
                // Privasi aktivitas dikelola di Edit Profil (PrivacyPrefs).
                // Watch Party menyusul saat fiturnya benar-benar jalan.
              ],
            ),

            const SizedBox(height: 24),

            // UNDUHAN
            _SectionLabel(context.l10n.settingsDownloads.toUpperCase()),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsDefaultQuality,
                  trailingText: '720p',
                ),
                _SettingTile(
                  title: context.l10n.settingsSavedEpisodes,
                  trailingText: _formatStorageSummary(
                    context,
                    ref.watch(downloadsListProvider),
                  ),
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.storage),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // TENTANG & LEGAL
            _SectionLabel(context.l10n.settingsAbout.toUpperCase()),
            _SectionContainer(
              children: [
                _SettingTile(
                  title: context.l10n.settingsAbout,
                  trailingText: 'v1.0.0',
                  trailingTextColor: AppColors.primary,
                  onTap: () => context.push(AppRoutes.about),
                ),
                _SettingTile(
                  title: context.l10n.settingsPrivacy,
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                _SettingTile(
                  title: context.l10n.settingsTerms,
                  onTap: () => context.push(AppRoutes.termsOfService),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Logout button (visible if logged in)
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Version footer
            Center(
              child: Text(
                'VibeNime v1.0.0',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
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

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    this.trailingText,
    this.trailing,
    this.trailingTextColor,
    this.onTap,
  });

  final String title;
  final String? trailingText;
  final Widget? trailing;
  final Color? trailingTextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              ?trailing,
              if (trailingText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingText!,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color:
                            trailingTextColor ?? AppColors.textMuted(context),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color:
                            trailingTextColor ?? AppColors.textMuted(context),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet picker untuk pilih theme mode (dark / light / system).
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.current});
  final ThemeMode current;

  List<(ThemeMode, String, IconData, String)> _options(BuildContext context) =>
      [
        (
          ThemeMode.dark,
          context.l10n.settingsThemeDark,
          Icons.dark_mode_rounded,
          context.l10n.settingsThemeDarkDesc,
        ),
        (
          ThemeMode.light,
          context.l10n.settingsThemeLight,
          Icons.light_mode_rounded,
          context.l10n.settingsThemeLightDesc,
        ),
        (
          ThemeMode.system,
          context.l10n.settingsFollowSystem,
          Icons.brightness_auto_rounded,
          context.l10n.settingsThemeSystemDesc,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.tiny),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.settingsThemePick,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            for (final opt in _options(context))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(context, opt.$1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: opt.$1 == current
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: opt.$1 == current
                            ? AppColors.primary
                            : AppColors.borderColor(context),
                        width: opt.$1 == current ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          opt.$3,
                          size: 22,
                          color: opt.$1 == current
                              ? AppColors.primary
                              : AppColors.textMuted(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.$2,
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.$4,
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (opt.$1 == current)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
