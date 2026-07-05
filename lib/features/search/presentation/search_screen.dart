import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/section_header.dart';
import '../../discover/data/anime_repository.dart';
import '../../discover/presentation/discover_providers.dart';
import 'search_providers.dart';
import 'widgets/anime_compact_card.dart';
import 'widgets/anime_list_card.dart';
import 'widgets/filter_dropdown.dart';
import 'widgets/sort_dropdown.dart';
import 'widgets/view_mode_toggle.dart';
import '../../../core/theme/app_radius.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild saat preferensi Bahasa Judul berubah → displayTitle ikut refresh.
    ref.watch(appSettingsProvider.select((s) => s.titleLanguage));
    final query = ref.watch(searchQueryProvider);
    final genres = ref.watch(selectedGenresProvider);
    final year = ref.watch(selectedYearProvider);
    final season = ref.watch(selectedSeasonProvider);
    final format = ref.watch(selectedFormatProvider);
    final airingStatus = ref.watch(selectedAiringStatusProvider);
    final asyncResults = ref.watch(searchResultsProvider);
    final hasQuery = query.trim().length >= 2;
    final hasAnyFilter =
        genres.isNotEmpty ||
        year != null ||
        season != null ||
        format != null ||
        airingStatus != null;
    final showResults = hasQuery || hasAnyFilter;

    // **Sync controller dengan state query** — sebelumnya bug: di-set
    // langsung di build() bikin infinite rebuild → screen blank pas balik
    // dari tab lain. Pakai ref.listen biar cuma fire saat state berubah.
    ref.listen<String>(searchQueryProvider, (prev, next) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    // **Auto-save query ke history** saat search return result non-empty.
    // Type generic dihapus — biar dart infer dari provider type yang benar
    // (`AsyncValue<List<Anime>>`). Sebelumnya pakai `List<dynamic>` yang
    // mismatch → ref.listen throw TypeError.
    ref.listen(searchResultsProvider, (_, next) {
      next.whenData((list) {
        if (list.isEmpty) return;
        final currentQuery = ref.read(searchQueryProvider).trim();
        if (currentQuery.length < 2) return;
        ref.read(searchHistoryRepositoryProvider).add(currentQuery);
      });
    });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Headline serif italic
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                context.l10n.searchHeader,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 34,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary(context),
                  height: 1.05,
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                onChanged: (val) =>
                    ref.read(searchQueryProvider.notifier).state = val,
                style: GoogleFonts.roboto(fontSize: 14),
                decoration: InputDecoration(
                  hintText: query.isEmpty
                      ? context.l10n.searchHint
                      : '"$query"',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        ),
                ),
              ),
            ),

            // 5 filter dropdown row (Genres / Year / Season / Format / Status)
            const SizedBox(height: 18),
            const _FilterBar(),

            // Sort dropdown + view mode toggle (kanan align)
            const SizedBox(height: 12),
            const _SortAndViewRow(),

            // Conditional content
            if (!showResults)
              const _DefaultState()
            else
              _ResultsState(
                asyncResults: asyncResults,
                query: query,
                genres: genres,
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Filter bar 5-column — AniList style.
/// Layout: Wrap supaya kalau layar sempit (mobile <600px), filter
/// wrap ke baris kedua. Tablet+ semua 5 dalam satu baris.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  static String _seasonLabel(String s) => switch (s) {
    'WINTER' => 'Winter',
    'SPRING' => 'Spring',
    'SUMMER' => 'Summer',
    'FALL' => 'Fall',
    _ => s,
  };

  static String _formatLabel(String f) => switch (f) {
    'TV' => 'TV Show',
    'TV_SHORT' => 'TV Short',
    'MOVIE' => 'Movie',
    'OVA' => 'OVA',
    'ONA' => 'ONA',
    'SPECIAL' => 'Special',
    'MUSIC' => 'Music',
    _ => f,
  };

  static String _statusLabel(String s) => switch (s) {
    'RELEASING' => 'Releasing',
    'FINISHED' => 'Finished',
    'NOT_YET_RELEASED' => 'Not Yet Released',
    'CANCELLED' => 'Cancelled',
    'HIATUS' => 'Hiatus',
    _ => s,
  };

  Future<void> _pickGenres(BuildContext context, WidgetRef ref) async {
    Haptic.selection();
    // Reuse existing GenrePickerScreen (full-screen multi-select).
    await context.push(AppRoutes.genrePicker);
  }

  Future<void> _pickYear(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final now = DateTime.now().year;
    final picked = await showSingleSelectSheet<int?>(
      context: context,
      title: context.l10n.searchFilterYear,
      currentValue: current,
      options: [
        (value: null, label: 'Any'),
        for (var y = now + 1; y >= 1980; y--) (value: y, label: '$y'),
      ],
    );
    if (picked == null && current == null) return;
    ref.read(selectedYearProvider.notifier).state = picked;
  }

  Future<void> _pickSeason(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final picked = await showSingleSelectSheet<String?>(
      context: context,
      title: context.l10n.searchFilterSeason,
      currentValue: current,
      options: const [
        (value: null, label: 'Any'),
        (value: 'WINTER', label: 'Winter (Jan-Mar)'),
        (value: 'SPRING', label: 'Spring (Apr-Jun)'),
        (value: 'SUMMER', label: 'Summer (Jul-Sep)'),
        (value: 'FALL', label: 'Fall (Okt-Des)'),
      ],
    );
    if (picked == null && current == null) return;
    ref.read(selectedSeasonProvider.notifier).state = picked;
  }

  Future<void> _pickFormat(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final picked = await showSingleSelectSheet<String?>(
      context: context,
      title: 'Format',
      currentValue: current,
      options: const [
        (value: null, label: 'Any'),
        (value: 'TV', label: 'TV Show'),
        (value: 'TV_SHORT', label: 'TV Short'),
        (value: 'MOVIE', label: 'Movie'),
        (value: 'OVA', label: 'OVA'),
        (value: 'ONA', label: 'ONA'),
        (value: 'SPECIAL', label: 'Special'),
        (value: 'MUSIC', label: 'Music Video'),
      ],
    );
    if (picked == null && current == null) return;
    ref.read(selectedFormatProvider.notifier).state = picked;
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final picked = await showSingleSelectSheet<String?>(
      context: context,
      title: 'Status Airing',
      currentValue: current,
      options: const [
        (value: null, label: 'Any'),
        (value: 'RELEASING', label: 'Releasing'),
        (value: 'FINISHED', label: 'Finished'),
        (value: 'NOT_YET_RELEASED', label: 'Not Yet Released'),
        (value: 'CANCELLED', label: 'Cancelled'),
        (value: 'HIATUS', label: 'Hiatus'),
      ],
    );
    if (picked == null && current == null) return;
    ref.read(selectedAiringStatusProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(selectedGenresProvider);
    final year = ref.watch(selectedYearProvider);
    final season = ref.watch(selectedSeasonProvider);
    final format = ref.watch(selectedFormatProvider);
    final status = ref.watch(selectedAiringStatusProvider);

    // Width per dropdown — adaptive. Mobile pakai (width-20*2-gap*4)/5,
    // Tablet+ pakai 150px fix biar tidak terlalu lebar di desktop.
    final tier = Breakpoints.of(context);
    final mq = MediaQuery.sizeOf(context);
    final isCompact = tier == DeviceTier.mobile;
    final itemWidth = isCompact
        ? (mq.width - 40 - 24) /
              3 // 3 per row di mobile
        : 160.0;

    final children = [
      SizedBox(
        width: itemWidth,
        child: FilterDropdown(
          label: 'Genres',
          valueLabel: genres.isEmpty ? 'Any' : '${genres.length} dipilih',
          isActive: genres.isNotEmpty,
          onTap: () => _pickGenres(context, ref),
        ),
      ),
      SizedBox(
        width: itemWidth,
        child: FilterDropdown(
          label: 'Year',
          valueLabel: year != null ? '$year' : 'Any',
          isActive: year != null,
          onTap: () => _pickYear(context, ref, year),
        ),
      ),
      SizedBox(
        width: itemWidth,
        child: FilterDropdown(
          label: 'Season',
          valueLabel: season != null ? _seasonLabel(season) : 'Any',
          isActive: season != null,
          onTap: () => _pickSeason(context, ref, season),
        ),
      ),
      SizedBox(
        width: itemWidth,
        child: FilterDropdown(
          label: 'Format',
          valueLabel: format != null ? _formatLabel(format) : 'Any',
          isActive: format != null,
          onTap: () => _pickFormat(context, ref, format),
        ),
      ),
      SizedBox(
        width: itemWidth,
        child: FilterDropdown(
          label: 'Airing Status',
          valueLabel: status != null ? _statusLabel(status) : 'Any',
          isActive: status != null,
          onTap: () => _pickStatus(context, ref, status),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: children,
      ),
    );
  }
}

/// Row di bawah filter bar — sort dropdown + view mode toggle. Align kanan.
class _SortAndViewRow extends StatelessWidget {
  const _SortAndViewRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SortDropdown(),
          const SizedBox(width: 8),
          Container(
            height: 18,
            width: 1,
            color: AppColors.borderColor(context),
          ),
          const SizedBox(width: 8),
          const ViewModeToggle(),
        ],
      ),
    );
  }
}

