import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/animation/animations.dart';
import '../../../core/i18n/l10n_extension.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../shared/widgets/lottie_empty_state.dart';
import '../../../shared/widgets/press_animation.dart';
import '../../favorites/data/favorite_entry.dart';
import '../../favorites/presentation/favorites_providers.dart';
import '../../../core/theme/app_radius.dart';

/// Pustaka — AniList-style My List dengan 4 tab status.
///
/// Tab: All / Watching / Completed / Planning.
/// Setiap card menampilkan progress bar "EP X / Y (Z%)" dari history.
///
/// Tab Offline sudah pindah ke Settings → Penyimpanan.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// null = All, else filter by status.
  WatchStatus? _activeStatus;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(favoritesProvider).valueOrNull ?? const [];
    final filtered = _activeStatus == null
        ? all
        : all.where((e) => e.status == _activeStatus).toList();

    // Counts per tab — for badge di pill
    final watchingCount = all
        .where((e) => e.status == WatchStatus.watching)
        .length;
    final completedCount = all
        .where((e) => e.status == WatchStatus.completed)
        .length;
    final planningCount = all
        .where((e) => e.status == WatchStatus.planning)
        .length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeadline()),
            SliverToBoxAdapter(
              child: _buildTabs(
                allCount: all.length,
                watchingCount: watchingCount,
                completedCount: completedCount,
                planningCount: planningCount,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // AnimatedSwitcher antar tab — content fade+slide saat user
            // ganti status filter. Key per status supaya switcher detect
            // perubahan dan trigger transition.
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: AppAnimations.medium,
                switchInCurve: AppAnimations.smoothSpring,
                switchOutCurve: AppAnimations.smoothSpring,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('lib-tab-${_activeStatus?.name ?? "all"}'),
                  child: filtered.isEmpty
                      ? _buildEmptyState(context)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: Breakpoints.value(
                                    context,
                                    mobile: 2,
                                    tablet: 3,
                                    desktop: 4,
                                    desktopLg: 5,
                                  ),
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.6,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) =>
                                _LibraryCard(entry: filtered[i]),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Text(
        'Pustaka kamu',
        style: GoogleFonts.playfairDisplay(
          fontSize: 34,
          fontStyle: FontStyle.italic,
          color: AppColors.textPrimary(context),
          height: 1.05,
        ),
      ),
    );
  }

  Widget _buildTabs({
    required int allCount,
    required int watchingCount,
    required int completedCount,
    required int planningCount,
  }) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _TabPill(
            label: context.l10n.libraryAll,
            count: allCount,
            isActive: _activeStatus == null,
            onTap: () => _setStatus(null),
          ),
          const SizedBox(width: 8),
          _TabPill(
            label: context.l10n.libraryWatching,
            count: watchingCount,
            isActive: _activeStatus == WatchStatus.watching,
            onTap: () => _setStatus(WatchStatus.watching),
          ),
          const SizedBox(width: 8),
          _TabPill(
            label: context.l10n.libraryCompleted,
            count: completedCount,
            isActive: _activeStatus == WatchStatus.completed,
            onTap: () => _setStatus(WatchStatus.completed),
          ),
          const SizedBox(width: 8),
          _TabPill(
            label: context.l10n.libraryPlanning,
            count: planningCount,
            isActive: _activeStatus == WatchStatus.planning,
            onTap: () => _setStatus(WatchStatus.planning),
          ),
        ],
      ),
    );
  }

  void _setStatus(WatchStatus? status) {
    Haptic.selection();
    setState(() => _activeStatus = status);
  }

  Widget _buildEmptyState(BuildContext context) {
    // Pilih Lottie + copy konteks per status. Lottie fallback ke icon
    // kalau file belum di-download (lihat assets/lottie/README.md).
    final (
      lottieAsset,
      fallbackIcon,
      title,
      subtitle,
    ) = switch (_activeStatus) {
      WatchStatus.watching => (
        'assets/lottie/empty_library.json',
        Icons.play_circle_outline_rounded,
        'Belum ada anime yang sedang ditonton',
        'Mulai nonton dari Beranda — status auto-update saat kamu putar episode pertama.',
      ),
      WatchStatus.completed => (
        'assets/lottie/success_check.json',
        Icons.check_circle_outline_rounded,
        'Belum ada anime yang selesai ditonton',
        'Terus menonton! Saat kamu finish episode terakhir, anime auto-pindah ke sini.',
      ),
      WatchStatus.planning => (
        'assets/lottie/empty_library.json',
        Icons.bookmark_outline_rounded,
        'Daftar tonton kosong',
        'Tap "Add to List" di Detail anime untuk simpan rencana tonton.',
      ),
      null => (
        'assets/lottie/empty_library.json',
        Icons.library_books_outlined,
        'Pustaka kamu masih kosong',
        'Buka Detail anime → "Add to List" untuk mulai tracking tontonan.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 32),
      child: LottieEmptyState(
        assetPath: lottieAsset,
        fallbackIcon: fallbackIcon,
        title: title,
        subtitle: subtitle,
        actionLabel: 'Jelajahi anime',
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}

// ─── Card with progress bar ─────────────────────────────────────────────

class _LibraryCard extends ConsumerWidget {
  const _LibraryCard({required this.entry});

  final FavoriteEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider(entry.animeId));

    return PressableScale(
      onTap: () =>
          context.push(AppRoutes.animeDetailPath(entry.animeId.toString())),
      scaleDown: 0.96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover with status badge overlay.
          // Pakai Expanded (bukan AspectRatio) supaya cover mengisi sisa tinggi
          // sel grid — mencegah overflow saat title 2 baris + progress bar.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (entry.coverImage.isEmpty)
                    Container(color: AppColors.surfaceElevated(context))
                  else
                    CachedNetworkImage(
                      imageUrl: entry.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.surfaceElevated(context)),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceElevated(context),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 24,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ),
                  // Status badge top-right
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _StatusBadge(status: entry.status),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          // Progress bar + label
          _ProgressIndicator(
            current: progress.current,
            total: progress.total,
            fraction: progress.fraction,
            status: entry.status,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      WatchStatus.watching => (AppColors.primary, Icons.play_arrow_rounded),
      WatchStatus.completed => (AppColors.success, Icons.check_rounded),
      WatchStatus.planning => (
        AppColors.textMuted(context),
        Icons.bookmark_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({
    required this.current,
    required this.total,
    required this.fraction,
    required this.status,
  });

  final int current;
  final int? total;
  final double fraction;
  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final percent = (fraction * 100).round();

    // Label dynamic per status
    String label;
    if (status == WatchStatus.completed) {
      label = total != null ? 'Selesai · $total ep' : 'Selesai';
    } else if (status == WatchStatus.planning && current == 0) {
      label = total != null ? 'Belum ditonton · $total ep' : 'Belum ditonton';
    } else if (total == null) {
      label = 'EP $current / —';
    } else {
      label = 'EP $current / $total · $percent%';
    }

    final effectiveFraction = status == WatchStatus.completed ? 1.0 : fraction;
    final barColor = status == WatchStatus.completed
        ? AppColors.success
        : AppColors.primaryAdaptive(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar — Tween animation: fill dari 0 → target saat pertama tampil.
        // Disembunyikan kalau total null (anime ongoing tanpa info).
        if (total != null)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: effectiveFraction),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tiny),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: AppColors.borderColor(context),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        if (total != null) const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.textMuted(context),
          ),
        ),
      ],
    );
  }
}

// ─── Tab pill ────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryAdaptive(context)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive
                ? AppColors.primaryAdaptive(context)
                : AppColors.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.surface(context)
                    : AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppColors.surface(context)
                    : AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
