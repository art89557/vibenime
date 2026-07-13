import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/decorative_anime_card.dart';
import 'widgets/top_rank_carousel.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/section_header.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../../favorites/data/favorites_sync_coordinator.dart';
import '../../history/data/history_entry.dart';
import '../../history/data/watch_history_sync_coordinator.dart';
import '../../history/presentation/history_item_menu.dart';
import '../../history/presentation/history_providers.dart';
import '../../notifications/data/episode_airing_repository.dart';
import '../../player/data/aniwatch_client.dart';
import '../../player/data/miruro_client.dart';
import '../data/anime_repository.dart';
import '../data/for_you_repository.dart';
import 'discover_providers.dart';
import '../../../core/theme/app_radius.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Track image URLs yang sudah di-precache supaya tidak di-precache 2x
  /// (hot reload, list refresh, dll).
  final Set<String> _precached = <String>{};

  /// Controller untuk doomscroll "Completed Anime" — trigger loadMore saat
  /// dekat bottom.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Jadwalkan ulang notifikasi episode (sesuai My List + setting) saat app
    // sampai di Home — koreksi airingAt yang bergeser tiap sesi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      rescheduleEpisodeNotifications(ref);
      // Sinkron progress nonton + favorit dari cloud (no-op guest/offline).
      syncWatchHistory(ref);
      syncFavorites(ref);
      // Bangunkan source English lebih awal: Aniwatch (utama) + Miruro (fallback).
      ref.read(aniwatchClientProvider).warmup();
      ref.read(miruroClientProvider).warmup();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 800) {
      ref
          .read(paginatedDiscoverProvider(DiscoverSection.completed).notifier)
          .loadMore();
    }
  }

  /// Precache top-N cover image dari trending list ke `ImageCache` Flutter.
  ///
  /// Ini bikin scroll Detail → balik Home → image instan tanpa flash.
  /// Juga membantu performansi initial paint kalau user scroll cepat ke bawah.
  void _precacheCovers(List<dynamic> animes, BuildContext ctx) {
    final top = animes.take(6);
    for (final a in top) {
      final url = (a as dynamic).coverImage as String?;
      if (url == null || url.isEmpty || _precached.contains(url)) continue;
      _precached.add(url);
      // Defer 1 frame supaya tidak block initial paint.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheImage(CachedNetworkImageProvider(url), ctx).catchError((_) {
          // Silent — kalau fail, fallback widget akan render placeholder.
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild saat preferensi Bahasa Judul berubah → displayTitle ikut refresh.
    ref.watch(appSettingsProvider.select((s) => s.titleLanguage));
    final user = ref.watch(appAuthControllerProvider).user;

    // Precache trigger: listen ke trending provider dan trigger precache
    // saat data ready (idempotent — di-skip kalau URL sudah di-cache).
    ref.listen(discoverSectionProvider(DiscoverSection.trending), (prev, next) {
      next.whenData((list) => _precacheCovers(list, context));
    });

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceElevated(context),
            onRefresh: () async {
              ref.invalidate(discoverSectionProvider);
              ref
                  .read(
                    paginatedDiscoverProvider(
                      DiscoverSection.completed,
                    ).notifier,
                  )
                  .refresh();
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: CustomScrollView(
              // PageStorageKey: keep scroll position saat navigate ke Detail.
              // Controller: doomscroll loadMore "Completed Anime".
              key: const PageStorageKey('home_scroll'),
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _Header(username: user?.username)),
                const SliverToBoxAdapter(child: _ResumeBigCard()),
                const SliverToBoxAdapter(child: _RecentWatchedRow()),
                // "Hot Anime" — grid podium #1/#2/#3 (gantikan row Trending
                // horizontal lama). Sumber data tetap section trending.
                const SliverToBoxAdapter(child: _HotAnimeSection()),
                const SliverToBoxAdapter(child: _ForYouSection()),
                SliverToBoxAdapter(
                  child: _DiscoverSection(
                    section: DiscoverSection.topRated,
                    title: context.l10n.homeTopAllTime,
                    subtitle: context.l10n.homeTopAllTimeSub,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DiscoverSection(
                    section: DiscoverSection.upcoming,
                    title: context.l10n.homeUpcoming,
                    subtitle: context.l10n.homeUpcomingSub,
                  ),
                ),
                const SliverToBoxAdapter(child: _CompletedHeader()),
                const _CompletedGrid(),
                const _CompletedFooter(),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header: "halo, {nama} —" + "vibe apa hari ini?" (serif italic).
class _Header extends StatelessWidget {
  const _Header({this.username});

  final String? username;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeGreeting(username ?? 'otome'),
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.homeVibe,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.go(AppRoutes.search),
            icon: const Icon(Icons.search_rounded, size: 26),
          ),
          const _AvatarDot(),
        ],
      ),
    );
  }
}