class _DefaultState extends StatelessWidget {
  const _DefaultState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 24),
        _RecentSearches(),
        _TrendingIndonesia(),
      ],
    );
  }
}

/// Recent search history dari Hive box `search_history`.
///
/// Item disimpan auto saat user mencari (debounce + query >=2 char).
/// Tap item → set search query ke value tsb. Tap × → hapus dari history.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(searchHistoryProvider);

    return asyncHistory.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const MonoLabel('TERAKHIR DICARI'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Haptic.medium();
                      ref.read(searchHistoryRepositoryProvider).clearAll();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'hapus',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...history.map(
              (item) => Dismissible(
                key: ValueKey('history-$item'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  ref.read(searchHistoryRepositoryProvider).remove(item);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: AppColors.error.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Haptic.light();
                    ref.read(searchQueryProvider.notifier).state = item;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppColors.textMuted(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 16,
                          color: AppColors.textMuted(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrendingIndonesia extends ConsumerWidget {
  const _TrendingIndonesia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrending = ref.watch(
      discoverSectionProvider(DiscoverSection.trending),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: MonoLabel('TRENDING DI INDONESIA'),
        ),
        asyncTrending.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorRetry(
            compact: true,
            message: e.toString(),
            onRetry: () => ref.invalidate(
              discoverSectionProvider(DiscoverSection.trending),
            ),
          ),
          data: (list) => Column(
            children: list.take(4).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final anime = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: GestureDetector(
                  onTap: () => context.push(
                    AppRoutes.animeDetailPath(anime.id.toString()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontStyle: FontStyle.italic,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(
                            width: 36,
                            height: 50,
                            child: anime.coverImage.isEmpty
                                ? Container(color: AppColors.surface(context))
                                : Image.network(
                                    anime.coverImage,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                anime.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+${20 - i * 4}% pencarian hari ini',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ResultsState extends ConsumerWidget {
  const _ResultsState({
    required this.asyncResults,
    required this.query,
    required this.genres,
  });

  final AsyncValue asyncResults;
  final String query;
  final List<String> genres;

  /// Build pesan empty state yang kontekstual berdasarkan filter aktif.
  String _emptyMessage(BuildContext context) {
    final trimmed = query.trim();
    final hasQuery = trimmed.isNotEmpty;
    final hasGenres = genres.isNotEmpty;
    final genreStr = genres.join(', ');
    if (hasQuery && hasGenres) {
      return context.l10n.searchNoResultsQueryGenre(trimmed, genreStr);
    }
    if (hasQuery) return context.l10n.searchNoResultsQuery(trimmed);
    if (hasGenres) return context.l10n.searchNoResultsGenre(genreStr);
    return context.l10n.searchNoResults;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncResults.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: AnimeGridSkeleton(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorRetry(
          message: e.toString(),
          onRetry: () => ref.invalidate(searchResultsProvider),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                _emptyMessage(context),
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
              ),
            ),
          );
        }
        final viewMode = ref.watch(viewModeProvider);
        switch (viewMode) {
          case SearchViewMode.compact:
            // Compact: smaller cells, more columns (mobile 4, desktop 8-10).
            final baseCols = Breakpoints.columnsFor(context);
            final compactCols = (baseCols * 1.4).round();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: compactCols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: 0.55,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => AnimeCompactCard(
                anime: list[i],
                onTap: () => context.push(
                  AppRoutes.animeDetailPath(list[i].id.toString()),
                ),
              ),
            );
          case SearchViewMode.large:
            // Large: AnimeCard standar, columns adaptive.
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Breakpoints.columnsFor(context),
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.48,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => AnimeCard(
                anime: list[i],
                width: double.infinity,
                onTap: () => context.push(
                  AppRoutes.animeDetailPath(list[i].id.toString()),
                ),
              ),
            );
          case SearchViewMode.list:
            // List: detailed horizontal card stacked. Desktop pakai 2 col
            // grid biar tidak terlalu lebar.
            final tier = Breakpoints.of(context);
            final listCols = tier == DeviceTier.desktopLg
                ? 3
                : tier == DeviceTier.desktop
                ? 2
                : 1;
            if (listCols == 1) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => AnimeListCard(
                  anime: list[i],
                  onTap: () => context.push(
                    AppRoutes.animeDetailPath(list[i].id.toString()),
                  ),
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: listCols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 180,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => AnimeListCard(
                anime: list[i],
                onTap: () => context.push(
                  AppRoutes.animeDetailPath(list[i].id.toString()),
                ),
              ),
            );
        }
      },
    );
  }
}
