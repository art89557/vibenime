import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/section_header.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../history/data/history_entry.dart';
import '../../history/presentation/history_providers.dart';
import '../data/anime_repository.dart';
import 'discover_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(discoverSectionProvider);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            children: [
              _Header(username: user?.name),
              const _ContinueWatchingSection(),
              const _DiscoverSection(
                section: DiscoverSection.trending,
                title: 'Trending Now',
                subtitle: 'Anime paling banyak ditonton minggu ini',
              ),
              const _DiscoverSection(
                section: DiscoverSection.popular,
                title: 'Popular Season',
                subtitle: 'Sedang tayang & populer',
              ),
              const _DiscoverSection(
                section: DiscoverSection.topRated,
                title: 'Top Rated',
                subtitle: 'Skor tertinggi sepanjang masa',
              ),
              const _DiscoverSection(
                section: DiscoverSection.upcoming,
                title: 'Upcoming',
                subtitle: 'Akan tayang segera',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.username});

  final String? username;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username == null ? 'Halo!' : 'Halo, @$username 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Mau nonton apa hari ini?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textOnDarkMuted,
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

class _DiscoverSection extends ConsumerWidget {
  const _DiscoverSection({
    required this.section,
    required this.title,
    this.subtitle,
  });

  final DiscoverSection section;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(discoverSectionProvider(section));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        asyncList.when(
          loading: () => const AnimeRowSkeleton(),
          error: (e, _) => ErrorRetry(
            compact: true,
            message: e.toString(),
            onRetry: () => ref.invalidate(discoverSectionProvider(section)),
          ),
          data: (list) => SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final anime = list[i];
                return AnimeCard(
                  anime: anime,
                  onTap: () => context.push(
                    AppRoutes.animeDetailPath(anime.id.toString()),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Section "Continue Watching" — hanya muncul kalau ada history menonton.
class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentWatchedProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Continue Watching',
          subtitle: 'Lanjutkan dari posisi terakhir',
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ContinueWatchingCard(entry: history[i]),
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends ConsumerWidget {
  const _ContinueWatchingCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnime = ref.watch(animeDetailProvider(entry.animeId));

    return SizedBox(
      width: 220,
      child: GestureDetector(
        onTap: () => context.push(
          AppRoutes.playerPath(entry.animeId.toString(), entry.episodeId),
        ),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: asyncAnime.when(
                      loading: () => Container(
                        color: AppColors.surfaceDarkElevated,
                      ),
                      error: (_, _) => Container(
                        color: AppColors.surfaceDarkElevated,
                      ),
                      data: (anime) {
                        final url = anime.bannerImage ?? anime.coverImage;
                        return url.isEmpty
                            ? Container(color: AppColors.surfaceDarkElevated)
                            : Image.network(url, fit: BoxFit.cover);
                      },
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (entry.progressFraction != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: entry.progressFraction,
                        minHeight: 3,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              asyncAnime.maybeWhen(
                data: (a) => a.title,
                orElse: () => 'Loading…',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Episode ${entry.episodeNumber}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textOnDarkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
