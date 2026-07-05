import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../../favorites/presentation/favorites_providers.dart';
import '../../gamification/presentation/level_card.dart';
import '../../history/presentation/history_providers.dart';
import '../../../core/theme/app_radius.dart';

/// Profile screen — Supabase-only identity.
///
/// AniList sync sudah dihilangkan. Statistik dihitung dari Hive history
/// (local). Aktivitas dari recent watched. Logout sign-out Supabase.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAuthed = ref.watch(appAuthControllerProvider).isAuthenticated;

    if (!appAuthed) {
      return _GuestProfile();
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHeader(),
            const SizedBox(height: 16),
            _StatCardsRow(),
            const SizedBox(height: 24),
            const LevelCard(),
            const SizedBox(height: 24),
            _ActivityFeed(),
            const SizedBox(height: 16),
            _LogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _ProfileHeader — Supabase user info
// ─────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appAuthControllerProvider).user;

    final avatarUrl = appUser?.avatarUrl;
    final displayName = appUser?.username ?? 'user';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevated(context),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: ClipOval(
              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                  : Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: AppColors.textMuted(context),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$displayName',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appUser?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.textMuted(context),
            tooltip: 'Edit profil',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.textMuted(context),
            tooltip: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _StatCardsRow — stats from local Hive (history + favorites)
// ─────────────────────────────────────────────────────────────────────────

class _StatCardsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pakai allHistoryProvider (1 entry per episode unique) untuk hitung
    // stats akurat. recentWatchedProvider cuma return 10 latest per-anime —
    // tidak cocok untuk total.
    final history = ref.watch(allHistoryProvider);
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];

    // Total unique anime yang pernah ditonton
    final uniqueAnimeIds = history.map((h) => h.animeId).toSet();
    final totalJudul = uniqueAnimeIds.length;
    // Total episode ditonton — count entries (sudah unique per animeId:epId)
    final totalEp = history.length;
    // Total menit ditonton — pakai durationSeconds kalau episode dianggap
    // "finished" (>= 90% atau sisa <30s), else pakai positionSeconds aktual.
    // Ini hindari double-count saat user resume → finish (replace, bukan add).
    final totalSeconds = history.fold<int>(0, (sum, h) {
      final dur = h.durationSeconds;
      if (dur != null && h.isFinished) return sum + dur;
      return sum + h.positionSeconds;
    });
    final totalJam = (totalSeconds / 3600).floor();
    final totalFavorit = favorites.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$totalJudul',
              label: context.l10n.profileStatTitles,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(value: _formatNumber(totalEp), label: 'ep'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${totalJam}j',
              label: context.l10n.profileStatHours,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$totalFavorit',
              label: context.l10n.profileStatFavorites,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  /// Cek apakah [value] adalah angka pure (no satuan) — kalau iya, animasi
  /// count-up dari 0 → target. Kalau ada satuan/suffix (mis. "2.4k", "15j"),
  /// skip count-up dan tampilkan as-is (terlalu kompleks untuk parse).
  int? get _numericValue {
    final n = int.tryParse(value);
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final numeric = _numericValue;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        children: [
          // Animated count-up dari 0 → numeric value, durasi 1200ms easeOut.
          // Kalau value bukan numeric pure, fallback ke text static.
          numeric != null
              ? TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: numeric),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutQuart,
                  builder: (_, v, _) => Text(
                    v.toString(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.05,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.05,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _ActivityFeed — recent history (Hive-based)
// ─────────────────────────────────────────────────────────────────────────

class _ActivityFeed extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentWatchedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Aktivitas terbaru',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Center(
                child: Text(
                  'Belum ada aktivitas',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: history.take(5).map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityItem(
                    icon: Icons.play_arrow_rounded,
                    title: 'EP ${e.episodeNumber} · Anime #${e.animeId}',
                    subtitle: 'menit ${_formatPos(e.position)}',
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  static String _formatPos(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _LogoutButton — Supabase sign-out
// ─────────────────────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    Haptic.heavy();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          context.l10n.logoutConfirmTitle,
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.l10n.logoutConfirmBody,
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: AppColors.textMuted(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.actionCancel,
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.l10n.settingsLogout),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(appAuthControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () => _logout(context, ref),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(context.l10n.settingsLogout),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _GuestProfile — fallback kalau belum login app
// ─────────────────────────────────────────────────────────────────────────

class _GuestProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mode Tamu',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Buat akun untuk akses Watch Party, Diskusi,\n'
                'dan sync data lintas device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textMuted(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.register),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface(context),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(context.l10n.profileCreateAccount),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(
                  'Sudah punya akun? Login',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.primary,
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
