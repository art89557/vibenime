import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../favorites/data/favorite_entry.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../favorites/presentation/favorites_providers.dart';
import 'widgets/status_picker_sheet.dart';
import '../../history/presentation/history_providers.dart';
import '../../search/presentation/search_providers.dart';
import '../../watch_party/presentation/widgets/start_party_card.dart';
import 'anime_detail_providers.dart';
import 'widgets/characters_tab.dart';
import 'widgets/discussion_tab.dart';
import 'widgets/episodes_grid.dart';
import 'widgets/hero_banner.dart';
import 'widgets/metric_cards.dart';
import 'widgets/recommended_anime_section.dart';
import 'widgets/related_anime_section.dart';
import 'widgets/watch_now_button.dart';
import '../../../core/theme/app_radius.dart';

class AnimeDetailScreen extends ConsumerStatefulWidget {
  const AnimeDetailScreen({required this.animeId, super.key});

  final String animeId;

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Set genre filter di Search lalu navigate ke tab Search.
  ///
  /// User flow: tap genre chip "Action" di Detail → Search screen kebuka
  /// dengan filter Action aktif → langsung lihat anime Action lainnya.
  /// Sesuai prinsip **Golden Rule 7 — Internal Locus of Control**
  /// (user merasa app responsif terhadap intent mereka).
  void _searchByGenre(String genre) {
    Haptic.selection();
    ref.read(selectedGenresProvider.notifier).state = [genre];
    // Clear filter lain supaya hanya genre yang aktif (less surprise).
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedYearProvider.notifier).state = null;
    ref.read(selectedSeasonProvider.notifier).state = null;
    ref.read(selectedFormatProvider.notifier).state = null;
    context.go('/search');
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Dynamic FAB style berdasarkan status entry sekarang.
  /// Return (label, icon, background color).
  (String, IconData, Color) _fabStyleFor(WatchStatus? status) {
    switch (status) {
      case WatchStatus.watching:
        return ('Watching', Icons.play_circle_rounded, AppColors.primary);
      case WatchStatus.completed:
        return ('Completed', Icons.check_circle_rounded, AppColors.success);
      case WatchStatus.planning:
        return ('Planning', Icons.bookmark_rounded, AppColors.warning);
      case null:
        return ('Add to List', Icons.add_rounded, AppColors.primary);
    }
  }