class _AvatarDot extends ConsumerWidget {
  const _AvatarDot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appAuthControllerProvider).user;
    final url = user?.avatarUrl;

    return GestureDetector(
      onTap: () => context.go(AppRoutes.settings),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceElevated(context),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          image: (url != null && url.isNotEmpty)
              ? DecorationImage(
                  image: CachedNetworkImageProvider(url),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: (url == null || url.isEmpty)
            ? Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.textMuted(context),
              )
            : null,
      ),
    );
  }
}

/// Big "Lanjutkan" card — banner anime + progress bar + play button.
/// Hanya muncul kalau ada history.
class _ResumeBigCard extends ConsumerWidget {
  const _ResumeBigCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentWatchedProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    final entry = history.first;
    final asyncAnime = ref.watch(animeDetailProvider(entry.animeId));
    final isSynced = ref.watch(appAuthControllerProvider).isAuthenticated;

    return asyncAnime.when(
      loading: () => const SizedBox(height: 200),
      error: (_, _) => const SizedBox.shrink(),
      data: (anime) {
        final url = anime.bannerImage ?? anime.coverImage;

        // **Smart resume**: kalau episode terakhir SUDAH selesai dan masih ada
        // episode berikutnya yang sudah rilis → tawarkan "BERIKUTNYA · EP n+1"
        // (mulai dari awal), bukan replay episode lama di posisi akhir.
        final maxReleased = anime.nextAiringEpisode != null
            ? anime.nextAiringEpisode!.episode - 1
            : anime.episodes;
        final nextNumber = entry.episodeNumber + 1;
        final goNext =
            entry.isFinished &&
            maxReleased != null &&
            nextNumber <= maxReleased;

        final targetEpisodeId = goNext
            ? 'ep-${entry.animeId}-$nextNumber'
            : entry.episodeId;
        final epLabel = goNext
            ? context.l10n.homeResumeNextEp(
                nextNumber.toString().padLeft(2, '0'),
              )
            : context.l10n.homeResumeEp(
                entry.episodeNumber.toString().padLeft(2, '0'),
              );
        final posLabel = goNext
            ? context.l10n.homeResumeNextLabel
            : _formatPos(entry);
        final progress = goNext ? 0.0 : (entry.progressFraction ?? 0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: GestureDetector(
            onTap: () => context.push(
              AppRoutes.playerPath(entry.animeId.toString(), targetEpisodeId),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: url,
                        memCacheWidth: 1080,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: AppColors.surfaceElevated(context)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Color.fromRGBO(11, 14, 20, 0.3),
                            Color.fromRGBO(11, 14, 20, 0.85),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    epLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSynced) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: context.l10n.homeSyncedTooltip,
                                    child: const Icon(
                                      Icons.cloud_done_rounded,
                                      size: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            Text(
                              anime.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  posLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                const Spacer(),
                                _PlayButton(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.tiny,
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPos(HistoryEntry e) {
    final pos = e.position;
    final dur = e.duration ?? const Duration(minutes: 24);
    String fmt(Duration d) {
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return '${fmt(pos)} / ${fmt(dur)}';
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: AppColors.onAccent,
        size: 28,
      ),
    );
  }
}

/// Section "Hot Anime" — header + grid podium #1/#2/#3 (data: trending).
class _HotAnimeSection extends ConsumerWidget {
  const _HotAnimeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(
      discoverSectionProvider(DiscoverSection.trending),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Hot Anime',
          subtitle: context.l10n.homeTrendingSub,
          onSeeAll: () => context.push(AppRoutes.ranking),
        ),
        asyncList.when(
          loading: () => const AnimeRowSkeleton(),
          error: (e, _) => ErrorRetry(
            compact: true,
            message: e.toString(),
            onRetry: () => ref.invalidate(
              discoverSectionProvider(DiscoverSection.trending),
            ),
          ),
          data: (list) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TopRankCarousel(top: list.take(3).toList()),
          ),
        ),
      ],
    );
  }
}

class _DiscoverSection extends ConsumerWidget {
  const _DiscoverSection({
    required this.section,
    required this.title,
    this.subtitle,
    this.showRefresh = false,
  });

  final DiscoverSection section;
  final String title;
  final String? subtitle;
  final bool showRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(discoverSectionProvider(section));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          onRefresh: showRefresh
              ? () => ref.invalidate(discoverSectionProvider(section))
              : null,
        ),
        asyncList.when(
          loading: () => const AnimeRowSkeleton(),
          error: (e, _) => ErrorRetry(
            compact: true,
            message: e.toString(),
            onRetry: () => ref.invalidate(discoverSectionProvider(section)),
          ),
          data: (list) => SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final anime = list[i];
                return DecorativeAnimeCard(
                  anime: anime,
                  width: 140,
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

/// Section "Buat Kamu" — rekomendasi personal dari afinitas genre (favorit +
/// history). Kalau user belum punya data seed / gagal → fallback ke populer
/// musim ini supaya header tetap berisi.
class _ForYouSection extends ConsumerWidget {
  const _ForYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(forYouProvider);

    // Loading awal / error / hasil kosong → fallback populer (header sama).
    final fallback = _DiscoverSection(
      section: DiscoverSection.popular,
      title: context.l10n.homeForYou,
      subtitle: context.l10n.homeForYouSub,
      showRefresh: true,
    );

    return async.maybeWhen(
      data: (result) {
        if (result.isEmpty) return fallback;
        final subtitle = result.basedOnGenres.isEmpty
            ? context.l10n.homeForYouSub
            : context.l10n.homeForYouBasedOn(result.basedOnGenres.join(', '));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n.homeForYou,
              subtitle: subtitle,
              onRefresh: () => ref.invalidate(forYouProvider),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: result.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final anime = result.items[i];
                  return DecorativeAnimeCard(
                    anime: anime,
                    width: 140,
                    onTap: () => context.push(
                      AppRoutes.animeDetailPath(anime.id.toString()),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      orElse: () => fallback,
    );
  }
}

/// Row horizontal "Terakhir Ditonton" — resume cepat + opsi per item.
/// Tap = lanjutkan, long-press = menu (lanjutkan/detail/selesai/hapus).
class _RecentWatchedRow extends ConsumerWidget {
  const _RecentWatchedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentWatchedProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.homeRecentlyWatched,
          onSeeAll: () => context.push(AppRoutes.history),
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _RecentCard(entry: recent[i]),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends ConsumerWidget {
  const _RecentCard({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anime = ref.watch(animeDetailProvider(entry.animeId)).valueOrNull;
    final cover = anime?.coverImage ?? '';
    final title = anime?.displayTitle ?? context.l10n.commonLoading;
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.playerPath(entry.animeId.toString(), entry.episodeId),
      ),
      onLongPress: () => showWatchItemMenu(context, ref, entry),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 120,
                height: 168,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover.isEmpty)
                      Container(color: AppColors.surfaceElevated(context))
                    else
                      CachedNetworkImage(
                        imageUrl: cover,
                        memCacheWidth: 400,
                        fit: BoxFit.cover,
                      ),
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: entry.progressFraction ?? 0,
                        minHeight: 3,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'EP ${entry.episodeNumber.toString().padLeft(2, '0')}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header section "Completed Anime" untuk feed doomscroll di bawah Home.
class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader();

  @override
  Widget build(BuildContext context) {
    return const SectionHeader(
      title: 'Completed Anime',
      subtitle: 'anime tamat — scroll terus',
    );
  }
}

/// Grid infinite-scroll "Completed Anime" (status FINISHED). Returns a SLIVER —
/// dipakai langsung di CustomScrollView Home supaya paginasi natural.
class _CompletedGrid extends ConsumerWidget {
  const _CompletedGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      paginatedDiscoverProvider(DiscoverSection.completed),
    );

    if (state.items.isEmpty) {
      if (state.isLoading) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      if (state.error != null) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorRetry(
              compact: true,
              message: state.error.toString(),
              onRetry: () => ref
                  .read(
                    paginatedDiscoverProvider(
                      DiscoverSection.completed,
                    ).notifier,
                  )
                  .loadInitial(),
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Breakpoints.columnsFor(context),
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          // 0.48 (bukan 0.52) — sel cukup tinggi untuk cover 2:3 + judul
          // 2 baris + meta; selaras dengan grid Search. 0.52 terbukti
          // overflow 8.2px di device.
          childAspectRatio: 0.48,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final anime = state.items[i];
          return AnimeCard(
            anime: anime,
            width: double.infinity,
            onTap: () =>
                context.push(AppRoutes.animeDetailPath(anime.id.toString())),
          );
        }, childCount: state.items.length),
      ),
    );
  }
}

/// Footer spinner saat doomscroll memuat halaman berikutnya. Returns a SLIVER.
class _CompletedFooter extends ConsumerWidget {
  const _CompletedFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingMore = ref.watch(
      paginatedDiscoverProvider(
        DiscoverSection.completed,
      ).select((s) => s.isLoadingMore),
    );
    if (!loadingMore) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
