import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/source_type.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../../player/data/video_catalog_repository.dart';
import 'admin_providers.dart';
import 'widgets/anime_group_card.dart';
import '../../../core/theme/app_radius.dart';

/// Admin Panel — list semua video sources di catalog.
///
/// **Layout v2 (polished):**
/// - Header card dengan stats dashboard (total anime, sources, per-type)
/// - Search bar + filter chips (source type)
/// - Anime group cards (expandable)
/// - FAB tambah + AppBar action: bulk insert, refresh, logout
class AdminListScreen extends ConsumerWidget {
  const AdminListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appAuthControllerProvider).user;

    // Gate 1: belum login app → arahkan ke login screen primary
    if (appUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Gate 2: bukan admin (user_metadata.role != 'admin') → tolak akses
    if (!appUser.isAdmin) {
      return _NotAdminScreen(email: appUser.email);
    }

    final asyncFiltered = ref.watch(filteredAdminSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavHelper.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => context.push(AppRoutes.adminBulk),
            tooltip: 'Bulk Insert',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Haptic.light();
              ref.invalidate(adminVideoSourcesProvider);
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context, ref),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Stats dashboard header
            _StatsHeader(email: appUser.email),

            // Search + filter row
            _SearchAndFilter(),

            // Content
            Expanded(
              child: asyncFiltered.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetry(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(adminVideoSourcesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyState(
                      hasFilter:
                          ref.read(adminFilterQueryProvider).isNotEmpty ||
                          ref.read(adminFilterSourceTypeProvider) != null,
                    );
                  }
                  // Group by anilist_id
                  final grouped = <int, List<VideoSource>>{};
                  for (final s in list) {
                    grouped.putIfAbsent(s.anilistId, () => []).add(s);
                  }
                  final entries = grouped.entries.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return AnimeGroupCard(
                        anilistId: e.key,
                        sources: e.value,
                        onTapEntry: (s) => context.push(
                          '${AppRoutes.adminPanel}/edit',
                          extra: s,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Haptic.medium();
          context.push('${AppRoutes.adminPanel}/new');
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.adminAdd),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onAccent,
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    Haptic.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          'Logout?',
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.l10n.adminLogoutBody,
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: AppColors.textMuted(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.commonCancel,
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appAuthControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }
}

/// Screen yang muncul saat user login tapi BUKAN admin — tolak akses.
class _NotAdminScreen extends StatelessWidget {
  const _NotAdminScreen({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavHelper.safePop(context),
        ),
        title: Text(
          'Admin Panel',
          style: GoogleFonts.roboto(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warning, width: 2),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.warning,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.adminAccessDenied,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.adminNotAdminBody(email),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textMuted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                  ),
                  child: Text(context.l10n.adminBackHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _StatsHeader — dashboard card menampilkan ringkasan catalog
// ─────────────────────────────────────────────────────────────────────────

class _StatsHeader extends ConsumerWidget {
  const _StatsHeader({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(adminStatsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.surfaceElevated(context),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + email
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.adminLoggedInAs,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats grid
          asyncStats.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
            error: (e, _) => Text(
              context.l10n.adminError(e.toString()),
              style: GoogleFonts.roboto(fontSize: 11, color: AppColors.error),
            ),
            data: (stats) => Column(
              children: [
                Row(
                  children: [
                    _StatBox(
                      icon: Icons.movie_rounded,
                      label: 'Anime',
                      value: stats.totalAnime.toString(),
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      icon: Icons.video_library_rounded,
                      label: 'Sources',
                      value: stats.totalSources.toString(),
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      icon: Icons.layers_rounded,
                      label: 'Type',
                      value: stats.byType.length.toString(),
                    ),
                  ],
                ),
                if (stats.byType.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Per-type breakdown bar
                  Row(
                    children: stats.byType.entries.map((e) {
                      final pct = stats.totalSources == 0
                          ? 0.0
                          : e.value / stats.totalSources;
                      return Expanded(
                        flex: (pct * 100).round().clamp(1, 100),
                        child: Tooltip(
                          message: '${e.key.label}: ${e.value}',
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _colorForType(e.key),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorForType(SourceType type) {
    switch (type) {
      case SourceType.archiveOrg:
        return AppColors.success;
      case SourceType.youtube:
        return AppColors.error;
      case SourceType.mux:
        return AppColors.warning;
      case SourceType.cloudflareR2:
        return AppColors.primary;
      case SourceType.manual:
        return AppColors.textOnDarkMuted;
    }
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary(context),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 0.8,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SearchAndFilter — search bar + horizontal scrollable filter chips
// ─────────────────────────────────────────────────────────────────────────

class _SearchAndFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(adminFilterQueryProvider);
    final selectedType = ref.watch(adminFilterSourceTypeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (val) =>
                ref.read(adminFilterQueryProvider.notifier).state = val,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: context.l10n.adminSearchCatalogHint,
              hintStyle: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textMuted(context),
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          ref.read(adminFilterQueryProvider.notifier).state =
                              '',
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceElevated(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.borderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.borderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: context.l10n.adminFilterAll,
                isActive: selectedType == null,
                onTap: () =>
                    ref.read(adminFilterSourceTypeProvider.notifier).state =
                        null,
              ),
              for (final t in SourceType.values) ...[
                const SizedBox(width: 6),
                _FilterChip(
                  label: t.label,
                  isActive: selectedType == t,
                  onTap: () =>
                      ref.read(adminFilterSourceTypeProvider.notifier).state =
                          selectedType == t ? null : t,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptic.selection();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.borderColor(context),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.onAccent
                  : AppColors.textPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _EmptyState — kontekstual (kalau filter aktif → message beda)
// ─────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter
                  ? Icons.search_off_rounded
                  : Icons.video_library_outlined,
              size: 56,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? context.l10n.adminNoFilterResults
                  : context.l10n.adminCatalogEmpty,
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? context.l10n.adminCatalogEmptyFilterSub
                  : context.l10n.adminCatalogEmptySub,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
