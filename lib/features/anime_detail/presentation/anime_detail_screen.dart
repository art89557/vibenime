import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../history/data/history_entry.dart';
import '../../history/presentation/history_providers.dart';
import 'add_to_list_sheet.dart';
import 'anime_detail_providers.dart';
import 'widgets/episodes_grid.dart';
import 'widgets/hero_banner.dart';
import 'widgets/related_anime_section.dart';
import 'widgets/watch_now_button.dart';

class AnimeDetailScreen extends ConsumerWidget {
  const AnimeDetailScreen({required this.animeId, super.key});

  final String animeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(animeId) ?? 0;
    final asyncDetail = ref.watch(animeDetailProvider(id));
    final isAuthed = ref.watch(authControllerProvider).isAuthenticated;

    return Scaffold(
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(animeDetailProvider(id)),
          ),
        ),
        data: (anime) => _DetailBody(anime: anime, animeId: id),
      ),
      floatingActionButton: !isAuthed
          ? null
          : asyncDetail.maybeWhen(
              data: (anime) => FloatingActionButton.extended(
                onPressed: () => showAddToListSheet(
                  context: context,
                  mediaId: anime.id,
                  title: anime.title,
                ),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Add to List'),
              ),
              orElse: () => null,
            ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.anime, required this.animeId});

  final Anime anime;
  final int animeId;

  static final _htmlRegex = RegExp(r'<[^>]*>');
  static String _stripHtml(String input) =>
      input.replaceAll(_htmlRegex, '').replaceAll('&nbsp;', ' ').trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEps = ref.watch(animeEpisodesProvider(animeId));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero banner di top.
        HeroBanner(
          anime: anime,
          onBack: () => context.pop(),
        ),

        // Genre chips.
        if (anime.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: anime.genres
                  .map((g) => _GenreChip(label: g))
                  .toList(growable: false),
            ),
          ),

        // "Mulai Tonton" big button.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: asyncEps.when(
            loading: () => const SizedBox(
              height: 52,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (eps) => WatchNowButton(animeId: animeId, episodes: eps),
          ),
        ),

        // Synopsis.
        if (anime.description != null && anime.description!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
            child: Text(
              'Synopsis',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _stripHtml(anime.description!),
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textOnDarkMuted,
              ),
            ),
          ),
        ],

        // Resume banner (existing logic).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ResumeBanner(animeId: animeId),
        ),

        // Anime Terkait section.
        RelatedAnimeSection(relations: anime.relations),

        // Episode grid.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'Episodes',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        asyncEps.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorRetry(
              compact: true,
              message: e.toString(),
              onRetry: () => ref.invalidate(animeEpisodesProvider(animeId)),
            ),
          ),
          data: (eps) => EpisodesGrid(
            episodes: eps,
            onTap: (ep) => context.push(
              AppRoutes.playerPath(animeId.toString(), ep.id),
            ),
          ),
        ),

        const SizedBox(height: 100), // padding bawah biar FAB tidak tabrakan
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Banner "Lanjutkan menonton" — copy dari versi sebelumnya, dipakai di
/// dalam Detail kalau ada history.
class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner({required this.animeId});

  final int animeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(latestHistoryForAnimeProvider(animeId));
    if (history == null || history.isFinished) {
      return const SizedBox.shrink();
    }
    return Material(
      color: AppColors.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppRoutes.playerPath(animeId.toString(), history.episodeId),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: AppColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lanjutkan menonton',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _resumeSubtitle(history),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                    if (history.progressFraction != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: history.progressFraction,
                          minHeight: 4,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  String _resumeSubtitle(HistoryEntry h) {
    final mins = h.position.inMinutes;
    final secs = h.position.inSeconds % 60;
    final time =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return 'Episode ${h.episodeNumber} • menit $time';
  }
}
