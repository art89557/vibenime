import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/error_retry.dart';
import '../data/anime_repository.dart';
import '../data/rank_trend_store.dart';
import 'discover_providers.dart';

/// Warna medali per peringkat: #1 emas, #2 perak, #3 perunggu, #4+ amber.
Color _medalColor(int rank) => switch (rank) {
  1 => const Color(0xFFFFC107),
  2 => const Color(0xFFC0C7D1),
  3 => const Color(0xFFCD7F32),
  _ => const Color(0xFFFFC107),
};

/// Layar Peringkat Anime — 2 tab: **All Time** (popularity) & **Weekly**
/// (trending). Podium top-3 (#1 lebar penuh, #2 & #3 berdampingan) lalu tile
/// kaya untuk #4+. Thumbnail pakai Hero (`cover-<id>`, hanya tab aktif) →
/// transisi mulus ke Detail. Tab Weekly menampilkan indikator tren.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () =>
                NavHelper.safePop(context, fallback: AppRoutes.home),
          ),
          title: Text(
            context.l10n.rankingTitle,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.textPrimary(context),
            unselectedLabelColor: AppColors.textMuted(context),
            labelStyle: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'All Time'),
              Tab(text: 'Weekly'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RankingList(section: DiscoverSection.popular, tabIndex: 0),
            _RankingList(section: DiscoverSection.trending, tabIndex: 1),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends ConsumerStatefulWidget {
  const _RankingList({required this.section, required this.tabIndex});

  final DiscoverSection section;

  /// 0 = All Time, 1 = Weekly. Hero hanya aktif di tab aktif (cegah duplicate
  /// hero tag dengan tab tetangga yang juga ter-mount di TabBarView).
  final int tabIndex;

  @override
  ConsumerState<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends ConsumerState<_RankingList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  TabController? _tabController;

  Map<int, RankTrend> _trends = const {};
  int _trendForCount = -1;

  bool get _isWeekly => widget.section == DiscoverSection.trending;
  bool get _isActiveTab => (_tabController?.index ?? 0) == widget.tabIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = controller..addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(paginatedDiscoverProvider(widget.section).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  List<Anime> _dedupe(List<Anime> items) {
    final seen = <int>{};
    final out = <Anime>[];
    for (final a in items) {
      if (seen.add(a.id)) out.add(a);
    }
    return out;
  }

  void _maybeComputeTrends(List<Anime> items) {
    if (!_isWeekly || items.isEmpty || items.length == _trendForCount) return;
    final count = items.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trends = ref
          .read(rankTrendStoreProvider)
          .computeAndMaybeSave(items.map((a) => a.id).toList());
      setState(() {
        _trends = trends;
        _trendForCount = count;
      });
    });
  }

  RankTrend? _trendFor(int id) => _isWeekly ? _trends[id] : null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(paginatedDiscoverProvider(widget.section));

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetry(
        message: state.error.toString(),
        onRetry: () => ref
            .read(paginatedDiscoverProvider(widget.section).notifier)
            .loadInitial(),
      );
    }

    final items = _dedupe(state.items);
    _maybeComputeTrends(items);

    // Item 0 = blok podium (#1 + #2/#3). Sisanya tile mulai #4 (items[3]).
    final hasPodium = items.isNotEmpty;
    final tileCount = items.length > 3 ? items.length - 3 : 0;
    final podiumCount = hasPodium ? 1 : 0;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref
          .read(paginatedDiscoverProvider(widget.section).notifier)
          .refresh(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: podiumCount + tileCount + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (hasPodium && i == 0) {
            return _PodiumBlock(
              items: items,
              enableHero: _isActiveTab,
              trendFor: _trendFor,
            );
          }
          final tileIdx = i - podiumCount;
          if (tileIdx < tileCount) {
            final dataIdx = 3 + tileIdx;
            final anime = items[dataIdx];
            return _RankTile(
              rank: dataIdx + 1,
              anime: anime,
              trend: _trendFor(anime.id),
              enableHero: _isActiveTab,
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────── Podium (#1 + #2/#3) ────────────────────────────

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.items,
    required this.enableHero,
    required this.trendFor,
  });

  final List<Anime> items;
  final bool enableHero;
  final RankTrend? Function(int id) trendFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          _PosterCard(
            rank: 1,
            anime: items[0],
            aspectRatio: 16 / 9,
            big: true,
            enableHero: enableHero,
            trend: trendFor(items[0].id),
          ),
          if (items.length >= 2) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PosterCard(
                    rank: 2,
                    anime: items[1],
                    aspectRatio: 4 / 3,
                    enableHero: enableHero,
                    trend: trendFor(items[1].id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: items.length >= 3
                      ? _PosterCard(
                          rank: 3,
                          anime: items[2],
                          aspectRatio: 4 / 3,
                          enableHero: enableHero,
                          trend: trendFor(items[2].id),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu poster podium: gambar (overlay badge/skor/eps) + judul & views di
/// bawah gambar. Dipakai untuk #1 (lebar penuh, [big]) dan #2/#3.
class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.rank,
    required this.anime,
    required this.aspectRatio,
    required this.enableHero,
    this.big = false,
    this.trend,
  });

  final int rank;
  final Anime anime;
  final double aspectRatio;
  final bool enableHero;
  final bool big;
  final RankTrend? trend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.animeDetailPath(anime.id.toString())),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _maybeHero(
                    enable: enableHero,
                    animeId: anime.id,
                    child: anime.coverImage.isEmpty
                        ? Container(color: AppColors.surfaceElevated(context))
                        : CachedNetworkImage(
                            imageUrl: anime.coverImage,
                            fit: BoxFit.cover,
                          ),
                  ),
                  // Gradient bawah untuk legibilitas "Eps".
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color.fromRGBO(0, 0, 0, 0.55),
                        ],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                  // Rank badge + tren (kiri-atas).
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
                        _RankBadge(rank: rank, big: big),
                        if (trend != null) ...[
                          const SizedBox(width: 4),
                          _TrendBadge(trend: trend!),
                        ],
                      ],
                    ),
                  ),
                  // Skor (kanan-atas).
                  if (anime.averageScore != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ScorePill(score: anime.averageScore!),
                    ),
                  // Eps (kiri-bawah).
                  if (anime.episodes != null)
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Text(
                        'Eps ${anime.episodes}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: big ? 12 : 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            anime.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: big ? 16 : 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          if (anime.popularity != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 13,
                  color: AppColors.textMuted(context),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${compactCount(anime.popularity!)} views',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 11.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── #4+ : tile kaya ────────────────────────────────

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.anime,
    required this.enableHero,
    this.trend,
  });

  final int rank;
  final Anime anime;
  final bool enableHero;
  final RankTrend? trend;

  @override
  Widget build(BuildContext context) {
    final english = anime.englishTitle;
    final hasSubtitle =
        english != null && english.isNotEmpty && english != anime.displayTitle;
    final desc = anime.description?.trim();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.animeDetailPath(anime.id.toString())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail + rank badge + eps overlay.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 58,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _maybeHero(
                      enable: enableHero,
                      animeId: anime.id,
                      child: anime.coverImage.isEmpty
                          ? Container(color: AppColors.surface(context))
                          : CachedNetworkImage(
                              imageUrl: anime.coverImage,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(top: 4, left: 4, child: _RankBadge(rank: rank)),
                    if (trend != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _TrendBadge(trend: trend!),
                      ),
                    if (anime.episodes != null)
                      Positioned(
                        left: 5,
                        bottom: 4,
                        child: Text(
                          'Eps ${anime.episodes}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(blurRadius: 3, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Metadata.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 1),
                    Text(
                      english,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 11.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (anime.averageScore != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          (anime.averageScore! / 10).toStringAsFixed(2),
                          style: _tileMeta(context),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (anime.popularity != null) ...[
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 13,
                          color: AppColors.textMuted(context),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${compactCount(anime.popularity!)} views',
                          style: _tileMeta(context),
                        ),
                      ],
                    ],
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _tileMeta(BuildContext context) => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    color: AppColors.textMuted(context),
  );
}

// ─────────────────────────── Sub-komponen kecil ─────────────────────────────

/// Bungkus [child] dengan Hero (`cover-<id>`) hanya kalau [enable] true.
Widget _maybeHero({
  required bool enable,
  required int animeId,
  required Widget child,
}) {
  return enable ? Hero(tag: 'cover-$animeId', child: child) : child;
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, this.big = false});

  final int rank;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 8 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: _medalColor(rank),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '#$rank',
        style: GoogleFonts.jetBrainsMono(
          fontSize: big ? 13 : 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
          const SizedBox(width: 2),
          Text(
            (score / 10).toStringAsFixed(2),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final RankTrend trend;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (trend) {
      RankTrend.rising => (Icons.arrow_drop_up_rounded, AppColors.success),
      RankTrend.falling => (Icons.arrow_drop_down_rounded, AppColors.error),
      RankTrend.steady => (Icons.remove_rounded, AppColors.textMuted(context)),
      RankTrend.fresh => (Icons.fiber_new_rounded, AppColors.primary),
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(1),
      child: Icon(icon, size: trend == RankTrend.fresh ? 13 : 18, color: color),
    );
  }
}