  Future<void> _openStatusPicker(Anime anime) async {
    Haptic.medium();
    final repo = ref.read(favoritesRepositoryProvider);
    final currentEntry = repo.getEntry(anime.id);
    final result = await showStatusPickerSheet(
      context: context,
      animeTitle: anime.title,
      currentStatus: currentEntry?.status,
    );
    if (result == null) return;
    if (!mounted) return;

    if (result.remove) {
      await repo.remove(anime.id);
      if (!mounted) return;
      AppSnackbar.success(context, '${anime.title} dihapus dari list');
    } else if (result.value != null) {
      await repo.addOrUpdate(anime, result.value!);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        '${anime.title} disimpan sebagai ${result.value!.label}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(widget.animeId) ?? 0;
    final asyncDetail = ref.watch(animeDetailProvider(id));
    final currentEntry = ref.watch(favoriteEntryProvider(id));

    return Scaffold(
      // **Stack di Scaffold level** — action bar floating SELALU di atas
      // ListView, gesture-nya tidak intercepted oleh Scrollable parent.
      body: Stack(
        children: [
          // Main scrollable content
          Positioned.fill(
            child: asyncDetail.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 40),
                child: ErrorRetry(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(animeDetailProvider(id)),
                ),
              ),
              data: (anime) =>
                  ResponsiveContainer(child: _buildBody(context, anime, id)),
            ),
          ),
          // Floating back — HANYA untuk state loading/error. State `data`
          // pakai tombol back bawaan SliverAppBar (lihat _buildBody).
          if (!asyncDetail.hasValue)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: CircleIconButton(
                icon: Icons.arrow_back,
                onTap: _handleBack,
                tooltip: 'Kembali',
              ),
            ),
        ],
      ),
      // Status picker FAB — open bottom sheet untuk pilih Watching/
      // Completed/Planning. Label & icon dynamic per current status.
      floatingActionButton: asyncDetail.maybeWhen(
        data: (anime) {
          final (label, icon, bg) = _fabStyleFor(currentEntry?.status);
          return FloatingActionButton.extended(
            onPressed: () => _openStatusPicker(anime),
            icon: Icon(icon),
            label: Text(label),
            backgroundColor: bg,
            foregroundColor: Colors.black,
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildBody(BuildContext context, Anime anime, int animeId) {
    final asyncEps = ref.watch(animeEpisodesProvider(animeId));

    return CustomScrollView(
      slivers: [
        // ── Parallax collapsing header ──
        _buildSliverAppBar(context, anime),

        // ── Konten ──
        SliverList(
          delegate: SliverChildListDelegate([
            // Poster cover + judul + studio (scroll normal).
            DetailTitleBlock(anime: anime),

            // 3 metric cards
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: MetricCards(anime: anime),
            ),

            // Genre chips — tap untuk filter Search by genre tsb
            if (anime.genres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: anime.genres
                      .take(5)
                      .map(
                        (g) => _GenrePill(
                          label: g,
                          onTap: () => _searchByGenre(g),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),

            // Big watch button + download
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: asyncEps.when(
                loading: () => const SizedBox(
                  height: 52,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (eps) => WatchNowButton(
                  animeId: animeId,
                  anime: anime,
                  episodes: eps,
                ),
              ),
            ),

            // Pesta Nonton card — show active parties (join) atau tombol "Mulai"
            StartPartyCard(
              animeId: animeId,
              animeTitle: anime.title,
              episodeNumber: 1,
            ),

            // Tabs
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.textPrimary(context),
                unselectedLabelColor: AppColors.textMuted(context),
                labelStyle: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  Tab(text: context.l10n.detailTabEpisodes),
                  Tab(text: context.l10n.detailTabSynopsis),
                  Tab(text: context.l10n.detailTabCharacters),
                  Tab(text: context.l10n.detailTabDiscussion),
                ],
              ),
            ),

            // Tab content
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                switch (_tabController.index) {
                  case 0:
                    return _EpisodeTab(
                      animeId: animeId,
                      asyncEps: asyncEps,
                      thumbnailMap: anime.episodeThumbnails,
                      // Banner > cover sebagai fallback image untuk episode
                      // tanpa thumbnail spesifik (visual lebih konsisten).
                      fallbackImageUrl: anime.bannerImage ?? anime.coverImage,
                      // nextAiringEpisode.episode = episode yang akan tayang.
                      // Episode rilis = nextAiring - 1. Kalau null (anime
                      // selesai), tampilkan semua.
                      maxReleasedEpisode: anime.nextAiringEpisode != null
                          ? anime.nextAiringEpisode!.episode - 1
                          : null,
                    );
                  case 1:
                    return _SinopsisTab(anime: anime);
                  case 2:
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CharactersTab(characters: anime.characters),
                    );
                  case 3:
                    return DiscussionTab(animeId: animeId);
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),

            // Anime Terkait (di luar tabs, biar tetap bisa di-discover)
            RelatedAnimeSection(relations: anime.relations),

            // Rekomendasi AniList ("Kamu mungkin suka")
            RecommendedAnimeSection(items: anime.recommendations),

            const SizedBox(height: 100),
          ]),
        ),
      ],
    );
  }

  /// SliverAppBar dengan parallax collapsing header. Banner mengecil & memudar
  /// saat scroll (CollapseMode.parallax), lalu pinned jadi nav bar standar.
  /// Judul anime fade-in di toolbar hanya saat sudah collapsed.
  Widget _buildSliverAppBar(BuildContext context, Anime anime) {
    const expandedHeight = 300.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: CircleIconButton(
          icon: Icons.arrow_back,
          onTap: _handleBack,
          tooltip: 'Kembali',
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPad = MediaQuery.of(context).padding.top;
          final collapsedH = kToolbarHeight + topPad;
          final current = constraints.biggest.height;
          // fraction: 1 = fully expanded, 0 = fully collapsed.
          final fraction =
              ((current - collapsedH) / (expandedHeight - collapsedH)).clamp(
                0.0,
                1.0,
              );
          // Judul fade-in hanya di ~45% terakhir proses collapse.
          final titleOpacity = (((1 - fraction) - 0.55) / 0.45).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: DetailHeaderBackground(anime: anime),
              ),
              // Judul collapsed — di area toolbar, di samping tombol back.
              Positioned(
                top: topPad,
                height: kToolbarHeight,
                left: 64,
                right: 16,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Text(
                      anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeTab extends ConsumerWidget {
  const _EpisodeTab({
    required this.animeId,
    required this.asyncEps,
    this.thumbnailMap = const {},
    this.fallbackImageUrl,
    this.maxReleasedEpisode,
  });

  final int animeId;
  final AsyncValue asyncEps;
  final Map<int, String?> thumbnailMap;
  final String? fallbackImageUrl;
  final int? maxReleasedEpisode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncEps.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorRetry(
          compact: true,
          message: e.toString(),
          onRetry: () => ref.invalidate(animeEpisodesProvider(animeId)),
        ),
      ),
      data: (eps) {
        final watched = ref.watch(watchedEpisodeIdsProvider(animeId));
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: EpisodesGrid(
            episodes: eps,
            thumbnailMap: thumbnailMap,
            fallbackImageUrl: fallbackImageUrl,
            maxReleasedEpisode: maxReleasedEpisode,
            watchedIds: watched,
            onTap: (ep) =>
                context.push(AppRoutes.playerPath(animeId.toString(), ep.id)),
          ),
        );
      },
    );
  }
}

class _SinopsisTab extends StatelessWidget {
  const _SinopsisTab({required this.anime});

  final Anime anime;

  static final _htmlRegex = RegExp(r'<[^>]*>');
  static String _stripHtml(String input) =>
      input.replaceAll(_htmlRegex, '').replaceAll('&nbsp;', ' ').trim();

  @override
  Widget build(BuildContext context) {
    if (anime.description == null || anime.description!.isEmpty) {
      return _PlaceholderTab(
        icon: Icons.description_outlined,
        message: context.l10n.detailNoSynopsis,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Text(
        _stripHtml(anime.description!),
        style: GoogleFonts.roboto(
          fontSize: 13,
          height: 1.6,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted(context)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
